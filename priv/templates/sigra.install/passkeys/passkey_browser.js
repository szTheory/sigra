import {
  browserSupportsWebAuthnAutofill,
  startAuthentication as browserStartAuthentication,
  startRegistration as browserStartRegistration,
} from "@simplewebauthn/browser";

const CEREMONY_ABORTED = "ERROR_CEREMONY_ABORTED";
const ERROR_PASSKEY_UNSUPPORTED = "ERROR_PASSKEY_UNSUPPORTED";

export class WebAuthnError extends Error {
  constructor(message, code) {
    super(message);
    this.name = "WebAuthnError";
    this.code = code;
  }
}

export const WebAuthnAbortService = {
  cancelCeremony() {},
};

function normalizeAbort(error) {
  if (
    error &&
    (error.name === "AbortError" || error.code === CEREMONY_ABORTED)
  ) {
    return new WebAuthnError("aborted", CEREMONY_ABORTED);
  }

  return error;
}

function buildWebAuthnError(message, code) {
  return new WebAuthnError(message, code);
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || "";
}

function safeLoginStatus(error) {
  if (
    error?.code === ERROR_PASSKEY_UNSUPPORTED ||
    error?.name === "NotSupportedError"
  ) {
    return {
      status: "unsupported",
      message: "Passkeys aren't available in this browser.",
    };
  }

  if (
    error?.code === CEREMONY_ABORTED ||
    error?.name === "AbortError" ||
    error?.name === "NotAllowedError"
  ) {
    return {
      status: "canceled",
      message: "Passkey sign-in was canceled.",
    };
  }

  if (
    error?.name === "TimeoutError" ||
    error?.code === "ERROR_CEREMONY_TIMEOUT"
  ) {
    return {
      status: "timeout",
      message: "That passkey request timed out.",
    };
  }

  return {
    status: "error",
    message:
      "We couldn't finish passkey sign-in. Try again or use another way to continue.",
  };
}

function updateLoginStatus(form, errorOrStatus) {
  const statusElement = form.querySelector("[data-passkey-login-status]");

  if (!statusElement) {
    return;
  }

  const status =
    typeof errorOrStatus === "string"
      ? { status: errorOrStatus, message: "" }
      : safeLoginStatus(errorOrStatus);

  statusElement.dataset.passkeyStatus = status.status;
  statusElement.textContent = status.message;
}

function clearLoginStatus(form) {
  const statusElement = form.querySelector("[data-passkey-login-status]");

  if (!statusElement) {
    return;
  }

  statusElement.dataset.passkeyStatus = "";
  statusElement.textContent = "";
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
  });

  if (!response.ok) {
    throw new Error("passkey_options_failed");
  }

  const json = await response.json();
  return json.options;
}

function submitPasskeyLogin(form, completeUrl, responseInput, response) {
  responseInput.value = JSON.stringify(response);
  form.action = completeUrl;
  form.querySelectorAll("input[name='user[email]']").forEach((input) => {
    input.disabled = true;
  });
  HTMLFormElement.prototype.submit.call(form);
}

export async function conditionalMediationAvailable() {
  return browserSupportsWebAuthnAutofill();
}

export async function startRegistration({ optionsJSON, signal }) {
  try {
    return await browserStartRegistration({ optionsJSON, signal });
  } catch (error) {
    throw normalizeAbort(error);
  }
}

export async function startAuthentication({
  optionsJSON,
  signal,
  useBrowserAutofill = false,
}) {
  try {
    if (useBrowserAutofill) {
      if (!(await conditionalMediationAvailable())) {
        throw buildWebAuthnError("unsupported", ERROR_PASSKEY_UNSUPPORTED);
      }
    }

    return await browserStartAuthentication({
      optionsJSON,
      signal,
      useBrowserAutofill,
    });
  } catch (error) {
    throw normalizeAbort(error);
  }
}

export function attachPasskeyLogin(options = {}) {
  const form = options.form || document.querySelector("#passkey_login_form");
  const button =
    options.button || document.querySelector("#passkey_login_button");

  if (!form || !button) {
    return { attached: false };
  }

  const responseInput = form.querySelector("input[name='passkey[response]']");

  if (!responseInput) {
    return { attached: false };
  }

  const optionsUrl =
    options.optionsUrl ||
    form.dataset.optionsUrl ||
    form.dataset.optionsPath ||
    "/users/log_in/passkey/options";
  const completeUrl =
    options.completeUrl || form.action || "/users/log_in/passkey";

  let loginAttemptId = 0;
  let activeController = null;
  let authenticationOptionsPromise = null;

  function fetchLoginOptions() {
    if (!authenticationOptionsPromise) {
      authenticationOptionsPromise = fetchAuthenticationOptions(
        optionsUrl,
        {},
      ).catch((error) => {
        authenticationOptionsPromise = null;
        throw error;
      });
    }

    return authenticationOptionsPromise;
  }

  async function authenticateExplicit(event) {
    event.preventDefault();
    const operationId = ++loginAttemptId;
    activeController?.abort();
    const controller = new AbortController();
    activeController = controller;

    try {
      clearLoginStatus(form);

      const optionsJSON = await fetchLoginOptions();
      if (operationId !== loginAttemptId) return;

      const response = await startAuthentication({
        optionsJSON,
        useBrowserAutofill: false,
        signal: controller.signal,
      });

      if (operationId !== loginAttemptId || controller.signal.aborted) return;

      if (activeController === controller) {
        activeController = null;
      }

      submitPasskeyLogin(form, completeUrl, responseInput, response);
    } catch (error) {
      if (operationId !== loginAttemptId) return;
      if (activeController === controller) {
        activeController = null;
      }
      authenticationOptionsPromise = null;
      updateLoginStatus(form, error);
    }
  }

  button.addEventListener("click", authenticateExplicit);
  form.addEventListener("submit", authenticateExplicit);

  const ready =
    options.enableConditionalUI === true
      ? (async () => {
          const operationId = loginAttemptId;
          let controller = null;

          try {
            if (!(await conditionalMediationAvailable())) {
              throw buildWebAuthnError(
                "unsupported",
                ERROR_PASSKEY_UNSUPPORTED,
              );
            }

            if (operationId !== loginAttemptId) return;

            controller = new AbortController();
            activeController = controller;
            const optionsJSON = await fetchLoginOptions();

            if (
              operationId !== loginAttemptId ||
              controller.signal.aborted
            ) {
              return;
            }

            const response = await startAuthentication({
              optionsJSON,
              useBrowserAutofill: true,
              signal: controller.signal,
            });

            if (
              operationId !== loginAttemptId ||
              controller.signal.aborted
            ) {
              return;
            }

            submitPasskeyLogin(form, completeUrl, responseInput, response);
          } catch (error) {
            if (
              operationId !== loginAttemptId ||
              controller?.signal.aborted
            ) {
              return;
            }
            authenticationOptionsPromise = null;

            if (options.silentConditionalErrors === false) {
              updateLoginStatus(form, error);
            } else {
              clearLoginStatus(form);
            }
          } finally {
            if (activeController === controller) {
              activeController = null;
            }
          }
        })()
      : Promise.resolve();

  return { attached: true, ready };
}
