import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "container" ]
  static values = {
    mode: String,
    startUrl: String,
    statusUrl: String,
    startOverUrl: String,
  }

  connect() {
    this.pollTimer = null
    this.pollCount = 0
    this.maxPolls = 60

    this.checkStatus()

    this._visibilityHandler = () => {
      if (document.visibilityState === "visible") {
        this.checkStatus()
      }
    }
    document.addEventListener("visibilitychange", this._visibilityHandler)
  }

  disconnect() {
    this.stopPolling()
    if (this._visibilityHandler) {
      document.removeEventListener("visibilitychange", this._visibilityHandler)
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { "Accept": "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()

      if (data.status === "complete") {
        this.stopPolling()
        this.handleComplete(data)
      } else if (data.status === "processing") {
        this.showSpinner()
        this.startPolling()
      } else if (data.status === "failed") {
        this.stopPolling()
        this.showError("Generation failed. Please try again.")
      } else {
        this.startGeneration()
      }
    } catch (err) {
      this.startGeneration()
    }
  }

  async startGeneration() {
    this.showSpinner()
    try {
      const response = await fetch(this.startUrlValue, { headers: { "Accept": "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()

      if (data.body || this.modeValue === "questions") {
        this.stopPolling()
        this.handleComplete(data)
      } else {
        this.startPolling()
      }
    } catch (err) {
      this.startPolling()
    }
  }

  startPolling() {
    this.stopPolling()
    this.pollCount = 0
    this.pollTimer = setInterval(() => {
      this.pollCount++
      if (this.pollCount > this.maxPolls) {
        this.stopPolling()
        this.showError("Generation is taking too long. Please try again.")
        return
      }
      this.pollStatus()
    }, 2000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async pollStatus() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { "Accept": "application/json" } })
      if (!response.ok) return
      const data = await response.json()

      if (data.status === "complete") {
        this.stopPolling()
        this.handleComplete(data)
      } else if (data.status === "failed") {
        this.stopPolling()
        this.showError("Generation failed. Please try again.")
      }
    } catch (err) {
      // Keep polling on network errors
    }
  }

  handleComplete(data) {
    if (this.modeValue === "draft") {
      this.populateForm(data)
    } else if (this.modeValue === "questions") {
      if (data.all_good) {
        const draftUrl = this.element.dataset.pollingDraftUrl
        if (draftUrl) window.location.href = draftUrl
      } else if (data.vague) {
        const questionsUrl = this.element.dataset.pollingQuestionsUrl
        if (questionsUrl) {
          const url = new URL(questionsUrl, window.location.origin)
          url.searchParams.set("follow_up", data.vague.question_id)
          url.searchParams.set("follow_up_text", data.vague.follow_up_text)
          window.location.href = url.toString()
        }
      }
    }
  }

  populateForm(data) {
    const warnings = data.warnings && data.warnings.length
      ? data.warnings.map(w => `<div class="flash alert">${this.escapeHtml(w)}</div>`).join("")
      : ""

    const draftForm = document.getElementById("draft-form")
    const textarea = document.getElementById("draft-body-textarea")
    const warningsContainer = document.getElementById("draft-warnings")

    if (textarea) {
      textarea.value = data.body || ""
      textarea.dispatchEvent(new CustomEvent("draft:loaded", {
        bubbles: true,
        detail: { body: data.body || "" }
      }))
    }
    if (warningsContainer) warningsContainer.innerHTML = warnings

    this.containerTarget.innerHTML = ""
    if (draftForm) draftForm.style.display = "block"
  }

  showSpinner() {
    const message = this.modeValue === "draft" ? "Generating your draft email…" : "Reviewing your answers…"

    const draftForm = document.getElementById("draft-form")
    if (draftForm) draftForm.style.display = "none"

    this.containerTarget.innerHTML = `
      <div class="slm-spinner">
        <div class="spinner-icon"></div>
        <p>${message}</p>
      </div>
    `
  }

  showError(message) {
    this.containerTarget.innerHTML = `
      <div class="slm-error">
        <p>${message}</p>
        <button onclick="location.reload()">Retry</button>
      </div>
    `
  }

  escapeHtml(text) {
    if (!text) return ""
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
