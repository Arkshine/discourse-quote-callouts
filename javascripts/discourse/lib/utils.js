/**
 * Convert a hex color code to an RGBA string with the given opacity.
 * Supports both 3-digit (#abc) and 6-digit (#aabbcc) hex formats.
 *
 * @param {string} hexCode - The hex color code (e.g. "#ff0000" or "#f00").
 * @param {number} opacity - The alpha value (0–1).
 * @returns {string} RGBA color string (e.g. "rgba(255,0,0,0.5)").
 */
export function hexToRGBA(hexCode, opacity) {
  let hex = hexCode.replace("#", "");

  // Expand shorthand hex (#abc → #aabbcc)
  if (hex.length === 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }

  // Parse RGB values from hex
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);

  return `rgba(${r},${g},${b}, ${opacity})`;
}

/**
 * Capitalize the first letter of a string.
 *
 * @param {string} string - Input string.
 * @returns {string} String with first letter capitalized.
 */
export function capitalizeFirstLetter(string) {
  return string?.charAt(0).toUpperCase() + string?.slice(1);
}

/**
 * Check if a DOM element is effectively empty.
 * Conditions:
 *  - No text content (ignoring whitespace).
 *  - No child elements.
 *  - No non-whitespace text nodes.
 *
 * @param {HTMLElement} element - DOM element to check.
 * @returns {boolean} True if element is empty, false otherwise.
 */
export function isNodeEmpty(element) {
  // No text content (after trimming whitespace)
  const hasNoText = !element.textContent.trim();

  // No child elements (including void elements like <img>)
  const hasNoElements = !element.children.length;

  // No non-whitespace text nodes
  const hasNoTextNodes = Array.from(element.childNodes)
    .filter((node) => node.nodeType === Node.TEXT_NODE)
    .every((node) => !node.textContent.trim());

  return hasNoText && hasNoElements && hasNoTextNodes;
}

/**
 * Return null if the string is empty or only whitespace.
 *
 * @param {string} value - Input string.
 * @returns {string|null} Trimmed string or null if empty.
 */
export function nullIfEmpty(value) {
  return value?.trim() ? value : null;
}

// --- Settings helpers ---

/**
 * Process callout settings from site settings.
 * - Ensures aliases are split and normalized.
 * - The main type is always the first in the list.
 *
 * @returns {Array} Array of callout settings with expanded type list.
 */
export function processCalloutSettings() {
  const callouts = settings.callouts || [];

  return callouts.map((setting) => {
    const types = [setting.type];

    // Add aliases if present (split by "|")
    if (setting.alias) {
      types.push(
        ...setting.alias
          .split("|")
          .map((alias) => alias.trim())
          .filter(Boolean)
      );
    }

    return {
      ...setting,
      type: types,
    };
  });
}

/**
 * Find a callout setting by type.
 * Matches against both the main type and aliases.
 *
 * @param {Array} calloutSettings - Array of settings to search in.
 * @param {string} type - Callout type to search for.
 * @returns {Object|undefined} Matching callout setting or undefined if not found.
 */
export function findCalloutSetting(calloutSettings, type) {
  return calloutSettings.find((callout) =>
    callout.type.includes(type?.toLowerCase())
  );
}