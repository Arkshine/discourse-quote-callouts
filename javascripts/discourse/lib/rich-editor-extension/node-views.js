import CalloutNodeView from "../../components/callout-node-view";
import CalloutTitleNodeView from "../../components/callout-title-node-view";
import GlimmerNodeView from "../../lib/glimmer-node-view";
import { DEFAULT_CALLOUT_TYPE, findCalloutOptions } from "../config";

const calloutNodeView =
  ({ getContext }) =>
  (node, view, getPos) => {
    const name = "callout";

    return new GlimmerNodeView({
      node,
      view,
      getPos,
      getContext,
      component: CalloutNodeView,
      name,
      buildDOM() {
        const dom = document.createElement("div");
        dom.className = `composer-${name}-node`;

        const contentDOM = document.createElement("blockquote");
        contentDOM.classList.add(name);
        contentDOM.setAttribute("data-callout-type", node.attrs.type);

        const options = findCalloutOptions(node.attrs.type);

        if (options) {
          if (options?.mainType) {
            contentDOM.setAttribute("data-callout-type", options.mainType);
            contentDOM.setAttribute("data-callout-alias", options.type);
          } else {
            contentDOM.setAttribute("data-callout-type", options.type);
          }
        } else {
          contentDOM.setAttribute("data-callout-type", DEFAULT_CALLOUT_TYPE);
        }

        if (node.attrs.isCollapsed) {
          contentDOM.classList.add("is-collapsed");
        }

        if (node.attrs.isCollapsible) {
          contentDOM.classList.add("is-collapsible");
        }

        dom.appendChild(contentDOM);

        return { dom, contentDOM };
      },
    });
  };

const calloutTitleNodeView =
  ({ getContext }) =>
  (node, view, getPos) => {
    const name = "callout-title";

    return new GlimmerNodeView({
      node,
      view,
      getPos,
      getContext,
      component: CalloutTitleNodeView,
      name,
      buildDOM() {
        const dom = document.createElement("div");
        dom.className = `composer-${name}-node ${name}`;

        const contentDOM = document.createElement("span");
        contentDOM.className = `${name}-inner`;
        dom.appendChild(contentDOM);

        return { dom, contentDOM };
      },
    });
  };

class calloutBodyNodeView {
  constructor() {
    const dom = document.createElement("div");
    dom.className = "callout-content";
    this.dom = dom;
    this.contentDOM = dom;
  }

  ignoreMutation(mutation) {
    return mutation.type !== "selection";
  }
}

export const nodeViews = {
  callout: calloutNodeView,
  callout_title: calloutTitleNodeView,
  callout_body: calloutBodyNodeView,
};
