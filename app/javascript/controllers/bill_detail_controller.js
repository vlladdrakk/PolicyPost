import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "summary" ]

  toggle(event) {
    this.summaryTarget.classList.toggle("bill-summary-row--open")
    event.currentTarget.textContent =
      this.summaryTarget.classList.contains("bill-summary-row--open") ? "▲" : "▼"
  }
}
