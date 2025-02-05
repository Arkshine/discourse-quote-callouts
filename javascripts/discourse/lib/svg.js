import DOMPurify from "./vendor/dom-purify";

const SVG_SANITIZER_CONFIG = {
  // Return a DOM fragment for proper node creation
  RETURN_DOM_FRAGMENT: true,

  // Only allow SVG-specific tags
  ALLOWED_TAGS: [
    "svg",
    "path",
    "circle",
    "rect",
    "line",
    "polyline",
    "polygon",
    "ellipse",
    "g",
    "defs",
    "title",
    "linearGradient",
    "radialGradient",
    "stop",
    "mask",
    "pattern",
    "clipPath",
  ],

  ALLOWED_ATTR: [
    // Core SVG attributes
    "viewBox",
    "d",
    "points",
    "preserveAspectRatio",

    // Presentation attributes
    "fill",
    "stroke",
    "stroke-width",
    "stroke-linecap",
    "stroke-linejoin",
    "stroke-dasharray",
    "stroke-dashoffset",
    "stroke-opacity",
    "fill-opacity",
    "opacity",

    // Transform attributes
    "transform",
    "transform-origin",

    // Basic shape attributes
    "cx",
    "cy",
    "r",
    "rx",
    "ry",
    "x",
    "y",
    "x1",
    "y1",
    "x2",
    "y2",
    "width",
    "height",

    // Gradient attributes
    "gradientUnits",
    "gradientTransform",
    "offset",
    "stop-color",
    "stop-opacity",

    // Other common attributes
    "id",
    "class",
    "style",

    // Pattern/mask attributes
    "patternUnits",
    "maskUnits",
    "maskContentUnits",
  ],

  USE_PROFILES: { svg: true },
  ALLOW_DATA_ATTR: false,
  ALLOW_UNKNOWN_PROTOCOLS: false,
  ALLOW_NAMESPACES: false,
};

export function createSafeSVG(svgString, size = 16) {
  const fragment = DOMPurify.sanitize(svgString, SVG_SANITIZER_CONFIG);
  const node = document.importNode(fragment, true);
  const svgElement = node.firstChild;

  if (svgElement && svgElement instanceof SVGSVGElement) {
    svgElement.setAttribute("width", `${size}`);
    svgElement.setAttribute("height", `${size}`);
    //svgElement.setAttribute("fill", "currentColor");
    //svgElement.setAttribute("stroke", "currentColor");
    return svgElement;
  }

  return null;
}
