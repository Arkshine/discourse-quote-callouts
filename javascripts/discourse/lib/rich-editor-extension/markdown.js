import { CALLOUT_REGEX, findCalloutOptions } from "../config";
import { splitAtFirstLineBreak, stripPrefix } from "../rich-editor-utils";
import { capitalizeFirstLetter } from "../utils";

export const parse = {
  blockquote_open(state, _token, tokens, i) {
    state._bqStack ||= [];

    // A blockquote wrapping a paragraph produces this token layout:
    // i+0: blockquote_open
    // i+1: paragraph_open
    // i+2: inline
    // i+3: paragraph_close
    // ...
    // blockquote_close
    const inlineToken = tokens[i + 2];
    const firstLine = (inlineToken?.content || "").split("\n")[0];
    const match =
      tokens[i + 1]?.type === "paragraph_open" &&
      inlineToken?.type === "inline" &&
      firstLine.match(CALLOUT_REGEX);

    if (!match) {
      state._bqStack.push("blockquote");
      state.openNode(state.schema.nodes.blockquote);
      return true;
    }

    const { callout: rawCallout, marker, fold } = match.groups;

    let calloutType = rawCallout.toLowerCase();
    let options = findCalloutOptions(calloutType);
    if (!options) {
      calloutType = settings.callout_fallback_type || "note";
      options = findCalloutOptions(calloutType);
    }

    state._bqStack.push("callout");

    stripPrefix(inlineToken, marker.length);

    // Trim leading whitespace from the first text token.
    const firstChild = inlineToken.children?.[0];
    if (firstChild?.type === "text") {
      firstChild.content = firstChild.content.replace(/^\s+/, "");
      if (!firstChild.content) {
        inlineToken.children.shift();
      }
    }

    const { title, rest } = splitAtFirstLineBreak(inlineToken);
    const hasCustomTitle = title.length > 0;

    if (!hasCustomTitle) {
      const defaultTitle = options?.title ?? capitalizeFirstLetter(calloutType);
      inlineToken.children = [{ type: "text", content: defaultTitle }];
    } else {
      inlineToken.children = title;
    }

    const foldOptions = {
      fold,
      isCollapsed: fold === "-",
      isCollapsible: ["-", "+"].includes(fold),
      hasBody: rest.length > 0 || tokens[i + 4]?.type !== "blockquote_close",
    };

    // Inject the remaining body content as a new paragraph right after the title paragraph.
    if (rest.length) {
      tokens.splice(
        i + 4,
        0,
        { type: "paragraph_open", tag: "p", nesting: 1 },
        { type: "inline", children: rest, content: "" },
        { type: "paragraph_close", tag: "p", nesting: -1 }
      );
    }

    state.openNode(state.schema.nodes.callout, {
      type: calloutType,
      hasCustomTitle,
      ...foldOptions,
    });

    state.openNode(state.schema.nodes.callout_title, {
      type: calloutType,
      ...foldOptions,
    });

    return true;
  },

  paragraph_open(state) {
    if (state.top()?.type === state.schema.nodes.callout_title) {
      return true;
    }

    state.openNode(state.schema.nodes.paragraph);
    return true;
  },

  paragraph_close(state) {
    const top = state.top();

    if (top?.type === state.schema.nodes.callout_title) {
      state.closeNode();
      state.openNode(state.schema.nodes.callout_body);
      return true;
    }

    if (top?.type === state.schema.nodes.paragraph) {
      state.closeNode();
      return true;
    }

    return false;
  },

  blockquote_close(state) {
    const kind = state._bqStack.pop();
    const topType = () => state.top()?.type;

    if (kind === "callout") {
      if (topType() === state.schema.nodes.callout_title) {
        state.closeNode();
      }
      if (topType() === state.schema.nodes.callout_body) {
        state.closeNode();
      }
      if (topType() === state.schema.nodes.callout) {
        state.closeNode();
      }
      return true;
    }

    if (kind === "blockquote") {
      if (topType() === state.schema.nodes.blockquote) {
        state.closeNode();
      }
      return true;
    }

    return false;
  },
};

export const serializeNode = {
  callout(state, node) {
    // Renders the body's children directly
    // when getSelected is used inside a callout body
    if (node.childCount < 2) {
      const only = node.childCount === 1 ? node.child(0) : null;

      if (only?.type.name === "callout_body") {
        only.forEach((child, _offset, index) =>
          state.render(child, only, index)
        );
      }
      return;
    }

    const titleNode = node.child(0);
    const bodyNode = node.child(1);

    // Captures the title as a plain string. renderInline() appends directly to
    // state.out with no way to redirect it, so we reset the buffer to isolate
    // just the title output, read it, then restore the original state.
    const prev = state.out;
    const prevDelim = state.delim;
    const prevClosed = state.closed;
    const prevAtBlockStart = state.atBlockStart;

    state.out = "";
    state.delim = "";
    state.closed = null;
    state.atBlockStart = true;

    state.renderInline(titleNode);
    let title = state.out.trim();

    state.out = prev;
    state.delim = prevDelim;
    state.closed = prevClosed;
    state.atBlockStart = prevAtBlockStart;

    const fold = node.attrs.fold || "";
    const titleStr = node.attrs.hasCustomTitle ? ` ${title}` : "";
    const marker = `[!${node.attrs.type}]${fold}${titleStr}`;

    state.wrapBlock("> ", null, node, () => {
      state.write(bodyNode.childCount ? `${marker}\n` : marker);

      if (bodyNode.childCount) {
        bodyNode.forEach((child, _offset, index) => {
          if (index > 0) {
            const prevChild = bodyNode.child(index - 1);
            // Uses size=1 (newline only, no blank line) when going from a
            // paragraph to a block, so the nested wrapBlock doesn't emit
            // a spurious blank "> " via its internal flushClose(). Use
            // size=2 otherwise to keep adjacent paragraphs/blocks separated.
            const paraToBlock =
              prevChild.type.name === "paragraph" &&
              child.type.name !== "paragraph";
            state.flushClose(paraToBlock ? 1 : 2);
          }
          state.render(child, bodyNode, index);
        });
      }
    });
  },
};
