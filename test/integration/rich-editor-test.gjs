import {
  click,
  focus,
  render,
  settled,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DEditor from "discourse/components/d-editor";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { paste } from "discourse/tests/helpers/qunit-helpers";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";
import {
  assertCursorInBody,
  callHandleClick,
  findNode,
  insertEmptyParagraphAt,
  isInsideNode,
  setCursorInNode,
  typeText,
} from "../helpers/rich-editor-helpers";

async function selectCalloutType(type) {
  await click(".callout-chooser-trigger");
  await click(`.callout-chooser-row[data-type="${type}"]`);
}

function setupCalloutSettings(hooks) {
  hooks.beforeEach(function () {
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
        title: "",
        color: "#ec7500",
      },
      {
        type: "tip",
        alias: "hint",
        icon: "fire-flame-curved",
        title: "Pro Tip",
        color: "#00bfbc",
      },
      { type: "example", alias: "", icon: "list", title: "", color: "#7852ee" },
    ];
    settings.callout_fallback_type = "note";
    settings.callout_fallback_icon = "far-pen-to-square";
    settings.callout_fallback_color = "#027aff";
    settings.svg_icons =
      "far-pen-to-square|triangle-exclamation|fire-flame-curved|list";

    this.siteSettings.rich_editor = true;
  });
}

module(
  "Integration | Rich Editor | Callout – markdown parsing & serialisation",
  function (hooks) {
    setupRenderingTest(hooks);
    setupCalloutSettings(hooks);

    test("basic note callout renders correct node structure", async function (assert) {
      const markdown = "> [!note]\n> Hello world";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".composer-callout-node")
            .exists("callout node wrapper exists");
          assert
            .dom(".composer-callout-node .callout[data-callout-type='note']")
            .exists("data-callout-type attribute is set");
          assert
            .dom(".callout-title-inner")
            .exists("title inner element exists");
          assert
            .dom(".callout-content p")
            .hasText("Hello world", "body paragraph is rendered");
        },
        markdown
      );
    });

    test("callout with custom inline title", async function (assert) {
      const markdown = "> [!note] My Custom Title\n> Content here";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-title-inner")
            .hasText("My Custom Title", "custom inline title is preserved");
        },
        markdown
      );
    });

    test("aliased callout maps to main type", async function (assert) {
      const markdown = "> [!caution]\n> Content";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".composer-callout-node .callout[data-callout-type='warning']")
            .exists("alias maps to main type for data-callout-type");
          assert
            .dom(
              ".composer-callout-node .callout[data-callout-alias='caution']"
            )
            .exists("alias is preserved in data-callout-alias");
        },
        markdown
      );
    });

    test("unknown callout type falls back to configured fallback", async function (assert) {
      await testMarkdown(
        assert,
        "> [!does-not-exist]\n> Content",
        () => {
          assert
            .dom(".composer-callout-node .callout")
            .exists("callout is rendered");
          assert
            .dom(".composer-callout-node .callout[data-callout-type='note']")
            .exists("falls back to configured fallback type");
        },
        "> [!note]\n> Content"
      );
    });

    test("foldable callout (expanded)", async function (assert) {
      const markdown = "> [!note]+ Title\n> Content";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.dom(".callout").exists("callout exists");
          assert
            .dom(".callout")
            .hasClass("is-collapsible", "callout is collapsible");
          assert
            .dom(".callout")
            .doesNotHaveClass("is-collapsed", "callout is not collapsed");
          assert.dom(".callout-fold").exists("fold control exists");
        },
        markdown
      );
    });

    test("foldable callout (collapsed)", async function (assert) {
      const markdown = "> [!warning]- Title\n> Content";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.dom(".callout").exists("callout exists");
          assert
            .dom(".callout")
            .hasClass("is-collapsible", "callout is collapsible");
          assert
            .dom(".callout")
            .hasClass("is-collapsed", "callout is collapsed");
          assert.dom(".callout-fold").exists("fold control exists");
        },
        markdown
      );
    });

    test("foldable callout with empty body doesn't add fold control", async function (assert) {
      const markdown = "> [!note]+ Title";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-content p")
            .doesNotExist("has no body paragraph");
          assert
            .dom(".callout-fold")
            .doesNotExist("fold control doesn't exist");
        },
        markdown
      );
    });

    test("nested callout inside callout", async function (assert) {
      const markdown = "> [!note] Title\n> Outer\n> > [!tip] Title\n> > Inner";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout[data-callout-type='note']")
            .exists("outer callout exists");
          assert
            .dom(
              ".callout[data-callout-type='note'] .callout[data-callout-type='tip']"
            )
            .exists("inner callout is nested correctly");
        },
        markdown
      );
    });

    test("callout with rich inline formatting", async function (assert) {
      const markdown = "> [!note]\n> **bold** and *italic*";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert.dom(".callout-content strong").exists("bold is rendered");
          assert.dom(".callout-content em").exists("italic is rendered");
        },
        markdown
      );
    });

    test("callout with multi-line body", async function (assert) {
      const markdown = "> [!note] Title\n> Line 1\n> Line 2\n> Line 3";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-content p")
            .exists({ count: 1 }, "one body paragraph");
        },
        markdown
      );
    });

    test("callout case-insensitive type parsing", async function (assert) {
      await testMarkdown(
        assert,
        "> [!NOTE]\n> Content",
        () => {
          assert
            .dom(".composer-callout-node .callout")
            .exists("callout is rendered");
        },
        "> [!note]\n> Content"
      );
    });

    test("callout with empty body", async function (assert) {
      const markdown = "> [!note]";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-content p")
            .doesNotExist("has no body paragraph");
        },
        markdown
      );
    });

    test("callout with empty body and custom title", async function (assert) {
      const markdown = "> [!note] Title";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-content p")
            .doesNotExist("has no body paragraph");
        },
        markdown
      );
    });

    test("callout with emoji in custom title", async function (assert) {
      const markdown = "> [!note] Hello :smile:\n> Content";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-title-inner img.emoji")
            .exists("emoji image is rendered in the title");
        },
        markdown
      );
    });

    test("callout with bold and emoji in custom title", async function (assert) {
      const markdown = "> [!note] **Bold** :smile:\n> Content";
      await testMarkdown(
        assert,
        markdown,
        () => {
          assert
            .dom(".callout-title-inner strong")
            .hasText("Bold", "bold text is rendered in the title");
          assert
            .dom(".callout-title-inner img.emoji")
            .exists("emoji image is rendered after bold in the title");
        },
        markdown
      );
    });
  }
);

