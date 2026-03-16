import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import { and, eq, not, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { findCalloutOptions } from "../lib/config";
import {
  activeCalloutPosFromView,
  findAncestor,
} from "../lib/rich-editor-utils";
import { capitalizeFirstLetter, toggleCalloutCollapse } from "../lib/utils";
import CalloutChooser from "./callout-chooser";

export default class CalloutTitleNodeView extends Component {
  @service appEvents;
  @service calloutSettings;
  @service calloutMoveState;
  @service site;
  @service capabilities;

  @tracked type = this.args.node.attrs.type;
  @tracked fold = this.args.node.attrs.fold || "";
  @tracked isCollapsed = this.args.node.attrs.isCollapsed;
  @tracked isCollapsible = this.args.node.attrs.isCollapsible;
  @tracked hasBody = this.args.node.attrs.hasBody;
  @tracked activeCalloutPos = null;

  constructor() {
    super(...arguments);

    this.args.onSetup?.(this);
    this.activeCalloutPos = activeCalloutPosFromView(this.args.view);

    this.appEvents.on(
      "callout:selection-changed",
      this,
      this.onSelectionChanged
    );

    const { fold } = this.args.node.attrs;
    this.fold = fold;
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
  }

  get isSelected() {
    return this.activeCalloutPos === this.args.getPos() - 1;
  }

  get isMoveEnabled() {
    return this.calloutMoveState.isEnabledFor(this.args.getPos() - 1);
  }

  get isNested() {
    const { state } = this.args.view;
    const calloutPos = this.args.getPos() - 1;
    const $pos = state.doc.resolve(calloutPos);
    return $pos.parent.type === state.schema.nodes.callout_body;
  }

  get canShowMoreOptions() {
    return this.capabilities.touch || this.hasBody || this.isCollapsible;
  }

  ignoreMutation(mutation) {
    const { target, type } = mutation;
    const element =
      target.nodeType === Node.ELEMENT_NODE ? target : target.parentElement;

    if (!element) {
      return true;
    }

    const inControls =
      element.closest(".callout-left-controls") ||
      element.closest(".callout-right-controls");
    const inTitle = element.closest(".callout-title-inner");

    if (inControls || !inTitle) {
      return true;
    }

    if (type === "characterData" || type === "selection") {
      return false;
    }

    return true;
  }

  get calloutType() {
    return this.args.node.attrs.type || this.calloutSettings.fallbackType;
  }

  update(node) {
    this.type = node.attrs.type;
    this.fold = node.attrs.fold || "";
    this.isCollapsed = node.attrs.isCollapsed;
    this.isCollapsible = node.attrs.isCollapsible;
    this.hasBody = node.attrs.hasBody;
  }

  updateNodeMarkup(attrs) {
    const { state, dispatch } = this.args.view;
    const titlePos = this.args.getPos();
    const calloutPos = titlePos - 1;

    let tr = state.tr;

    const calloutNode = state.doc.nodeAt(calloutPos);
    if (calloutNode && calloutNode.type.name === "callout") {
      tr = tr.setNodeMarkup(calloutPos, null, {
        ...calloutNode.attrs,
        ...attrs,
      });
    }

    const titleNode = tr.doc.nodeAt(titlePos);
    if (titleNode && titleNode.type.name === "callout_title") {
      tr = tr.setNodeMarkup(titlePos, null, {
        ...titleNode.attrs,
        ...attrs,
      });
    }

    dispatch(tr);
  }

  @action
  focusEditor() {
    next(() => {
      this.args.view.focus();
    });
  }

  @action
  onTypeChange(newType) {
    this.type = newType;
    this.updateNodeMarkup({ type: this.type });

    // Update default title text when it's not a custom title
    const { state, dispatch } = this.args.view;
    const titlePos = this.args.getPos();
    const calloutNode = state.doc.nodeAt(titlePos - 1);

    if (calloutNode && !calloutNode.attrs.hasCustomTitle) {
      const options = findCalloutOptions(newType);
      const defaultTitle = options?.title || capitalizeFirstLetter(newType);
      const titleNode = state.doc.nodeAt(titlePos);

      if (titleNode) {
        const from = titlePos + 1;
        const to = from + titleNode.content.size;
        const tr = state.tr.replaceWith(
          from,
          to,
          defaultTitle ? state.schema.text(defaultTitle) : []
        );
        tr.setMeta("callout:isDefaultTitle", true);
        dispatch(tr);
      }
    }

    next(() => {
      this.focusEditor();
    });
  }

  @action
  setFold(value) {
    this.fold = value;
    this.isCollapsed = value === "-";
    this.isCollapsible = value !== "";

    this.updateNodeMarkup({
      fold: this.fold,
      isCollapsed: this.isCollapsed,
      isCollapsible: this.isCollapsible,
    });
  }

  @action
  deleteCallout() {
    const { view } = this.args;
    const { schema } = view.state;

    const callout = findAncestor(view.state, schema.nodes.callout);
    if (!callout) {
      return;
    }

    const tr = view.state.tr;
    tr.delete(callout.pos, callout.pos + callout.node.nodeSize);
    view.dispatch(tr);
    view.focus();
  }

  @action
  toggleMoveControls() {
    const calloutPos = this.args.getPos() - 1;
    this.calloutMoveState.toggle(calloutPos);
  }

  get foldOptions() {
    const trans = (key) =>
      i18n(themePrefix(`composer.menu.folding_options.${key}`));
    return [
      { value: "", label: trans("none"), className: "option-none" },
      { value: "-", label: trans("collapsed"), className: "option-collapsed" },
      { value: "+", label: trans("expanded"), className: "option-expanded" },
    ];
  }

  @action
  toggleCollapse() {
    const isCollapsing = !this.isCollapsed;

    toggleCalloutCollapse(
      this.args.dom.parentElement.querySelector(".callout-content"),
      isCollapsing,
      (isCollapsed) => {
        this.isCollapsed = isCollapsed;
        this.updateNodeMarkup({ isCollapsed });
      }
    );
  }

  <template>
    <span
      class={{concatClass
        "callout-controls-hub"
        (if this.isSelected "is-selected")
      }}
    >
      <span class="callout-left-controls" contenteditable="false">
        <CalloutChooser
          @value={{this.type}}
          @onChange={{this.onTypeChange}}
          @onClose={{this.focusEditor}}
          @disabled={{not this.isSelected}}
        />
      </span>

      {{#if this.isSelected}}
        <span class="callout-right-controls" contenteditable="false">
          {{#if this.canShowMoreOptions}}
            <DMenu
              @identifier="callout-options-menu"
              @icon="ellipsis-vertical"
              @class="callout-control-btn btn-no-text btn-transparent"
              @translatedTitle={{i18n
                (themePrefix "composer.menu.more_options")
              }}
            >
              <:content>
                <DropdownMenu @class="callout-control-dropdown" as |dropdown|>
                  {{#if this.capabilities.touch}}
                    <dropdown.item class="callout-control-dropdown__move-item">
                      <span>{{i18n (themePrefix "composer.menu.move")}}</span>
                      <DToggleSwitch
                        @state={{this.isMoveEnabled}}
                        {{on "click" this.toggleMoveControls}}
                      />
                    </dropdown.item>
                  {{/if}}

                  {{#if (or this.hasBody this.isCollapsible)}}
                    <dropdown.item class="callout-control-dropdown__fold-item">
                      <span>{{i18n
                          (themePrefix "composer.menu.folding")
                        }}</span>
                      {{#each this.foldOptions as |option|}}
                        <DButton
                          class={{concatClass
                            "callout-control-fold"
                            "text-size btn btn-flat"
                            option.className
                            (if (eq option.value this.fold) "active")
                          }}
                          @action={{fn this.setFold option.value}}
                        >
                          {{option.label}}
                        </DButton>
                      {{/each}}
                    </dropdown.item>
                  {{/if}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}

          <DButton
            @icon="trash-can"
            @action={{this.deleteCallout}}
            class="callout-control-btn callout-delete-btn btn-no-text btn-transparent"
            @translatedTitle={{i18n (themePrefix "composer.delete_callout")}}
          />
        </span>
      {{/if}}
    </span>

    {{#if (and this.isCollapsible this.hasBody)}}
      <DButton
        @icon="chevron-down"
        @action={{this.toggleCollapse}}
        @preventFocus={{true}}
        @translatedTitle={{i18n (themePrefix "composer.menu.toggle_folding")}}
        class={{concatClass
          "callout-fold btn btn-no-text btn-transparent"
          (if this.isCollapsed "is-collapsed")
        }}
      />
    {{/if}}
  </template>
}
