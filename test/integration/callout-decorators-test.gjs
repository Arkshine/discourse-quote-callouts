import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CookedHtml from "discourse/components/post/cooked-html";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupCookedPost } from "../helpers/cooked-post-helpers.js";

module("Integration | Callout | Cooked decorators", function (hooks) {
  setupRenderingTest(hooks);

  setupCookedPost(hooks);

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
