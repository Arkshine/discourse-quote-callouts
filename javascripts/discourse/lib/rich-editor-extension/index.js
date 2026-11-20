import { commands } from "./commands";
import { inputRules } from "./input-rules";
import { handleBackspace } from "./keyboard";
import { parse, serializeNode } from "./markdown";
import { nodeViews } from "./node-views";
import { plugins } from "./plugins";
import { nodeSpec } from "./schema";

/** @type {RichEditorExtension} */
const extension = {
  name: "callout",
  nodeViews,
  commands,
  nodeSpec,
  parse,
  serializeNode,
  inputRules,
  plugins,
  keymap: ({ pmState }) => ({
    Backspace: (state, dispatch) => handleBackspace(state, dispatch, pmState),
  }),
};

export default extension;