module("Integration | Rich Editor | Callout – commands", function (hooks) {
  setupRenderingTest(hooks);
  setupCalloutSettings(hooks);

  async function setupEditor(assert, markdown) {
    const self = new (class {
      value = markdown;
    })();
    const handleSetup = (tm) => {
      self.textManipulation = tm;
      self.view = tm.view;
    };

    await render(
      <template>
        <DEditor
          @value={{self.value}}
          @processPreview={{false}}
          @onSetup={{handleSetup}}
        />
      </template>
    );

    await click(".composer-toggle-switch");
    await waitFor(".ProseMirror");
    await settled();

    return self;
  }

  function selectText(view, text) {
    let from = null;
    let to = null;

    view.state.doc.descendants((node, pos) => {
      if (from === null && node.isText && node.text?.includes(text)) {
        const offset = node.text.indexOf(text);

        from = pos + offset;
        to = from + text.length;

        return false;
      }
    });

    if (from === null) {
      return false;
    }

    const SelectionClass = view.state.selection.constructor;
    view.dispatch(
      view.state.tr.setSelection(
        SelectionClass.create(view.state.doc, from, to)
      )
    );

    return true;
  }

  function runInsertCallout(editor) {
    let error = null;
    try {
      editor.textManipulation.getSelected();
      editor.textManipulation.commands.insertCallout("note");
    } catch (e) {
      error = e;
    }
    return error;
  }

  test("insertCallout with empty selection creates a new callout", async function (assert) {
    const editor = await setupEditor(assert, "");

    const error = runInsertCallout(editor);
    await settled();

    assert.strictEqual(error, null, "no error");
    assert
      .dom(".callout[data-callout-type='note']")
      .exists("callout is created");
  });

  test("insertCallout with text selected outside a callout wraps it in a callout", async function (assert) {
    const editor = await setupEditor(assert, "Some text");

    assert.true(selectText(editor.view, "Some text"), "text selected");

    const error = runInsertCallout(editor);
    await settled();

    assert.strictEqual(error, null, "no error");
    assert
      .dom(".callout[data-callout-type='note'] .callout-content p")
      .hasText("Some text", "selected text becomes the callout body");
  });

  test("insertCallout with text selected inside a callout body creates a nested callout", async function (assert) {
    const editor = await setupEditor(assert, "> [!note]\n> More content here");

    assert.true(
      selectText(editor.view, "More content here"),
      "body text selected"
    );

    const error = runInsertCallout(editor);
    await settled();

    assert.strictEqual(
      error,
      null,
      "no crash when inserting from within a callout body"
    );
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='note']"
      )
      .exists("nested callout is created");
  });

  test("insertCallout with cursor inside a callout title wraps the whole callout", async function (assert) {
    const editor = await setupEditor(assert, "> [!note]\n> Body");

    let titlePos = null;
    editor.view.state.doc.descendants((node, pos) => {
      if (titlePos === null && node.type.name === "callout_title") {
        titlePos = pos + 1;
        return false;
      }
    });
    assert.notStrictEqual(titlePos, null, "found title node");

    const SelectionClass = editor.view.state.selection.constructor;
    editor.view.dispatch(
      editor.view.state.tr.setSelection(
        SelectionClass.create(editor.view.state.doc, titlePos)
      )
    );

    const error = runInsertCallout(editor);
    await settled();

    assert.strictEqual(error, null, "no error");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='note']"
      )
      .exists("existing callout is wrapped in a new one");
  });

  test("insertCallout with partial inline selection wraps selected text in a callout", async function (assert) {
    const editor = await setupEditor(assert, "Hello world and more");

    assert.true(selectText(editor.view, "world"), "partial text selected");

    const error = runInsertCallout(editor);
    await settled();

    assert.strictEqual(error, null, "no error");
    assert
      .dom(".callout[data-callout-type='note']")
      .exists("callout is created");
    assert
      .dom(".callout[data-callout-type='note'] .callout-content p")
      .hasText("world", "selected inline text becomes the callout body");
  });

  test("insertCallout with multi-block selection wraps all blocks in a callout", async function (assert) {
    const editor = await setupEditor(assert, "# Heading\n\nParagraph text");

    const { view } = editor;
    const { doc } = view.state;

    let from = null;
    let to = null;
    doc.descendants((node, pos) => {
      if (from === null && node.type.name === "heading") {
        from = pos + 1;
      }
      if (
        node.type.name === "paragraph" &&
        node.textContent === "Paragraph text"
      ) {
        to = pos + node.nodeSize - 1;
      }
    });

    assert.notStrictEqual(from, null, "found heading");
    assert.notStrictEqual(to, null, "found paragraph");

    const SelectionClass = view.state.selection.constructor;
    view.dispatch(
      view.state.tr.setSelection(SelectionClass.create(doc, from, to))
    );

    const error = runInsertCallout(editor);
    await settled();

    assert.strictEqual(error, null, "no error");
    assert
      .dom(".callout[data-callout-type='note']")
      .exists("callout is created");
    assert
      .dom(".callout-content h1")
      .hasText("Heading", "heading is preserved in the callout body");
    assert
      .dom(".callout-content p")
      .hasText("Paragraph text", "paragraph is preserved in the callout body");
  });
});

