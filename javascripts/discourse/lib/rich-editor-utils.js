import { findCalloutOptions } from "./config";
import { capitalizeFirstLetter } from "./utils";

/**
 * Checks if the cursor is at the start of a block.
 * from https://github.com/ProseMirror/prosemirror-commands/blob/master/src/commands.ts
 *
 * @param {Object} state - The current state of the editor.
 * @param {Object} view - The view of the editor.
 * @returns {Object|null} The cursor position if at the start of a block, null otherwise.
 */
export function atBlockStart(state, view) {
  let { $cursor } = state.selection;
  if (
    !$cursor ||
    (view ? !view.endOfTextblock("backward", state) : $cursor.parentOffset > 0)
  ) {
    return null;
  }
  return $cursor;
}

// https://github.com/discourse/discourse/pull/31933#discussion_r2019739410
export function changedDescendants(old, cur, f, offset = 0) {
  const oldSize = old.childCount,
    curSize = cur.childCount;
  outer: for (let i = 0, j = 0; i < curSize; i++) {
    const child = cur.child(i);
    for (let scan = j, e = Math.min(oldSize, i + 5); scan < e; scan++) {
      if (old.child(scan) === child) {
        j = scan + 1;
        offset += child.nodeSize;
        continue outer;
      }
    }
    f(child, offset);
    if (j < oldSize && old.child(j).sameMarkup(child)) {
      changedDescendants(old.child(j), child, f, offset + 1);
    } else {
      child.nodesBetween(0, child.content.size, f, offset + 1);
    }
    offset += child.nodeSize;
  }
}

/**
 * Finds the nearest ancestor node of a given type in the current selection.
 *
 * @param {Object} state - The current state of the editor.
 * @param {Object} nodeType - The type of node to find.
 * @param {Object} attrs - Optional attributes to narrow the match.
 * @returns {Object|null} The ancestor { node, depth, pos } if found, null otherwise.
 */
export function findAncestor(state, nodeType, attrs = {}) {
  const { $from } = state.selection;
  const hasAttrs = Object.keys(attrs).length > 0;

  for (let depth = $from.depth; depth >= 0; depth--) {
    const node = $from.node(depth);
    if (node.type === nodeType) {
      if (
        !hasAttrs ||
        Object.keys(attrs).every((key) => node.attrs[key] === attrs[key])
      ) {
        return { node, depth, pos: $from.before(depth) };
      }
    }
  }

  return null;
}

/**
 * Returns the document position of the innermost callout the cursor is in,
 * or null. Mirrors the plugin's logic so components can read the current
 * active callout on mount without waiting for an appEvent.
 *
 * @param {import("prosemirror-view").EditorView} view
 * @returns {number|null}
 */
export function activeCalloutPosFromView(view) {
  const { selection, schema } = view.state;
  if (selection.node?.type === schema.nodes.callout) {
    return selection.from;
  }
  const ancestor = findAncestor(view.state, schema.nodes.callout);
  return ancestor?.pos ?? null;
}

/**
 * Checks if a node of a specific type is present in the current selection,
 * with optional scoping by specific attributes.
 *
 * @param {Object} state - The current state of the editor.
 * @param {Object} nodeType - The type of node to find.
 * @param {Object} attrs - Optional attributes to narrow the match.
 * @returns {boolean} True if the node is present, false otherwise.
 */
export function inNode(state, nodeType, attrs = {}) {
  return findAncestor(state, nodeType, attrs) !== null;
}

/**
 * Builds a callout node with a title and body.
 *
 * @param {Object} schema - The schema of the editor.
 * @param {string} type - The type of the callout.
 * @param {Object} options - Optional parameters.
 * @param {string} options.title - The title of the callout.
 * @param {Array} options.bodyNodes - The nodes to wrap in the body.
 * @returns {Object} The callout node.
 */
export function buildCallout(schema, type, { title = "", bodyNodes } = {}) {
  const options = findCalloutOptions(type);
  if (!options) {
    type = settings.callout_fallback_type || "note";
  }
  const titleText = title || options?.title || capitalizeFirstLetter(type);
  const titleNode = schema.nodes.callout_title.create(
    { type },
    schema.text(titleText)
  );
  const bodyContent = bodyNodes || [schema.nodes.paragraph.create()];
  const bodyNode = schema.nodes.callout_body.create(null, bodyContent);

  return schema.nodes.callout.create({ type, hasCustomTitle: !!title }, [
    titleNode,
    bodyNode,
  ]);
}

/**
 * Insert a block node at an inline selection:
 * - consumes adjacent hard_breaks to avoid stray <br>s at split edges
 * - removes empty sibling paragraphs left by the paragraph split
 *
 * @param {Object} tr - The transaction to modify.
 * @param {Object} schema - The schema of the editor.
 * @param {Object} selection - The current selection.
 * @param {Object} node - The node to insert.
 * @returns {Object} The modified transaction.
 */
