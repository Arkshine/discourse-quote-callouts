export function hexToRGBA(hexCode, opacity) {
  let hex = hexCode.replace("#", "");

  if (hex.length === 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }

  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);

  return `rgba(${r},${g},${b}, ${opacity})`;
}

export function capitalizeFirstLetter(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

export function isNodeEmpty(element) {
  // No text content (after trimming whitespace)
  const hasNoText = !element.textContent.trim();
  // No child elements (including void elements like img)
  const hasNoElements = !element.children.length;
  // No non-whitespace text nodes
  const hasNoTextNodes = Array.from(element.childNodes)
    .filter((node) => node.nodeType === Node.TEXT_NODE)
    .every((node) => !node.textContent.trim());

  return hasNoText && hasNoElements && hasNoTextNodes;
}
