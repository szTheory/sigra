// CopyToClipboard — Phase 93 UI-SPEC revision 1 (locked at §Component Inventory)
//
// Reads `data-copy-text` from the hook's element, calls
// navigator.clipboard.writeText(...), and swaps the inner text of the
// matching child span (whose id contains "copy-btn-text-") to "Copied!"
// for 1500ms, then restores the original label.
//
// Mirrors the CopyBackupCodes hook usage at
// priv/templates/sigra.install/core/mfa_settings_live.ex:530-560.
//
// Usage:
//
//   <button
//     type="button"
//     phx-hook="CopyToClipboard"
//     id={"copy-secret-btn-" <> credential.id}
//     data-copy-text={plaintext_value}
//     class="btn btn-ghost btn-sm"
//   >
//     <.icon name="hero-clipboard-document" class="w-4 h-4" />
//     <span id={"copy-btn-text-" <> credential.id <> "-secret"}>Copy client secret</span>
//   </button>
//
// The hook finds the first child element whose id starts with
// "copy-btn-text-" and uses that as the label-swap target. If no such
// element is found, clipboard writing still works but no label swap occurs.

export const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", async () => {
      const text = this.el.dataset.copyText
      if (!text) return

      // The label-swap target is the <span> child whose id starts with "copy-btn-text-".
      const label = this.el.querySelector("[id^='copy-btn-text-']")
      const original = label ? label.textContent : null

      try {
        await navigator.clipboard.writeText(text)

        if (label && original !== null) {
          label.textContent = "Copied!"
          setTimeout(() => {
            if (label) label.textContent = original
          }, 1500)
        }
      } catch (err) {
        // Clipboard write failed (e.g. permission denied, insecure context).
        // Log a warning but do not throw — the user can still manually copy
        // the value from the displayed code block.
        console.warn("CopyToClipboard: clipboard write failed", err)
      }
    })
  },
}

// Named export map mirroring the PasskeyHooks pattern at
// priv/templates/sigra.install/passkeys/passkey_hooks.js.
export const ClipboardHooks = { CopyToClipboard }
