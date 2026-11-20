import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CookedHtml from "discourse/components/post/cooked-html";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Callout | Cooked decorators", function (hooks) {
  setupRenderingTest(hooks);

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

  test("later decorators reach callout titles and bodies", async function (assert) {
    // Registered after the callouts decorator, like plugins that load later.
    withPluginApi((api) => {
      api.decorateCookedElement((element) => {
        element
          .querySelectorAll(".probe")
          .forEach((node) => node.classList.add("decorated"));
      });
    });

    const probe = '<span class="probe">x</span>';
    this.post.cooked = `
      <blockquote>
        <p>[!note] ${probe}<br>Body ${probe}</p>
        <blockquote><p>[!warning]- Nested</p><p>${probe}</p></blockquote>
      </blockquote>
    `;

    await render(<template><CookedHtml @post={{this.post}} /></template>);

    for (const selector of [
      ".callout-title-inner",
      ".callout-content > p",
      ".callout.is-collapsed .callout-content",
    ]) {
      assert
        .dom(`${selector} .probe`)
        .hasClass("decorated", `${selector} content is decorated`);
    }
  });
});
