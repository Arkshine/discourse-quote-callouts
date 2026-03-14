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

  CALLOUT_WITH_MARKDOWN_TITLE: dedent(`
    > [!note] **Bold** and *italic*
    > Content with formatted title
  `),

  CALLOUT_WITH_BBCODE_TITLE: dedent(`
    > [!note] [b]Bold[/b] and [i]italic[/i]
    > Content with BBCode title
  `),

  CALLOUT_CASE_INSENSITIVE: dedent(`
    > [!Note]
  `),

  CALLOUT_WITH_EMOJI: dedent(`
    > [!note]
    > :smile:
  `),

  FOLDABLE_CALLOUT_EXPANDED: dedent(`
    > [!note]+ Expanded by default
    > This content should be visible
    > Multiple lines here
  `),

  FOLDABLE_CALLOUT_COLLAPSED: dedent(`
    > [!warning]- Collapsed by default
    > This content should be hidden initially
    > But still in the DOM
  `),

  FOLDABLE_EMPTY_CALLOUT: dedent(`
    > [!note]+
  `),

  NESTED_CALLOUT_IN_CALLOUT: dedent(`
    > [!note] Outer callout
    > Some content before
    > > [!warning] Inner callout
    > > Nested warning content
    > Back to outer content
  `),

  MULTIPLE_NESTED_CALLOUTS: dedent(`
    > [!note] Parent
    > Parent content
    > > [!tip] First child
    > > First child content
    > 
    > > [!warning] Second child
    > > Second child content
    > Back to parent
  `),

  CALLOUT_WITH_ONLY_NESTED_CALLOUT: dedent(`
    > [!note]
    > > [!tip]
    > > All content is nested
  `),

  DEEPLY_NESTED_CALLOUTS: dedent(`
    > [!note] Level 1
    > First level content
    > > [!tip] Level 2
    > > Second level content
    > > > [!warning] Level 3
    > > > Third level content
  `),

  MIXED_QUOTES_AND_CALLOUTS: dedent(`
    > Regular quote start
    > > [!note] Callout in middle
    > > Callout content
    > > > Regular nested quote
    > > > Inside the callout
    > > Back to callout
    > Back to outer quote
  `),

  CALLOUT_WITH_CODE_BLOCK: dedent(`
    > [!note] Code Example
    > Here's some code:
    > \`\`\`javascript
    > function test() {
    >   return true;
    > }
    > \`\`\`
    > And more text after
  `),

  CALLOUT_WITH_INLINE_CODE: dedent(`
    > [!tip]
    > Use \`console.log()\` to debug
    > Or \`debugger;\` statement
  `),

  CALLOUT_WITH_IMAGE: dedent(`
    > [!note]
    > Check this image:
    > ![alt text](https://example.com/image.jpg)
  `),

  CALLOUT_WITH_TABLE: dedent(`
    > [!note]
    > Here's a table:
    >
    > | Column 1 | Column 2 |
    > |----------|----------|
    > | Value A  | Value B  |
    > | Value C  | Value D  |
  `),

  NON_CALLOUT_WITH_MARKER_IN_CONTENT: dedent(`
    > This is a regular quote
    > And here is [!note] in the middle
    > Not a callout marker
  `),

  CALLOUT_TITLE_WITH_NEWLINE: dedent(`
    > [!note] Title here
    > This should be content, not title
    > More content
  `),

  ADJACENT_NESTED_CALLOUTS: dedent(`
    > [!note] Parent
    > > [!tip] First nested
    > > Tip content
    >
    > > [!warning] Second nested
    > > Warning content
  `),

  CALLOUT_WITH_TASK_LIST: dedent(`
    > [!note] Todo
    > - [ ] Unchecked task
    > - [x] Checked task
    > - [ ] Another task
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
      .dom(".callout[data-callout-type='warning']")
      .exists("Alias is correctly mapped to the main type");
    assert
      .dom(".callout[data-callout-alias='caution']")
      .exists("Alias is correctly mapped to the alias");
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

    assert
      .dom(".callout-fold")
      .doesNotExist("Fold icon is not shown for empty callout");
  });

  test("invalid callout format", async function (assert) {
    await visitAndCreate(FIXTURES.INVALID_CALLOUT_FORMAT);

    assert.dom(".callout").exists({ count: 1 }, "Only one callout is rendered");
  });

  test("callout with multiple aliases", async function (assert) {
    await visitAndCreate(FIXTURES.ALIASED_TIP);

    assert
      .dom(".callout[data-callout-type='tip']")
      .exists("Main type is recognized");
    assert
      .dom(".callout[data-callout-alias='hint']")
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

  test("callout with markdown in title", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_MARKDOWN_TITLE);

    assert
      .dom(".callout-title .callout-title-inner strong")
      .exists("Bold markdown in title is rendered");
    assert
      .dom(".callout-title .callout-title-inner em")
      .exists("Italic markdown in title is rendered");
    assert
      .dom(".callout-content")
      .includesText("Content with formatted title", "Content is correct");
  });

  test("callout with BBCode in title", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_BBCODE_TITLE);

    assert
      .dom(".callout-title .callout-title-inner .bbcode-b")
      .exists("Bold BBCode in title is rendered");
    assert
      .dom(".callout-title .callout-title-inner .bbcode-i")
      .exists("Italic BBCode in title is rendered");
    assert
      .dom(".callout-content")
      .includesText("Content with BBCode title", "Content is correct");
  });

  test("callout with insensitive case", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_BBCODE_TITLE);

    assert.dom(".callout").exists("Callout is rendered");
  });

  test("callout content emptiness", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_EMOJI);

    assert
      .dom(".callout-content")
      .exists("Content element exists with emoji")
      .hasText("", "Text content is empty but has emoji");

    assert.dom(".callout-content img").exists("Contains emoji image");
  });

  test("foldable callout expanded by default", async function (assert) {
    await visitAndCreate(FIXTURES.FOLDABLE_CALLOUT_EXPANDED);

    assert
      .dom(".callout")
      .exists("Callout is rendered")
      .hasClass("is-collapsible", "Callout is collapsible")
      .doesNotHaveClass("is-collapsed", "Callout is not collapsed");
    assert.dom(".callout-fold").exists("Fold icon is shown");
    assert
      .dom(".callout-content")
      .exists("Content is rendered")
      .hasText(
        "This content should be visible Multiple lines here",
        "Content is visible"
      );

    await click(".callout-title");
    assert
      .dom(".callout")
      .hasClass("is-collapsed", "Callout is now collapsed after click");
  });

  test("foldable callout collapsed by default", async function (assert) {
    await visitAndCreate(FIXTURES.FOLDABLE_CALLOUT_COLLAPSED);

    assert
      .dom(".callout")
      .exists("Callout is rendered")
      .hasClass("is-collapsible", "Callout is collapsible")
      .hasClass("is-collapsed", "Callout is collapsed by default");
    assert.dom(".callout-fold").exists("Fold icon is shown");
    assert
      .dom(".callout-content")
      .exists("Content exists in DOM")
      .hasText(
        "This content should be hidden initially But still in the DOM",
        "Content is in DOM"
      );

    await click(".callout-title");
    assert
      .dom(".callout")
      .doesNotHaveClass("is-collapsed", "Callout is now expanded after click");
  });

  test("foldable empty callout should not show fold icon", async function (assert) {
    await visitAndCreate(FIXTURES.FOLDABLE_EMPTY_CALLOUT);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout-fold")
      .doesNotExist("Fold icon is not shown for empty callout");
    assert
      .dom(".callout")
      .doesNotHaveClass(
        "is-collapsible",
        "Empty callout is not marked as collapsible"
      );
  });

  test("nested callout inside callout", async function (assert) {
    await visitAndCreate(FIXTURES.NESTED_CALLOUT_IN_CALLOUT);

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("Outer note callout exists");
    assert
      .dom(".callout[data-callout-type='note'] > .callout-title")
      .includesText("Outer callout", "Outer callout title is correct");

    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='warning']"
      )
      .exists("Inner warning callout exists inside outer callout");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='warning'] .callout-content"
      )
      .includesText(
        "Nested warning content",
        "Inner callout content is correct"
      );

    assert
      .dom(".callout[data-callout-type='note'] > .callout-content")
      .includesText("Some content before", "Outer content before nested exists")
      .includesText(
        "Back to outer content",
        "Outer content after nested exists"
      );
  });

  test("multiple nested callouts at same level", async function (assert) {
    await visitAndCreate(FIXTURES.MULTIPLE_NESTED_CALLOUTS);

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("Parent callout exists");

    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip']"
      )
      .exists("First child tip callout exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='warning']"
      )
      .exists("Second child warning callout exists");

    assert
      .dom(".callout[data-callout-type='note'] > .callout-content")
      .includesText("Parent content", "Parent content exists")
      .includesText("Back to parent", "Parent content after children exists");
  });

  test("callout with only nested callout (no own content)", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_ONLY_NESTED_CALLOUT);

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("Outer callout exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip']"
      )
      .exists("Nested callout exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip'] .callout-content"
      )
      .includesText("All content is nested", "Nested content is correct");
  });

  test("deeply nested callouts (3 levels)", async function (assert) {
    await visitAndCreate(FIXTURES.DEEPLY_NESTED_CALLOUTS);

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("Level 1 callout exists");

    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip']"
      )
      .exists("Level 2 callout exists");

    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip'] .callout[data-callout-type='warning']"
      )
      .exists("Level 3 callout exists");

    assert
      .dom(".callout[data-callout-type='note'] > .callout-content")
      .includesText("First level content", "Level 1 content exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip'] > .callout-content"
      )
      .includesText("Second level content", "Level 2 content exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip'] .callout[data-callout-type='warning'] .callout-content"
      )
      .includesText("Third level content", "Level 3 content exists");
  });

  test("mixed regular quotes and callouts", async function (assert) {
    await visitAndCreate(FIXTURES.MIXED_QUOTES_AND_CALLOUTS);

    assert.dom("blockquote").exists("Outer quote exists");

    assert
      .dom("blockquote .callout[data-callout-type='note']")
      .exists("Callout exists inside regular quote");

    assert
      .dom("blockquote .callout blockquote")
      .exists("Regular quote exists inside callout");
    assert
      .dom("blockquote .callout blockquote")
      .includesText("Regular nested quote", "Nested quote content is correct");
  });

  test("callout with code block", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_CODE_BLOCK);

    assert.dom(".callout").exists("Callout is rendered");
    assert.dom(".callout pre code").exists("Code block is rendered");
    assert
      .dom(".callout pre code")
      .includesText("function test()", "Code content is preserved");
  });

  test("callout with inline code", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_INLINE_CODE);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout-content code")
      .exists({ count: 2 }, "Inline code elements exist");
    assert
      .dom(".callout-content")
      .includesText("console.log()", "First code snippet exists")
      .includesText("debugger;", "Second code snippet exists");
  });

  test("callout with image", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_IMAGE);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout-content img")
      .exists("Image is rendered")
      .hasAttribute("alt", "alt text", "Image has alt text")
      .hasAttribute(
        "src",
        "https://example.com/image.jpg",
        "Image has correct src"
      );
  });

  test("callout with table", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_TABLE);

    assert.dom(".callout").exists("Callout is rendered");
    assert.dom(".callout-content table").exists("Table is rendered");
    assert
      .dom(".callout-content table th")
      .exists({ count: 2 }, "Table headers exist");
    assert
      .dom(".callout-content table td")
      .exists({ count: 4 }, "Table cells exist");
  });

  test("non-callout with marker in content", async function (assert) {
    await visitAndCreate(FIXTURES.NON_CALLOUT_WITH_MARKER_IN_CONTENT);

    assert.dom("blockquote").exists("Blockquote exists");
    assert
      .dom(".callout")
      .doesNotExist("Marker in middle of content should not create callout");
    assert
      .dom("blockquote")
      .includesText("[!note]", "Marker text is preserved in regular quote");
  });

  test("callout title with newline", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_TITLE_WITH_NEWLINE);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout-title .callout-title-inner")
      .hasText("Title here", "Only first line is title");
    assert
      .dom(".callout-content")
      .includesText(
        "This should be content, not title",
        "Text after newline is content"
      );
  });

  test("adjacent nested callouts", async function (assert) {
    await visitAndCreate(FIXTURES.ADJACENT_NESTED_CALLOUTS);

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("Parent callout exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip']"
      )
      .exists("First nested callout exists");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='warning']"
      )
      .exists("Second nested callout exists");
  });

  test("callout with task list", async function (assert) {
    await visitAndCreate(FIXTURES.CALLOUT_WITH_TASK_LIST);

    assert.dom(".callout").exists("Callout is rendered");
    assert
      .dom(".callout-content ul li")
      .exists({ count: 3 }, "All task items exist");
  });

  test("escapedExcerpt strips basic callout marker", function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", {
      excerpt: "[!note] This is a note",
      pinned: true,
    });

    assert.strictEqual(
      topic.escapedExcerpt,
      "This is a note",
      "basic callout marker is stripped from excerpt"
    );
  });

  test("escapedExcerpt strips marker with fold indicator", function (assert) {
    const store = this.owner.lookup("service:store");
    const topicExpanded = store.createRecord("topic", {
      excerpt: "[!note]+ Expanded content",
      pinned: true,
    });
    const topicCollapsed = store.createRecord("topic", {
      excerpt: "[!warning]- Collapsed content",
      pinned: true,
    });

    assert.strictEqual(
      topicExpanded.escapedExcerpt,
      "Expanded content",
      "fold + marker is stripped"
    );
    assert.strictEqual(
      topicCollapsed.escapedExcerpt,
      "Collapsed content",
      "fold - marker is stripped"
    );
  });

  test("escapedExcerpt strips marker with hyphenated type", function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", {
      excerpt: "[!my-custom-type] Content here",
      pinned: true,
    });

    assert.strictEqual(
      topic.escapedExcerpt,
      "Content here",
      "hyphenated callout type is stripped"
    );
  });

  test("escapedExcerpt preserves non-callout brackets", function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", {
      excerpt: "Regular [text] here",
      pinned: true,
    });

    assert.strictEqual(
      topic.escapedExcerpt,
      "Regular [text] here",
      "non-callout brackets are not stripped"
    );
  });

  test("escapedExcerpt returns null when excerpt is not set", function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", { pinned: true });

    assert.strictEqual(
      topic.escapedExcerpt,
      undefined,
      "returns undefined when no excerpt"
    );
  });
});
