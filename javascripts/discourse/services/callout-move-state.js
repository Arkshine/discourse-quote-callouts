import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class CalloutMoveState extends Service {
  @tracked calloutPos = null;

  get isEnabled() {
    return this.calloutPos !== null;
  }

  toggle(pos) {
    this.calloutPos = this.calloutPos === pos ? null : pos;
  }

  enable(pos) {
    this.calloutPos = pos;
  }

  reset() {
    this.calloutPos = null;
  }

  isEnabledFor(pos) {
    return this.calloutPos === pos;
  }
}
