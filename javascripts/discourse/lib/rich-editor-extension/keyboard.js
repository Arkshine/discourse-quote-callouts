import { findAncestor } from "../rich-editor-utils";

// Some QoL improvements when navigating callouts using arrow keys
// to make easier to move in and out of nested callouts.
export function handleArrowDown({
  view,
  $from,
  schema,
  dispatch,
  state,
  TextSelection,
}) {
  if (!view.endOfTextblock("down")) {
    return false;
  }

  const parent = $from.parent;
  const isEmptyParagraph =
    parent.type === schema.nodes.paragraph && parent.content.size === 0;

  // From the title into an empty body:
  // insert a paragraph and move cursor into it.
  //
  //   Before                   After (↓)
  //   ┌─ callout ────────┐     ┌─ callout ────────┐
  //   │  Title|          │     │  Title           │
  //   │  (empty body)    │     │  |               │
  //   └──────────────────┘     └──────────────────┘
  const titleAncestor = findAncestor(state, schema.nodes.callout_title);
  if (titleAncestor) {
    const calloutNode = $from.node(titleAncestor.depth - 1);
    const bodyNode = calloutNode.childCount > 1 ? calloutNode.child(1) : null;

    if (bodyNode && bodyNode.content.size === 0) {
      const bodyContentStart =
        titleAncestor.pos + titleAncestor.node.nodeSize + 1;
      const tr = state.tr.insert(
        bodyContentStart,
        schema.nodes.paragraph.create()
      );

      tr.setMeta("callout:keyboardNav", true);
      tr.setSelection(TextSelection.create(tr.doc, bodyContentStart + 1));
      dispatch(tr.scrollIntoView());

      return true;
    }
    return false;
  }

  // On a trailing empty paragraph inside the body:
  // remove it and move cursor after the callout (inserting a paragraph there
  // only when no content already exists).
  //
  //   Before                          After (↓)
  //   ┌─ outer ──────────────────┐    ┌─ outer ──────────────────┐
  //   │  ┌─ inner ───────────┐   │    │  ┌─ inner ───────────┐   │
  //   │  │  Title            │   │    │  │  Title            │   │
  //   │  │  Content          │   │    │  │  Content          │   │
  //   │  │  |                │   │    │  └───────────────────┘   │
  //   │  └───────────────────┘   │    │  |                       │
  //   └──────────────────────────┘    └──────────────────────────┘
  if (isEmptyParagraph) {
    const bodyAncestor = findAncestor(state, schema.nodes.callout_body);

    if (bodyAncestor) {
      const index = $from.index($from.depth - 1);

      if (index + 1 === bodyAncestor.node.childCount) {
        const trailingParaPos = $from.before($from.depth);
        const calloutAncestor = findAncestor(state, schema.nodes.callout);
        const posAfterCallout =
          calloutAncestor.pos + calloutAncestor.node.nodeSize;

        let tr = state.tr;

        tr.delete(trailingParaPos, trailingParaPos + parent.nodeSize);
        const newAfterPos = posAfterCallout - parent.nodeSize;

        // Only create a new paragraph when nothing exists after the callout.
        if (!state.doc.nodeAt(posAfterCallout)) {
          tr.insert(newAfterPos, schema.nodes.paragraph.create());
        }

        tr.setMeta("callout:keyboardNav", true);
        tr.setSelection(TextSelection.create(tr.doc, newAfterPos + 1));

        dispatch(tr.scrollIntoView());
        return true;
      }
    }
  }

  // At the last position in the callout:
  // insert a paragraph after.
  //
  //   Before                          After (↓)
  //   ┌─ outer ──────────────────┐    ┌─ outer ──────────────────┐
  //   │  ┌─ inner ───────────┐   │    │  ┌─ inner ───────────┐   │
  //   │  │  Title            │   │    │  │  Title            │   │
  //   │  │  Content|         │   │    │  │  Content          │   │
  //   │  └───────────────────┘   │    │  └───────────────────┘   │
  //   └──────────────────────────┘    │  |                       │
  //                                   └──────────────────────────┘
  const calloutAncestor = findAncestor(state, schema.nodes.callout);
  if (calloutAncestor) {
    const index = $from.index(calloutAncestor.depth - 1);
    const parentNode = $from.node(calloutAncestor.depth - 1);

    if (index + 1 === parentNode.childCount) {
      const afterPos = calloutAncestor.pos + calloutAncestor.node.nodeSize;
      const tr = state.tr.insert(afterPos, schema.nodes.paragraph.create());

      tr.setMeta("callout:keyboardNav", true);
      tr.setSelection(TextSelection.create(tr.doc, afterPos + 1));
      dispatch(tr.scrollIntoView());

      return true;
    }
  }

  return false;
}

