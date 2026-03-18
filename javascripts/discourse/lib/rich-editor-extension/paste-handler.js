import { CALLOUT_REGEX, findCalloutOptions } from "../config";
import { capitalizeFirstLetter } from "../utils";

// Converts pasted markdown callout syntax (e.g. `> [!note]`) into callout
// nodes. Handles both blockquote-based and plain-text `> ` pastes, with
// recursive support for nested callouts.

const PLAIN_TEXT_QUOTE_PREFIX = /^\s*>\s?/;

// Strips `stripLen` leading characters from the text content of a fragment.
function sliceFragment(fragment, stripLen, schema) {
  const nodes = [];
  let remaining = stripLen;

  fragment.forEach((node) => {
    if (node.isText && remaining > 0) {
      const len = node.text.length;
      if (len > remaining) {
        nodes.push(schema.text(node.text.slice(remaining), node.marks));
      }
      remaining -= len;
    } else {
      nodes.push(node);
    }
  });

  return fragment.constructor.from(nodes);
}

// Tries to convert a blockquote node into a callout.
// Returns null if the first paragraph doesn't match the `[!type]` pattern.
function convertBlockquoteToCallout(blockquote, schema) {
  const firstPara = blockquote.firstChild;
  const match =
    firstPara?.type === schema.nodes.paragraph &&
    firstPara.textContent.match(CALLOUT_REGEX);

  if (!match) {
    return null;
  }

  const { callout: type, fold, marker } = match.groups;
  const lowerType = type.toLowerCase();
  const foldAttr = fold || "";

  const titleContent = sliceFragment(firstPara.content, marker.length, schema);
  const defaultTitle =
    findCalloutOptions(lowerType)?.title ?? capitalizeFirstLetter(lowerType);

  const titleNode = schema.nodes.callout_title.create(
    { type: lowerType, fold: foldAttr },
    titleContent.size ? titleContent : [schema.text(defaultTitle)]
  );

  const bodyContent = Array.from(
    { length: blockquote.childCount - 1 },
    (_, i) => blockquote.child(i + 1)
  );

  if (!bodyContent.length) {
    bodyContent.push(schema.nodes.paragraph.create());
  }

  return schema.nodes.callout.create({ type: lowerType, fold: foldAttr }, [
    titleNode,
    schema.nodes.callout_body.create(null, bodyContent),
  ]);
}

// Recursively walks a fragment, converting callout-like content into callout
// nodes. Plain-text `> ` paragraphs are buffered, then flushed as a
// blockquote and converted. Existing blockquotes are converted directly.
export function transformFragmentsToCallouts(fragment, schema) {
  const nodes = [];
  let buffer = [];
  let changed = false;

  const flush = () => {
    if (!buffer.length) {
      return;
    }

    changed = true;

    const content = fragment.constructor.from(buffer);
    buffer = [];

    const transformed = transformFragmentsToCallouts(content, schema);
    const bq = schema.nodes.blockquote.create(null, transformed);
    nodes.push(convertBlockquoteToCallout(bq, schema) || bq);
  };

  fragment.forEach((node) => {
    const match =
      node.type === schema.nodes.paragraph &&
      node.textContent.match(PLAIN_TEXT_QUOTE_PREFIX);

    if (match) {
      buffer.push(
        node.copy(sliceFragment(node.content, match[0].length, schema))
      );
      return;
    }

    flush();

    let newNode = node;
    const newContent = transformFragmentsToCallouts(node.content, schema);

    if (newContent !== node.content) {
      newNode = node.copy(newContent);
      changed = true;
    }

    if (newNode.type === schema.nodes.blockquote) {
      const callout = convertBlockquoteToCallout(newNode, schema);
      if (callout) {
        newNode = callout;
        changed = true;
      }
    }

    nodes.push(newNode);
  });

  flush();

  return changed ? fragment.constructor.from(nodes) : fragment;
}
