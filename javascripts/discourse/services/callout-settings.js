import Service from "@ember/service";
import { setupCalloutSettings } from "../lib/config";
import { capitalizeFirstLetter } from "../lib/utils";

export default class CalloutSettings extends Service {
  #data = [];

  constructor() {
    super(...arguments);
    this.#data = this.#process();

    // Static settings used in the prosemirror extension
    setupCalloutSettings(this);
  }

  #process() {
    const callouts = settings.callouts || [];
    const entries = [];

    for (const callout of callouts) {
      const aliases = (callout.alias ?? "")
        .split("|")
        .map((alias) => alias.trim())
        .filter(Boolean);

      entries.push({
        ...callout,
        type: callout.type,
        name: callout.type,
        title: callout.title || capitalizeFirstLetter(callout.type),
      });

      for (const alias of aliases) {
        entries.push({
          ...callout,
          type: alias,
          mainType: callout.type,
          name: alias,
          title: callout.title || capitalizeFirstLetter(alias),
        });
      }
    }

    return entries;
  }

  allTypes() {
    return this.all().map((callout) => callout.type);
  }

  all() {
    return this.#data;
  }

  find(type) {
    const lowerType = type?.toLowerCase();
    return this.#data.find((callout) => callout.type === lowerType);
  }

  search(term) {
    return this.allTypes().filter((type) =>
      type.startsWith(term.toLowerCase())
    );
  }
}
