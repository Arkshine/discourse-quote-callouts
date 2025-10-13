import { setOwner } from "@ember/owner";
import discourseComputed from "discourse/lib/decorators";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { createSafeSVG } from "../lib/svg";
import { capitalizeFirstLetter, hexToRGBA, isNodeEmpty } from "../lib/utils";

const CALLOUT_REGEX =
  /^\[!(?<callout>[^\]]+)\](?<fold>[+-])? *?(?<title>.*) *?/;
const CALLOUT_EXCERPT_REGEX = new RegExp(`\\[!\\w+\\][+-]? *`, "gmi");

class QuoteCallouts {
  calloutTitles = [];

  constructor(owner, api) {
    setOwner(this, owner);

    this.callouts = this.processCalloutSettings();

    api.modifyClass("model:topic", (Superclass) => {
      return class extends Superclass {
        @discourseComputed("excerpt")
        escapedExcerpt() {
          return super.escapedExcerpt?.replace(CALLOUT_EXCERPT_REGEX, "");
        }
      };
    });

    api.decorateCookedElement((element) => {
      element.querySelectorAll("blockquote").forEach((blockquote) => {
        const firstElement = blockquote?.firstElementChild;

        if (
          !firstElement ||
          firstElement.tagName === "BLOCKQUOTE" ||
          (firstElement.tagName === "ASIDE" &&
            firstElement.classList.contains("quote"))
        ) {
          // Nested quotes
          return;
        }

        this.processBlockquotes(blockquote);
        this.bindFoldEvents(blockquote);
      });
    });

    if (api.decorateChatMessage) {
      api.decorateChatMessage(
        (element) => {
          element.querySelectorAll("blockquote").forEach((blockquote) => {
            this.processBlockquotes(blockquote);
            this.bindFoldEvents(blockquote);
          });
        },
        {
          id: "quote-callouts",
        }
      );
    }

    api.cleanupStream(this.cleanup.bind(this));
  }

  processCalloutSettings() {
    return settings.callouts.map((setting) => {
      if (setting.alias) {
        setting.type = [
          setting.type,
          ...setting.alias
            .split("|")
            .map((alias) => alias.trim())
            .filter(Boolean),
        ];
      } else {
        setting.type = [setting.type];
      }

      return setting;
    });
  }

  findCalloutSetting(type) {
    return this.callouts.find((callout) => callout.type.includes(type));
  }

  getActualCalloutType(calloutType) {
    // 查找包含该 calloutType 的设置
    const setting = this.findCalloutSetting(calloutType);

    if (!setting) {
      return calloutType; // 找不到匹配，返回原值
    }

    // 返回原始的 type（数组的第一个元素）
    return setting.type[0];
  }

  processBlockquotes(blockquote) {
    const firstParagraph = blockquote.querySelector("p");
    if (!firstParagraph) {
      return;
    }

    // > [!note] This is a note
    // First child can be only a #TEXT.
    const firstChild = firstParagraph?.firstChild;
    if (!firstChild || firstChild.nodeType !== Node.TEXT_NODE) {
      return;
    }

    // [!<callout>]<fold>? <title>?
    const match = firstChild.textContent.match(CALLOUT_REGEX);
    if (!match || !match.groups?.callout) {
      return;
    }

    const fold = match.groups?.fold || "";

    let calloutType = match.groups.callout.toLowerCase();
    let calloutIcon;

    // Remove the callout from the text
    firstChild.nodeValue = firstChild.nodeValue
      .replace(`[!${match.groups.callout}]${fold}`, "")
      .trimLeft();

    const setting = this.findCalloutSetting(calloutType);

    if (!setting) {
      calloutType = settings.callout_fallback_type || "note";
      calloutIcon = settings.callout_fallback_icon || "pencil";
    } else {
      calloutIcon = setting.icon;
    }

    // Do we have a title, either text or element (excluding newline)?
    const hasCustomTitle =
      !!match.groups?.title?.trim() ||
      (firstChild.nextSibling?.nodeType === Node.ELEMENT_NODE &&
        firstChild.nextSibling?.tagName !== "BR");

    let title;

    if (hasCustomTitle) {
      const nodes = Array.from(firstParagraph.childNodes);
      const result = [];

      // Retrieves all nodes after the callout until a newline appears
      for (const node of nodes) {
        if (
          node.nodeName === "BR" ||
          (node.nodeType === Node.TEXT_NODE &&
            node.textContent.startsWith("\n"))
        ) {
          break;
        }

        result.push(node);
      }

      title = result.length ? result : null;
    }

    if (!title) {
      title = setting?.title || capitalizeFirstLetter(calloutType);
    }

    const titleRow = this.createTitleRow(calloutIcon, title, fold);

    this.cleanupParagraph(firstParagraph);

    blockquote.prepend(titleRow);
    blockquote.dataset.calloutType = this.getActualCalloutType(calloutType);
    blockquote.classList.add("callout");

    blockquote.style.backgroundColor = hexToRGBA(
      setting?.color || settings.callout_fallback_color,
      settings.callout_background_opacity / 100
    );

    this.createContentRow(blockquote, titleRow, fold);
  }

