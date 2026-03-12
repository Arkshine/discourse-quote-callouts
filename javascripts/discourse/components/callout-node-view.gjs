import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { activeCalloutPosFromView } from "../lib/rich-editor-utils";

export default class CalloutNodeView extends Component {
  @service appEvents;
  @service calloutSettings;
  @service calloutMoveState;

  @tracked activeCalloutPos = null;
  @tracked hasEmptyBody = false;
  @tracked needsInsertAfter = false;
  @tracked canNestUp = false;
  @tracked canNestDown = false;
  @tracked canMoveUp = false;
  @tracked canMoveDown = false;

  constructor() {
    super(...arguments);

    this.args.onSetup?.(this);
    this.activeCalloutPos = activeCalloutPosFromView(this.args.view);
    this.updateState();

    this.appEvents.on(
      "callout:selection-changed",
      this,
      this.onSelectionChanged
    );
  }

  willDestroy() {
    super.willDestroy();

    this.appEvents.off(
      "callout:selection-changed",
      this,
      this.onSelectionChanged
    );
  }

  onSelectionChanged(pos) {
    this.activeCalloutPos = pos;
    this.updateState();
  }

  get isSelected() {
    return this.activeCalloutPos === this.args.getPos();
  }

  get showMoveControls() {
    return this.calloutMoveState.isEnabledFor(this.args.getPos());
  }

  updateState() {
    const calloutPos = this.args.getPos();
    if (calloutPos == null) {
      this.canMoveUp = false;
      this.canMoveDown = false;
      this.canNestUp = false;
      this.canNestDown = false;
      this.hasEmptyBody = false;
      this.needsInsertAfter = false;
      return;
    }

    const contentElement = this.args.dom?.querySelector(".callout-content");
    this.hasEmptyBody = contentElement
      ? contentElement.childElementCount === 0
      : false;

    const { state } = this.args.view;
    const { schema } = state;
    const $pos = state.doc.resolve(calloutPos);
    const index = $pos.index($pos.depth);

    // Check siblings for nest buttons
    const prevSibling = index > 0 ? $pos.parent.child(index - 1) : null;
    const nextSibling =
      index < $pos.parent.childCount - 1 ? $pos.parent.child(index + 1) : null;

    this.canNestUp = prevSibling?.type === schema.nodes.callout;
    this.canNestDown = nextSibling?.type === schema.nodes.callout;

    const isNested = $pos.parent.type === schema.nodes.callout_body;
    const isEmptyParagraph = (node) =>
      node?.type === schema.nodes.paragraph && node.content.size === 0;

    // Only skip empty paragraphs at the very edges of the parent
    // (leading/trailing empty paragraphs), not separators between nodes
    const isLeadingEmpty = index === 1 && isEmptyParagraph(prevSibling);
    const isTrailingEmpty =
      index === $pos.parent.childCount - 2 && isEmptyParagraph(nextSibling);

    const hasPrev = index > 0 && !isLeadingEmpty;
    const hasNext = index < $pos.parent.childCount - 1 && !isTrailingEmpty;

    this.canMoveUp = hasPrev || isNested;
    this.canMoveDown = hasNext || isNested;

    if ($pos.parent.type !== schema.nodes.callout_body) {
      this.needsInsertAfter = false;
      return;
    }

    const calloutNode = state.doc.nodeAt(calloutPos);
    if (!calloutNode) {
      this.needsInsertAfter = false;
      return;
    }

    const afterPos = calloutPos + calloutNode.nodeSize;
    const $after = state.doc.resolve(afterPos);
    const nodeAfter = $after.nodeAfter;

    this.needsInsertAfter =
      !nodeAfter || nodeAfter.type === schema.nodes.callout;
  }

  #resolveCallout() {
    const { view } = this.args;
    const { state } = view;
    const { schema } = state;

    const calloutPos = this.args.getPos();
    if (calloutPos == null) {
      return null;
    }

    const calloutNode = state.doc.nodeAt(calloutPos);
    if (!calloutNode) {
      return null;
    }

    const $pos = state.doc.resolve(calloutPos);
    const index = $pos.index($pos.depth);

