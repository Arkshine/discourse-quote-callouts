import { commands } from "./commands.js";
import { inputRules } from "./input-rules.js";
import { handleBackspace } from "./keyboard.js";
import { parse, serializeNode } from "./markdown.js";
import { nodeViews } from "./node-views.js";
import { plugins } from "./plugins.js";
import { nodeSpec } from "./schema.js";

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
