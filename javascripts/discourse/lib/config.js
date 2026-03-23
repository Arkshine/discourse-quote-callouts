import { isTesting } from "discourse/lib/environment";
import { capitalizeFirstLetter } from "./utils";

export const CALLOUT_EXCERPT_REGEX = new RegExp(`\\[![^\\]]+\\][+-]? *`, "gmi");
export const CALLOUT_REGEX =
  /^(?<marker>\[!(?<callout>[^\]]+)\](?<fold>[+-])?\s*?)(?<title>.*)?/;
export const CALLOUT_MARKER_REGEX = /\[![^\]]+\]/;
export const CALLOUT_CONTROLS_META = "callout:controls";

// Default callout type when callout_fallback_type is not set
export const DEFAULT_CALLOUT_TYPE = settings.callout_fallback_type || "note";

let cache;

function getCalloutData() {
  if (!cache || isTesting()) {
    cache = buildCalloutData(settings.callouts || []);
  }
  return cache;
}

function buildCalloutData(callouts) {
  const entries = [];

  for (const callout of callouts) {
    const aliases = (callout.alias ?? "")
      .split("|")
      .map((alias) => alias.trim().toLowerCase())
      .filter(Boolean);

    const type = callout.type.trim().toLowerCase();
    const title = callout.title?.trim();
    const hasExplicitTitle = Boolean(title);

    entries.push({
      ...callout,
      type,
      name: type,
      title: title || capitalizeFirstLetter(type),
      aliases,
      hasExplicitTitle,
    });

    for (const alias of aliases) {
      entries.push({
        ...callout,
        type: alias,
        mainType: type,
        name: alias,
        title: title || capitalizeFirstLetter(alias),
        hasExplicitTitle,
      });
    }
  }

  return entries;
}

export function findCalloutOptions(type) {
  return getCalloutData().find(
    (callout) => callout.type === type?.toLowerCase()
  );
}

export function getAllCallouts() {
  return getCalloutData();
}

export function getChooserCallouts() {
  return getCalloutData().filter(
    (callout) => !callout.mainType || !callout.hasExplicitTitle
  );
}

export function getAllCalloutTypes() {
  return getCalloutData().map((callout) => callout.type);
}

export function searchCallouts(term) {
  return getAllCalloutTypes().filter((type) =>
    type.startsWith(term.toLowerCase())
  );
}
