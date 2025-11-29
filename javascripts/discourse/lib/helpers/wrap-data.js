import { helper } from "@ember/component/helper";

/**
 * Usage: {{wrap-data ast calloutSettings}}
 * Returns { ast, calloutSettings } so you can pass as @data
 */
export default helper(function wrapData([ast, calloutSettings]) {
  return { ast, calloutSettings };
});