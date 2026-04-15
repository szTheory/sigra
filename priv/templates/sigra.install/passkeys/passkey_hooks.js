import {
  WebAuthnAbortService,
  WebAuthnError,
  startAuthentication,
  startRegistration,
} from "@simplewebauthn/browser"

const CEREMONY_ABORTED = "ERROR_CEREMONY_ABORTED"

function toPlainObject(payload) {
  return JSON.parse(JSON.stringify(payload))
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

      this.handleEvent(startEvent, async (payload = {}) => {
        this.cancelPasskeyCeremony("superseded", false)

        const operationId = this.__sigraPasskeyOperationId + 1
        const abortController = new AbortController()

        this.__sigraPasskeyOperationId = operationId
        this.__sigraPasskeyAbortController = abortController
        this.__sigraPasskeyActive = true

        try {
          const response = await startCeremony(payload.options, abortController.signal)

          if (!this.isLatestPasskeyOperation(operationId) || abortController.signal.aborted) {
            return
          }

          this.pushEvent(successEvent, { response: toPlainObject(response) })
        } catch (error) {
          if (!this.isLatestPasskeyOperation(operationId)) {
            return
          }

          if (abortController.signal.aborted || isCeremonyAbort(error)) {
            this.pushEvent(abortedEvent, { reason: "aborted" })
          } else {
            this.pushEvent(errorEvent, normalizeError(error))
          }
        } finally {
          if (this.isLatestPasskeyOperation(operationId)) {
            this.__sigraPasskeyAbortController = null
            this.__sigraPasskeyActive = false
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
        this.pushEvent(reason.includes("disconnect") ? abortedEvent : abortedEvent, { reason })
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
  startCeremony(optionsJSON, signal) {
    return startRegistration({ optionsJSON, signal })
  },
})

export const PasskeyAuthenticate = buildHook({
  startEvent: "sigra:passkey-authenticate:start",
  successEvent: "sigra:passkey-authenticate:success",
  errorEvent: "sigra:passkey-authenticate:error",
  abortedEvent: "sigra:passkey-authenticate:aborted",
  startCeremony(optionsJSON, signal) {
    return startAuthentication({ optionsJSON, signal })
  },
})

export const PasskeyHooks = {
  PasskeyRegister,
  PasskeyAuthenticate,
}
