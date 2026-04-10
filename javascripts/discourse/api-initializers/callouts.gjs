import { computed } from "@ember/object";
import { setOwner } from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import Callout from "../components/callout";
import CalloutChooserPanel from "../components/callout-chooser-panel";
import {
  CALLOUT_EXCERPT_REGEX,
  CALLOUT_REGEX,
  DEFAULT_CALLOUT_TYPE,
} from "../lib/config";
import richEditorExtension from "../lib/rich-editor-extension/index";
import {
  collectNodesUntil,
  firstMeaningfulNode,
  isNodeEmpty,
  leadingTextFromNode,
} from "../lib/utils";

class QuoteCallouts {
  constructor(owner, api) {
    setOwner(this, owner);
    this.api = api;
    this.hasChatContext = !!api.decorateChatMessage;

    api.registerRichEditorExtension(richEditorExtension);

    const fallbackLocale = window.I18n.fallbackLocale || "en";
    if (!window.I18n.translations[fallbackLocale].js.composer) {
      window.I18n.translations[fallbackLocale].js.composer = {};
    }
    window.I18n.translations[fallbackLocale].js.composer.callout_sample = "";

    api.addComposerToolbarPopupMenuOption({
      action: (toolbarEvent) => {
        const defaultType = DEFAULT_CALLOUT_TYPE;
        if (toolbarEvent.commands) {
          toolbarEvent.commands.insertCallout(defaultType);
        } else {
          toolbarEvent.applySurround(
            `> [!${defaultType}]\n> `,
            " ",
            "callout_sample"
          );
        }
      },
      icon: "callout",
      label: themePrefix("composer.callout"),
      shortcut: "q",
    });

    // Add callout to keyboard shortcuts help modal
    // TODO: Remove this if core generates the list later.
    api.modifyClass("component:modal/keyboard-shortcuts-help", (Superclass) => {
      return class extends Superclass {
        get shortcuts() {
          const shortcuts = super.shortcuts;
          if (!shortcuts?.composing?.shortcuts) {
            return shortcuts;
          }

          shortcuts.composing.shortcuts.callout = `
            <span class="delimiter-or" dir="ltr">
              <kbd>Ctrl</kbd>
              <kbd>q</kbd>
            </span>
            ${i18n(themePrefix("composer.insert_callout"))}`;
          return shortcuts;
        }
      };
    });

    api.modifyClass("model:topic", (Superclass) => {
      return class extends Superclass {
        @computed("excerpt")
        get escapedExcerpt() {
          return super.escapedExcerpt?.replace(CALLOUT_EXCERPT_REGEX, "");
        }
      };
    });

    api.decorateCookedElement((cooked, helper) => {
      this.processCookedElement(cooked, helper);
    });

    if (this.hasChatContext) {
      api.decorateChatMessage(
        (element, helper) => {
          this.processCookedElement(element, helper, { isChat: true });
        },
        {
          id: "quote-callouts",
        }
      );

      api.registerChatComposerButton?.({
        id: "quote-callouts",
        icon: "callout",
        label: themePrefix("composer.insert_callout"),
        position: "dropdown",
        action() {
          const identifier = "callout-chooser";
          const trigger = document.querySelector(
            ".chat-composer-dropdown__trigger-btn"
          );

          this.menu.show(trigger, {
            identifier,
            component: <template>
              <CalloutChooserPanel
                @onSelect={{@data.onSelect}}
                @close={{@data.close}}
              />
            </template>,
            data: {
              onSelect: (type) => {
                const markup = `> [!${type}]\n> `;
                this.composer.textarea.addText(
                  this.composer.textarea.getSelected(),
                  markup
                );
                this.composer.focus();
              },
              close: () => {
                this.menu.close(identifier);
              },
            },
          });
        },
      });
    }
  }

  processCookedElement(element, helper, { isChat = false } = {}) {
    const isPreview = !isChat && !helper.model;
    const calloutCounter = { value: 0 };

    for (const blockquote of element.querySelectorAll("blockquote")) {
      // Skip if already processed (replaced with container)
      if (!blockquote.parentElement) {
        continue;
      }

      const calloutTrees = this.parseHeaders(blockquote);
      if (!calloutTrees?.isCallout) {
        continue;
      }

      if (isPreview) {
        this.assignPreviewMetadata(calloutTrees, calloutCounter);
      }

      const { root } = calloutTrees;
      const container = document.createElement("div");

      root.replaceWith(container);
      helper.renderGlimmer(container, Callout, { ...calloutTrees });
    }
  }

  parseHeaders(blockquoteElement) {
    // First element must be a paragraph
    const firstParagraph = blockquoteElement?.firstElementChild;
    if (!firstParagraph || firstParagraph.tagName !== "P") {
      return null;
    }

    // Ignore leading whitespace.
    // Allow a single inline wrapper around the marker (like accidental strong or em).
    const first = firstMeaningfulNode(firstParagraph);
    const leading = leadingTextFromNode(first);

    if (!leading) {
      return null;
    }

    // Matches [!<callout>]<fold>? <title>?
    const match = leading.match(CALLOUT_REGEX);
    if (!match) {
      return null;
    }

    const type = match.groups.callout.toLowerCase() || DEFAULT_CALLOUT_TYPE;
    const fold = match.groups.fold || "";
    const title = match.groups.title?.trim() || "";

    // Strips the marker from the content
    firstParagraph.innerHTML = firstParagraph.innerHTML
      .replace(match.groups.marker, "")
      .trimLeft();

    // Supports inline element such as date in the title
    // Loops through the nodes until a newline appears
    const { nodes: titleNodes, hasInline: titleHasInline } =
      this.collectTitleNodes(firstParagraph);

    // Single callout without content
    if (isNodeEmpty(firstParagraph)) {
      firstParagraph.remove();
    }

    // Check recursively blockquotes, treat others as content
    const children = Array.from(blockquoteElement.children).map((child) => {
      if (child.tagName === "BLOCKQUOTE") {
        const parsed = this.parseHeaders(child);
        if (parsed) {
          return parsed;
        }
      }
      return { content: child, isCallout: false };
    });

    return {
      root: blockquoteElement,
      isCallout: true,
      type,
      title: {
        text: title,
        nodes: titleNodes,
        hasInline: titleHasInline,
      },
      fold,
      children,
    };
  }

  assignPreviewMetadata(calloutData, counter) {
    calloutData.isPreview = true;
    calloutData.calloutIndex = counter.value++;

    if (calloutData.children) {
      for (const child of calloutData.children) {
        if (child.isCallout) {
          this.assignPreviewMetadata(child, counter);
        }
      }
    }
  }

  collectTitleNodes(paragraphEl) {
    const nodes = collectNodesUntil(
      paragraphEl,
      (node) =>
        node.nodeName === "BR" ||
        (node.nodeType === Node.TEXT_NODE && node.textContent.startsWith("\n")),
      {
        onStop: (node) => node.remove(),
      }
    );
    const hasInline = nodes.some((node) => node.nodeType === Node.ELEMENT_NODE);

    // Detach nodes from the DOM
    nodes.forEach((node) => node.remove());

    return {
      nodes,
      hasInline,
    };
  }
}

export default {
  name: "discourse-quote-callouts",

  initialize(owner) {
    withPluginApi((api) => {
      this.instance = new QuoteCallouts(owner, api);
    });
  },

  teardown() {
    this.instance = null;
  },
};
