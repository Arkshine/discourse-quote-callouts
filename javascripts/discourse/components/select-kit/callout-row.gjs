import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { classNames } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import iconOrSvg from "../../helpers/icon-or-svg";
import { hexToRGBA } from "../../lib/utils";

@classNames("callout-row-wrapper")
export default class CalloutRow extends SelectKitRowComponent {
  @action
  setupColor(element) {
    const { item } = this;
    element.parentElement.style.setProperty(
      "--q-callout-background",
      hexToRGBA(
        item.color || settings.callout_fallback_color,
        settings.callout_background_opacity / 100
      )
    );
  }

  <template>
    <div class="callout-selected-indicator"></div>
    <div
      class="callout-row"
      data-callout-type={{this.item.mainType}}
      data-callout-alias={{this.item.type}}
    >
      <div
        class={{concatClass "callout-title" (if this.isSelected "is-selected")}}
        {{didInsert this.setupColor}}
      >
        <span class="callout-icon">
          {{iconOrSvg this.item.icon}}
        </span>
        <span class="callout-title-inner">{{this.item.title}}</span>
      </div>
    </div>
  </template>
}