  bindFoldEvents(blockquote) {
    if (!blockquote.classList.contains("is-collapsible")) {
      return;
    }

    const titleRow = blockquote.querySelector(".callout-title");
    const content = blockquote.querySelector(".callout-content");

    if (!titleRow || !content) {
      return;
    }

    const handleClick = () => {
      const isCollapsing = !blockquote.classList.contains("is-collapsed");
      const foldSpan = titleRow.querySelector(".callout-fold");

      content.removeAttribute("style");
      content.style.overflowY = "clip";
      content.style.height = content.scrollHeight + "px";

      if (isCollapsing) {
        content.style.height = content.scrollHeight + "px";
        content.offsetHeight; // reflow
        content.style.height = "0px";
      }

      blockquote.classList.toggle("is-collapsed");
      if (foldSpan) {
        foldSpan.classList.toggle("is-collapsed");
      }

      content.addEventListener(
        "transitionend",
        () => {
          content.style = blockquote.classList.contains("is-collapsed")
            ? "display: none"
            : "";
        },
        { once: true }
      );
    };

    this.calloutTitles.push(titleRow);
    titleRow._calloutHandler = handleClick;
    titleRow.addEventListener("click", handleClick);
  }

  cleanupBindFoldEvents() {
    this.calloutTitles.forEach((titleRow) => {
      titleRow.removeEventListener("click", titleRow._calloutHandler);
      delete titleRow._calloutHandler;
    });

    this.calloutTitles = [];
  }

  createTitleRow(icon, title, fold) {
    const titleRow = document.createElement("div");
    titleRow.classList.add("callout-title");

    if (icon) {
      let svg;

      const iconSpan = document.createElement("span");
      iconSpan.classList.add("callout-icon");

      if (icon.startsWith("<svg")) {
        svg = createSafeSVG(icon);

        if (svg) {
          iconSpan.appendChild(svg);
        } else {
          icon = "pencil";
        }
      }

      if (!svg) {
        iconSpan.innerHTML = iconHTML(icon);
      }

      titleRow.appendChild(iconSpan);
    }

    if (title) {
      const titleSpan = document.createElement("span");
      titleSpan.classList.add("callout-title-inner");

      if (typeof title === "string") {
        titleSpan.textContent = title;
      } else {
        titleSpan.append(...title);
      }
      titleRow.appendChild(titleSpan);
    }

    if (fold) {
      const foldSpan = document.createElement("span");
      foldSpan.classList.add("callout-fold");
      if (fold === "-") {
        foldSpan.classList.add("is-collapsed");
      }

      foldSpan.innerHTML = iconHTML("chevron-down");
      titleRow.appendChild(foldSpan);
    }

    return titleRow;
  }

  createContentRow(blockquote, titleRow, fold) {
    const contents = Array.from(blockquote.children).filter(
      (node) => node !== titleRow
    );

    if (contents.length) {
      const contentContainer = document.createElement("div");
      contentContainer.className = "callout-content";
      contentContainer.append(...contents);

      blockquote.appendChild(contentContainer);

      if (fold) {
        blockquote.classList.add("is-collapsible");

        if (fold === "-") {
          blockquote.classList.add("is-collapsed");
        }
      }
    } else if (fold) {
      titleRow.querySelector(".callout-fold")?.remove();
    }
  }

  cleanupParagraph(paragraph) {
    const firstParagraphChild = paragraph?.firstElementChild;
    if (
      firstParagraphChild &&
      (firstParagraphChild.tagName === "BR" ||
        !firstParagraphChild.textContent.trim())
    ) {
      firstParagraphChild.remove();
    }

    if (isNodeEmpty(paragraph)) {
      paragraph.remove();
    }
  }

  cleanup() {
    this.cleanupBindFoldEvents();
  }
}

export default {
  name: "discourse-quote-callouts",

  initialize(owner) {
    withPluginApi("1.39.0", (api) => {
      this.instance = new QuoteCallouts(owner, api);
    });
  },

  tearDown() {
    this.instance = null;
    this.cleanup();
  },
};
