import { getOwner } from "@ember/owner";

export function setupCookedPost(hooks) {
  hooks.beforeEach(function () {
    settings.callouts = [];
    settings.callout_fallback_type = "note";
    settings.callout_fallback_icon = "";
    settings.callout_fallback_color = "#027aff";
    settings.callout_background_opacity = 10;

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });
    this.post = store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
    });
  });
}
