import { action, computed } from "@ember/object";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { convertIconClass, iconHTML } from "discourse/lib/icon-library";
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
import { createSafeSVG } from "../lib/svg";
import {
  capitalizeFirstLetter,
  collectNodesUntil,
  firstMeaningfulNode,
  hexToRGBA,
  isNodeEmpty,
  leadingTextFromNode,
} from "../lib/utils";

const ONEBOX_SELECTOR = "aside.onebox, aside.quote[data-topic]";
const PENDING_ONEBOX_SELECTOR = "a.onebox";

class QuoteCallouts {
  @service calloutSettings;

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
      shortcut: "alt+C",
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
              <kbd>Alt</kbd>
              <kbd>C</kbd>
            </span>
            ${i18n(themePrefix("composer.insert_callout"))}`;
          return shortcuts;
        }
      };
    });

    const instance = this;
    api.modifyClass("component:modal/history", (Superclass) => {
      return class extends Superclass {
        @action
        async calculateBodyDiff(_, [bodyDiff]) {
          await super.calculateBodyDiff(_, [bodyDiff]);

          if (this.viewMode === "side_by_side_markdown" || !this.bodyDiff) {
            return;
          }

          const root = document.createElement("div");
          root.innerHTML = this.bodyDiff;
          instance.renderStaticCallouts(root, this.viewMode);
          this.bodyDiff = root.innerHTML;
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

    // Strips callout marker only on collapsed quote (see PostQuotedContent)
    api.modifyClass("component:post/cooked-html", (Superclass) => {
      return class extends Superclass {
        get cooked() {
          const value = super.cooked;
          const isCollapsedQuote =
            this.args.cooked &&
            this.args.className === "post__contents-cooked-quote";

          if (!isCollapsedQuote || !value) {
            return value;
          }

          // `value` may be a TrustedHTML wrapper. Template re-wraps via `trustHTML`.
          return value.toString().replace(CALLOUT_EXCERPT_REGEX, "");
        }
      };
    });

    api.decorateCookedElement((cooked, helper) => {
      this.processCookedElement(cooked, helper);
      return () => this.disconnectPreviewObserver(cooked);
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

  renderStaticCallouts(element, viewMode) {
    if (viewMode !== "inline" && viewMode !== "side_by_side") {
      return;
    }

    for (const blockquote of element.querySelectorAll("blockquote")) {
      if (!blockquote.parentElement) {
        continue;
      }

      let typeChanged = false;
      let previousType;

      if (
        blockquote.classList.contains("diff-ins") ||
        blockquote.classList.contains("diff-del")
      ) {
        blockquote
          .querySelectorAll("ins, del")
          .forEach((node) => node.replaceWith(...node.childNodes));
        blockquote.normalize();
      } else {
        const firstParagraph = blockquote.firstElementChild;
        if (firstParagraph?.tagName === "P") {
          firstParagraph.innerHTML = firstParagraph.innerHTML.replace(
            /\[!.*?\]/,
            (marker) => {
              if (/<ins[\s>]/.test(marker) && /<del[\s>]/.test(marker)) {
                typeChanged = true;

                const oldMarker = marker
                  .replace(/<ins[^>]*>.*?<\/ins>/g, "")
                  .replace(/<\/?del[^>]*>/g, "");
                const oldMatch = oldMarker.match(/^\[!([^\]]+)\]/);

                if (oldMatch) {
                  previousType = oldMatch[1].toLowerCase();
                }

                return marker
                  .replace(/<del[^>]*>.*?<\/del>/g, "")
                  .replace(/<\/?ins[^>]*>/g, "");
              }
              return marker.replace(/<\/?(?:ins|del)[^>]*>/g, "");
            }
          );
        }
      }

      const preservedClasses = ["diff-ins", "diff-del"].filter((className) =>
        blockquote.classList.contains(className)
      );

      const calloutTree = this.parseHeaders(blockquote);
      if (calloutTree?.isCallout) {
        if (typeChanged && previousType) {
          calloutTree.previousType = previousType;
        }

        const built = this.buildStaticCallout(calloutTree);
        preservedClasses.forEach((className) => built.classList.add(className));

        if (typeChanged) {
          built.classList.add("callout-type-changed");
        }

        calloutTree.root.replaceWith(built);
      }
    }

    if (viewMode !== "side_by_side") {
      return;
    }

    const sideCallouts = (selector) =>
      [...element.querySelectorAll(`${selector} .callout`)].filter(
        (callout) =>
          !callout.classList.contains("diff-ins") &&
          !callout.classList.contains("diff-del")
      );
    const prevCallouts = sideCallouts(".revision-content.--previous");
    const currCallouts = sideCallouts(".revision-content.--current");
    const pairs = Math.min(prevCallouts.length, currCallouts.length);

    for (let i = 0; i < pairs; i++) {
      if (
        prevCallouts[i].dataset.calloutType !==
        currCallouts[i].dataset.calloutType
      ) {
        prevCallouts[i].classList.add("callout-type-changed");
        currCallouts[i].classList.add("callout-type-changed");
      }
    }
  }

  buildStaticCallout(tree) {
    const options = this.calloutSettings.find(tree.type);
    const resolvedType = options?.mainType || options?.type || tree.type;
    const alias = options?.type ? tree.type : resolvedType;
    const iconSource = options?.icon || settings.callout_fallback_icon;
    const color = options?.color || settings.callout_fallback_color;

    const bq = document.createElement("blockquote");
    bq.className = "callout";
    bq.dataset.calloutType = resolvedType;
    bq.dataset.calloutAlias = alias;
    bq.style.setProperty("--q-callout-color", color);
    bq.style.setProperty(
      "--q-callout-background",
      hexToRGBA(color, settings.callout_background_opacity / 100)
    );

    const titleElement = document.createElement("div");
    titleElement.className = "callout-title";

    if (tree.previousType) {
      const prevOptions = this.calloutSettings.find(tree.previousType);
      const prevIconSource =
        prevOptions?.icon || settings.callout_fallback_icon;

      if (prevIconSource) {
        const prevIcon = document.createElement("span");
        prevIcon.className = "callout-icon callout-icon--old";
        prevIcon.innerHTML = prevIconSource.startsWith("<svg")
          ? createSafeSVG(prevIconSource)
          : iconHTML(convertIconClass(prevIconSource));
        titleElement.append(prevIcon);
      }
    }

    if (iconSource) {
      const iconElement = document.createElement("span");
      iconElement.className = tree.previousType
        ? "callout-icon callout-icon--new"
        : "callout-icon";
      iconElement.innerHTML = iconSource.startsWith("<svg")
        ? createSafeSVG(iconSource)
        : iconHTML(convertIconClass(iconSource));
      titleElement.append(iconElement);
    }

    const titleInner = document.createElement("span");
    titleInner.className = "callout-title-inner";

    if (tree.title.hasInline && tree.title.nodes.length) {
      tree.title.nodes.forEach((node) => titleInner.append(node));
    } else {
      titleInner.textContent =
        tree.title.text ||
        options?.title ||
        capitalizeFirstLetter(resolvedType);
    }

    titleElement.append(titleInner);
    bq.append(titleElement);

    if (tree.children?.length) {
      const content = document.createElement("div");
      content.className = "callout-content";

      for (const child of tree.children) {
        if (child.isCallout) {
          content.append(this.buildStaticCallout(child));
        } else if (child.content) {
          content.append(child.content);
        }
      }

      bq.append(content);
    }

    return bq;
  }

  processCookedElement(element, helper, { isChat = false } = {}) {
    const isPreview = !isChat && !helper.model;
    const calloutCounter = { value: 0 };

    // Removes marker from onebox excerpts
    element
      .querySelectorAll(ONEBOX_SELECTOR)
      .forEach((aside) => this.stripMarkerFromExcerpt(aside));

    if (isPreview) {
      this.observePreviewOneboxes(element);
    }

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

  stripMarkerFromExcerpt(blockquote) {
    const walker = document.createTreeWalker(blockquote, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      node.nodeValue = node.nodeValue.replace(CALLOUT_EXCERPT_REGEX, "");
    }
  }

  // Covers the first time the markdown preview is opened.
  observePreviewOneboxes(preview) {
    this.previewObservers ??= new WeakMap();

    if (this.previewObservers.has(preview)) {
      return;
    }

    if (!preview.querySelector(PENDING_ONEBOX_SELECTOR)) {
      return;
    }

    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (
            node.nodeType === Node.ELEMENT_NODE &&
            node.matches(ONEBOX_SELECTOR)
          ) {
            this.stripMarkerFromExcerpt(node);
          }
        }
      }

      if (!preview.querySelector(PENDING_ONEBOX_SELECTOR)) {
        this.disconnectPreviewObserver(preview);
      }
    });

    observer.observe(preview, { childList: true, subtree: true });
    this.previewObservers.set(preview, observer);
  }

  disconnectPreviewObserver(preview) {
    const observer = this.previewObservers?.get(preview);
    if (observer) {
      observer.disconnect();
      this.previewObservers.delete(preview);
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
