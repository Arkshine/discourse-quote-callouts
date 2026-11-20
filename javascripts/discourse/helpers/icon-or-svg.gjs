import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { convertIconClass, iconHTML } from "discourse/lib/icon-library";
import { createSafeSVG } from "../lib/svg.js";

export default function iconOrSvg(source) {
  if (isEmpty(source)) {
    return "";
  }

  if (source.startsWith("<svg")) {
    return trustHTML(createSafeSVG(source));
  }

  return trustHTML(iconHTML(convertIconClass(source)));
}
