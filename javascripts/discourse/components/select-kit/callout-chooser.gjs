import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";
import CalloutHeader from "./callout-header";
import CalloutRow from "./callout-row";

@classNames("callout-chooser")
@selectKitOptions({
  clearable: false,
  filterable: true,
  additionalFilters: "",
  closeOnChange: true,
  showFullTitle: false,
  selectedNameComponent: CalloutHeader,
})
@pluginApiIdentifiers("callout-chooser")
export default class CalloutChooser extends ComboBoxComponent {
  @service calloutSettings;

  @tracked results = this.args?.results;

  valueProperty = "type";
  labelProperty = "title";
  titleProperty = "title";

  click() {
    const { selectKit } = this;
    const { isExpanded, open, close } = selectKit;

    if (isExpanded) {
      close();
    } else {
      open();
    }
  }

  get content() {
    const filtered = this.results?.length ? new Set(this.results) : null;
    const all = this.calloutSettings.all();

    if (filtered) {
      return all.filter((callout) => filtered.has(callout.type));
    }

    return all;
  }

  modifyComponentForRow() {
    return CalloutRow;
  }
}
