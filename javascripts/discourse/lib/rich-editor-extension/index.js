import { commands } from "./commands";
import { inputRules } from "./input-rules";
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
};

export default extension;
