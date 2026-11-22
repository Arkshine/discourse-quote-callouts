import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// PrettyText output for a callout inside [quote="eviltrout, post:1, topic:280"].
const TOPIC_QUOTE_COOKED = `<aside class="quote no-group" data-username="eviltrout" data-post="1" data-topic="280">
<div class="title">
<div class="quote-controls"></div>
 eviltrout:</div>
<blockquote>
<blockquote>
<p>[!tip] Title<br>
Body</p>
</blockquote>
</blockquote>
</aside>`;

// Discourse topic onebox, whose excerpt is plain text.
const TOPIC_ONEBOX_COOKED = `<aside class="quote" data-post="1" data-topic="280">
<div class="title"><div class="quote-controls"></div><a href="/t/280">Title</a></div>
<blockquote>[!tip] Excerpt</blockquote>
</aside>`;

acceptance("Callouts Theme Component - Topic quotes", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    topicResponse.post_stream.posts[0].cooked = TOPIC_QUOTE_COOKED;
    topicResponse.post_stream.posts[1].cooked = TOPIC_ONEBOX_COOKED;

    server.get("/t/280.json", () => helper.response(topicResponse));
    server.get("/t/280/:post_number.json", () =>
      helper.response(topicResponse)
    );
  });

  test("callout inside topic quote in a post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 aside.quote .callout[data-callout-type='tip']")
      .exists();
    assert.dom("#post_1 aside.quote .callout-title").hasText("Title");
    assert.dom("#post_1 .callout-chooser-trigger").doesNotExist();
  });

  test("marker is stripped from topic onebox in a post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.dom("#post_2 aside.quote blockquote").hasText("Excerpt");
    assert.dom("#post_2 .callout").doesNotExist();
  });
});
