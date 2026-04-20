// Sigra passkeys:start
import { PasskeyHooks } from "./passkey_hooks"
import { attachPasskeyLogin } from "./passkey_browser"
hooks: { ...colocatedHooks, ...PasskeyHooks }
document.addEventListener("DOMContentLoaded", () => attachPasskeyLogin({ enableConditionalUI: true }))
// Sigra passkeys:end
