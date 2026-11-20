import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import iconOrSvg from "../helpers/icon-or-svg.gjs";
import CalloutChooserPanel from "./callout-chooser-panel.gjs";

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
      ...attributes
      @contentClass="callout-chooser-content"
      @disabled={{@disabled}}
      @identifier="callout-chooser"
      @offset={{2}}
      @onClose={{this.onClose}}
      @onRegisterApi={{this.onRegisterApi}}
      @placement="bottom-start"
      @triggerClass="callout-chooser-trigger"
    >
      <:trigger>
        <span class="callout-icon">
          {{iconOrSvg this.icon}}
        </span>
      </:trigger>
      <:content>
        <CalloutChooserPanel
          @onSelect={{this.onSelect}}
          @selectedType={{@value}}
        />
      </:content>
    </DMenu>
  </template>
}
