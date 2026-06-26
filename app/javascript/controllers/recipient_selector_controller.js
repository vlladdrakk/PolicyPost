import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["localMpPostalCode", "cabinetMinisterList"]

  connect() {
    this._updateVisibility()
  }

  selectLocalMp() {
    this._updateVisibility()
  }

  selectPrimeMinister() {
    this._updateVisibility()
  }

  selectCabinetMinister() {
    this._updateVisibility()
  }

  _updateVisibility() {
    const selected = this.element.querySelector('input[name="recipient_type"]:checked')
    const type = selected ? selected.value : null

    if (this.hasLocalMpPostalCodeTarget) {
      this.localMpPostalCodeTarget.style.display = type === "local_mp" ? "block" : "none"
    }
    if (this.hasCabinetMinisterListTarget) {
      this.cabinetMinisterListTarget.style.display = type === "cabinet_minister" ? "block" : "none"
    }
  }
}