module("Integration | Rich Editor | Callout – node view", function (hooks) {
  setupRenderingTest(hooks);
  setupCalloutSettings(hooks);

  test("Inserted callout is selected by default", async function (assert) {
    await setupRichEditor(assert, "> [!note]\n> Hello");

    assert
      .dom(".composer-callout-node")
      .hasClass("has-selection", "callout is selected");
  });

  test("Unselected callout node view does not render controls", async function (assert) {
    await setupRichEditor(assert, "> [!note]\n> Hello\n\n> Text");

    assert
      .dom(".composer-callout-node")
      .doesNotHaveClass("has-selection", "callout is not selected");

    assert
      .dom(".callout-right-controls")
      .doesNotExist("right controls area does not exist");

    assert.dom(".callout-handle").doesNotExist("handle does not exist");
  });

  test("Selected callout node view renders controls", async function (assert) {
    await setupRichEditor(assert, "> [!note] My title\n> My content");

    assert
      .dom(".composer-callout-node")
      .hasClass("has-selection", "callout is selected");

    assert.dom(".callout-right-controls").exists("right controls area exists");
    assert.dom(".callout-handle").exists("handle exists");
  });

  test("callout chooser is present and shows correct type", async function (assert) {
    await setupRichEditor(assert, "> [!tip]\n> Content");

    assert
      .dom(".callout-chooser-trigger")
      .exists("callout chooser trigger is mounted");
    assert
      .dom(".callout-chooser-trigger .callout-icon svg")
      .hasClass("d-icon-fire-flame-curved");
  });

  test("changing callout type via chooser updates the node", async function (assert) {
    await setupRichEditor(assert, "> [!note]\n> Hello");

    await click(".composer-callout-node");
    await selectCalloutType("warning");

    assert
      .dom(".callout[data-callout-type='warning']")
      .exists("callout type is updated after chooser selection");
  });

  test("changing callout type via chooser serializes to correct markdown", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Hello");

    await click(".composer-callout-node");
    await selectCalloutType("warning");

    assert.true(
      editorClass.value.startsWith("> [!warning]"),
      `markdown starts with "> [!warning]", got: ${editorClass.value}`
    );
  });

  test("changing callout type via chooser updates the title to configured default", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Hello");

    await click(".composer-callout-node");
    await selectCalloutType("tip");

    const title = findNode(editorClass.view, "callout_title");
    assert.strictEqual(
      title.node.textContent,
      "Pro Tip",
      "title is updated to the configured default for tip"
    );
  });

  test("changing callout type via chooser updates the title to capitalized name", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Hello");

    await click(".composer-callout-node");
    await selectCalloutType("example");

    const title = findNode(editorClass.view, "callout_title");
    assert.strictEqual(
      title.node.textContent,
      "Example",
      "title is capitalized type name when no configured title exists"
    );
  });

  test("changing callout type via chooser does not overwrite a custom title", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note] My Custom\n> Hello"
    );

    await click(".composer-callout-node");
    await selectCalloutType("warning");

    const title = findNode(editorClass.view, "callout_title");
    assert.strictEqual(
      title.node.textContent,
      "My Custom",
      "custom title is preserved when changing type"
    );
  });

  test("changing callout type on non-custom title serializes without title text", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Hello");

    await click(".composer-callout-node");
    await selectCalloutType("warning");

    assert.strictEqual(
      editorClass.value,
      "> [!warning]\n> Hello",
      "markdown has no title text because hasCustomTitle remains false"
    );
  });

  test("clicking delete button removes the callout", async function (assert) {
    await setupRichEditor(assert, "> [!note]\n> Hello");

    assert.dom(".composer-callout-node").exists("callout is present");
    assert.dom(".callout-right-controls").exists("right controls area exists");
    assert.dom(".callout-delete-btn").exists("delete button is present");

    await click(".callout-delete-btn");

    assert
      .dom(".composer-callout-node")
      .doesNotExist("callout is removed after delete");
  });

  test("fold toggle is present when callout is collapsible", async function (assert) {
    await setupRichEditor(
      assert,
      "> [!note]-\nContent \n\n > [!tip]+\nContent"
    );

    assert
      .dom("[data-callout-type='note'] .callout-fold")
      .exists("fold toggle exists for note");
    assert
      .dom("[data-callout-type='tip'] .callout-fold")
      .exists("fold toggle exists for tip");

    assert
      .dom("[data-callout-type='note']")
      .hasClass("is-collapsed", "note callout is collapsed");
    assert
      .dom("[data-callout-type='tip']")
      .doesNotHaveClass("is-collapsed", "tip callout is not collapsed");

    assert
      .dom("[data-callout-type='note']")
      .hasClass("is-collapsible", "note callout is collapsible");
    assert
      .dom("[data-callout-type='tip']")
      .hasClass("is-collapsible", "tip callout is collapsible");

    await click("[data-callout-type='note'] .callout-fold");
    assert
      .dom("[data-callout-type='note']")
      .doesNotHaveClass("is-collapsed", "note callout is expanded");

    await click("[data-callout-type='tip'] .callout-fold");
    assert
      .dom("[data-callout-type='tip']")
      .hasClass("is-collapsed", "tip callout is collapsed");
  });

  test("fold controls toggle collapsed state", async function (assert) {
    await setupRichEditor(
      assert,
      "> [!note]+\n> Content \n\n > [!tip]-\nContent"
    );

    await focus("[data-callout-type='note']");
    await click("[data-callout-type='note'] .callout-fold");
    assert
      .dom("[data-callout-type='note']")
      .hasClass("is-collapsed", "body is collapsed after fold selection");

    await focus("[data-callout-type='tip']");
    await click("[data-callout-type='tip'] .callout-fold");
    assert
      .dom("[data-callout-type='tip']")
      .doesNotHaveClass(
        "is-collapsed",
        "body is expanded after fold selection"
      );
  });

  test("fold toggle options updates the state", async function (assert) {
    await setupRichEditor(assert, "> [!note]\n> Content");

    await focus(".callout");
    assert
      .dom(".callout-options-menu-trigger")
      .exists("fold toggle options exists");
    await click(".callout-options-menu-trigger");

    assert.dom(".option-collapsed").exists("fold option collapsed exists");
    assert.dom(".option-expanded").exists("fold option expanded exists");
    assert.dom(".option-none").exists("fold option none exists");
    assert.dom(".option-none.active").exists("fold option none is active");

    await click(".option-collapsed");
    assert
      .dom(".callout")
      .hasClass("is-collapsed", "body is collapsed after fold selection");
    assert
      .dom(".option-collapsed")
      .hasClass("active", "fold option collapsed is active");
    assert
      .dom(".option-none")
      .doesNotHaveClass("active", "fold option none is not active");

    await click(".option-expanded");
    assert
      .dom(".callout")
      .doesNotHaveClass(
        "is-collapsed",
        "body is expanded after fold selection"
      );
    assert
      .dom(".option-expanded")
      .hasClass("active", "fold option expanded is active");
    assert
      .dom(".option-collapsed")
      .doesNotHaveClass("active", "fold option collapsed is not active");
  });
});

