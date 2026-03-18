/**
 * Finds the first node matching `nodeTypeName` (and optional predicate)
 * in the document.
 */
export function findNode(view, nodeTypeName, predicate) {
  let found = null;
  view.state.doc.descendants((node, pos, parent) => {
    if (!found && node.type.name === nodeTypeName) {
      if (!predicate || predicate(node, pos, parent)) {
        found = { node, pos };
        return false;
      }
    }
  });
  return found;
}

/**
 * Places the cursor at the first content position inside the first
 * node of `nodeTypeName`.
 */
export function setCursorInNode(view, nodeTypeName, predicate = null) {
  const result = findNode(view, nodeTypeName, predicate);
  if (!result) {
    return null;
  }

  const $pos = view.state.doc.resolve(result.pos + 1);
  view.dispatch(
    view.state.tr.setSelection(view.state.selection.constructor.near($pos))
  );
  return result.pos;
}

/**
 * Places the cursor at an exact document position.
 */
export function setCursorAt(view, pos) {
  const $pos = view.state.doc.resolve(pos);
  view.dispatch(
    view.state.tr.setSelection(
      view.state.selection.constructor.create(view.state.doc, $pos)
    )
  );
}

/**
 * Walks upward from `selection.$from` and returns `true` if any
 * ancestor has the given type name.
 */
export function isInsideNode(selection, nodeTypeName) {
  const { $from } = selection;
  for (let d = $from.depth; d >= 0; d--) {
    if ($from.node(d).type.name === nodeTypeName) {
      return true;
    }
  }
  return false;
}

/**
 * Asserts that the cursor is inside a paragraph within a callout body.
 */
export function assertCursorInBody(
  assert,
  view,
  message = "cursor is inside the callout body"
) {
  assert.strictEqual(
    view.state.selection.$from.parent.type.name,
    "paragraph",
    "cursor is inside a paragraph"
  );
  assert.true(isInsideNode(view.state.selection, "callout_body"), message);
}

/**
 * Inserts an empty paragraph at the given document position.
 */
export function insertEmptyParagraphAt(view, pos) {
  const { schema } = view.state;
  view.dispatch(view.state.tr.insert(pos, schema.nodes.paragraph.create()));
}

/**
 * Directly invokes the `handleClick` plugin prop at the given position.
 */
export function callHandleClick(view, pos) {
  const event = new MouseEvent("click");
  for (const plugin of view.state.plugins) {
    if (plugin.props.handleClick?.(view, pos, event)) {
      return true;
    }
  }
  return false;
}

/**
 * Simulates typing text character by character into the ProseMirror editor,
 * triggering input rules via `handleTextInput`.
 */
export async function typeText(view, text, settled) {
  for (const char of text) {
    const { from, to } = view.state.selection;
    const handled = view.someProp("handleTextInput", (f) =>
      f(view, from, to, char)
    );

    if (!handled) {
      view.dispatch(view.state.tr.insertText(char, from, to));
    }

    await settled();
  }
}
