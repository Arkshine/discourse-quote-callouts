import Service from "@ember/service";
import {
  findCalloutOptions,
  getAllCallouts,
  getAllCalloutTypes,
  searchCallouts,
} from "../lib/config";

export default class CalloutSettings extends Service {
  allTypes() {
    return getAllCalloutTypes();
  }

  all() {
    return getAllCallouts();
  }

  find(type) {
    return findCalloutOptions(type);
  }

  search(term) {
    return searchCallouts(term);
  }
}
