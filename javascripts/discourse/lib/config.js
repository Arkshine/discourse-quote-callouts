export const CALLOUT_EXCERPT_REGEX = new RegExp(`\\[!\\w+\\][+-]? *`, "gmi");
export const CALLOUT_REGEX =
  /^(?<marker>\[!(?<callout>[^\]]+)\](?<fold>[+-])?\s*?)(?<title>.*)?/;
export const CALLOUT_CONTROLS_META = "callout:controls";

// Static settings set by the service and used by the rich editor extension
let calloutSettings;

export function setupCalloutSettings(data) {
  calloutSettings = data;
}

export function getCalloutSettings() {
  return calloutSettings;
}

export function findCalloutOptions(type) {
  return calloutSettings?.find(type);
}
