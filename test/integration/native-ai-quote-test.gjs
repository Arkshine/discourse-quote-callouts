import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CookedHtml from "discourse/components/post/cooked-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupCookedPost } from "../helpers/cooked-post-helpers.js";

module("Integration | Callout | Native AI quotes", function (hooks) {
  setupRenderingTest(hooks);

  setupCookedPost(hooks);

  test("cooked AI quotes retain their badge and nested callouts", async function (assert) {
    this.post.cooked = `
      <blockquote data-ai-generated="true">
        <span class="ai-badge" data-ai-label="AI"></span>
        <p>[!note] Literal AI content</p>
        <blockquote><p>[!note] Nested title<br>Nested body</p></blockquote>
      </blockquote>
    `;

    await render(<template><CookedHtml @post={{this.post}} /></template>);

    assert
      .dom("blockquote[data-ai-generated='true'] > .ai-badge")
      .exists("the core badge remains intact");
    assert
      .dom("blockquote[data-ai-generated='true'] > p")
      .hasText("[!note] Literal AI content");
    assert.dom("blockquote[data-ai-generated='true'] .callout").exists();
  });

  test("AI attribution protects cooked quotes without a badge element", async function (assert) {
    this.post.cooked = `
      <blockquote data-ai-generated="true">
        <p>[!note] Literal AI content</p>
      </blockquote>
    `;

    await render(<template><CookedHtml @post={{this.post}} /></template>);

    assert.dom(".callout").doesNotExist();
    assert
      .dom("blockquote[data-ai-generated='true'] > p")
      .hasText("[!note] Literal AI content");
  });
});
