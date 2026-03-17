import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import iconOrSvg from "../helpers/icon-or-svg";
import { hexToRGBA } from "../lib/utils";

export default class CalloutChooser extends Component {
  @service calloutSettings;

  @tracked chooserFilter = "";
  @tracked chooserHighlightedIndex = -1;

  chooserApi = null;

  calloutColorStyle = (color) => {
    const bg = hexToRGBA(
      color || settings.callout_fallback_color,
      settings.callout_background_opacity / 100
    );
    return trustHTML(
      `--q-callout-background: ${bg}; --q-callout-color: ${color || settings.callout_fallback_color};`
    );
  };

  get icon() {
    const options = this.calloutSettings.find(this.args.value);
    return options?.icon || settings.callout_fallback_icon;
  }

  get filteredCallouts() {
    const all = this.calloutSettings.all();
    if (!this.chooserFilter) {
      return all;
    }
    const filter = this.chooserFilter.toLowerCase();
    return all.filter(
      (callout) =>
        callout.type.includes(filter) ||
        callout.title.toLowerCase().includes(filter)
    );
  }

  scrollToView({ element, selector, block = "nearest" }) {
    next(() => {
      element
        ?.querySelector(`.callout-chooser-row.${selector}`)
        ?.scrollIntoView({ block });
    });
  }

  @action
  onRegisterApi(api) {
    this.chooserApi = api;
  }

  @action
  onFilterInput(event) {
    this.chooserFilter = event.target.value;
    this.chooserHighlightedIndex = -1;
  }

  @action
  onKeydown(event) {
    const items = this.filteredCallouts;
    const panel = event.target.closest(".callout-chooser-panel");

    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.chooserHighlightedIndex = Math.min(
        this.chooserHighlightedIndex + 1,
        items.length - 1
      );
      this.scrollToView({ element: panel, selector: "is-highlighted" });
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.chooserHighlightedIndex = Math.max(
        this.chooserHighlightedIndex - 1,
        0
      );
      this.scrollToView({ element: panel, selector: "is-highlighted" });
    } else if (event.key === "Enter") {
      event.preventDefault();
      const item = items[this.chooserHighlightedIndex];
      if (item) {
        this.selectType(item.type);
      }
    }
  }

  @action
  setChooserElement(element) {
    this.chooserElement = element;
  }

  @action
  focusInput(element) {
    element.focus({ preventScroll: true });
  }

  @action
  scrollToSelected(element) {
    this.scrollToView({ element, selector: "is-selected", block: "center" });
  }

  @action
  onShow() {
    const items = this.filteredCallouts;

    this.chooserHighlightedIndex = items.findIndex(
      (callout) => callout.type === this.args.value
    );
  }

  @action
  selectType(type) {
    this.chooserApi?.close();
    this.args.onChange?.(type);
  }

  @action
  onClose() {
    this.chooserFilter = "";
    this.chooserHighlightedIndex = -1;
    this.args.onClose?.();
  }

  <template>
    <DMenu
      @identifier="callout-chooser"
      @triggerClass="callout-chooser-trigger"
      @contentClass="callout-chooser-content"
      @placement="bottom-start"
      @disabled={{@disabled}}
      @onShow={{this.onShow}}
      @onClose={{this.onClose}}
      @onRegisterApi={{this.onRegisterApi}}
      @offset={{2}}
      class="btn-transparent"
    >
      <:trigger>
        <span class="callout-icon">
          {{iconOrSvg this.icon}}
        </span>
      </:trigger>
      <:content>
        <div class="callout-chooser-panel">
          <div class="callout-chooser-filter">
            <Input
              @type="search"
              @value={{this.chooserFilter}}
              class="filter-input"
              placeholder={{i18n (themePrefix "composer.menu.search")}}
              {{on "input" this.onFilterInput}}
              {{on "keydown" this.onKeydown}}
              {{didInsert this.focusInput}}
            />
            {{icon "magnifying-glass"}}
          </div>
          <div class="callout-chooser-list" {{didInsert this.scrollToSelected}}>
            {{#each this.filteredCallouts as |callout index|}}
              <DButton
                class={{concatClass
                  "callout-chooser-row"
                  (if (eq callout.type @value) "is-selected")
                  (if (eq index this.chooserHighlightedIndex) "is-highlighted")
                }}
                data-type={{callout.type}}
                style={{this.calloutColorStyle callout.color}}
                {{on "click" (fn this.selectType callout.type)}}
              >
                <span class="callout-chooser-row__icon">
                  {{iconOrSvg callout.icon}}
                </span>
                <span class="callout-chooser-row__name">
                  {{callout.title}}
                </span>
              </DButton>
            {{/each}}
          </div>
        </div>
      </:content>
    </DMenu>
  </template>
}