module(
  "Integration | Rich Editor | Callout – hasCustomTitle serialization",
  function (hooks) {
    setupRenderingTest(hooks);
    setupCalloutSettings(hooks);

    Object.entries({
      "callout without custom title serializes without title in markdown": {
        markdown: "> [!note]\n> Body",
      },
      "callout with custom title serializes with title in markdown": {
        markdown: "> [!note] My Title\n> Body",
      },
      "callout with default type title does not get re-emitted if not customised":
        {
          markdown: "> [!tip]\n> Body",
        },
      "callout with same text as default title is treated as custom": {
        markdown: "> [!tip] Pro Tip\n> Body",
      },
      "foldable callout without custom title serializes fold only": {
        markdown: "> [!note]+\n> Body",
      },
      "foldable callout with custom title serializes fold and title": {
        markdown: "> [!note]+ My Title\n> Body",
      },
      "collapsed callout serializes with - fold marker": {
        markdown: "> [!note]- My Title\n> Body",
      },
    }).forEach(([name, { markdown }]) => {
      test(`${name} serializes correctly`, async function (assert) {
        await testMarkdown(assert, markdown, () => {}, markdown);
      });
    });
  }
);
module("Integration | Rich Editor | Callout – paste handler", function (hooks) {
  setupRenderingTest(hooks);
  setupCalloutSettings(hooks);

  function pasteMarkdown(text) {
    return {
      files: [],
      getData: (type) => (type === "text/plain" ? text : ""),
    };
  }

  test("pasting callout markdown as plain text creates a callout node", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");

    const text = "> [!note]\n> Body text";
    await paste(".ProseMirror", text, pasteMarkdown(text));

    assert
      .dom(".callout")
      .exists("callout node is created from pasted plain-text markdown");
    assert
      .dom(".callout-content p")
      .hasText("Body text", "body content is preserved");
    assert.true(
      editorClass.value.startsWith("> [!note]"),
      "serialized markdown starts with callout marker"
    );
  });

  test("pasting a non-callout blockquote does not create a callout node", async function (assert) {
    await setupRichEditor(assert, "");

    const text = "> Just a regular blockquote";
    await paste(".ProseMirror", text, pasteMarkdown(text));

    assert
      .dom(".callout")
      .doesNotExist("no callout node created for a regular blockquote");
  });

  test("pasting nested callout markdown creates nested callout nodes", async function (assert) {
    await setupRichEditor(assert, "");

    const text = "> [!note]\n> Outer\n> > [!tip]\n> > Inner";
    await paste(".ProseMirror", text, pasteMarkdown(text));

    assert
      .dom(".callout[data-callout-type='note']")
      .exists("outer callout is created");
    assert
      .dom(
        ".callout[data-callout-type='note'] .callout[data-callout-type='tip']"
      )
      .exists("inner callout is nested correctly");
  });

  test("pasting callout with custom title preserves it", async function (assert) {
    await setupRichEditor(assert, "");

    const text = "> [!note] My Title\n> Body text";
    await paste(".ProseMirror", text, pasteMarkdown(text));

    assert
      .dom(".callout-title-inner")
      .hasText("My Title", "custom title is preserved from pasted markdown");
  });

  test("pasting callout with fold marker creates collapsible node", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");

    const text = "> [!note]+\n> Body text";
    await paste(".ProseMirror", text, pasteMarkdown(text));

    const callout = findNode(editorClass.view, "callout");
    assert.notStrictEqual(callout, null, "callout was created");
    assert.true(
      callout.node.attrs.isCollapsible,
      "pasted callout is collapsible"
    );
  });
});

