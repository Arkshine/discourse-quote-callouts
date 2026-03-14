import { DEFAULT_CALLOUT_TYPE } from "../config";
import {
  buildCallout,
  insertBlockAtInlineSelection,
} from "../rich-editor-utils";

export const commands = ({ schema, utils }) => ({
  insertCallout:
    (type = DEFAULT_CALLOUT_TYPE, title = "") =>
    (state, dispatch) => {
      const { selection } = state;
      const { $from, $to } = selection;

      const createCallout = (bodyNodes) =>
        buildCallout(schema, type, { title, bodyNodes });

      const setCursorAtBodyEnd = (
        tr,
        { calloutStart, nearPos, minPos = 0 } = {}
      ) => {
        let foundPos = calloutStart ?? null;

        if (foundPos == null) {
          const searchEnd = Math.min(
            tr.doc.content.size,
            nearPos + tr.doc.content.size
          );
          tr.doc.nodesBetween(nearPos, searchEnd, (node, pos) => {
            if (
              foundPos == null &&
              node.type === schema.nodes.callout &&
              pos >= minPos
            ) {
              foundPos = pos;
              return false;
            }
          });
        }

        if (foundPos == null) {
          return;
        }

        const foundNode = tr.doc.nodeAt(foundPos);
        const bodyEnd = foundPos + foundNode.nodeSize - 2;
        tr.setSelection(
          selection.constructor.near(tr.doc.resolve(bodyEnd), -1)
        );
      };

      const tr = state.tr;

      // If inside a callout title, wrap the entire callout in a new one
      if (utils.isNodeActive(state, schema.nodes.callout_title)) {
        for (let d = $from.depth; d >= 0; d--) {
          if ($from.node(d).type === schema.nodes.callout) {
            const calloutStart = $from.before(d);
            const existingCallout = $from.node(d);
            const newCallout = createCallout([existingCallout]);

            tr.replaceWith(
              calloutStart,
              calloutStart + existingCallout.nodeSize,
              newCallout
            );
            setCursorAtBodyEnd(tr, { calloutStart });
            break;
          }
        }
      } else if (selection.empty) {
        const callout = createCallout([schema.nodes.paragraph.create()]);
        tr.replaceSelectionWith(callout);
        setCursorAtBodyEnd(tr, {
          nearPos: $from.pos,
          minPos: $from.before($from.depth),
        });
      } else {
        const isBlockSelection =
          $from.parent === $to.parent &&
          $from.parentOffset === 0 &&
          $to.parentOffset === $from.parent.content.size &&
          $from.parent.isBlock &&
          $from.depth > 0;

        if (isBlockSelection) {
          const range = $from.blockRange($to);
          if (!range) {
            return false;
          }

          const content = state.doc.slice(range.start, range.end).content;
          const callout = createCallout(content);

          tr.replaceWith(range.start, range.end, callout);
          setCursorAtBodyEnd(tr, { calloutStart: range.start });
        } else {
          const inlineContent = state.doc.slice(
            selection.from,
            selection.to
          ).content;
          const callout = createCallout([
            schema.nodes.paragraph.create(null, inlineContent),
          ]);

          const calloutPos = insertBlockAtInlineSelection(
            tr,
            schema,
            selection,
            callout
          );
          if (calloutPos != null) {
            setCursorAtBodyEnd(tr, { calloutStart: calloutPos });
          }
        }
      }

      dispatch?.(tr.scrollIntoView());
      return true;
    },
});
