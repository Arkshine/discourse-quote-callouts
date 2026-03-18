import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import TextField from "discourse/components/text-field";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import scrollIntoView from "discourse/modifiers/scroll-into-view";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import iconOrSvg from "../helpers/icon-or-svg";
import { hexToRGBA } from "../lib/utils";

export default class CalloutChooserPanel extends Component {
  @service calloutSettings;

  @tracked searchTerm = "";
  @tracked selectedTypeIndex = -1;

  get filteredCallouts() {
    const all = this.calloutSettings.all();
    if (!this.searchTerm) {
      return all;
    }

    const filter = this.searchTerm.toLowerCase();
    return all.filter(
      (callout) =>
        callout.type.includes(filter) ||
        callout.title.toLowerCase().includes(filter)
    );
  }

  @action
  search(event) {
    this.searchTerm = event.target.value;
    this.selectedTypeIndex = -1;
  }

  @action
  handleKeydown(event) {
    const items = this.filteredCallouts;

    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.selectedTypeIndex = Math.min(
        this.selectedTypeIndex + 1,
        items.length - 1
      );
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.selectedTypeIndex = Math.max(this.selectedTypeIndex - 1, 0);
    } else if (event.key === "Enter") {
      event.preventDefault();
      const item = items[this.selectedTypeIndex];
      if (item) {
        this.selectType(item.type);
      }
    }
  }

  @action
  focus(element) {
    element.focus({ preventScroll: true });
    next(() => {
      this.selectedTypeIndex = this.filteredCallouts.findIndex(
        (callout) => callout.type === this.args.selectedType
      );
    });
  }

  @action
  selectType(type) {
    this.args.onSelect?.(type);
    this.args.close?.();
  }

  calloutColorStyle(color) {
    const bg = hexToRGBA(
      color || settings.callout_fallback_color,
      settings.callout_background_opacity / 100
    );
    return trustHTML(
      `--q-callout-background: ${bg}; --q-callout-color: ${color || settings.callout_fallback_color};`
    );
  }

  <template>
    <div class="callout-chooser-panel">
      <div class="callout-chooser-search">
        <TextField
          autocomplete="off"
          @placeholder={{i18n (themePrefix "composer.menu.search")}}
          @type="search"
          {{on "input" this.search}}
          {{on "keydown" this.handleKeydown}}
          {{didInsert this.focus}}
          @value={{readonly this.searchTerm}}
        />
        {{icon "magnifying-glass"}}
      </div>
      <DropdownMenu class="callout-chooser-list" as |menu|>
        {{#each this.filteredCallouts as |callout index|}}
          <menu.item>
            <DButton
              class={{concatClass
                "callout-chooser-row"
                (if (eq callout.type @selectedType) "is-selected")
                (if (eq index this.selectedTypeIndex) "is-highlighted")
              }}
              data-type={{callout.type}}
              style={{this.calloutColorStyle callout.color}}
              @action={{fn this.selectType callout.type}}
              {{scrollIntoView (eq index this.selectedTypeIndex)}}
            >
              <span class="callout-chooser-row__icon">
                {{iconOrSvg callout.icon}}
              </span>
              <span class="callout-chooser-row__name">
                {{callout.title}}
              </span>
            </DButton>
          </menu.item>
        {{/each}}
      </DropdownMenu>
    </div>
  </template>
}
