import { setOwner } from "@ember/owner";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { capitalizeFirstLetter, hexToRGBA } from "../lib/utils";

const CALLOUT_REGEX =
  /^\[!(?<callout>[^\]]+)\](?<fold>[+-])?\s*?(?<title>[^\n\r]*)?/;

class QuoteCallouts {
  calloutTitles = [];

  constructor(owner, api) {
    setOwner(this, owner);

    this.callouts = this.processCalloutSettings();

    api.decorateCookedElement((element) => {
      element.querySelectorAll("blockquote").forEach((blockquote) => {
        this.processBlockquotes(blockquote);
        this.bindFoldEvents(blockquote);
      });
    });

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
    return this.callouts.find((callout) =>
      callout.type.includes(type.toLowerCase())
    );
  }

  processBlockquotes(blockquote) {
    const firstParagraph = blockquote.querySelector("p");
    if (!firstParagraph) {
      return;
    }

    const match = firstParagraph.textContent.match(CALLOUT_REGEX);
    if (!match || !match.groups?.callout) {
      return;
    }

    let calloutType = match.groups?.callout;
    let calloutIcon;

    const setting = this.findCalloutSetting(calloutType);

    if (!setting) {
      calloutType = settings.callout_fallback_type || "note";
      calloutIcon = settings.callout_fallback_icon || "pencil";
    } else {
      calloutIcon = setting.icon;
    }

    const title =
      match.groups?.title?.trim() ||
      setting?.title ||
      capitalizeFirstLetter(calloutType);

    const fold = match.groups?.fold;
    const titleRow = this.createTitleRow(calloutIcon, title, fold);

    blockquote.prepend(titleRow, firstParagraph);
    blockquote.classList.add("callout", `callout-${calloutType}`);

    blockquote.style.backgroundColor = hexToRGBA(
      setting?.color || settings.callout_fallback_color,
      settings.callout_background_opacity / 100
    );

    this.cleanupParagraph(firstParagraph);

    const contents = Array.from(blockquote.childNodes).filter(
      (node) =>
        node.nodeType === Node.ELEMENT_NODE && !node.isSameNode(titleRow)
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
    }
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
      const iconSpan = document.createElement("span");
      iconSpan.className = icon;
      iconSpan.innerHTML = iconHTML(icon);
      titleRow.appendChild(iconSpan);
    }

    if (title) {
      const titleSpan = document.createElement("span");
      titleSpan.textContent = title;
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

  cleanupParagraph(paragraph) {
    const childNodes = Array.from(paragraph.childNodes);
    const [firstNode, newlineNode] = childNodes;

    if (firstNode?.nodeType === Node.TEXT_NODE) {
      paragraph.removeChild(firstNode);
    }

    if (newlineNode) {
      paragraph.removeChild(newlineNode);
    }

    if (!paragraph.textContent.trim()) {
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