module(
  "Integration | Rich Editor | Callout – hasCustomTitle and hasBody sync",
  function (hooks) {
    setupRenderingTest(hooks);
    setupCalloutSettings(hooks);

    test("clearing the title text and moving focus away restores the default title", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Body");
      const { view } = editorClass;

      const title = findNode(view, "callout_title");
      view.dispatch(
        view.state.tr.delete(
          title.pos + 1,
          title.pos + 1 + title.node.content.size
        )
      );

      setCursorInNode(view, "callout_body");
      await settled();

      assert.false(
        editorClass.value.includes("Note"),
        `default title must not appear in markdown: ${editorClass.value}`
      );
      assert.true(
        editorClass.value.startsWith("> [!note]\n"),
        `markdown remains clean: ${editorClass.value}`
      );
    });

    test("editing title to non-empty and moving focus does not trigger default restore", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Body");
      const { view } = editorClass;

      const title = findNode(view, "callout_title");
      assert.notStrictEqual(title, null, "found title node");

      const { schema } = view.state;
      view.dispatch(
        view.state.tr.replaceWith(
          title.pos + 1,
          title.pos + 1 + title.node.content.size,
          schema.text("Custom")
        )
      );
      await settled();

      setCursorInNode(view, "callout_body");
      await settled();
      const titleAfter = findNode(view, "callout_title");
      assert.strictEqual(
        titleAfter.node.textContent,
        "Custom",
        "non-empty title is preserved, not restored to default"
      );
    });

    test("clearing title on a type with configured default restores that default", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!tip] My Custom Tip Title\n> Body"
      );
      const { view } = editorClass;

      setCursorInNode(view, "callout_title");
      await settled();

      const title = findNode(view, "callout_title");
      assert.notStrictEqual(title, null, "found title node");

      view.dispatch(
        view.state.tr.delete(
          title.pos + 1,
          title.pos + 1 + title.node.content.size
        )
      );
      let bodyTextPos = null;
      view.state.doc.descendants((node, pos) => {
        if (bodyTextPos === null && node.isText) {
          bodyTextPos = pos;
          return false;
        }
      });
      assert.notStrictEqual(bodyTextPos, null, "found body text position");

      const SelectionClass = view.state.selection.constructor;
      view.dispatch(
        view.state.tr.setSelection(
          SelectionClass.create(view.state.doc, bodyTextPos)
        )
      );
      await settled();

      const titleAfter = findNode(view, "callout_title");
      assert.strictEqual(
        titleAfter.node.textContent,
        "Pro Tip",
        "title is restored to the configured default for tip type"
      );
    });

    test("editing title marks hasCustomTitle and serializes correctly", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Body");
      const { view } = editorClass;

      const title = findNode(view, "callout_title");
      const { schema } = view.state;

      view.dispatch(
        view.state.tr.replaceWith(
          title.pos + 1,
          title.pos + 1 + title.node.content.size,
          schema.text("My Custom Title")
        )
      );
      await settled();

      assert.true(
        findNode(view, "callout").node.attrs.hasCustomTitle,
        "hasCustomTitle is set to true after editing"
      );
      assert.strictEqual(
        editorClass.value,
        "> [!note] My Custom Title\n> Body",
        "serialized markdown includes the custom title"
      );
    });

    test("clearing custom title and changing type via chooser updates the title", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Body");

      const { view } = editorClass;

      const title = findNode(view, "callout_title");
      const { schema } = view.state;
      view.dispatch(
        view.state.tr.replaceWith(
          title.pos + 1,
          title.pos + 1 + title.node.content.size,
          schema.text("My Custom Title")
        )
      );
      await settled();

      const callout = findNode(view, "callout");
      assert.true(
        callout.node.attrs.hasCustomTitle,
        "callout has custom title after editing"
      );

      setCursorInNode(view, "callout_title");
      await settled();

      const titleAfterEdit = findNode(view, "callout_title");
      view.dispatch(
        view.state.tr.delete(
          titleAfterEdit.pos + 1,
          titleAfterEdit.pos + 1 + titleAfterEdit.node.content.size
        )
      );

      setCursorInNode(view, "callout_body");
      await settled();

      const calloutAfterRestore = findNode(view, "callout");
      assert.false(
        calloutAfterRestore.node.attrs.hasCustomTitle,
        "hasCustomTitle is reset after default title restore"
      );

      await click(".composer-callout-node");
      await selectCalloutType("warning");
      await settled();

      const titleAfterTypeChange = findNode(view, "callout_title");
      assert.strictEqual(
        titleAfterTypeChange.node.textContent,
        "Warning",
        "title is updated to the new type's default after type change"
      );
    });

    test("adding body content syncs hasBody to true", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]");
      const { view } = editorClass;

      const callout = findNode(view, "callout");
      assert.false(callout.node.attrs.hasBody, "hasBody starts false");

      setCursorInNode(view, "callout_title");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "Enter");

      const calloutAfter = findNode(view, "callout");
      assert.true(
        calloutAfter.node.attrs.hasBody,
        "hasBody is synced to true after body content is added"
      );
    });

    test("removing all body content syncs hasBody to false", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]\n> Body");
      const { view } = editorClass;

      const callout = findNode(view, "callout");
      assert.true(callout.node.attrs.hasBody, "hasBody starts true");

      const body = findNode(view, "callout_body");
      const para = body.node.child(0);
      view.dispatch(
        view.state.tr.delete(body.pos + 1, body.pos + 1 + para.nodeSize)
      );
      await settled();

      const calloutAfter = findNode(view, "callout");
      assert.false(
        calloutAfter.node.attrs.hasBody,
        "hasBody is synced to false after body content is removed"
      );
    });
  }
);

