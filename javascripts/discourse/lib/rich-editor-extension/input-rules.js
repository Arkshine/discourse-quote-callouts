import { DEFAULT_CALLOUT_TYPE } from "../config";
import { buildCallout } from "../rich-editor-utils";

export const inputRules = () => {
  function calloutInputHandler(state, type, start, end) {
    const callout = buildCallout(state.schema, type);

    const insertPos = start - 1;
    const tr = state.tr.replaceWith(insertPos, end, callout);

    const titleNode = callout.child(0);
    const bodyParaPos = insertPos + 1 + titleNode.nodeSize + 2;
    tr.setSelection(
      state.selection.constructor.near(tr.doc.resolve(bodyParaPos))
    );

    return tr.scrollIntoView();
  }

  return [
    {
      match: /^\/callout(?::(\w+))?\s$/, // /callout or /callout:type
      handler: (state, match, start, end) => {
        const type = match[1]?.toLowerCase() || DEFAULT_CALLOUT_TYPE;
        return calloutInputHandler(state, type, start, end);
      },
    },
    {
      match: /^!!(\w+)\s$/, // !!type
      handler: (state, match, start, end) => {
        const type = match[1].toLowerCase();
        return calloutInputHandler(state, type, start, end);
      },
    },
  ];
};
