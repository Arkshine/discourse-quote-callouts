import { findCalloutOptions } from "../config";
import { findAncestor } from "../rich-editor-utils";
import { capitalizeFirstLetter, hexToRGBA, isNodeEmpty } from "../utils";
import {
  handleArrowDown,
  handleArrowLeft,
  handleArrowUp,
  handleEnter,
} from "./keyboard";
import { transformFragmentsToCallouts } from "./paste-handler";

export function plugins({
  pmState: { Plugin, TextSelection, PluginKey },
  pmView: { Decoration, DecorationSet },
  getContext,
}) {
  const calloutPlugin = new Plugin({
    key: new PluginKey("callout"),

    props: {
      decorations(state) {
        const { doc, schema } = state;
        const calloutType = schema.nodes.callout;
        if (!calloutType) {
          return null;
        }

        const decos = [];
        doc.descendants((node, pos) => {
          if (node.type !== calloutType) {
            return;
          }

          const type =
            node.attrs.type || settings.callout_fallback_type || "note";
          const options = findCalloutOptions(type);
          const color = options?.color || settings.callout_fallback_color;
          const bg = hexToRGBA(
            color,
            settings.callout_background_opacity / 100
          );
          const darker = hexToRGBA(color, 0.3);

          if (color) {
            decos.push(
              Decoration.node(pos, pos + node.nodeSize, {
                style: `
                  --q-callout-background: ${bg}; 
                  --q-callout-color-darker: ${darker}; 
                  --q-callout-color: ${color};`,
              })
            );
          }
        });

        return DecorationSet.create(doc, decos);
      },

      transformPasted(slice, view) {
        const schema = view.state.schema;
        const newContent = transformFragmentsToCallouts(slice.content, schema);

        if (newContent !== slice.content) {
          return new slice.constructor(
            newContent,
            slice.openStart,
            slice.openEnd
          );
        }

        return slice;
      },

      // Inserts a paragraph when clicking below the last nested callout
      // in a body, so the user has a place to type after it.
      //
      //   ┌─ callout ──────────────┐
      //   │  Title                 │
      //   │  ┌─ nested ─────────┐  │
      //   │  │  ...             │  │
      //   │  └──────────────────┘  │
      //   │      click here        │
      //   └────────────────────────┘
      handleClick(view, pos) {
        const { state, dispatch } = view;
        const $pos = state.doc.resolve(pos);
        const {
          callout: calloutType,
          callout_body: bodyType,
          paragraph: pType,
        } = state.schema.nodes;

        if (!calloutType || !bodyType || !pType) {
          return false;
        }

        if (view.dom.querySelector(".callout-chooser.is-expanded")) {
          return false;
        }

        const parent = $pos.parent;

        if (parent.type === bodyType || parent.type === calloutType) {
          // title: skip if click is at/before the title
          if (
            parent.type === calloutType &&
            (parent.lastChild?.type !== bodyType ||
              $pos.parentOffset <= parent.child(0).nodeSize)
          ) {
            return false;
          }

          // body: skip if click is not at the end (e.g. above nested callout)
          if (
            parent.type === bodyType &&
            $pos.parentOffset < parent.content.size
          ) {
            return false;
          }

          const bodyNode = parent.type === bodyType ? parent : parent.lastChild;

          const lastChild = bodyNode.lastChild;
          if (!lastChild || lastChild.type !== calloutType) {
            return false;
          }

          const insertPos =
            parent.type === bodyType
              ? $pos.end($pos.depth)
              : $pos.end($pos.depth) - 1;

          const tr = state.tr.insert(insertPos, pType.create());
          tr.setSelection(TextSelection.create(tr.doc, insertPos + 1));
          dispatch(tr.scrollIntoView());

          return true;
        }

        return false;
      },

      handleKeyDown(view, event) {
        const { state, dispatch } = view;
        const { selection, schema } = state;
        const { $from, empty } = selection;

        if (!empty) {
          return false;
        }

        const ctx = { view, $from, schema, dispatch, state, TextSelection };

        const handlers = {
          ArrowDown: () => handleArrowDown(ctx),
          ArrowUp: () => handleArrowUp(ctx),
          Enter: () => handleEnter(ctx, event),
        };

        return handlers[event.key]?.() || false;
      },
      handleDOMEvents: {
        // Bypasses gapcursor
        // which intercepts ArrowLeft before handleKeyDown can run.
        keydown(view, event) {
          if (event.key === "ArrowLeft") {
            const { state } = view;
            const { selection, schema } = state;
            const { $from, empty } = selection;

            if (empty && handleArrowLeft({ view, $from, schema, state })) {
              event.preventDefault();
              return true;
            }
          }

          return false;
        },

        dragstart(_view, event) {
          if (
            event.target?.nodeType === Node.ELEMENT_NODE &&
            event.target.classList.contains("composer-callout-node")
          ) {
            event.target.classList.add("is-dragging");
          }
        },

        dragend(_view, event) {
          if (
            event.target?.nodeType === Node.ELEMENT_NODE &&
            event.target.classList.contains("composer-callout-node")
          ) {
            event.target.classList.remove("is-dragging");
          }
        },
      },
    },

    appendTransaction(transactions, oldState, newState) {
      const { schema } = newState;
      if (!schema.nodes.callout_title) {
        return null;
      }

      const isDefaultRestore = transactions.some((tr) =>
        tr.getMeta("callout:isDefaultTitle")
      );

      // On doc changes, track hasCustomTitle and sync hasBody
      if (transactions.some((tr) => tr.docChanged)) {
        let tr = null;

        newState.doc.descendants((node, pos) => {
          if (node.type !== schema.nodes.callout) {
            return;
          }

          if (!isDefaultRestore && !node.attrs.hasCustomTitle) {
            const titleNode = node.child(0);
            if (titleNode.content.size > 0) {
              let oldPos = pos;
              try {
                for (let i = transactions.length - 1; i >= 0; i--) {
                  oldPos = transactions[i].mapping.invert().map(oldPos);
                }
              } catch {
                return false;
              }

              const oldCallout = oldState.doc.nodeAt(oldPos);
              if (!oldCallout || oldCallout.type !== schema.nodes.callout) {
                return false;
              }

              if (!oldCallout.child(0).content.eq(titleNode.content)) {
                if (!tr) {
                  tr = newState.tr;
                }
                tr.setNodeMarkup(pos, null, {
                  ...node.attrs,
                  hasCustomTitle: true,
                });
              }
            }
          }

          // Sync hasBody attr with actual body content
          const bodyNode = node.child(1);
          const hasBody = bodyNode.childCount > 0;

          if (node.attrs.hasBody !== hasBody) {
            if (!tr) {
              tr = newState.tr;
            }
            const calloutNode = tr.doc.nodeAt(pos);
            tr.setNodeMarkup(pos, null, {
              ...calloutNode.attrs,
              hasBody,
            });

            const titlePos = pos + 1;
            const titleNode = tr.doc.nodeAt(titlePos);
            if (titleNode?.type === schema.nodes.callout_title) {
              tr.setNodeMarkup(titlePos, null, {
                ...titleNode.attrs,
                hasBody,
              });
            }
          }
        });

        if (tr) {
          return tr;
        }
      }

      // On selection changes, restore default title if user
      // left an empty callout title
      if (transactions.some((tr) => tr.selectionSet)) {
        const calloutTitleType = schema.nodes.callout_title;
        const oldTitleAncestor = findAncestor(oldState, calloutTitleType);

        if (oldTitleAncestor) {
          let titlePos = oldTitleAncestor.pos;
          for (const tr of transactions) {
            try {
              titlePos = tr.mapping.map(titlePos);
            } catch {
              return null;
            }
          }

          const titleNode = newState.doc.nodeAt(titlePos);
          if (
            titleNode &&
            titleNode.type === calloutTitleType &&
            titleNode.content.size === 0 &&
            findAncestor(newState, calloutTitleType)?.pos !== titlePos
          ) {
            const { type } = titleNode.attrs;
            const options = findCalloutOptions(type);
            const defaultTitle = options?.title || capitalizeFirstLetter(type);

            return newState.tr
              .insertText(defaultTitle, titlePos + 1)
              .setMeta("callout:isDefaultTitle", true);
          }
        }
      }

      return null;
    },
  });

  const calloutSelectionPlugin = new Plugin({
    key: new PluginKey("calloutSelection"),
    props: {
      handleClickOn(view, pos, node, nodePos, event) {
        if (node.type.name !== "callout") {
          return false;
        }

        let target = event.target;
        const $pos = view.state.doc.resolve(pos);

        if (!target.classList.contains("callout-title-inner")) {
          if (
            $pos.nodeBefore?.type.name === "callout_title" &&
            $pos.nodeAfter?.type.name === "callout_body"
          ) {
            target = target.querySelector(".callout-title-inner");
          } else if (target.classList.contains("callout-left-controls")) {
            target = null;
          } else {
            return false;
          }
        }

        // Don't force selection if title content is not empty
        if (target && !isNodeEmpty(target)) {
          if (
            !target.lastChild ||
            target.lastChild.nodeType !== Node.ELEMENT_NODE ||
            $pos.textOffset !== 0
          ) {
            return false;
          }
        }

        const titleNode = node.child(0);
        const titleEndPos = nodePos + 2 + titleNode.content.size;
        const tr = view.state.tr.setSelection(
          TextSelection.create(view.state.doc, titleEndPos)
        );
        view.dispatch(tr);
        return true;
      },
    },
    view() {
      return {
        update(view, prevState) {
          const { selection, schema } = view.state;

          if (selection.eq(prevState.selection)) {
            return;
          }

          let activeCalloutPos = null;

          if (selection.node?.type === schema.nodes.callout) {
            activeCalloutPos = selection.from;
          } else {
            const ancestor = findAncestor(view.state, schema.nodes.callout);
            if (ancestor) {
              activeCalloutPos = ancestor.pos;
            }
          }

          getContext().appEvents.trigger(
            "callout:selection-changed",
            activeCalloutPos
          );

          view.dom
            .querySelectorAll(".composer-callout-node.has-selection")
            .forEach((el) => el.classList.remove("has-selection"));

          if (activeCalloutPos !== null) {
            view.nodeDOM(activeCalloutPos)?.classList.add("has-selection");
          }
        },
      };
    },
  });

  return [calloutPlugin, calloutSelectionPlugin];
}
