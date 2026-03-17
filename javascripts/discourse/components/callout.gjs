import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import noop from "discourse/helpers/noop";
import iconOrSvg from "../helpers/icon-or-svg";
import { DEFAULT_CALLOUT_TYPE } from "../lib/config";
import {
  capitalizeFirstLetter,
  hexToRGBA,
  toggleCalloutCollapse,
} from "../lib/utils";
import CalloutChooser from "./callout-chooser";

export default class Callout extends Component {
  @service calloutSettings;

  @tracked isCollapsed;

  contentElement = null;

  type = DEFAULT_CALLOUT_TYPE;
  icon = settings.callout_fallback_icon;
  alias = this.type;

  constructor() {
    super(...arguments);

    const { type: calloutType, fold } = this.args.data;

    this.isCollapsed = fold && fold === "-";
    this.options = this.calloutSettings.find(calloutType);

    if (this.options?.type) {
      this.type = this.options.mainType || this.options.type;
      this.alias = calloutType;
    }

    if (this.options?.icon) {
      this.icon = this.options.icon;
    }
  }

  @action
  setupContent(element) {
    this.contentElement = element;
  }

  @action
  setupColor(element) {
    element.style.setProperty(
      "--q-callout-background",
      hexToRGBA(
        this.options?.color || settings.callout_fallback_color,
        settings.callout_background_opacity / 100
      )
    );

    element.style.setProperty(
      "--q-callout-color",
      this.options?.color || settings.callout_fallback_color
    );
  }

  @action
  preventSelection(event) {
    if (event.detail > 1) {
      // If double click
      event.preventDefault();
    }
  }

  @action
  toggleCollapse() {
    const isCollapsing = !this.isCollapsed;

    toggleCalloutCollapse(this.contentElement, isCollapsing, (isCollapsed) => {
      this.isCollapsed = isCollapsed;
    });
  }

  get isCollapsible() {
    return (
      ["-", "+"].includes(this.args.data.fold) &&
      this.args.data.children?.length > 0
    );
  }

  get title() {
    return (
      this.args.data.title.text ||
      this.options?.title ||
      capitalizeFirstLetter(this.type)
    );
  }

  @action
  onTypeChange(newType) {
    const { calloutIndex } = this.args.data;
    const textarea = document.querySelector(".d-editor-input");
    if (!textarea) {
      return;
    }

    const text = textarea.value;
    const markerRegex = /\[!([^\]]+)\]/gim;
    let match;
    let count = 0;

    while ((match = markerRegex.exec(text)) !== null) {
      const lineStart = text.lastIndexOf("\n", match.index - 1) + 1;
      const prefix = text.substring(lineStart, match.index);
      if (!/^(?:>[ \t]*)+$/.test(prefix)) {
        continue;
      }

      if (count === calloutIndex) {
        const newMarker = `[!${newType}]`;

        textarea.setSelectionRange(match.index, match.index + match[0].length);
        textarea.focus();
        document.execCommand("insertText", false, newMarker);
        break;
      }
      count++;
    }
  }

  <template>
    <blockquote
      class={{concatClass
        "callout"
        (if this.isCollapsed "is-collapsed")
        (if this.isCollapsible "is-collapsible")
      }}
      data-callout-type={{this.type}}
      data-callout-alias={{this.alias}}
      {{didInsert this.setupColor}}
    >
      {{! template-lint-disable no-invalid-interactive }}
      {{! template-lint-disable no-pointer-down-event-binding }}
      <div
        class="callout-title"
        {{on "click" (if this.isCollapsible this.toggleCollapse (noop))}}
        {{on "mousedown" this.preventSelection}}
      >
        {{#if @data.isPreview}}
          <CalloutChooser
            @value={{readonly this.type}}
            @onChange={{this.onTypeChange}}
            class="btn-transparent"
          />
        {{else if this.icon}}
          <span class="callout-icon">
            {{iconOrSvg this.icon}}
          </span>
        {{/if}}
        <span class="callout-title-inner">
          {{#if @data.title.hasInline}}
            {{#each @data.title.nodes as |node|}}
              {{node}}
            {{/each}}
          {{else}}
            {{this.title}}
          {{/if}}
        </span>
        {{#if this.isCollapsible}}
          <span
            class={{concatClass
              "callout-fold"
              (if this.isCollapsed "is-collapsed")
            }}
          >
            {{icon "chevron-down"}}
          </span>
        {{/if}}
      </div>

      {{#if @data.children}}
        <div class="callout-content" {{didInsert this.setupContent}}>
          {{#each @data.children as |child|}}
            {{#if child.isCallout}}
              <Callout @data={{child}} />
            {{else}}
              {{child.content}}
            {{/if}}
          {{/each}}
        </div>
      {{/if}}
    </blockquote>
  </template>
}