    return { view, state, schema, calloutPos, calloutNode, $pos, index };
  }

  #finishMove(tr, newCalloutPos) {
    const { view } = this.args;
    const $newPos = tr.doc.resolve(newCalloutPos + 2);
    tr.setSelection(view.state.selection.constructor.near($newPos));

    this.calloutMoveState.enable(newCalloutPos);
    view.dispatch(tr.scrollIntoView());
    view.focus();
    this.appEvents.trigger("callout:selection-changed", newCalloutPos);
  }

  @action
  addBody() {
    const ctx = this.#resolveCallout();
    if (!ctx) {
      return;
    }

    const { view, state, schema, calloutPos, calloutNode } = ctx;
    const titleNode = calloutNode.child(0);
    const bodyContentStart = calloutPos + 1 + titleNode.nodeSize + 1;
    const tr = state.tr.insert(
      bodyContentStart,
      schema.nodes.paragraph.create()
    );

    const $pos = tr.doc.resolve(bodyContentStart + 1);
    tr.setSelection(state.selection.constructor.near($pos));
    view.dispatch(tr.scrollIntoView());
    view.focus();
  }

  @action
  insertAfter() {
    const ctx = this.#resolveCallout();
    if (!ctx) {
      return;
    }

    const { view, state, schema, calloutPos, calloutNode } = ctx;
    const posAfter = calloutPos + calloutNode.nodeSize;
    const tr = state.tr.insert(posAfter, schema.nodes.paragraph.create());
    const $pos = tr.doc.resolve(posAfter + 1);

    tr.setSelection(state.selection.constructor.near($pos));
    view.dispatch(tr.scrollIntoView());
    view.focus();
  }

  @action
  moveUp() {
    const ctx = this.#resolveCallout();
    if (!ctx) {
      return;
    }

    const { state, schema, calloutPos, calloutNode, $pos, index } = ctx;
    const tr = state.tr;
    let newCalloutPos;

    if (index > 0) {
      const prevSibling = $pos.parent.child(index - 1);
      const prevSiblingPos = calloutPos - prevSibling.nodeSize;
      tr.insert(prevSiblingPos, calloutNode);
      const shifted = calloutPos + calloutNode.nodeSize;
      tr.delete(shifted, shifted + calloutNode.nodeSize);
      newCalloutPos = prevSiblingPos;
    } else if ($pos.parent.type === schema.nodes.callout_body) {
      const parentCalloutPos = $pos.before($pos.depth - 1);
      tr.insert(parentCalloutPos, calloutNode);
      const shifted = calloutPos + calloutNode.nodeSize;
      tr.delete(shifted, shifted + calloutNode.nodeSize);
      newCalloutPos = parentCalloutPos;
    } else {
      return;
    }

    this.#finishMove(tr, newCalloutPos);
  }

  @action
  moveDown() {
    const ctx = this.#resolveCallout();
    if (!ctx) {
      return;
    }

    const { state, schema, calloutPos, calloutNode, $pos, index } = ctx;
    const tr = state.tr;
    let newCalloutPos;

    if (index < $pos.parent.childCount - 1) {
      const nextSiblingPos = calloutPos + calloutNode.nodeSize;
      const nextSibling = state.doc.nodeAt(nextSiblingPos);
      if (!nextSibling) {
        return;
      }

      tr.insert(nextSiblingPos + nextSibling.nodeSize, calloutNode);
      tr.delete(calloutPos, calloutPos + calloutNode.nodeSize);

      newCalloutPos = calloutPos + nextSibling.nodeSize;
    } else if ($pos.parent.type === schema.nodes.callout_body) {
      const afterParentPos = $pos.after($pos.depth - 1);

      tr.insert(afterParentPos, calloutNode);
      tr.delete(calloutPos, calloutPos + calloutNode.nodeSize);

      newCalloutPos = afterParentPos - calloutNode.nodeSize;
    } else {
      return;
    }

    this.#finishMove(tr, newCalloutPos);
  }

  @action
  nestUp() {
    const ctx = this.#resolveCallout();
    if (!ctx) {
      return;
    }

    const { state, schema, calloutPos, calloutNode, $pos, index } = ctx;

    if (index === 0) {
      return;
    }

    const prevSibling = $pos.parent.child(index - 1);
    if (prevSibling.type !== schema.nodes.callout) {
      return;
    }

    const bodyEndPos = calloutPos - 2;
    const tr = state.tr;
    tr.insert(bodyEndPos, calloutNode);
    const shifted = calloutPos + calloutNode.nodeSize;
    tr.delete(shifted, shifted + calloutNode.nodeSize);

    this.#finishMove(tr, bodyEndPos);
  }

  @action
  nestDown() {
    const ctx = this.#resolveCallout();
    if (!ctx) {
      return;
    }

    const { state, schema, calloutPos, calloutNode, $pos, index } = ctx;

    if (index >= $pos.parent.childCount - 1) {
      return;
    }

    const nextSibling = $pos.parent.child(index + 1);
    if (nextSibling.type !== schema.nodes.callout) {
      return;
    }

    const nextCalloutPos = calloutPos + calloutNode.nodeSize;
    const nextCalloutNode = state.doc.nodeAt(nextCalloutPos);
    if (!nextCalloutNode) {
      return;
    }

    const titleNode = nextCalloutNode.child(0);
    const bodyContentStart = nextCalloutPos + 1 + titleNode.nodeSize + 1;

    const tr = state.tr;
    tr.insert(bodyContentStart, calloutNode);
    tr.delete(calloutPos, calloutPos + calloutNode.nodeSize);

    this.#finishMove(tr, bodyContentStart - calloutNode.nodeSize);
  }

  update(node) {
    const options = this.calloutSettings.find(node.attrs.type);
    const element = this.args.dom.firstElementChild;

    if (options?.mainType) {
      element.setAttribute("data-callout-type", options.mainType);
      element.setAttribute("data-callout-alias", options.type);
    } else {
      element.removeAttribute("data-callout-alias");
      element.setAttribute("data-callout-type", options.type);
    }

    element.classList.toggle("is-collapsed", node.attrs.isCollapsed);
    element.classList.toggle("is-collapsible", node.attrs.isCollapsible);

    this.updateState();
  }

  <template>
    {{#if this.isSelected}}
      {{#if this.showMoveControls}}
        {{#if (or this.canMoveUp this.canNestUp)}}
          <div
            class="callout-move-controls callout-top-controls"
            contenteditable="false"
          >
            {{#if this.canMoveUp}}
              <DButton
                @icon="arrow-up"
                @action={{this.moveUp}}
                class="callout-move-btn callout-move-up-btn btn btn-flat btn-small"
                @translatedTitle={{i18n (themePrefix "composer.menu.move_up")}}
                @preventFocus="true"
              />
            {{/if}}
            {{#if this.canNestUp}}
              <DButton
                @icon="arrow-up-from-bracket"
                @action={{this.nestUp}}
                class="callout-move-btn callout-nest-btn btn btn-flat btn-small"
                @translatedTitle={{i18n (themePrefix "composer.menu.nest_up")}}
                @preventFocus="true"
              />
            {{/if}}
          </div>
        {{/if}}
      {{else}}
        <div class="callout-handle" contenteditable="false">
          {{icon "grip-lines"}}
        </div>
      {{/if}}
      <div class="callout-bottom-controls" contenteditable="false">
        {{#if this.hasEmptyBody}}
          <DButton
            @icon="callout-add-body"
            @action={{this.addBody}}
            class="callout-add-body btn btn-flat btn-small"
            @translatedTitle={{i18n (themePrefix "composer.menu.add_body")}}
            @preventFocus="true"
          />
        {{/if}}

        {{#if this.showMoveControls}}

          {{#if this.canMoveDown}}
            <DButton
              @icon="arrow-down"
              @action={{this.moveDown}}
              class="callout-move-btn callout-move-down-btn btn btn-flat btn-small"
              @translatedTitle={{i18n (themePrefix "composer.menu.move_down")}}
              @preventFocus="true"
            />
          {{/if}}
          {{#if this.canNestDown}}
            <DButton
              @icon="arrow-up-from-bracket"
              @action={{this.nestDown}}
              class="callout-move-btn callout-nest-btn callout-nest-down btn btn-flat btn-small"
              @translatedTitle={{i18n (themePrefix "composer.menu.nest_down")}}
              @preventFocus="true"
            />
          {{/if}}
        {{/if}}

        {{#if this.needsInsertAfter}}
          <DButton
            @icon="callout-insert-after"
            @action={{this.insertAfter}}
            class="callout-add-after btn btn-flat btn-small"
            @translatedTitle={{i18n
              (themePrefix "composer.menu.insert_paragraph_after")
            }}
            @preventFocus="true"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
