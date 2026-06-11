// Sigra admin hooks — plain JS (NO import/export so it runs unbundled when
// pasted into the hand-maintained app.js readable tail).
//
// Defines window.SigraAdminHooks = { CmdK, CopyToClipboard, ThemeSwitch,
// AuthBrandingPreview }:
//   - CmdK: a fully client-side Cmd-K / Ctrl-K command palette bound to the
//     topbar trigger. Opens an ARIA dialog/listbox with focus trap, scope-aware
//     nav + find-a-user free text. No server round-trips (window.location.assign
//     only).
//   - CopyToClipboard: a delegated click handler on `.sg-admin-shell code.sg-code`
//     id chips — copies the text and shows a transient Stage-0 sg-toast. No
//     per-LiveView markup edits required.
//   - ThemeSwitch: a Light/Dark/System segmented control. Persists an explicit
//     choice in localStorage; System removes the override and follows
//     prefers-color-scheme through CSS.
//   - PageLoadingIndicator: listens to LiveView page-loading events and toggles
//     a restrained admin topbar loading rail for route navigation only.
//   - MetricHelp: delegated metric help popovers for hover, keyboard, and touch.
//   - FieldHelp: delegated form-label help tooltips for hover, keyboard, and touch.
//   - AuthBrandingPreview: optimistic local CSS-token updates for auth-branding
//     color previews while LiveView remains the source of truth for validation.
(function () {
  "use strict";

  var THEME_STORAGE_KEY = "sigra.admin.theme";
  var THEMES = ["light", "dark", "system"];
  var PAGE_LOADING_DELAY_MS = 180;
  var PAGE_LOADING_MIN_VISIBLE_MS = 220;
  var PAGE_LOADING_FADE_MS = 160;
  var PAGE_LOADING_MAX_ACTIVE_MS = 10000;
  var PAGE_LOADING_KINDS = {
    initial: true,
    patch: true,
    redirect: true,
  };
  var AUTH_BRANDING_HEX = /^#[0-9a-fA-F]{6}$/;
  var AUTH_BRANDING_COLOR_TOKENS = {
    accent_color: "--sigra-auth-light-accent",
    accent_foreground: "--sigra-auth-light-on-accent",
    background_color: "--sigra-auth-light-bg",
    surface_color: "--sigra-auth-light-surface",
    text_color: "--sigra-auth-light-text",
    muted_color: "--sigra-auth-light-muted",
    border_color: "--sigra-auth-light-border",
    dark_accent_color: "--sigra-auth-dark-accent",
    dark_accent_foreground: "--sigra-auth-dark-on-accent",
    dark_background_color: "--sigra-auth-dark-bg",
    dark_surface_color: "--sigra-auth-dark-surface",
    dark_text_color: "--sigra-auth-dark-text",
    dark_muted_color: "--sigra-auth-dark-muted",
    dark_border_color: "--sigra-auth-dark-border",
  };

  function storedTheme() {
    try {
      var value =
        window.localStorage && window.localStorage.getItem(THEME_STORAGE_KEY);
      return THEMES.indexOf(value) === -1 ? "system" : value;
    } catch (err) {
      return "system";
    }
  }

  function applyTheme(value) {
    var theme = THEMES.indexOf(value) === -1 ? "system" : value;
    if (theme === "system") {
      document.documentElement.removeAttribute("data-sg-admin-theme");
    } else {
      document.documentElement.setAttribute("data-sg-admin-theme", theme);
    }
    document.documentElement.dataset.sgAdminThemePreference = theme;
    document.querySelectorAll(".sg-admin-shell").forEach(function (shell) {
      shell.dataset.themePreference = theme;
      if (theme === "system") {
        shell.removeAttribute("data-theme");
      } else {
        shell.setAttribute("data-theme", theme);
      }
    });
    return theme;
  }

  applyTheme(storedTheme());

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

      var ds = this.el.dataset;
      this.commands = [
        { label: "Find users", href: ds.usersHref || "/admin/users" },
        { label: "Investigate audit", href: ds.auditHref || "/admin/audit" },
        {
          label: "Review " + (ds.overviewLabel || "Global") + " overview",
          href: ds.overviewHref || "/admin",
        },
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
            (this.activeIndex - 1 + this.filtered.length) %
            this.filtered.length;
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
    },
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

  function adminShell() {
    return document.querySelector(".sg-admin-shell");
  }

  // ---- MetricHelp (delegated; hover/focus/touch help for summary metrics) --
  function installMetricHelp() {
    if (window.__sigraMetricHelpInstalled) return;
    window.__sigraMetricHelpInstalled = true;

    function finePointer() {
      return (
        window.matchMedia &&
        window.matchMedia("(hover: hover) and (pointer: fine)").matches
      );
    }

    function rootFrom(target) {
      return target && target.closest
        ? target.closest("[data-sg-metric-help-root]")
        : null;
    }

    function helpFor(root) {
      var id = root && root.getAttribute("aria-describedby");
      return id ? document.getElementById(id) : null;
    }

    function open(root) {
      var help = helpFor(root);
      if (!root || !help) return;
      help.hidden = false;
      root.dataset.helpOpen = "true";
    }

    function close(root) {
      var help = helpFor(root);
      if (!root || !help) return;
      help.hidden = true;
      delete root.dataset.helpOpen;
      delete root.dataset.helpFocusOpenedAt;
    }

    function closeAll(except) {
      document
        .querySelectorAll('[data-sg-metric-help-root][data-help-open="true"]')
        .forEach(function (root) {
          if (root !== except) close(root);
        });
    }

    function closeRootWhenIdle(root) {
      window.setTimeout(function () {
        if (!root || root.contains(document.activeElement)) return;
        close(root);
      }, 0);
    }

    document.addEventListener("click", function (event) {
      var root = rootFrom(event.target);
      if (root) {
        var alreadyOpen = root.dataset.helpOpen === "true";
        var openedByFocusAt = Number(root.dataset.helpFocusOpenedAt || 0);
        var focusJustOpened =
          alreadyOpen &&
          document.activeElement === root &&
          Date.now() - openedByFocusAt < 350;
        delete root.dataset.helpFocusOpenedAt;
        closeAll(root);
        if (alreadyOpen && !focusJustOpened) {
          close(root);
        } else {
          open(root);
        }
        return;
      }

      closeAll(null);
    });

    document.addEventListener("focusin", function (event) {
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
      root.dataset.helpFocusOpenedAt = String(Date.now());
    });

    document.addEventListener("focusout", function (event) {
      var root = rootFrom(event.target);
      if (root) closeRootWhenIdle(root);
    });

    document.addEventListener("mouseover", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
    });

    document.addEventListener("mouseout", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root || root.contains(event.relatedTarget)) return;
      closeRootWhenIdle(root);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      closeAll(null);
    });
  }

  // ---- FieldHelp (delegated; hover/focus/touch help for form labels) -------
  function installFieldHelp() {
    if (window.__sigraFieldHelpInstalled) return;
    window.__sigraFieldHelpInstalled = true;

    function finePointer() {
      return (
        window.matchMedia &&
        window.matchMedia("(hover: hover) and (pointer: fine)").matches
      );
    }

    function rootFrom(target) {
      return target && target.closest
        ? target.closest("[data-sg-field-help-root]")
        : null;
    }

    function triggerFrom(target) {
      return target && target.closest
        ? target.closest("[data-sg-field-help-trigger]")
        : null;
    }

    function triggerFor(root) {
      return root && root.querySelector("[data-sg-field-help-trigger]");
    }

    function helpFor(root) {
      var trigger = triggerFor(root);
      var id = trigger && trigger.getAttribute("aria-controls");
      return id ? document.getElementById(id) : null;
    }

    function open(root) {
      var trigger = triggerFor(root);
      var help = helpFor(root);
      if (!root || !trigger || !help) return;
      help.hidden = false;
      trigger.setAttribute("aria-expanded", "true");
      root.dataset.helpOpen = "true";
    }

    function close(root) {
      var trigger = triggerFor(root);
      var help = helpFor(root);
      if (!root || !trigger || !help) return;
      help.hidden = true;
      trigger.setAttribute("aria-expanded", "false");
      delete root.dataset.helpOpen;
      delete root.dataset.helpFocusOpenedAt;
    }

    function closeAll(except) {
      document
        .querySelectorAll('[data-sg-field-help-root][data-help-open="true"]')
        .forEach(function (root) {
          if (root !== except) close(root);
        });
    }

    function closeRootWhenIdle(root) {
      window.setTimeout(function () {
        if (!root || root.contains(document.activeElement)) return;
        close(root);
      }, 0);
    }

    document.addEventListener("click", function (event) {
      var trigger = triggerFrom(event.target);
      if (trigger) {
        var root = rootFrom(trigger);
        var alreadyOpen = root && root.dataset.helpOpen === "true";
        var openedByFocusAt = Number(
          (root && root.dataset.helpFocusOpenedAt) || 0,
        );
        var focusJustOpened =
          alreadyOpen &&
          document.activeElement === trigger &&
          Date.now() - openedByFocusAt < 350;
        if (root) delete root.dataset.helpFocusOpenedAt;
        closeAll(root);
        if (alreadyOpen && !focusJustOpened) {
          close(root);
        } else {
          open(root);
        }
        return;
      }

      if (!rootFrom(event.target)) closeAll(null);
    });

    document.addEventListener("focusin", function (event) {
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
      root.dataset.helpFocusOpenedAt = String(Date.now());
    });

    document.addEventListener("focusout", function (event) {
      var root = rootFrom(event.target);
      if (root) closeRootWhenIdle(root);
    });

    document.addEventListener("mouseover", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root) return;
      closeAll(root);
      open(root);
    });

    document.addEventListener("mouseout", function (event) {
      if (!finePointer()) return;
      var root = rootFrom(event.target);
      if (!root || root.contains(event.relatedTarget)) return;
      closeRootWhenIdle(root);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      closeAll(null);
    });
  }

  function pageLoadingKind(event) {
    var detail = (event && event.detail) || {};
    return detail.kind || "redirect";
  }

  function routePageLoadingKind(event) {
    return PAGE_LOADING_KINDS[pageLoadingKind(event)] === true;
  }

  function installPageLoadingIndicator() {
    if (window.__sigraPageLoadingIndicatorInstalled) return;
    window.__sigraPageLoadingIndicatorInstalled = true;

    var activeCount = 0;
    var showTimer = null;
    var hideTimer = null;
    var resetTimer = null;
    var failsafeTimer = null;
    var visibleSince = 0;

    function clearShowTimer() {
      if (showTimer) {
        window.clearTimeout(showTimer);
        showTimer = null;
      }
    }

    function clearHideTimer() {
      if (hideTimer) {
        window.clearTimeout(hideTimer);
        hideTimer = null;
      }
    }

    function clearResetTimer() {
      if (resetTimer) {
        window.clearTimeout(resetTimer);
        resetTimer = null;
      }
    }

    function clearFailsafeTimer() {
      if (failsafeTimer) {
        window.clearTimeout(failsafeTimer);
        failsafeTimer = null;
      }
    }

    function setShellBusy(value) {
      document.querySelectorAll(".sg-admin-shell").forEach(function (shell) {
        if (value) {
          shell.setAttribute("aria-busy", "true");
        } else {
          shell.removeAttribute("aria-busy");
        }
      });
    }

    function clearTimers() {
      clearShowTimer();
      clearHideTimer();
      clearResetTimer();
      clearFailsafeTimer();
    }

    function removeLoadingState() {
      document.documentElement.removeAttribute("data-sg-admin-page-loading");
      setShellBusy(false);
      visibleSince = 0;
    }

    function resetLoadingState() {
      activeCount = 0;
      clearTimers();
      removeLoadingState();
    }

    function completeLoadingState() {
      clearTimers();
      activeCount = 0;
      setShellBusy(false);

      if (
        document.documentElement.getAttribute("data-sg-admin-page-loading") ===
        "true"
      ) {
        document.documentElement.dataset.sgAdminPageLoading = "complete";
        resetTimer = window.setTimeout(
          removeLoadingState,
          PAGE_LOADING_FADE_MS,
        );
      } else {
        removeLoadingState();
      }
    }

    function startFailsafeTimer() {
      clearFailsafeTimer();
      failsafeTimer = window.setTimeout(
        resetLoadingState,
        PAGE_LOADING_MAX_ACTIVE_MS,
      );
    }

    function show() {
      showTimer = null;
      if (activeCount <= 0 || !adminShell()) return;
      visibleSince = Date.now();
      document.documentElement.dataset.sgAdminPageLoading = "true";
      setShellBusy(true);
    }

    function scheduleHide() {
      if (
        !document.documentElement.hasAttribute("data-sg-admin-page-loading")
      ) {
        completeLoadingState();
        return;
      }

      var elapsed = Date.now() - visibleSince;
      var remaining = Math.max(PAGE_LOADING_MIN_VISIBLE_MS - elapsed, 0);
      if (remaining > 0) {
        hideTimer = window.setTimeout(completeLoadingState, remaining);
      } else {
        completeLoadingState();
      }
    }

    window.addEventListener("phx:page-loading-start", function (event) {
      if (pageLoadingKind(event) === "error") {
        resetLoadingState();
        return;
      }
      if (!routePageLoadingKind(event) || !adminShell()) return;

      activeCount += 1;
      clearHideTimer();
      clearResetTimer();
      setShellBusy(true);
      startFailsafeTimer();

      if (
        document.documentElement.getAttribute("data-sg-admin-page-loading") ===
        "complete"
      ) {
        document.documentElement.removeAttribute("data-sg-admin-page-loading");
      }

      if (
        !showTimer &&
        document.documentElement.getAttribute("data-sg-admin-page-loading") !==
          "true"
      ) {
        showTimer = window.setTimeout(show, PAGE_LOADING_DELAY_MS);
      }
    });

    window.addEventListener("phx:page-loading-stop", function (event) {
      if (pageLoadingKind(event) === "error") {
        resetLoadingState();
        return;
      }
      if (!routePageLoadingKind(event)) return;

      activeCount = Math.max(activeCount - 1, 0);
      if (activeCount === 0) {
        scheduleHide();
      }
    });

    window.addEventListener("pagehide", function () {
      resetLoadingState();
    });

    window.addEventListener("pageshow", function (event) {
      if (event.persisted) {
        resetLoadingState();
      }
    });
  }

  // CopyToClipboard is a no-op LiveView hook shell; the real behavior is the
  // delegated document listener installed once below. Registering it as a hook
  // keeps the LiveSocket hooks map symmetric and lets hosts opt in by name.
  var CopyToClipboard = {
    mounted: function () {
      installCopyDelegate();
    },
  };

  function authBrandingColorInput(target) {
    return target && typeof target.closest === "function"
      ? target.closest("[data-sg-auth-branding-color]")
      : null;
  }

  function applyAuthBrandingColor(form, input) {
    var name = input && input.dataset.sgAuthBrandingColor;
    var property = AUTH_BRANDING_COLOR_TOKENS[name];
    var value = String((input && input.value) || "")
      .trim()
      .toLowerCase();
    if (!property || !AUTH_BRANDING_HEX.test(value)) return;

    form
      .querySelectorAll("[data-sg-auth-branding-preview]")
      .forEach(function (preview) {
        preview.style.setProperty(property, value);
      });

    var field = input.closest(".sg-color-field");
    var label =
      field && field.querySelector("[data-sg-auth-branding-color-value]");
    if (label) {
      label.textContent = value;
    }
  }

  function applyAuthBrandingColors(form) {
    form
      .querySelectorAll("[data-sg-auth-branding-color]")
      .forEach(function (input) {
        applyAuthBrandingColor(form, input);
      });
  }

  var AuthBrandingPreview = {
    mounted: function () {
      var self = this;

      this._onInputCapture = function (event) {
        var input = authBrandingColorInput(event.target);
        if (!input || !self.el.contains(input)) return;
        applyAuthBrandingColor(self.el, input);
        event.stopPropagation();
      };
      this._onChange = function (event) {
        var input = authBrandingColorInput(event.target);
        if (!input || !self.el.contains(input)) return;
        applyAuthBrandingColor(self.el, input);
      };

      this.el.addEventListener("input", this._onInputCapture, true);
      this.el.addEventListener("change", this._onChange);
      applyAuthBrandingColors(this.el);
    },

    updated: function () {
      applyAuthBrandingColors(this.el);
    },

    destroyed: function () {
      if (this.el && this._onInputCapture) {
        this.el.removeEventListener("input", this._onInputCapture, true);
      }
      if (this.el && this._onChange) {
        this.el.removeEventListener("change", this._onChange);
      }
    },
  };

  var ThemeSwitch = {
    mounted: function () {
      var self = this;
      this.buttons = Array.prototype.slice.call(
        this.el.querySelectorAll("[data-theme-value]"),
      );
      this._onClick = function (event) {
        var button = event.target.closest("[data-theme-value]");
        if (!button || self.buttons.indexOf(button) === -1) return;
        event.preventDefault();
        self.setTheme(button.dataset.themeValue || "system", true);
      };
      this.el.addEventListener("click", this._onClick);
      this._onKeydown = function (event) {
        self.handleKeydown(event);
      };
      this.el.addEventListener("keydown", this._onKeydown);
      this._onStorage = function (event) {
        if (event.key === THEME_STORAGE_KEY) {
          self.setTheme(storedTheme(), false);
        }
      };
      window.addEventListener("storage", this._onStorage);
      this.setTheme(storedTheme(), false);
    },

    setTheme: function (value, persist) {
      var theme = applyTheme(value);
      if (persist) {
        try {
          if (theme === "system") {
            window.localStorage.removeItem(THEME_STORAGE_KEY);
          } else {
            window.localStorage.setItem(THEME_STORAGE_KEY, theme);
          }
        } catch (err) {}
      }
      this.buttons.forEach(function (button) {
        var selected = button.dataset.themeValue === theme;
        button.setAttribute("aria-checked", selected ? "true" : "false");
        button.setAttribute("tabindex", selected ? "0" : "-1");
        button.classList.toggle("is-active", selected);
      });
    },

    handleKeydown: function (event) {
      var currentIndex = this.buttons.indexOf(document.activeElement);
      if (currentIndex === -1) return;
      var key = event.key;
      var nextIndex = currentIndex;
      if (key === "ArrowRight" || key === "ArrowDown") {
        nextIndex = (currentIndex + 1) % this.buttons.length;
      } else if (key === "ArrowLeft" || key === "ArrowUp") {
        nextIndex =
          (currentIndex - 1 + this.buttons.length) % this.buttons.length;
      } else if (key === "Home") {
        nextIndex = 0;
      } else if (key === "End") {
        nextIndex = this.buttons.length - 1;
      } else if (key === " " || key === "Enter") {
        event.preventDefault();
        this.setTheme(
          document.activeElement.dataset.themeValue || "system",
          true,
        );
        return;
      } else {
        return;
      }
      event.preventDefault();
      var next = this.buttons[nextIndex];
      next.focus();
      this.setTheme(next.dataset.themeValue || "system", true);
    },

    destroyed: function () {
      if (this.el && this._onClick) {
        this.el.removeEventListener("click", this._onClick);
      }
      if (this.el && this._onKeydown) {
        this.el.removeEventListener("keydown", this._onKeydown);
      }
      if (this._onStorage) {
        window.removeEventListener("storage", this._onStorage);
      }
    },
  };

  installCopyDelegate();
  installMetricHelp();
  installFieldHelp();
  installPageLoadingIndicator();

  window.SigraAdminHooks = {
    AuthBrandingPreview: AuthBrandingPreview,
    CmdK: CmdK,
    CopyToClipboard: CopyToClipboard,
    ThemeSwitch: ThemeSwitch,
  };
})();
