import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { iconHTML } from "discourse/lib/icon-library";
import { createSafeSVG } from "../lib/svg";
import {
    capitalizeFirstLetter,
    hexToRGBA,
    findCalloutSetting,
    nullIfEmpty,
} from "../lib/utils";

/**
 * QuoteCallout component
 * Renders a styled callout box (like Note, Warning, etc.) with optional
 * collapse/expand functionality, icon, title, and background styling.
 */
export default class QuoteCallout extends Component {
    // --- State tracking ---
    @tracked isCollapsed = false;       // Whether the callout content is collapsed
    @tracked isTransitioning = false;   // Whether a collapse/expand transition is in progress

    contentEl = null; // Reference to the content DOM element

    // Precomputed values
    calloutSetting;
    canonicalType;
    type;
    title;
    icon;
    backgroundStyle;
    chevronIcon;
    isCollapsable;

    constructor() {
        super(...arguments);

        const { ast, calloutSettings } = this.args.data;

        this.calloutSetting = findCalloutSetting(calloutSettings, ast.type);

        this.canonicalType =
            this.calloutSetting?.type?.[0] ??
            settings.callout_fallback_type ??
            "note";

        this.type = (this.calloutSetting ? ast.type : null)
            ?? this.canonicalType;

        this.title =
            nullIfEmpty(ast.title) ??
            nullIfEmpty(this.calloutSetting?.title) ??
            capitalizeFirstLetter(this.type) ??
            "Note";

        let iconRaw =
            this.calloutSetting?.icon ??
            settings.callout_fallback_icon ??
            "pencil";
        this.icon = iconRaw.startsWith("<svg")
            ? createSafeSVG(iconRaw)
            : iconHTML(iconRaw);

        const color =
            this.calloutSetting?.color ??
            settings.callout_fallback_color ??
            "#ff0000";
        const opacity = (settings.callout_background_opacity ?? 20) / 100;
        this.backgroundStyle = `background-color: ${hexToRGBA(color, opacity)}`;

        this.chevronIcon = iconHTML("chevron-down");

        this.isCollapsable = nullIfEmpty(ast.fold) && ast.children.length > 0;
        this.isCollapsed = this.isCollapsable && ast.fold === "-";
    }

    /**
     * Register the content element when rendered.
     * Initializes expanded state by setting height to scrollHeight.
     */
    @action registerContent(el) {
        this.contentEl = el;
        el.style.overflow = "hidden";
        el.style.height = (!this.isCollapsed ? el.scrollHeight : 0) + "px";
    }

    /**
     * Toggle collapse/expand state of the callout.
     * Uses CSS transitions to animate height changes.
     */
    @action toggleCollapse() {
        if (!this.isCollapsable) {
            return; // Do nothing if folding is disabled
        }

        const el = this.contentEl;
        if (!el) {
            // If no element reference, just toggle state
            this.isCollapsed = !this.isCollapsed;
            return;
        }

        this.isTransitioning = true;

        if (!this.isCollapsed) {
            // Collapsing: set current height, force reflow, then animate to 0
            el.style.height = el.scrollHeight + "px";
            void el.offsetHeight; // force reflow
            el.style.height = "0px";
        } else {
            // Expanding: start at 0, then animate to measured height
            el.style.display = ""; // ensure visible
            el.style.height = "0px";
            void el.offsetHeight; // force reflow
            el.style.height = el.scrollHeight + "px";
        }

        this.isCollapsed = !this.isCollapsed;

        // Handle end of transition
        const onEnd = () => {
            this.isTransitioning = false;

            if (this.isCollapsed) {
                // Fully collapsed: hide element to remove tab stops
                el.style.display = "none";
            } else {
                // Fully expanded: clear height so content can grow naturally
                el.style.height = "";
            }
            el.removeEventListener("transitionend", onEnd);
        };
        el.addEventListener("transitionend", onEnd, { once: true });
    }
}