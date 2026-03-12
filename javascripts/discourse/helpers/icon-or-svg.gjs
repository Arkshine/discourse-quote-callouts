import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { convertIconClass, iconHTML } from "discourse/lib/icon-library";
import { createSafeSVG } from "../lib/svg";

export default function iconOrSvg(source) {
  if (isEmpty(source)) {
    return "";
  }

  if (source.startsWith("<svg")) {
    return htmlSafe(createSafeSVG(source));
  }

  return htmlSafe(iconHTML(convertIconClass(source)));
}