module(
  "Integration | Rich Editor | Callout – keyboard navigation",
  function (hooks) {
    setupRenderingTest(hooks);
    setupCalloutSettings(hooks);

    test("Enter in title moves cursor into the callout body", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Body text"
      );

      setCursorInNode(editorClass.view, "callout_title");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "Enter");

      assertCursorInBody(assert, editorClass.view);
    });

    test("Enter in title with empty body inserts a paragraph first", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]");

      setCursorInNode(editorClass.view, "callout_title");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "Enter");

      assertCursorInBody(assert, editorClass.view);
    });

    test("Enter in collapsed title expands the callout and moves cursor to body", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]-\n> Body text"
      );
      const { view } = editorClass;

      setCursorInNode(view, "callout_title");
      await settled();

      assert.true(
        findNode(view, "callout")?.node.attrs.isCollapsed,
        "callout starts collapsed"
      );

      await triggerKeyEvent(".ProseMirror", "keydown", "Enter");

      assert.false(
        findNode(view, "callout")?.node.attrs.isCollapsed,
        "callout is expanded after Enter"
      );
      assertCursorInBody(assert, view);
    });

    test("Enter in title inserts paragraph when body starts with nested callout", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> > [!tip]\n> > Inner"
      );
      const { view } = editorClass;

      setCursorInNode(view, "callout_title");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "Enter");

      assertCursorInBody(assert, view);

      const outerBody = findNode(view, "callout_body");
      assert.strictEqual(
        outerBody.node.child(0).type.name,
        "paragraph",
        "a paragraph was inserted before the nested callout"
      );
    });

    test("ArrowDown from title into empty body inserts a paragraph and enters it", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]");

      setCursorInNode(editorClass.view, "callout_title");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");

      assertCursorInBody(assert, editorClass.view);
    });

    test("ArrowDown on trailing empty paragraph in body exits the callout", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Content"
      );
      const { view } = editorClass;

      const body = findNode(view, "callout_body");
      assert.notStrictEqual(body, null, "found callout_body");

      insertEmptyParagraphAt(view, body.pos + body.node.nodeSize - 1);
      await settled();

      setCursorInNode(view, "paragraph", (n) => n.content.size === 0);
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");

      assert.false(
        isInsideNode(view.state.selection, "callout"),
        "cursor has exited the callout"
      );
    });

    test("ArrowDown at end of inner callout body inserts paragraph inside outer callout", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Outer\n> > [!tip]\n> > Inner content"
      );
      const { view } = editorClass;

      setCursorInNode(
        view,
        "callout_body",
        (_n, _pos, parent) =>
          parent?.type.name === "callout" && parent.attrs.type === "tip"
      );
      await settled();

      const outerCallout = findNode(
        view,
        "callout",
        (n) => n.attrs.type === "note"
      );
      const bodyBefore = outerCallout.node.child(1).childCount;

      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");

      const outerCalloutAfter = findNode(
        view,
        "callout",
        (n) => n.attrs.type === "note"
      );
      const bodyAfter = outerCalloutAfter.node.child(1).childCount;

      assert.ok(
        bodyAfter > bodyBefore,
        "a new paragraph was added inside the outer callout"
      );
      assert.true(
        isInsideNode(view.state.selection, "callout"),
        "cursor is still inside a callout"
      );
    });

    test("ArrowDown from trailing empty paragraph does not insert duplicate when content follows", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Outer\n> > [!tip]\n> > Inner"
      );
      const { view } = editorClass;

      const body = findNode(view, "callout_body");
      assert.notStrictEqual(body, null, "found outer callout_body");

      insertEmptyParagraphAt(view, body.pos + body.node.nodeSize - 1);
      await settled();

      setCursorInNode(view, "paragraph", (n) => n.content.size === 0);
      await settled();

      const docSizeBefore = view.state.doc.content.size;

      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");

      assert.ok(
        view.state.doc.content.size <= docSizeBefore,
        "no extra paragraph inserted when content already follows"
      );
      assert.false(
        isInsideNode(view.state.selection, "callout"),
        "cursor exited the outer callout"
      );
    });

    test("ArrowUp from empty paragraph after callout moves cursor back into the body", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Content"
      );
      const { view } = editorClass;

      const callout = findNode(view, "callout");
      assert.notStrictEqual(callout, null, "found callout node");

      insertEmptyParagraphAt(view, callout.pos + callout.node.nodeSize);
      await settled();

      setCursorInNode(
        view,
        "paragraph",
        (n, _pos, parent) =>
          n.content.size === 0 && parent?.type.name !== "callout_body"
      );
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowUp");

      assert.true(
        isInsideNode(view.state.selection, "callout_body"),
        "cursor moved back into the callout body"
      );
    });

    test("ArrowUp from body to title cleans up the auto-inserted empty paragraph", async function (assert) {
      const [editorClass] = await setupRichEditor(assert, "> [!note]");
      const { view } = editorClass;

      setCursorInNode(view, "callout_title");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowDown");

      assertCursorInBody(assert, view, "paragraph created after ArrowDown");

      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowUp");

      assert.strictEqual(
        findNode(view, "callout_body")?.node.childCount,
        0,
        "empty paragraph was cleaned up from body"
      );
    });

    test("empty paragraph is not cleaned up on mouse-driven navigation", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Content"
      );
      const { view } = editorClass;

      const body = findNode(view, "callout_body");
      insertEmptyParagraphAt(view, body.pos + body.node.nodeSize - 1);
      await settled();

      setCursorInNode(view, "paragraph", (n) => n.content.size === 0);
      await settled();

      assert.strictEqual(
        findNode(view, "callout_body")?.node.childCount,
        2,
        "body has two paragraphs (content + empty)"
      );

      const SelectionClass = view.state.selection.constructor;
      const titleNode = findNode(view, "callout_title");
      view.dispatch(
        view.state.tr.setSelection(
          SelectionClass.near(view.state.doc.resolve(titleNode.pos + 1))
        )
      );
      await settled();

      assert.strictEqual(
        findNode(view, "callout_body")?.node.childCount,
        2,
        "empty paragraph is preserved because navigation was not keyboard-driven"
      );
    });

    test("ArrowUp from non-first paragraph in body does not trigger cleanup", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> First\n>\n> Second"
      );
      const { view } = editorClass;

      const body = findNode(view, "callout_body");
      assert.ok(body.node.childCount > 1, "body has multiple paragraphs");

      setCursorInNode(view, "text", (n) => n.text === "Second");
      await settled();

      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowUp");

      const bodyAfter = findNode(view, "callout_body");
      assert.ok(
        bodyAfter.node.childCount > 1,
        "paragraphs are preserved, ArrowUp did not remove any"
      );
    });

    test("ArrowUp from content below callout inserts paragraph when body ends with nested callout", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> content\n> > [!abstract]\n\nText"
      );
      const { view } = editorClass;

      setCursorInNode(view, "text", (n) => n.text === "Text");
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowUp");

      const outerBody = findNode(view, "callout_body");
      const lastChild = outerBody.node.lastChild;
      assert.strictEqual(
        lastChild?.type.name,
        "paragraph",
        "a paragraph was inserted at the end of the outer callout body"
      );
      assert.true(
        isInsideNode(view.state.selection, "callout_body"),
        "cursor is inside the callout body"
      );
    });

    test("ArrowUp from empty paragraph does not enter nested callout when non-callout content exists above", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> content\n> > [!tip]\n> > Inner"
      );
      const { view } = editorClass;

      const outerBody = findNode(view, "callout_body");
      insertEmptyParagraphAt(view, outerBody.pos + outerBody.node.nodeSize - 1);
      await settled();

      setCursorInNode(view, "paragraph", (n) => n.content.size === 0);
      await settled();
      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowUp");

      const bodyAfter = findNode(view, "callout_body");
      assert.ok(
        bodyAfter.node.childCount > 1,
        "empty paragraph is still in the outer body (was not consumed by entering nested callout)"
      );
    });

    test("ArrowLeft at position 0 in title opens the callout chooser", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Body text"
      );
      const { view } = editorClass;

      setCursorInNode(view, "callout_title");
      await settled();

      assert.strictEqual(
        view.state.selection.$from.parentOffset,
        0,
        "cursor is at position 0 in the title"
      );

      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowLeft");

      assert
        .dom(".callout-chooser-trigger")
        .hasClass("-expanded", "callout chooser is opened");
    });

    test("ArrowLeft mid-title does not open the callout chooser", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note] My Title\n> Body text"
      );
      const { view } = editorClass;

      setCursorInNode(view, "text", (n) => n.text?.startsWith("My"));
      await settled();

      assert.ok(
        view.state.selection.$from.parentOffset > 0,
        "cursor is not at position 0"
      );

      await triggerKeyEvent(".ProseMirror", "keydown", "ArrowLeft");

      assert
        .dom(".callout-chooser-trigger")
        .doesNotHaveClass("-expanded", "callout chooser is NOT opened");
    });
  }
);

