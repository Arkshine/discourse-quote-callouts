import { triggerEvent } from "@ember/test-helpers";

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

export function setCursorAt(view, pos) {
  view.dispatch(
    view.state.tr.setSelection(
      view.state.selection.constructor.create(view.state.doc, pos)
    )
  );
}

export function isInsideNode(selection, nodeTypeName) {
  const { $from } = selection;
  for (let d = $from.depth; d >= 0; d--) {
    if ($from.node(d).type.name === nodeTypeName) {
      return true;
    }
  }
  return false;
}

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

export function insertEmptyParagraphAt(view, pos) {
  const { schema } = view.state;
  view.dispatch(view.state.tr.insert(pos, schema.nodes.paragraph.create()));
}

// No coordinates, so prosemirror-gapcursor's handleClick runs first.
export function callHandleClick(view, pos) {
  const event = new MouseEvent("click");
  for (const plugin of view.state.plugins) {
    if (plugin.props.handleClick?.(view, pos, event)) {
      return true;
    }
  }
  return false;
}

// Real click just below the node at `pos`, so ProseMirror resolves coordinates.
export async function clickBelow(view, pos) {
  const dom = view.nodeDOM(pos);
  dom.scrollIntoView({ block: "center" });
  const rect = dom.getBoundingClientRect();
  const opts = { clientX: rect.left + 20, clientY: rect.bottom + 1 };
  const target = document.elementFromPoint(opts.clientX, opts.clientY);
  await triggerEvent(target, "mousedown", opts);
  await triggerEvent(target, "mouseup", opts);
}

// Goes through handleTextInput so input rules fire.
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

// "parent: before | after", or null when not a gap cursor.
export function gapCursorAt(view) {
  const { selection } = view.state;
  if (selection.toJSON().type !== "gapcursor") {
    return null;
  }
  const { $from } = selection;
  return `${$from.parent.type.name}: ${$from.nodeBefore?.type.name ?? "start"} | ${$from.nodeAfter?.type.name ?? "end"}`;
}
