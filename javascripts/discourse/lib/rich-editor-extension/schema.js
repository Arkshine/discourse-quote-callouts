import { findCalloutOptions } from "../config";
import { plugins } from "./plugins";

export const nodeSpec = {
  callout: {
    group: "block",
    content: "callout_title callout_body",
    defining: true,
    createGapCursor: true,
    selectable: true,
    draggable: true,
    attrs: {
      type: { default: settings.callout_fallback_type || "note" },
      title: { default: "" },
      fold: { default: "" },
      isCollapsed: { default: false },
      isCollapsible: { default: false },
      hasBody: { default: false },
      hasCustomTitle: { default: false },
    },
    toDOM(node) {
      const { type, fold, isCollapsed, isCollapsible } = node.attrs;
      const classes = ["callout"];

      if (fold !== "") {
        if (isCollapsed) {
          classes.push("is-collapsed");
        }

        if (isCollapsible) {
          classes.push("is-collapsible");
        }
      }

      return [
        "blockquote",
        { class: classes.join(" "), "data-callout-type": type },
        0,
      ];
    },
    parseDOM: [
      {
        tag: "blockquote.callout",
        getAttrs(dom) {
          let type = dom.getAttribute("data-callout-type");

          const title =
            dom.querySelector(".callout-title-inner")?.textContent.trim() || "";

          const fold = dom.classList.contains("is-collapsible")
            ? dom.classList.contains("is-collapsed")
              ? "-"
              : "+"
            : "";

          if (!findCalloutOptions(type)) {
            type = settings.callout_fallback_type || "note";
          }

          return { type, title, fold, hasCustomTitle: title.length > 0 };
        },
      },
    ],
  },

  callout_title: {
    content: "inline*",
    marks: "_",
    defining: true,
    selectable: true,
    attrs: {
      type: { default: settings.callout_fallback_type || "note" },
      fold: { default: "" },
      isCollapsed: { default: false },
      isCollapsible: { default: false },
      hasBody: { default: false },
    },
    toDOM() {
      return [
        "div",
        { class: "callout-title" },
        ["span", { class: "callout-title-inner" }, 0],
      ];
    },
    parseDOM: [
      {
        tag: "div.callout-title",
        contentElement: "span.callout-title-inner",
      },
    ],
  },

  callout_body: {
    content: "block*",
    defining: true,
    selectable: false,
    createGapCursor: true,
    toDOM() {
      return ["div", { class: "callout-content" }, 0];
    },
    parseDOM: [{ tag: "div.callout-content" }],
  },

  plugins,
};
