import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CookedHtml from "discourse/components/post/cooked-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Callout | Local dates", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.discourse_local_dates_enabled = true;
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

  test("dates in titles, bodies and folded nested callouts use native formatting", async function (assert) {
    const date =
      '<span class="discourse-local-date" data-date="2026-10-25" data-time="00:00:00" data-timezone="Pacific/Pago_Pago">2026-10-25T11:00:00Z</span>';
    this.post.cooked = `
      <p class="reference-date">${date}</p>
      <blockquote>
        <p>[!note] ${date}<br>Deadline: ${date}</p>
        <blockquote><p>[!warning]- Nested</p><p>${date}</p></blockquote>
      </blockquote>
    `;

    await render(<template><CookedHtml @post={{this.post}} /></template>);

    const reference = document.querySelector(".reference-date .relative-time");
    assert.dom(reference).exists("Native date formatting is active");
    for (const selector of [
      ".callout-title-inner",
      ".callout-content > p",
      ".callout.is-collapsed .callout-content",
    ]) {
      assert
        .dom(`${selector} .discourse-local-date`)
        .hasClass("cooked-date", `${selector} contains a formatted date`);
      assert
        .dom(`${selector} .relative-time`)
        .hasText(reference.textContent, "Matches the date outside the callout");
      assert
        .dom(`${selector} .discourse-local-date`)
        .hasAttribute("data-timezone", "Pacific/Pago_Pago");
    }
  });
});
