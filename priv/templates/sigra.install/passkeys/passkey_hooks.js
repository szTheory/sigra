import {
  WebAuthnAbortService,
  WebAuthnError,
  startAuthentication,
  startRegistration,
} from "./passkey_browser"

const CEREMONY_ABORTED = "ERROR_CEREMONY_ABORTED"

function toPlainObject(payload) {
  return JSON.parse(JSON.stringify(payload))
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || ""
}

async function fetchOptions(optionsUrl, body = {}) {
  const response = await fetch(optionsUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json",
      "x-csrf-token": csrfToken(),
    },
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    throw new Error("passkey_options_failed")
  }

  const json = await response.json()
  return json.options
}

function appendHiddenInput(form, name, value) {
  const input = document.createElement("input")
  input.type = "hidden"
  input.name = name
  input.value = value
  form.appendChild(input)
}

function submitCompletion(completeUrl, response, extra = {}) {
  const form = document.createElement("form")
  form.method = "post"
  form.action = completeUrl
  form.hidden = true

  appendHiddenInput(form, "_csrf_token", csrfToken())
  appendHiddenInput(form, "passkey[response]", JSON.stringify(response))

  for (const [name, value] of Object.entries(extra)) {
    appendHiddenInput(form, name, value)
  }

  document.body.appendChild(form)
  HTMLFormElement.prototype.submit.call(form)
}

function buildHook({
  startEvent,
  successEvent,
  errorEvent,
  abortedEvent,
  startCeremony,
}) {
  return {
    mounted() {
      this.__sigraPasskeyAbortController = null
      this.__sigraPasskeyOperationId = 0
      this.__sigraPasskeyActive = false
      this.__sigraPasskeyAbortNotified = false

      this.handleEvent(startEvent, async (payload = {}) => {
        this.cancelPasskeyCeremony("superseded", false)

        const operationId = this.__sigraPasskeyOperationId + 1
        const abortController = new AbortController()

        this.__sigraPasskeyOperationId = operationId
        this.__sigraPasskeyAbortController = abortController
        this.__sigraPasskeyActive = true
        this.__sigraPasskeyAbortNotified = false

        try {
          const optionsJSON =
            payload.options ||
            (payload.optionsUrl
              ? await fetchOptions(payload.optionsUrl, payload.optionsBody || {})
              : null)

          const response = await startCeremony(payload, optionsJSON, abortController.signal)

          if (!this.isLatestPasskeyOperation(operationId) || abortController.signal.aborted) {
            return
          }

          this.pushEvent(successEvent, { response: toPlainObject(response) })

          if (payload.completeUrl) {
            const extra = { ...(payload.extra || {}) }
            const emailInput = document.querySelector("input[name='user[email]']")

            if (emailInput?.value && !extra["user[email]"]) {
              extra["user[email]"] = emailInput.value
            }

            submitCompletion(payload.completeUrl, response, extra)
          }
        } catch (error) {
          if (!this.isLatestPasskeyOperation(operationId)) {
            return
          }

          if (abortController.signal.aborted || isCeremonyAbort(error)) {
            if (!this.__sigraPasskeyAbortNotified) {
              this.pushEvent(abortedEvent, { reason: "aborted" })
            }
          } else {
            this.pushEvent(errorEvent, normalizeError(error))
          }
        } finally {
          if (this.isLatestPasskeyOperation(operationId)) {
            this.__sigraPasskeyAbortController = null
            this.__sigraPasskeyActive = false
            this.__sigraPasskeyAbortNotified = false
          }
        }
      })
    },

    destroyed() {
      this.cancelPasskeyCeremony("destroyed")
    },

    disconnected() {
      this.cancelPasskeyCeremony("disconnected")
    },

    cancelPasskeyCeremony(reason, notify = true) {
      if (!this.__sigraPasskeyAbortController) {
        return
      }

      this.__sigraPasskeyAbortController.abort()
      WebAuthnAbortService.cancelCeremony()

      if (notify && this.__sigraPasskeyActive) {
        this.__sigraPasskeyAbortNotified = true
        this.pushEvent(abortedEvent, { reason })
      }

      this.__sigraPasskeyAbortController = null
      this.__sigraPasskeyActive = false
    },

    isLatestPasskeyOperation(operationId) {
      return this.__sigraPasskeyOperationId === operationId
    },
  }
}

function normalizeError(error) {
  return {
    name: error?.name || "Error",
    message: error?.message || "Passkey ceremony failed",
    code: error?.code || null,
  }
}

function isCeremonyAbort(error) {
  return error instanceof WebAuthnError && error.code === CEREMONY_ABORTED
}

export const PasskeyRegister = buildHook({
  startEvent: "sigra:passkey-register:start",
  successEvent: "sigra:passkey-register:success",
  errorEvent: "sigra:passkey-register:error",
  abortedEvent: "sigra:passkey-register:aborted",
  startCeremony(_payload, optionsJSON, signal) {
    return startRegistration({ optionsJSON, signal })
  },
})

export const PasskeyAuthenticate = buildHook({
  startEvent: "sigra:passkey-authenticate:start",
  successEvent: "sigra:passkey-authenticate:success",
  errorEvent: "sigra:passkey-authenticate:error",
  abortedEvent: "sigra:passkey-authenticate:aborted",
  startCeremony(payload, optionsJSON, signal) {
    return startAuthentication({
      optionsJSON,
      signal,
      useBrowserAutofill: payload.useBrowserAutofill === true,
    })
  },
})

export const PasskeyHooks = {
  PasskeyRegister,
  PasskeyAuthenticate,
}