module(
  "Integration | Rich Editor | Callout – click to insert paragraph",
  function (hooks) {
    setupRenderingTest(hooks);
    setupCalloutSettings(hooks);

    test("clicking after a nested callout inside body inserts a paragraph", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Outer\n> > [!tip]\n> > Inner"
      );
      const { view } = editorClass;

      const innerCallout = findNode(
        view,
        "callout",
        (n) => n.attrs.type === "tip"
      );
      assert.notStrictEqual(innerCallout, null, "found inner callout");

      const posAfterInner = innerCallout.pos + innerCallout.node.nodeSize;

      const outerBody = findNode(view, "callout_body");
      const childCountBefore = outerBody.node.childCount;

      callHandleClick(view, posAfterInner);
      await settled();

      const outerBodyAfter = findNode(view, "callout_body");
      assert.ok(
        outerBodyAfter.node.childCount > childCountBefore,
        "a paragraph was inserted after the nested callout"
      );
    });

    test("clicking does not insert a duplicate when an empty paragraph already exists after nested callout", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> > [!tip]\n> > Inner"
      );
      const { view } = editorClass;

      const outerBody = findNode(view, "callout_body");
      const endOfBody = outerBody.pos + outerBody.node.nodeSize - 1;

      callHandleClick(view, endOfBody);
      await settled();

      const bodyAfterFirst = findNode(view, "callout_body");
      const childCountAfterFirst = bodyAfterFirst.node.childCount;

      const endOfBodyUpdated =
        bodyAfterFirst.pos + bodyAfterFirst.node.nodeSize - 1;
      callHandleClick(view, endOfBodyUpdated);
      await settled();

      const bodyAfterSecond = findNode(view, "callout_body");
      assert.strictEqual(
        bodyAfterSecond.node.childCount,
        childCountAfterFirst,
        "no duplicate paragraph inserted on second click"
      );
    });

    test("clicking at end of body with text content does not insert a paragraph", async function (assert) {
      const [editorClass] = await setupRichEditor(
        assert,
        "> [!note]\n> Body text"
      );
      const { view } = editorClass;

      const body = findNode(view, "callout_body");
      assert.notStrictEqual(body, null, "found callout_body");

      const endOfBody = body.pos + body.node.nodeSize - 1;
      const childCountBefore = body.node.childCount;

      callHandleClick(view, endOfBody);
      await settled();

      const bodyAfter = findNode(view, "callout_body");
      assert.strictEqual(
        bodyAfter.node.childCount,
        childCountBefore,
        "no paragraph inserted because body ends with text, not a nested callout"
      );
    });
  }
);

module("Integration | Rich Editor | Callout – input rules", function (hooks) {
  setupRenderingTest(hooks);
  setupCalloutSettings(hooks);

  test("/callout creates a default note callout with cursor in body", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "/callout ", settled);

    const callout = findNode(view, "callout");
    assert.notStrictEqual(callout, null, "callout node was created");
    assert.strictEqual(
      callout.node.attrs.type,
      "note",
      "callout defaults to note type"
    );
    assertCursorInBody(assert, view);
  });

  test("/callout:tip creates a tip callout", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "/callout:tip ", settled);

    const callout = findNode(view, "callout");
    assert.notStrictEqual(callout, null, "callout node was created");
    assert.strictEqual(callout.node.attrs.type, "tip", "callout type is tip");
    assertCursorInBody(assert, view);
  });

  test("!!tip creates a tip callout with cursor in body", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "!!tip ", settled);

    const callout = findNode(view, "callout");
    assert.notStrictEqual(callout, null, "callout node was created");
    assert.strictEqual(callout.node.attrs.type, "tip", "callout type is tip");
    assertCursorInBody(assert, view);
  });

  test("/callout populates the title with the configured default", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "/callout:note ", settled);

    const title = findNode(view, "callout_title");
    assert.notStrictEqual(title, null, "callout title exists");
    assert.strictEqual(
      title.node.textContent,
      "Note",
      "title contains the default label"
    );
    assert.false(
      findNode(view, "callout").node.attrs.hasCustomTitle,
      "hasCustomTitle is false"
    );
  });

  test("/callout:TYPE is case-insensitive", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "/callout:TIP ", settled);

    const callout = findNode(view, "callout");
    assert.notStrictEqual(callout, null, "callout node was created");
    assert.strictEqual(
      callout.node.attrs.type,
      "tip",
      "type is lowercased to tip"
    );
  });

  test("input rule does not fire mid-line", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "hello /callout ", settled);

    const callout = findNode(view, "callout");
    assert.strictEqual(
      callout,
      null,
      "no callout created when trigger is not at line start"
    );
  });

  test("/callout:unknowntype falls back to the configured default type", async function (assert) {
    const [editorClass] = await setupRichEditor(assert, "");
    const { view } = editorClass;

    await typeText(view, "/callout:xyz ", settled);

    const callout = findNode(view, "callout");
    assert.notStrictEqual(callout, null, "callout node was created");
    assert.strictEqual(
      callout.node.attrs.type,
      "note",
      "unknown type falls back to the default type"
    );
  });
});

