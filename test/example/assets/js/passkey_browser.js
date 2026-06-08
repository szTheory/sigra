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

function base64UrlEncode(bytes) {
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlDecode(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding =
    normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(normalized + padding);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function toUint8Array(value) {
  if (value instanceof Uint8Array) {
    return value;
  }

  if (value instanceof ArrayBuffer) {
    return new Uint8Array(value);
  }

  if (Array.isArray(value)) {
    return Uint8Array.from(value);
  }

  if (typeof value === "string") {
    return base64UrlDecode(value);
  }

  throw new Error("unsupported WebAuthn binary payload");
}

function serializeCredential(credential) {
  const response = credential.response;

  return {
    id: credential.id,
    rawId: base64UrlEncode(new Uint8Array(credential.rawId)),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment || null,
    response: {
      clientDataJSON: base64UrlEncode(new Uint8Array(response.clientDataJSON)),
      attestationObject: response.attestationObject
        ? base64UrlEncode(new Uint8Array(response.attestationObject))
        : null,
      authenticatorData: response.authenticatorData
        ? base64UrlEncode(new Uint8Array(response.authenticatorData))
        : null,
      signature: response.signature
        ? base64UrlEncode(new Uint8Array(response.signature))
        : null,
      userHandle: response.userHandle
        ? base64UrlEncode(new Uint8Array(response.userHandle))
        : null,
    },
    clientExtensionResults: credential.getClientExtensionResults(),
  };
}

function normalizeAbort(error) {
  if (
    error &&
    (error.name === "AbortError" || error.code === CEREMONY_ABORTED)
  ) {
    return new WebAuthnError("aborted", CEREMONY_ABORTED);
  }

  return error;
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || "";
}

function safeLoginStatus(error) {
  if (error === "email_required") {
    return {
      status: "email_required",
      message: "Enter your email to continue with a passkey.",
    };
  }

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

function findEmailInput(form, options) {
  if (options.emailInput) {
    return options.emailInput;
  }

  return (
    (form.dataset.emailInput
      ? document.querySelector(form.dataset.emailInput)
      : null) ||
    form.querySelector(
      "input[name='user[email]']:not([data-passkey-email-shadow])",
    )
  );
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
  HTMLFormElement.prototype.submit.call(form);
}

export async function conditionalMediationAvailable() {
  const publicKeyCredential = window.PublicKeyCredential;

  if (!publicKeyCredential) {
    return false;
  }

  if (
    typeof publicKeyCredential.isConditionalMediationAvailable !== "function"
  ) {
    return false;
  }

  return publicKeyCredential.isConditionalMediationAvailable();
}

export async function startRegistration({ optionsJSON, signal }) {
  try {
    const credential = await navigator.credentials.create({
      publicKey: {
        ...optionsJSON,
        challenge: toUint8Array(optionsJSON.challenge),
        user: {
          ...optionsJSON.user,
          id: toUint8Array(optionsJSON.user.id),
        },
      },
      signal,
    });

    return serializeCredential(credential);
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
    const request = {
      publicKey: {
        ...optionsJSON,
        challenge: toUint8Array(optionsJSON.challenge),
        allowCredentials: (optionsJSON.allowCredentials || []).map(
          (credential) => ({
            ...credential,
            id: toUint8Array(credential.id),
          }),
        ),
      },
      signal,
    };

    if (useBrowserAutofill) {
      if (!(await conditionalMediationAvailable())) {
        throw new WebAuthnError("unsupported", ERROR_PASSKEY_UNSUPPORTED);
      }

      Object.assign(request, { mediation: "conditional" });
    }

    const credential = await navigator.credentials.get(request);

    if (!credential) {
      throw new WebAuthnError("canceled", CEREMONY_ABORTED);
    }

    return serializeCredential(credential);
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

  const emailInput = findEmailInput(form, options);
  const emailShadowInput = form.querySelector("[data-passkey-email-shadow]");
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

  async function authenticateExplicit(event) {
    event.preventDefault();

    const email = (emailInput?.value || "").trim();

    if (!email) {
      updateLoginStatus(form, "email_required");
      return;
    }

    try {
      clearLoginStatus(form);

      const optionsJSON = await fetchAuthenticationOptions(optionsUrl, {
        user: { email },
      });

      const response = await startAuthentication({
        optionsJSON,
        useBrowserAutofill: false,
      });

      if (emailShadowInput) {
        emailShadowInput.value = email;
      }

      submitPasskeyLogin(form, completeUrl, responseInput, response);
    } catch (error) {
      updateLoginStatus(form, error);
    }
  }

  button.addEventListener("click", authenticateExplicit);
  form.addEventListener("submit", authenticateExplicit);

  const ready =
    options.enableConditionalUI === true
      ? (async () => {
          try {
            if (!(await conditionalMediationAvailable())) {
              throw new WebAuthnError("unsupported", ERROR_PASSKEY_UNSUPPORTED);
            }

            const optionsJSON = await fetchAuthenticationOptions(optionsUrl, {
              conditional: "true",
            });

            const response = await startAuthentication({
              optionsJSON,
              useBrowserAutofill: true,
            });

            submitPasskeyLogin(form, completeUrl, responseInput, response);
          } catch (error) {
            if (options.silentConditionalErrors === false) {
              updateLoginStatus(form, error);
            } else {
              clearLoginStatus(form);
            }
          }
        })()
      : Promise.resolve();

  return { attached: true, ready };
}
