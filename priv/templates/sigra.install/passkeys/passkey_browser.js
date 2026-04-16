import {
  browserSupportsWebAuthnAutofill,
  startAuthentication as browserStartAuthentication,
  startRegistration as browserStartRegistration,
} from "@simplewebauthn/browser"

const CEREMONY_ABORTED = "ERROR_CEREMONY_ABORTED"
const ERROR_PASSKEY_UNSUPPORTED = "ERROR_PASSKEY_UNSUPPORTED"

export class WebAuthnError extends Error {
  constructor(message, code) {
    super(message)
    this.name = "WebAuthnError"
    this.code = code
  }
}

export const WebAuthnAbortService = {
  cancelCeremony() {},
}

function normalizeAbort(error) {
  if (error && (error.name === "AbortError" || error.code === CEREMONY_ABORTED)) {
    return new WebAuthnError("aborted", CEREMONY_ABORTED)
  }

  return error
}

function buildWebAuthnError(message, code) {
  return new WebAuthnError(message, code)
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || ""
}

function safeLoginStatus(error) {
  if (error?.code === ERROR_PASSKEY_UNSUPPORTED || error?.name === "NotSupportedError") {
    return {
      status: "unsupported",
      message: "Passkeys aren't available in this browser.",
    }
  }

  if (
    error?.code === CEREMONY_ABORTED ||
    error?.name === "AbortError" ||
    error?.name === "NotAllowedError"
  ) {
    return {
      status: "canceled",
      message: "Passkey sign-in was canceled.",
    }
  }

  if (error?.name === "TimeoutError" || error?.code === "ERROR_CEREMONY_TIMEOUT") {
    return {
      status: "timeout",
      message: "That passkey request timed out.",
    }
  }

  return {
    status: "error",
    message: "We couldn't finish passkey sign-in. Try again or use another way to continue.",
  }
}

function updateLoginStatus(form, errorOrStatus) {
  const statusElement = form.querySelector("[data-passkey-login-status]")

  if (!statusElement) {
    return
  }

  const status =
    typeof errorOrStatus === "string"
      ? { status: errorOrStatus, message: "" }
      : safeLoginStatus(errorOrStatus)

  statusElement.dataset.passkeyStatus = status.status
  statusElement.textContent = status.message
}

async function fetchAuthenticationOptions(optionsUrl, body) {
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

function submitPasskeyLogin(form, completeUrl, responseInput, response) {
  responseInput.value = JSON.stringify(response)
  form.action = completeUrl
  HTMLFormElement.prototype.submit.call(form)
}

export async function conditionalMediationAvailable() {
  return browserSupportsWebAuthnAutofill()
}

export async function startRegistration({ optionsJSON, signal }) {
  try {
    return await browserStartRegistration({ optionsJSON, signal })
  } catch (error) {
    throw normalizeAbort(error)
  }
}

export async function startAuthentication({ optionsJSON, signal, useBrowserAutofill = false }) {
  try {
    if (useBrowserAutofill) {
      if (!(await conditionalMediationAvailable())) {
        throw buildWebAuthnError("unsupported", ERROR_PASSKEY_UNSUPPORTED)
      }
    }

    return await browserStartAuthentication({ optionsJSON, signal, useBrowserAutofill })
  } catch (error) {
    throw normalizeAbort(error)
  }
}

export function attachPasskeyLogin(options = {}) {
  const form = options.form || document.querySelector("#passkey_login_form")
  const button = options.button || document.querySelector("#passkey_login_button")

  if (!form || !button) {
    return { attached: false }
  }

  const emailInput = form.querySelector("input[name='user[email]']")
  const responseInput = form.querySelector("input[name='passkey[response]']")

  if (!responseInput) {
    return { attached: false }
  }

  const optionsUrl =
    options.optionsUrl ||
    form.dataset.optionsUrl ||
    form.dataset.optionsPath ||
    "/users/log_in/passkey/options"
  const completeUrl = options.completeUrl || form.action || "/users/log_in/passkey"

  async function authenticateExplicit(event) {
    event.preventDefault()

    const email = (emailInput?.value || "").trim()

    if (!email) {
      updateLoginStatus(form, "email_required")
      return
    }

    try {
      const optionsJSON = await fetchAuthenticationOptions(optionsUrl, {
        user: { email },
      })

      const response = await startAuthentication({
        optionsJSON,
        useBrowserAutofill: false,
      })

      submitPasskeyLogin(form, completeUrl, responseInput, response)
    } catch (error) {
      updateLoginStatus(form, error)
    }
  }

  button.addEventListener("click", authenticateExplicit)
  form.addEventListener("submit", authenticateExplicit)

  const ready =
    options.enableConditionalUI === true
      ? (async () => {
          try {
            if (!(await conditionalMediationAvailable())) {
              throw buildWebAuthnError("unsupported", ERROR_PASSKEY_UNSUPPORTED)
            }

            const optionsJSON = await fetchAuthenticationOptions(optionsUrl, {
              conditional: "true",
            })

            const response = await startAuthentication({
              optionsJSON,
              useBrowserAutofill: true,
            })

            submitPasskeyLogin(form, completeUrl, responseInput, response)
          } catch (error) {
            updateLoginStatus(form, error)
          }
        })()
      : Promise.resolve()

  return { attached: true, ready }
}
