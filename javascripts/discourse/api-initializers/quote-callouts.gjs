import { setOwner } from "@ember/owner";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { capitalizeFirstLetter, hexToRGBA } from "../lib/utils";

const CALLOUT_REGEX = /^\[!(?<callout>[^\]]+)\]\s*?(?<title>[^\n\r]*)?/;

class QuoteCallouts {
  constructor(owner, api) {
    setOwner(this, owner);

    this.callouts = this.processCalloutSettings();

    api.decorateCookedElement((element) => {
      element.querySelectorAll("blockquote").forEach((blockquote) => {
        this.processBlockquotes(blockquote);
      });
    });
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

    const titleRow = this.createTitleRow(calloutIcon, title);

    blockquote.prepend(titleRow, firstParagraph);
    blockquote.classList.add("callout", `callout-${calloutType}`);
    blockquote.style.backgroundColor = hexToRGBA(
      setting?.color || settings.callout_fallback_color,
      settings.callout_background_opacity / 100
    );

    this.cleanupParagraph(firstParagraph);
  }

  createTitleRow(icon, title) {
    const titleRow = document.createElement("div");
    titleRow.className = "callout-title";

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
  },
};
