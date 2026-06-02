// Sigra admin hooks — plain JS (NO import/export so it runs unbundled when
// pasted into the hand-maintained app.js readable tail).
//
// Defines window.SigraAdminHooks = { CmdK, CopyToClipboard }:
//   - CmdK: a fully client-side Cmd-K / Ctrl-K command palette bound to the
//     hidden topbar trigger. Reveals the trigger on mount (progressive
//     enhancement — hosts without this hook never see a dead button), opens an
//     ARIA dialog/listbox with focus trap, scope-aware nav + find-a-user free
//     text. No server round-trips (window.location.assign only).
//   - CopyToClipboard: a delegated click handler on `.sg-admin-shell code.sg-code`
//     id chips — copies the text and shows a transient Stage-0 sg-toast. No
//     per-LiveView markup edits required.
(function () {
  "use strict";

  // ---- shared toast helper (reuses Stage-0 sg-toast classes) --------------
  function ensureToastRegion() {
    var region = document.querySelector(".sg-toast-region");
    if (!region) {
      region = document.createElement("div");
      region.className = "sg-toast-region";
      region.setAttribute("aria-live", "polite");
      document.body.appendChild(region);
    }
    return region;
  }

  function showToast(message) {
    var region = ensureToastRegion();
    var toast = document.createElement("div");
    toast.className = "sg-toast sg-toast--enter";
    toast.setAttribute("role", "status");
    toast.textContent = message;
    region.appendChild(toast);
    window.setTimeout(function () {
      toast.classList.remove("sg-toast--enter");
      toast.classList.add("sg-toast--leave");
      window.setTimeout(function () {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 240);
    }, 2000);
  }

  var FOCUSABLE =
    'a[href], button:not([disabled]), input, [tabindex]:not([tabindex="-1"])';

  // ---- CmdK hook ----------------------------------------------------------
  var CmdK = {
    mounted: function () {
      var self = this;
      this.el.classList.add("is-ready");

      var ds = this.el.dataset;
      this.commands = [
        { label: "Go to Users", href: ds.usersHref || "/admin/users" },
        { label: "Go to Audit", href: ds.auditHref || "/admin/audit" },
        {
          label: "Go to " + (ds.overviewLabel || "Global") + " overview",
          href: ds.overviewHref || "/admin"
        }
      ];
      this.usersHref = ds.usersHref || "/admin/users";

      this.overlay = null;
      this.activeIndex = 0;
      this.filtered = this.commands.slice();

      this._onKeydown = function (event) {
        var key = event.key ? event.key.toLowerCase() : "";
        if ((event.metaKey || event.ctrlKey) && key === "k") {
          event.preventDefault();
          self.toggle();
        }
      };
      document.addEventListener("keydown", this._onKeydown);

      this._onTriggerClick = function () {
        self.open();
      };
      this.el.addEventListener("click", this._onTriggerClick);
    },

    toggle: function () {
      if (this.overlay) {
        this.close();
      } else {
        this.open();
      }
    },

    open: function () {
      if (this.overlay) return;
      var self = this;

      var overlay = document.createElement("div");
      overlay.className = "sg-cmdk sg-cmdk--enter";

      var dialog = document.createElement("div");
      dialog.className = "sg-cmdk__dialog";
      dialog.setAttribute("role", "dialog");
      dialog.setAttribute("aria-modal", "true");
      dialog.setAttribute("aria-label", "Command palette");

      var input = document.createElement("input");
      input.type = "text";
      input.className = "sg-cmdk__input";
      input.setAttribute("aria-label", "Find a user or jump to a page");
      input.setAttribute("placeholder", "Find a user or jump to a page…");

      var list = document.createElement("ul");
      list.className = "sg-cmdk__list";
      list.setAttribute("role", "listbox");

      dialog.appendChild(input);
      dialog.appendChild(list);
      overlay.appendChild(dialog);
      document.body.appendChild(overlay);

      this.overlay = overlay;
      this.dialog = dialog;
      this.input = input;
      this.list = list;
      this.activeIndex = 0;
      this.renderItems("");

      // click on scrim (outside dialog) closes
      this._onOverlayClick = function (event) {
        if (event.target === overlay) {
          self.close();
        }
      };
      overlay.addEventListener("click", this._onOverlayClick);

      // input filtering
      this._onInput = function () {
        self.activeIndex = 0;
        self.renderItems(input.value);
      };
      input.addEventListener("input", this._onInput);

      // keyboard within the open palette
      this._onDialogKeydown = function (event) {
        self.handleKeydown(event);
      };
      dialog.addEventListener("keydown", this._onDialogKeydown);

      input.focus();
    },

    renderItems: function (query) {
      var self = this;
      var q = (query || "").trim().toLowerCase();
      this.filtered = q
        ? this.commands.filter(function (cmd) {
            return cmd.label.toLowerCase().indexOf(q) !== -1;
          })
        : this.commands.slice();

      this.list.innerHTML = "";

      if (this.filtered.length === 0) {
        var empty = document.createElement("li");
        empty.className = "sg-cmdk__empty";
        empty.textContent = q
          ? 'Press Enter to find users matching "' + query.trim() + '"'
          : "No matches";
        this.list.appendChild(empty);
        return;
      }

      if (this.activeIndex >= this.filtered.length) {
        this.activeIndex = this.filtered.length - 1;
      }

      this.filtered.forEach(function (cmd, index) {
        var item = document.createElement("li");
        item.className = "sg-cmdk__item";
        item.setAttribute("role", "option");
        item.textContent = cmd.label;
        var active = index === self.activeIndex;
        item.classList.toggle("is-active", active);
        item.setAttribute("aria-selected", active ? "true" : "false");
        item.addEventListener("click", function () {
          self.navigate(cmd.href);
        });
        self.list.appendChild(item);
      });
    },

    handleKeydown: function (event) {
      var key = event.key;

      if (key === "Escape") {
        event.preventDefault();
        this.close();
        return;
      }

      if (key === "ArrowDown") {
        event.preventDefault();
        if (this.filtered.length) {
          this.activeIndex = (this.activeIndex + 1) % this.filtered.length;
          this.refreshActive();
        }
        return;
      }

      if (key === "ArrowUp") {
        event.preventDefault();
        if (this.filtered.length) {
          this.activeIndex =
            (this.activeIndex - 1 + this.filtered.length) % this.filtered.length;
          this.refreshActive();
        }
        return;
      }

      if (key === "Enter") {
        event.preventDefault();
        var text = this.input.value.trim();
        if (this.filtered.length) {
          this.navigate(this.filtered[this.activeIndex].href);
        } else if (text) {
          var sep = this.usersHref.indexOf("?") !== -1 ? "&" : "?";
          this.navigate(this.usersHref + sep + "q=" + encodeURIComponent(text));
        }
        return;
      }

      if (key === "Tab") {
        this.trapFocus(event);
      }
    },

    refreshActive: function () {
      var self = this;
      var items = this.list.querySelectorAll(".sg-cmdk__item");
      items.forEach(function (item, index) {
        var active = index === self.activeIndex;
        item.classList.toggle("is-active", active);
        item.setAttribute("aria-selected", active ? "true" : "false");
      });
    },

    trapFocus: function (event) {
      var focusables = this.dialog.querySelectorAll(FOCUSABLE);
      if (!focusables.length) return;
      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    },

    navigate: function (href) {
      this.close();
      window.location.assign(href);
    },

    close: function () {
      if (!this.overlay) return;
      this.overlay.removeEventListener("click", this._onOverlayClick);
      if (this.dialog) {
        this.dialog.removeEventListener("keydown", this._onDialogKeydown);
      }
      if (this.input) {
        this.input.removeEventListener("input", this._onInput);
      }
      if (this.overlay.parentNode) {
        this.overlay.parentNode.removeChild(this.overlay);
      }
      this.overlay = null;
      this.dialog = null;
      this.input = null;
      this.list = null;
      if (this.el) {
        this.el.focus();
      }
    },

    destroyed: function () {
      document.removeEventListener("keydown", this._onKeydown);
      if (this.el && this._onTriggerClick) {
        this.el.removeEventListener("click", this._onTriggerClick);
      }
      this.close();
    },

    disconnected: function () {
      this.close();
    }
  };

  // ---- CopyToClipboard (delegated; no per-LiveView markup) ----------------
  function installCopyDelegate() {
    if (window.__sigraCopyDelegateInstalled) return;
    window.__sigraCopyDelegateInstalled = true;

    document.addEventListener("click", function (event) {
      var target = event.target;
      if (!target || typeof target.closest !== "function") return;
      var code = target.closest(".sg-admin-shell code.sg-code");
      if (!code) return;

      var text = (code.textContent || "").trim();
      if (!text) return;

      var done = function () {
        showToast("Copied");
      };

      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, function () {
            // swallow rejection — clipboard may be blocked; no throw
          });
        }
      } catch (err) {
        // ignore — never throw from a click handler
      }
    });

    // Hint affordance: label admin id chips on first pass.
    var label = function () {
      var chips = document.querySelectorAll(".sg-admin-shell code.sg-code");
      chips.forEach(function (chip) {
        if (!chip.getAttribute("title")) {
          chip.setAttribute("title", "Click to copy");
        }
      });
    };
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", label);
    } else {
      label();
    }
  }

  // CopyToClipboard is a no-op LiveView hook shell; the real behavior is the
  // delegated document listener installed once below. Registering it as a hook
  // keeps the LiveSocket hooks map symmetric and lets hosts opt in by name.
  var CopyToClipboard = {
    mounted: function () {
      installCopyDelegate();
    }
  };

  installCopyDelegate();

  window.SigraAdminHooks = {
    CmdK: CmdK,
    CopyToClipboard: CopyToClipboard
  };
})();
