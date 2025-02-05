import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function dedent(calloutText) {
  return calloutText
    .split("\n")
    .map((line) => line.trim())
    .join("\n")
    .trim();
}

const FIXTURES = {
  BASIC_CALLOUT: dedent(`
    > [!note]
    > This is a note callout
  `),

  ALIASED_CALLOUT: dedent(`
    > [!caution]
    > This is a warning callout
  `),

  UNKNOWN_TYPE_CALLOUT: dedent(`
    > [!unknown-type]
    > This should use fallback
  `),

  MULTIPLE_CALLOUTS: dedent(`
    > [!note]
    > First callout

    Some text between

    > [!warning]
    > Second callout
  `),

  CUSTOM_TITLE_CALLOUT: dedent(`
    > [!tip]
    > This is a tip
  `),

  NESTED_CONTENT: dedent(`
    > [!example]
    > ## Heading
    > - List item 1
    > - List item 2
    > 
    > \`inline code\`
  `),

  EMPTY_CALLOUT: dedent(`
    > [!note]
  `),

  INVALID_CALLOUT_FORMAT: dedent(`
    > [!note]
    > First callout
    > [!warning]
    > This won't create a second callout
  `),

  ALIASED_TIP: dedent(`
    > [!hint]
    > This uses the tip alias
  `),

  MULTILINE_CONTENT: dedent(`
    > [!note]
    > First line
    > Second line
    > Third line
  `),

  MARKDOWN_FORMATTING: dedent(`
    > [!note]
    > **Bold** and *italic* and ~~strikethrough~~
  `),

  WITH_LINKS: dedent(`
    > [!note]
    > Here's a [link](https://example.com)
  `),

  CALLOUT_WITH_CUSTOM_INLINE_TITLE: dedent(`
    > [!note] My Custom Title
    > Content with custom title
  `),

  CALLOUT_WITH_NESTED_MARKDOWN_QUOTE: dedent(`
    > [!note]
    > Here's a nested quote:
    > > This is a nested quote
    > > It continues here
    > And this is still part of the callout
  `),

  CALLOUT_WITH_NESTED_BBCODE_QUOTE: dedent(`
    > [!note]
    > Here's a nested quote:
    > [quote]
    > This is a nested BBCode quote
    > Another line in the quote
    > [/quote]
    > And this is still part of the callout
  `),

  CALLOUT_INSIDE_MARKDOWN_QUOTE: dedent(`
    > Regular quote start
    > > [!note]
    > > This is a callout inside a quote
    > Quote continues
  `),

  CALLOUT_INSIDE_BBCODE_QUOTE: dedent(`
    [quote]
    > [!note]
    > This is a callout inside a BBCode quote
    More callout content
    [/quote]
  `),

  DEEPLY_NESTED_QUOTES: dedent(`
    > [!note]
    > First level
    > > Second level
    > > [quote]
    > > Third level BBCode
    > > [/quote]
    > Back to callout
  `),
};

async function visitAndCreate(content) {
  await visit("/latest");
  await click("#create-topic");

  const categoryChooser = selectKit(".category-chooser");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(2);

  await fillIn(".d-editor-input", content);
}