export function handleArrowUp({
  view,
  $from,
  schema,
  dispatch,
  state,
  TextSelection,
}) {
  // From a position right after a callout whose body ends with a
  // nested callout (no paragraph to land on):
  // insert a paragraph at the end of that callout's body.
  //
  //   Before                          After (↑)
  //   ┌─ callout ──────────────────┐  ┌─ callout ──────────────────┐
  //   │  ┌─ nested ───────────┐    │  │  ┌─ nested ───────────┐    │
  //   │  │  ...               │    │  │  │  ...               │    │
  //   │  └────────────────────┘    │  │  └────────────────────┘    │
  //   └────────────────────────────┘  │  |                         │
  //   Text|                           └────────────────────────────┘
  if (view.endOfTextblock("up")) {
    const index = $from.index($from.depth - 1);
    if (index > 0) {
      const prevNode = $from.node($from.depth - 1).child(index - 1);

      if (prevNode.type === schema.nodes.callout) {
        const body = prevNode.child(1);
        const lastBodyChild = body.lastChild;

        if (!lastBodyChild || lastBodyChild.type === schema.nodes.callout) {
          // Insert a ¶ at the end of the callout's body
          const bodyEnd = $from.before($from.depth) - 2;

          const tr = state.tr.insert(bodyEnd, schema.nodes.paragraph.create());
          tr.setSelection(TextSelection.create(tr.doc, bodyEnd + 1));
          dispatch(tr.scrollIntoView());
          return true;
        }
      }
    }
  }

  const isEmptyParagraph =
    $from.parent.type === schema.nodes.paragraph &&
    $from.parent.content.size === 0;

  // From an empty paragraph right after the callout:
  // move back into the nested callout body.
  //
  //   Before                   After (↑)
  //   ┌─ callout ────────┐     ┌─ callout ────────┐
  //   │  ┌─ nested ────┐ │     │  ┌─ nested ────┐ │
  //   │  │  Content    │ │     │  │  Content    │ │
  //   │  └─────────────┘ │     │  │  |          │ │
  //   │  |               │     │  └─────────────┘ │
  //   └──────────────────┘     └──────────────────┘
  if (isEmptyParagraph) {
    const parentNode = $from.node($from.depth - 1);
    const index = $from.index($from.depth - 1);

    if (index > 0) {
      const prevNode = parentNode.child(index - 1);

      if (prevNode.type === schema.nodes.callout) {
        let allCalloutsAbove = true;
        for (let i = 0; i < index; i++) {
          if (parentNode.child(i).type !== schema.nodes.callout) {
            allCalloutsAbove = false;
            break;
          }
        }

        if (allCalloutsAbove) {
          const tr = state.tr.delete(
            $from.before($from.depth),
            $from.after($from.depth)
          );

          const prevCalloutBody = prevNode.child(1);
          const lastBodyChild = prevCalloutBody.lastChild;
          const hasTrailingEmpty =
            lastBodyChild?.type === schema.nodes.paragraph &&
            lastBodyChild.content.size === 0;

          const bodyEndPos = $from.before($from.depth) - 2;

          if (hasTrailingEmpty) {
            tr.setMeta("callout:keyboardNav", true);
            tr.setSelection(TextSelection.create(tr.doc, bodyEndPos));
          } else {
            tr.insert(bodyEndPos, schema.nodes.paragraph.create());
            tr.setMeta("callout:keyboardNav", true);
            tr.setSelection(TextSelection.create(tr.doc, bodyEndPos + 1));
          }

          dispatch(tr.scrollIntoView());
          return true;
        }
      }
    }

    // From the only empty paragraph in a callout body, move up to the title
    // and remove the paragraph. This is the reverse of ArrowDown/Enter from
    // the title which inserted it.
    //
    //   Before                   After (↑)
    //   ┌─ callout ────────┐     ┌─ callout ────────┐
    //   │  Title           │     │  Title|          │
    //   │  |               │     │  (empty body)    │
    //   └──────────────────┘     └──────────────────┘
    const bodyAncestor = findAncestor(state, schema.nodes.callout_body);
    if (bodyAncestor && bodyAncestor.node.childCount === 1) {
      const calloutAncestor = findAncestor(state, schema.nodes.callout);
      if (calloutAncestor) {
        const titleNode = calloutAncestor.node.child(0);
        const titleEndPos = calloutAncestor.pos + 2 + titleNode.content.size;

        const paraPos = $from.before($from.depth);
        const tr = state.tr.delete(paraPos, paraPos + $from.parent.nodeSize);

        tr.setMeta("callout:keyboardNav", true);
        tr.setSelection(TextSelection.create(tr.doc, titleEndPos));

        dispatch(tr.scrollIntoView());
        return true;
      }
    }
  }
  return false;
}

