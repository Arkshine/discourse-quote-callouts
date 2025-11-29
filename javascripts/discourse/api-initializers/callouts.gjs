import { withPluginApi } from "discourse/lib/plugin-api";
import QuoteCallout from "../components/quote-callout";
import discourseComputed from "discourse/lib/decorators";
import { isNodeEmpty, processCalloutSettings } from "../lib/utils.js"

// Regex to detect callout syntax: [!type][+-] optional title
const CALLOUT_REGEX = /^\[!(?<callout>[^\]]+)\](?<fold>[+-])?\s*(?<title>.*)/;

export default {
  name: "discourse-quote-callouts",

  initialize() {
    withPluginApi("1.39.0", (api) => {
      // Modify topic model to strip callout markers from excerpts
      api.modifyClass("model:topic", (Superclass) => {
        return class extends Superclass {
          @discourseComputed("excerpt")
          escapedExcerpt() {
            return super.escapedExcerpt?.replace(CALLOUT_EXCERPT_REGEX, "");
          }
        };
      });

      // Apply transformations to posts
      api.decorateCookedElement((element, helper) => {
        transformBlockquotes(element, helper);
      });

      // Apply transformations to chat messages
      if (api.decorateChatMessage) {
        api.decorateChatMessage((element, helper) => {
          transformBlockquotes(element, helper);
        });
      }
    });
  },
};

/**
 * Transform blockquotes into QuoteCallout components
 */
function transformBlockquotes(element, helper) {
  const calloutSettings = processCalloutSettings();

  element.querySelectorAll("blockquote").forEach((blockquote) => {
    const firstParagraph = blockquote.querySelector("p");
    if (!firstParagraph) return;

    const match = parseCallout(firstParagraph);
    if (!match) return;

    const { type, title, fold } = processCallout(firstParagraph, match);

    // Collect all children (including modified first paragraph)
    const children = Array.from(blockquote.children);

    // Replace blockquote with container
    const container = document.createElement("div");
    blockquote.replaceWith(container);

    // Mount Glimmer component
    helper.renderGlimmer(container, QuoteCallout, {
      type,
      title,
      fold,
      children,
      calloutSettings
    });
  });
}

/**
 * Parse the first paragraph text for callout syntax
 */
function parseCallout(firstParagraph) {
  const text = firstParagraph.textContent.trim();
  return text.match(CALLOUT_REGEX);
}

/**
 * Process the callout: remove marker, extract title if present
 */
function processCallout(firstParagraph, match) {
  const type = match.groups.callout?.toLowerCase() ?? "note";
  const fold = match.groups.fold?.trim() || "";

  // Remove the callout marker only, leave other tags intact
  firstParagraph.innerHTML = firstParagraph.innerHTML
    .replace(`[!${match.groups.callout}]${fold}`, "")
    .trimLeft();

  const title = extractTitle(firstParagraph, match);

  // Remove empty first paragraph
  if (isNodeEmpty(firstParagraph)) {
    firstParagraph.remove();
  }

  return { type, fold, title };
}

/**
 * Extract custom title from the first paragraph if present
 */
function extractTitle(firstParagraph, match) {
  const firstChild = firstParagraph.firstChild;
  const hasCustomTitle =
    !!match.groups?.title?.trim() ||
    (firstChild?.nextSibling?.nodeType === Node.ELEMENT_NODE &&
      firstChild.nextSibling.tagName !== "BR");

  if (!hasCustomTitle) return null;

  const nodes = Array.from(firstParagraph.childNodes);
  const result = [];

  for (const node of nodes) {
    if (
      node.nodeName === "BR" ||
      (node.nodeType === Node.TEXT_NODE && node.textContent.startsWith("\n"))
    ) {
      // Remove break/newline before stopping
      node.remove();
      break;
    }

    // Serialize each node to HTML or text
    result.push(node.outerHTML || node.textContent);

    // Remove node from DOM
    node.remove();
  }

  return result.length > 0 ? result.join("") : null;
}