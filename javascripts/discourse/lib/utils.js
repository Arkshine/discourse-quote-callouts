/**
 * Toggles the collapse state of a callout content element.
 *
 * @param {HTMLElement} element
 * @param {boolean} isCollapsing
 * @param {function(boolean): void} onUpdate
 */
export function toggleCalloutCollapse(element, isCollapsing, onUpdate) {
  if (!element) {
    return;
  }

  // Let the CSS handle the collapse if we can.
  if (CSS.supports("interpolate-size: allow-keywords")) {
    onUpdate(isCollapsing);
    return;
  }

  element.removeAttribute("style");
  element.style.height = element.scrollHeight + "px";

  if (isCollapsing) {
    element.style.height = element.scrollHeight + "px";
    element.offsetHeight; // reflow
    element.style.height = "0px";
  }

  onUpdate(isCollapsing);

  element.addEventListener(
    "transitionend",
    () => {
      if (isCollapsing) {
        element.style.display = "none";
      } else {
        element.style.height = "";
      }
    },
    { once: true }
  );
}

/**
 * Converts hex code to rgba.
 *
 * @param {string} hexCode
 * @param {number} opacity
 * @returns {string}
 */
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

/**
 * Capitalizes the first letter of a string.
 *
 * @param {string} string
 * @returns {string}
 */
export function capitalizeFirstLetter(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

/**
 * Checks if a node is truly empty.
 *
 * @param {Node} element
 * @returns {boolean}
 */
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

/**
 * Collects nodes until a condition is met.
 *
 * @param {Node} parentNode
 * @param {function(Node): boolean} stopWhen
 * @param {Object} options
 * @param {function(Node): void} options.onEach
 * @param {function(Node): void} options.onStop
 * @param {function(Node[]): void} options.onEnd
 * @returns {Node[]}
 */
export function collectNodesUntil(
  parentNode,
  stopWhen,
  { onEach, onStop, onEnd } = {}
) {
  const collected = [];

  for (const node of Array.from(parentNode.childNodes)) {
    if (stopWhen(node)) {
      onStop?.(node);
      break;
    }
    collected.push(node);
    onEach?.(node);
  }
  onEnd?.(collected);
  return collected;
}

/**
 * Gets the first text node that has content
 * @param {Node} node
 * @returns {Node}
 */
export function firstMeaningfulNode(node) {
  let child = node.firstChild;

  while (
    child &&
    child.nodeType === Node.TEXT_NODE &&
    !child.textContent.trim()
  ) {
    child = child.nextSibling;
  }

  return child;
}

/**
 * Gets the leading text from a node
 * @param {Node} node
 * @returns {string}
 */
export function leadingTextFromNode(node) {
  if (!node) {
    return null;
  }

  if (node.nodeType === Node.TEXT_NODE) {
    return node.textContent;
  }

  if (node.nodeType === Node.ELEMENT_NODE) {
    const inner = firstMeaningfulNode(node);

    if (inner?.nodeType === Node.TEXT_NODE) {
      return inner.textContent;
    }
  }

  return null;
}
