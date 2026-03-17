import Component from "@glimmer/component";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import iconOrSvg from "../helpers/icon-or-svg";
import CalloutChooserPanel from "./callout-chooser-panel";

export default class CalloutChooser extends Component {
  @service calloutSettings;

  menuApi = null;

  get icon() {
    const options = this.calloutSettings.find(this.args.value);
    return options?.icon || settings.callout_fallback_icon;
  }

  @action
  onRegisterApi(api) {
    this.menuApi = api;
  }

  @action
  onShow() {
    next(() => {
      // Panel handles initial selection via @selectedType
    });
  }

  @action
  onClose() {
    this.args.onClose?.();
  }

  @action
  onSelect(type) {
    this.menuApi?.close();
    this.args.onChange?.(type);
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
      ...attributes
    >
      <:trigger>
        <span class="callout-icon">
          {{iconOrSvg this.icon}}
        </span>
      </:trigger>
      <:content>
        <CalloutChooserPanel
          @selectedType={{@value}}
          @onSelect={{this.onSelect}}
        />
      </:content>
    </DMenu>
  </template>
}