acceptance("Callouts Theme Component", function (needs) {
  needs.user();

  needs.hooks.beforeEach(() => {
    settings.callouts = [
      {
        type: "note",
        alias: "",
        icon: "far-pen-to-square",
        title: "",
        color: "#086ddd",
      },
      {
        type: "warning",
        alias: "caution|attention",
        icon: "triangle-exclamation",
        title: "Custom Warning",
        color: "#ec7500",
      },
      {
        type: "tip",
        alias: "hint",
        icon: "fire-flame-curved",
        title: "Pro Tip",
        color: "#00bfbc",
      },
      {
        type: "example",
        alias: "",
        icon: "list",
        title: "",
        color: "#7852ee",
      },
    ];
    settings.callout_fallback_type = "note";
    settings.callout_fallback_icon = "far-pen-to-square";
    settings.callout_fallback_color = "#027aff";
    settings.svg_icons =
      "far-pen-to-square|triangle-exclamation|fire-flame-curved|list";
  });

  test("basic callout rendering", async function (assert) {
    await visitAndCreate(FIXTURES.BASIC_CALLOUT);

    assert
      .dom(".callout")
      .exists("Callout container exists")
      .hasAttribute("data-callout-type", "note", "Callout has correct type");
    assert
      .dom(".callout-title .callout-title-inner")
      .hasText("Note", "Callout title is rendered");
    assert
      .dom(".callout-content")
      .hasText("This is a note callout", "Callout content is rendered");
    assert
      .dom(".callout-icon svg")
      .hasClass("d-icon-far-pen-to-square", "Callout icon is rendered");
  });

  test("callout with aliases", async function (assert) {
    await visitAndCreate(FIXTURES.ALIASED_CALLOUT);

    assert
      .dom(".callout[data-callout-type='caution']")
      .exists("Alias is correctly mapped to correct type");
    assert
      .dom(".callout-icon svg")
      .hasClass("d-icon-triangle-exclamation", "Callout icon is correct");
  });

  test("fallback behavior", async function (assert) {
    await visitAndCreate(FIXTURES.UNKNOWN_TYPE_CALLOUT);

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("Fallback type is applied");
    assert
      .dom(".callout-title .callout-title-inner")
      .hasText("Note", "Title is correct");
    assert
      .dom(".callout-icon svg")
      .hasClass("d-icon-far-pen-to-square", "Fallback icon is used");
  });

  test("multiple callouts in one post", async function (assert) {
    await visitAndCreate(FIXTURES.MULTIPLE_CALLOUTS);

    assert.dom(".callout").exists({ count: 2 }, "Both callouts are rendered");
    assert
      .dom(".callout[data-callout-type='note']")
      .exists("First callout type is correct");
    assert
      .dom(".callout[data-callout-type='warning']")
      .exists("Second callout type is correct");
  });

  test("callout with custom title", async function (assert) {
    await visitAndCreate(FIXTURES.CUSTOM_TITLE_CALLOUT);

    assert
      .dom(".callout-title .callout-title-inner")
      .hasText("Pro Tip", "Custom title from settings is used");
  });

  test("callout with nested content", async function (assert) {
    await visitAndCreate(FIXTURES.NESTED_CONTENT);

    assert.dom(".callout h2").exists("Heading is rendered");
    assert
      .dom(".callout ul li")
      .exists({ count: 2 }, "List items are rendered");
    assert.dom(".callout code").exists("Code is rendered");
  });

  test("callout with empty content", async function (assert) {
    await visitAndCreate(FIXTURES.EMPTY_CALLOUT);

    assert.dom(".callout").exists("Empty callout is rendered");
    assert
      .dom(".callout-content")
      .doesNotExist("No content element when empty");
  });

  test("invalid callout format", async function (assert) {
    await visitAndCreate(FIXTURES.INVALID_CALLOUT_FORMAT);

    assert.dom(".callout").exists({ count: 1 }, "Only one callout is rendered");
  });

  test("callout with multiple aliases", async function (assert) {
    await visitAndCreate(FIXTURES.ALIASED_TIP);

    assert
      .dom(".callout[data-callout-type='hint']")
      .exists("Alias is recognized");
    assert
      .dom(".callout-title .callout-title-inner")
      .hasText("Pro Tip", "Correct title is used for aliased type");
    assert
      .dom(".callout-icon svg")
      .hasClass(
        "d-icon-fire-flame-curved",
        "Correct icon is used for aliased type"
      );
  });

  test("callout with multi-line content", async function (assert) {
    await visitAndCreate(FIXTURES.MULTILINE_CONTENT);

    assert
      .dom(".callout-content")
      .hasText(
        "First line Second line Third line",
        "Multi-line content is rendered correctly"
      );
  });

  test("callout with markdown formatting", async function (assert) {
    await visitAndCreate(FIXTURES.MARKDOWN_FORMATTING);

    assert.dom(".callout-content strong").exists("Bold text is rendered");
    assert.dom(".callout-content em").exists("Italic text is rendered");
    assert.dom(".callout-content s").exists("Strikethrough text is rendered");
  });

  test("callout with links", async function (assert) {
    await visitAndCreate(FIXTURES.WITH_LINKS);

    assert
      .dom(".callout-content a")
      .exists("Link is rendered")
      .hasAttribute("href", "https://example.com", "Link has correct href");
  });

  test("callout with custom inline title", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_CUSTOM_INLINE_TITLE);

    assert
      .dom(".callout")
      .exists("Callout is rendered")
      .hasAttribute("data-callout-type", "note", "Callout has correct type");
    assert
      .dom(".callout-title .callout-title-inner")
      .hasText(
        "My Custom Title",
        "Custom inline title is used instead of default"
      );
    assert
      .dom(".callout-content")
      .hasText("Content with custom title", "Content is correctly rendered");
  });

  test("callout with nested markdown quote", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_NESTED_MARKDOWN_QUOTE);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout blockquote")
      .exists("Nested quote is rendered inside callout");
    assert
      .dom(".callout-content")
      .includesText("This is a nested quote", "Quote content is preserved");
  });

  test("callout with nested BBCode quote", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_NESTED_BBCODE_QUOTE);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout blockquote")
      .exists("Nested BBCode quote is rendered inside callout");
    assert
      .dom(".callout-content")
      .includesText(
        "This is a nested BBCode quote",
        "Quote content is preserved"
      );
  });

  test("callout inside markdown quote", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_INSIDE_MARKDOWN_QUOTE);

    assert.dom("blockquote").exists("Quote is rendered");
    assert
      .dom("blockquote .callout")
      .exists("Callout is rendered inside quote");
    assert
      .dom("blockquote .callout-content")
      .hasText(
        "This is a callout inside a quote\nQuote continues",
        "Callout content is expected"
      );
  });

  test("callout inside BBCode quote", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_INSIDE_BBCODE_QUOTE);

    assert.dom(".quote").exists("BBCode quote is rendered");
    assert
      .dom(".quote .callout")
      .exists("Callout is rendered inside BBCode quote");
    assert
      .dom(".quote .callout-content")
      .hasText(
        "This is a callout inside a BBCode quote\nMore callout content",
        "Callout content is preserved"
      );
  });

  test("deeply nested quotes within callout", async function (assert) {
    await visitAndCreate(FIXTURES.DEEPLY_NESTED_QUOTES);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout blockquote")
      .exists({ count: 2 }, "Both nested quotes are rendered");
    assert
      .dom(".callout-content")
      .includesText("First level", "Original callout content is preserved");
    assert
      .dom(".callout blockquote")
      .includesText("Second level", "Markdown quote content is preserved");
    assert
      .dom(".callout blockquote .quote blockquote")
      .includesText("Third level BBCode", "BBCode quote content is preserved");
  });
});