export function insertBlockAtInlineSelection(tr, schema, selection, node) {
  const { $from, $to } = selection;
  const blockStart = $from.before($from.depth);

  const from =
    $from.nodeBefore?.type === schema.nodes.hard_break
      ? selection.from - 1
      : selection.from;
  const to =
    $to.nodeAfter?.type === schema.nodes.hard_break
      ? selection.to + 1
      : selection.to;
  tr.replaceWith(from, to, node);

  let insertedPos = null;
  tr.doc.nodesBetween(blockStart, tr.doc.content.size, (nd, pos) => {
    if (!insertedPos && nd.type === node.type && pos >= blockStart) {
      insertedPos = pos;
      return false;
    }
  });

  if (insertedPos == null) {
    return null;
  }

  const afterPos = insertedPos + tr.doc.nodeAt(insertedPos).nodeSize;
  const nodeAfter = tr.doc.nodeAt(afterPos);
  if (nodeAfter?.type === schema.nodes.paragraph && !nodeAfter.content.size) {
    tr.delete(afterPos, afterPos + nodeAfter.nodeSize);
  }

  const nodeBefore = tr.doc.resolve(insertedPos).nodeBefore;
  if (nodeBefore?.type === schema.nodes.paragraph && !nodeBefore.content.size) {
    tr.delete(insertedPos - nodeBefore.nodeSize, insertedPos);
    insertedPos -= nodeBefore.nodeSize;
  }

  return insertedPos;
}

/**
 * Checks if a node of a specific type is active in the current selection,
 * (with optional scoping by specific attributes), and that no other nodes
 * of any other type are present in the selection.
 *
 * @param {Object} state - The current state of the editor.
 * @param {Object} nodeType - The type of node to find.
 * @param {Object} attrs - Optional attributes to narrow the match.
 * @returns {boolean} True if the node is active, false otherwise.
 */
export function isNodeActive(state, nodeType, attrs = {}) {
  const { from, to, empty } = state.selection;
  const nodeRanges = [];

  state.doc.nodesBetween(from, to, (node, pos) => {
    if (node.isText) {
      return;
    }

    const relativeFrom = Math.max(from, pos);
    const relativeTo = Math.min(to, pos + node.nodeSize);

    nodeRanges.push({
      node,
      from: relativeFrom,
      to: relativeTo,
    });
  });

  const selectionRange = to - from;

  const matchedNodeRanges = nodeRanges
    .filter((nodeRange) => {
      return nodeType.name === nodeRange.node.type.name;
    })
    .filter((nodeRange) => {
      if (!Object.keys(attrs).length) {
        return true;
      } else {
        return Object.keys(attrs).every(
          (key) => nodeRange.node.attrs[key] === attrs[key]
        );
      }
    });

  if (empty) {
    return !!matchedNodeRanges.length;
  }

  // Determines if there are other nodes not matching nodeType in the selection
  // by summing selection ranges to find "gaps" in the selection.
  const range = matchedNodeRanges.reduce(
    (sum, nodeRange) => sum + nodeRange.to - nodeRange.from,
    0
  );

  // If there are no "gaps" in the selection, it means the nodeType is active
  // with no other node types selected.
  return range >= selectionRange;
}

export function stripPrefix(inlineToken, prefixLen) {
  let remaining = prefixLen;
  const out = [];

  for (const tok of inlineToken.children || []) {
    if (remaining <= 0) {
      out.push(tok);
      continue;
    }

    if (tok.type !== "text") {
      continue;
    }

    const len = tok.content.length;
    if (len > remaining) {
      out.push({ ...tok, content: tok.content.slice(remaining) });
      remaining = 0;
    } else {
      remaining -= len;
    }
  }

  inlineToken.children = out;
}

export function splitAtFirstLineBreak(inlineToken) {
  const children = inlineToken.children || [];
  const title = [];
  const rest = [];
  let foundBreak = false;

  for (const tok of children) {
    if (foundBreak) {
      rest.push(tok);
      continue;
    }

    if (tok.type === "softbreak" || tok.type === "hardbreak") {
      foundBreak = true;
      continue;
    }

    if (tok.type === "text") {
      const splitIdx = tok.content.indexOf("\n");
      if (splitIdx !== -1) {
        title.push({ ...tok, content: tok.content.slice(0, splitIdx) });
        const remainder = tok.content.slice(splitIdx + 1);
        if (remainder) {
          rest.push({ ...tok, content: remainder });
        }
        foundBreak = true;
        continue;
      }
    }

    title.push(tok);
  }

  return { title, rest };
}