// Inside the title:
// move cursor into the body (inserting a paragraph first if the body is empty).
//
//   Before                   After (Enter)
//   ┌─ callout ────────┐     ┌─ callout ────────┐
//   │  Title|          │     │  Title           │
//   │  Some content    │     │  Some content|   │
//   └──────────────────┘     └──────────────────┘
export function handleEnter(
  { $from, schema, dispatch, state, TextSelection },
  event
) {
  const titleAncestor = findAncestor(state, schema.nodes.callout_title);
  if (!titleAncestor) {
    return false;
  }

  const { node: titleNode, depth: titleDepth, pos: titlePos } = titleAncestor;
  const calloutNode = $from.node(titleDepth - 1);
  if (calloutNode.type !== schema.nodes.callout || calloutNode.childCount < 2) {
    return false;
  }

  const bodyNode = calloutNode.child(1);
  if (bodyNode.type !== schema.nodes.callout_body) {
    return false;
  }

  event.preventDefault();

  const bodyContentStart = $from.after(titleDepth) + 1;
  let tr = state.tr;

  if (calloutNode.attrs.isCollapsed) {
    const calloutPos = $from.before(titleDepth - 1);
    tr = tr
      .setNodeMarkup(calloutPos, null, {
        ...calloutNode.attrs,
        isCollapsed: false,
        fold: "+",
      })
      .setNodeMarkup(titlePos, null, {
        ...titleNode.attrs,
        isCollapsed: false,
        fold: "+",
      });
  }

  if (
    bodyNode.childCount === 0 ||
    bodyNode.firstChild.type !== schema.nodes.paragraph
  ) {
    tr = tr.insert(bodyContentStart, schema.nodes.paragraph.create());
  }

  dispatch(
    tr
      .setMeta("callout:keyboardNav", true)
      .setSelection(TextSelection.create(tr.doc, bodyContentStart + 1))
      .scrollIntoView()
  );

  return true;
}

// Inside the title:
// ArrowLeft at position 0 in the callout title opens the callout chooser.
export function handleArrowLeft({ view, $from, schema, state }) {
  const titleAncestor = findAncestor(state, schema.nodes.callout_title);
  if (!titleAncestor) {
    return false;
  }

  if ($from.parentOffset !== 0) {
    return false;
  }

  const titleDOM = view.nodeDOM(titleAncestor.pos);
  const chooserTrigger = titleDOM
    ?.closest(".composer-callout-node")
    ?.querySelector(".callout-chooser-trigger");

  if (chooserTrigger) {
    chooserTrigger.click();
    return true;
  }

  return false;
}
