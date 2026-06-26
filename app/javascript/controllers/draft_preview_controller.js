import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "address", "body", "resetPlaceholders", "copyButton", "statusMessage"]
  static values = {
    recipientEmail: String,
    subject: String
  }

  connect() {
    this.rawBody = null
    this.manualEdit = false
    this._boundOnDraftLoaded = this._onDraftLoaded.bind(this)

    const bodyEl = this.bodyTarget
    if (bodyEl && bodyEl.value) {
      this.rawBody = bodyEl.value
    }

    this.element.addEventListener("draft:loaded", this._boundOnDraftLoaded)
  }

  disconnect() {
    this.element.removeEventListener("draft:loaded", this._boundOnDraftLoaded)
  }

  _onDraftLoaded(event) {
    this.rawBody = event.detail.body
    this.manualEdit = false
    this._updatePreview()
  }

  onNameInput() {
    if (this.manualEdit) return
    this._updatePreview()
  }

  onAddressInput() {
    if (this.manualEdit) return
    this._updatePreview()
  }

  onBodyInput() {
    if (!this.manualEdit) {
      this.manualEdit = true
      this._toggleResetLink(true)
    }
  }

  resetPreview(event) {
    event.preventDefault()
    this.manualEdit = false
    this._toggleResetLink(false)
    this._updatePreview()
  }

  copyDraft() {
    const text = this.bodyTarget.value || ""
    if (!text) return

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        this._showStatus("Draft copied to clipboard.")
        this._flashButton(this.copyButtonTarget, "Copied!")
      }, () => {
        this._fallbackCopy(text)
      })
    } else {
      this._fallbackCopy(text)
    }
  }

  _fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.left = "-9999px"
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()

    try {
      const successful = document.execCommand("copy")
      if (successful) {
        this._showStatus("Draft copied to clipboard.")
        this._flashButton(this.copyButtonTarget, "Copied!")
      } else {
        this._showStatus("Could not copy to clipboard. Please select all and copy manually.", true)
      }
    } catch (err) {
      this._showStatus("Could not copy to clipboard. Please select all and copy manually.", true)
    }

    document.body.removeChild(textarea)
  }

  openEmail(event) {
    const body = this.bodyTarget.value || ""

    if (body.includes("[YOUR_FULL_NAME]") || body.includes("[YOUR_ADDRESS]")) {
      this._showStatus("Please fill in your full name and address before opening your email app.", true)
      event.preventDefault()
      return
    }

    const email = this.recipientEmailValue
    const subject = this.subjectValue
    const mailto = this._buildMailto(email, subject, body)

    window.location.href = mailto
  }

  _updatePreview() {
    if (!this.rawBody) return

    const name = this.nameTarget.value || ""
    const address = this.addressTarget.value || ""

    this.bodyTarget.value = this.rawBody
      .replaceAll("[YOUR_FULL_NAME]", name)
      .replaceAll("[YOUR_ADDRESS]", address)
  }

  _toggleResetLink(show) {
    if (this.hasResetPlaceholdersTarget) {
      this.resetPlaceholdersTarget.style.display = show ? "" : "none"
    }
  }

  _buildMailto(email, subject, body) {
    const params = new URLSearchParams()
    if (subject) params.set("subject", subject)
    if (body) params.set("body", body)

    let url = "mailto:"
    if (email) url += encodeURIComponent(email)
    const query = params.toString()
    if (query) url += "?" + query
    return url
  }

  _showStatus(message, isError = false) {
    if (!this.hasStatusMessageTarget) return
    this.statusMessageTarget.textContent = message
    this.statusMessageTarget.style.display = "block"
    this.statusMessageTarget.className = "draft-status-message " + (isError ? "draft-status-message--error" : "draft-status-message--success")
  }

  _flashButton(button, text) {
    if (!button) return
    const original = button.textContent
    button.textContent = text
    setTimeout(() => { button.textContent = original }, 1500)
  }
}
