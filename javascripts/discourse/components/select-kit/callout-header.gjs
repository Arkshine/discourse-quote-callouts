import Component from "@glimmer/component";
import { reads } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import selectKitPropUtils from "discourse/select-kit/lib/select-kit-prop-utils";
import iconOrSvg from "../../helpers/icon-or-svg";

@tagName("")
@selectKitPropUtils
export default class CalloutHeader extends Component {
  @reads("headerLang") lang;

  <template>
    {{#if @item.icon}}
      <div
        lang={{this.lang}}
        class="select-kit-selected-name selected-name choice callout-icon"
      >
        {{iconOrSvg @item.icon}}
      </div>
    {{/if}}
  </template>
}