module("Integration | Rich Editor | Callout – move controls", function (hooks) {
  setupRenderingTest(hooks);
  setupCalloutSettings(hooks);

  hooks.beforeEach(() => {
    forceMobile();
  });

  function getCalloutTypes(view) {
    const types = [];
    view.state.doc.descendants((node) => {
      if (node.type.name === "callout") {
        types.push(node.attrs.type);
        return false;
      }
    });
    return types;
  }

  function enableMoveMode(owner, view, type) {
    const calloutMoveState = owner.lookup("service:callout-move-state");
    const pos = setCursorInNode(
      view,
      "callout",
      (node) => node.attrs.type === type
    );

    if (pos !== null) {
      calloutMoveState.enable(pos);
    }

    return pos;
  }

  test("move buttons are not shown when move mode is disabled", async function (assert) {
    await setupRichEditor(assert, "> [!note]\n> Body\n\n> [!tip]\n> Body");

    assert
      .dom(".callout-top-controls")
      .doesNotExist("top move controls not shown by default");
    assert
      .dom(".callout-bottom-controls .callout-move-btn")
      .doesNotExist("bottom move controls not shown by default");
    assert.dom(".callout-handle").exists("drag handle is shown instead");
  });

  test("move buttons appear when move mode is enabled", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Body\n\n> [!tip]\n> Body"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    assert
      .dom(
        "[data-callout-type='note'] ~ .callout-bottom-controls .callout-move-down-btn"
      )
      .exists("move controls are shown");
    assert
      .dom("[data-callout-type='note'] .callout-handle")
      .doesNotExist("drag handle is hidden when move mode is on");
  });

  test("clicking moveDown swaps callout with next sibling", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    assert.deepEqual(
      getCalloutTypes(editorClass.view),
      ["note", "tip"],
      "initial order: note, tip"
    );

    await click(
      "[data-callout-type='note'] ~ .callout-bottom-controls .callout-move-down-btn"
    );

    assert.deepEqual(
      getCalloutTypes(editorClass.view),
      ["tip", "note"],
      "order after moveDown: tip, note"
    );
  });

  test("clicking moveUp swaps callout with previous sibling", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "tip");
    await settled();

    assert
      .dom(".callout-top-controls .callout-move-up-btn")
      .exists("move up button is shown");

    await click(
      "[data-callout-type='tip'] ~ .callout-top-controls .callout-move-up-btn"
    );

    assert.deepEqual(
      getCalloutTypes(editorClass.view),
      ["tip", "note"],
      "order after moveUp: tip, note"
    );
  });

  test("move up button hidden for first callout at top level", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    assert
      .dom(
        "[data-callout-type='note'] ~ .callout-top-controls .callout-move-up-btn"
      )
      .doesNotExist("move up button is hidden for first child at top level");
    assert
      .dom(
        "[data-callout-type='note'] ~ .callout-bottom-controls .callout-move-down-btn"
      )
      .exists("move down button is shown");
  });

  test("move down button hidden for last callout at top level", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "tip");
    await settled();

    assert
      .dom(
        "[data-callout-type='tip'] ~ .callout-bottom-controls .callout-move-down-btn"
      )
      .doesNotExist("move down button is hidden for last child at top level");
    assert
      .dom(
        "[data-callout-type='tip'] ~ .callout-top-controls .callout-move-up-btn"
      )
      .exists("move up button is shown");
  });

  test("nest buttons appear when adjacent sibling is a callout", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Body\n\n> [!tip]\n> Body\n\n> [!warning]\n> Body"
    );

    enableMoveMode(this.owner, editorClass.view, "tip");
    await settled();

    assert
      .dom(
        "[data-callout-type='tip'] ~ .callout-top-controls .callout-nest-btn:not(.callout-nest-down)"
      )
      .exists("nest up button is shown (prev sibling is a callout)");
    assert
      .dom(
        "[data-callout-type='tip'] ~ .callout-bottom-controls .callout-nest-down"
      )
      .exists("nest down button is shown (next sibling is a callout)");
  });

  test("nest buttons hidden when adjacent sibling is not a callout", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "paragraph text\n\n> [!note]\n> Body\n\nparagraph after"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    assert
      .dom(
        "[data-callout-type='note'] ~ .callout-top-controls .callout-nest-btn"
      )
      .doesNotExist("no nest buttons when adjacent siblings are paragraphs");
  });

  test("clicking nestUp moves callout into previous sibling callout body", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "tip");
    await settled();

    await click(
      "[data-callout-type='tip'] ~ .callout-top-controls .callout-nest-btn:not(.callout-nest-down)"
    );

    const tipNode = findNode(
      editorClass.view,
      "callout",
      (node) => node.attrs.type === "tip"
    );
    const $pos = editorClass.view.state.doc.resolve(tipNode.pos);
    assert.strictEqual(
      $pos.parent.type.name,
      "callout_body",
      "tip is now nested inside note's callout_body"
    );
  });

  test("clicking nestDown moves callout into next sibling callout body", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    await click(
      "[data-callout-type='note'] ~ .callout-bottom-controls .callout-nest-down"
    );

    const noteNode = findNode(
      editorClass.view,
      "callout",
      (node) => node.attrs.type === "note"
    );
    const $pos = editorClass.view.state.doc.resolve(noteNode.pos);
    assert.strictEqual(
      $pos.parent.type.name,
      "callout_body",
      "note is now nested inside tip's callout_body"
    );
  });

  test("move serializes correctly after swapping", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    await click(
      "[data-callout-type='note'] ~ .callout-bottom-controls .callout-move-down-btn"
    );

    assert.true(
      editorClass.value.indexOf("[!tip]") <
        editorClass.value.indexOf("[!note]"),
      `serialized markdown has tip before note: ${editorClass.value}`
    );
  });

  test("no move buttons for a single callout at top level", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Only callout"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    assert
      .dom(".callout-top-controls .callout-move-up-btn")
      .doesNotExist("no move up for single callout");
    assert
      .dom(".callout-bottom-controls .callout-move-down-btn")
      .doesNotExist("no move down for single callout");
    assert
      .dom(".callout-top-controls .callout-nest-btn")
      .doesNotExist("no nest up buttons for single callout");
    assert
      .dom(".callout-bottom-controls .callout-nest-btn")
      .doesNotExist("no nest down buttons for single callout");
  });

  test("nested callout shows move buttons (can lift out)", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> > [!tip]\n> > Nested content"
    );

    enableMoveMode(this.owner, editorClass.view, "tip");
    await settled();

    assert
      .dom(
        "[data-callout-type='tip'] ~ .callout-top-controls .callout-move-up-btn"
      )
      .exists(
        "move up is shown for nested callout (can lift out above parent)"
      );
    assert
      .dom(
        "[data-callout-type='tip'] ~ .callout-bottom-controls .callout-move-down-btn"
      )
      .exists(
        "move down is shown for nested callout (can lift out below parent)"
      );
  });

  test("nestUp serializes correctly", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "tip");
    await settled();

    await click(
      "[data-callout-type='tip'] ~ .callout-top-controls .callout-nest-btn:not(.callout-nest-down)"
    );

    assert.true(
      editorClass.value.includes("> > [!tip]"),
      `serialized markdown has nested tip: ${editorClass.value}`
    );
    assert.false(
      editorClass.value.split("\n").some((line) => line.startsWith("> [!tip]")),
      "tip is not at top level in markdown"
    );
  });

  test("nestDown serializes correctly", async function (assert) {
    const [editorClass] = await setupRichEditor(
      assert,
      "> [!note]\n> Note body\n\n> [!tip]\n> Tip body"
    );

    enableMoveMode(this.owner, editorClass.view, "note");
    await settled();

    await click(
      "[data-callout-type='note'] ~ .callout-bottom-controls .callout-nest-down"
    );

    assert.true(
      editorClass.value.includes("> > [!note]"),
      `serialized markdown has nested note: ${editorClass.value}`
    );
  });
});
