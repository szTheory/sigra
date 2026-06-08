// Plain JS mirror is committed into priv/static/assets/js/app.js.
(() => {
  const COOKIE_NAME = "sigra_demo_brand";
  const THEME_COOKIE_NAME = "sigra_demo_theme";
  const STORAGE_KEY = "sigra.demo.brand";
  const THEME_STORAGE_KEY = "sigra.demo.theme";
  const THEMES = ["system", "light", "dark"];

  const textKeys = ["product_name", "email_from_name", "email_from_address"];

  const sigraStyleTokens = [
    ["--sigra-auth-accent", "accent_color"],
    ["--sigra-auth-on-accent", "accent_foreground"],
    ["--sigra-auth-bg", "background_color"],
    ["--sigra-auth-surface", "surface_color"],
    ["--sigra-auth-text", "text_color"],
    ["--sigra-auth-muted", "muted_color"],
    ["--sigra-auth-border", "border_color"],
  ];

  const vaultrStyleTokens = [
    ["--vt-color-primary", "accent_color"],
    ["--vt-color-primary-strong", "accent_color"],
    ["--vt-color-accent", "accent_color"],
    ["--vt-color-on-primary", "accent_foreground"],
    ["--vt-color-page", "background_color"],
    ["--vt-color-panel", "surface_color"],
    ["--vt-color-panel-alt", "background_color"],
    ["--vt-color-ink", "text_color"],
    ["--vt-color-muted", "muted_color"],
    ["--vt-color-line", "border_color"],
    ["--vt-color-line-strong", "border_color"],
  ];

  function normalizeTheme(value) {
    const normalized = String(value || "")
      .trim()
      .toLowerCase();
    return THEMES.includes(normalized) ? normalized : null;
  }

  function readBrandState() {
    const host = document.querySelector("[data-demo-brand-presets]");

    if (!host) {
      return null;
    }

    try {
      const presets = JSON.parse(host.dataset.demoBrandPresets || "[]");
      const defaultId = host.dataset.demoBrandDefault || presets[0]?.id;
      const defaultTheme = normalizeTheme(host.dataset.demoBrandThemeDefault);

      return {
        presets,
        defaultId,
        defaultTheme,
        currentBrandId: defaultId,
        currentTheme: defaultTheme,
        themeLocked: false,
      };
    } catch (_error) {
      return null;
    }
  }

  function readCookie(name) {
    const cookie = document.cookie
      .split(";")
      .map((cookie) => cookie.trim())
      .find((cookie) => cookie.startsWith(`${name}=`));

    if (!cookie) {
      return null;
    }

    return decodeURIComponent(cookie.split("=").slice(1).join("="));
  }

  function storedBrandId() {
    const cookieBrandId = readCookie(COOKIE_NAME);

    if (cookieBrandId) {
      return cookieBrandId;
    }

    try {
      return window.localStorage?.getItem(STORAGE_KEY);
    } catch (_error) {
      return null;
    }
  }

  function storedTheme() {
    const cookieTheme = normalizeTheme(readCookie(THEME_COOKIE_NAME));

    if (cookieTheme) {
      return cookieTheme;
    }

    try {
      return normalizeTheme(window.localStorage?.getItem(THEME_STORAGE_KEY));
    } catch (_error) {
      return null;
    }
  }

  function storeBrandId(id) {
    document.cookie = `${COOKIE_NAME}=${encodeURIComponent(id)}; Max-Age=31536000; Path=/; SameSite=Lax`;

    try {
      window.localStorage?.setItem(STORAGE_KEY, id);
    } catch (_error) {
      return;
    }
  }

  function storeTheme(theme) {
    document.cookie = `${THEME_COOKIE_NAME}=${encodeURIComponent(theme)}; Max-Age=31536000; Path=/; SameSite=Lax`;

    try {
      window.localStorage?.setItem(THEME_STORAGE_KEY, theme);
    } catch (_error) {
      return;
    }
  }

  function findPreset(state, id) {
    return (
      state.presets.find((preset) => preset.id === id) ||
      state.presets.find((preset) => preset.id === state.defaultId) ||
      state.presets[0]
    );
  }

  function defaultThemeForPreset(state, preset) {
    return (
      normalizeTheme(preset?.default_theme) ||
      normalizeTheme(preset?.profile?.theme) ||
      state.defaultTheme ||
      "system"
    );
  }

  function resolveTheme(state, preset, value) {
    return normalizeTheme(value) || defaultThemeForPreset(state, preset);
  }

  function activeVariant(theme) {
    if (theme === "dark") {
      return "dark";
    }

    if (
      theme === "system" &&
      window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches
    ) {
      return "dark";
    }

    return "light";
  }

  function profileForTheme(preset, theme) {
    const profiles = preset.profiles || {};
    const variant = activeVariant(theme);
    return (
      profiles[variant] ||
      preset.profile ||
      profiles.light ||
      profiles.dark ||
      {}
    );
  }

  function variantProperty(property, variant) {
    if (property.startsWith("--sigra-auth-")) {
      return `--sigra-auth-${variant}-${property.slice("--sigra-auth-".length)}`;
    }

    if (property.startsWith("--vt-color-")) {
      return `--vt-${variant}-color-${property.slice("--vt-color-".length)}`;
    }

    return property;
  }

  function setText(root, key, value) {
    root
      .querySelectorAll(`[data-demo-brand-text="${key}"]`)
      .forEach((element) => {
        element.textContent = value || "";
      });
  }

  function applyVariantStyles(root, preset, theme, tokens) {
    const profiles = preset.profiles || {};

    for (const [property] of tokens) {
      root.style.removeProperty(property);
    }

    for (const variant of ["light", "dark"]) {
      const profile = profiles[variant] || preset.profile || {};

      for (const [property, key] of tokens) {
        if (profile[key]) {
          root.style.setProperty(
            variantProperty(property, variant),
            profile[key],
          );
        }
      }
    }

    if (tokens === vaultrStyleTokens) {
      root.style.setProperty(
        "--vt-light-color-accent-soft",
        "color-mix(in oklab, var(--vt-light-color-accent) 18%, var(--vt-light-color-panel))",
      );
      root.style.setProperty(
        "--vt-dark-color-accent-soft",
        "color-mix(in oklab, var(--vt-dark-color-accent) 26%, transparent)",
      );
    }

    root.dataset.theme = theme;
  }

  function applyBrandAssets(profile) {
    const productName = profile.product_name || "";
    const logoUrl = profile.logo_url || "";
    const logoAlt =
      profile.logo_alt || (productName ? `${productName} logo` : "Brand logo");

    document.querySelectorAll("[data-demo-brand-logo]").forEach((element) => {
      if (logoUrl) {
        element.setAttribute("src", logoUrl);
        element.setAttribute("alt", logoAlt);
        element.hidden = false;
      } else {
        element.removeAttribute("src");
        element.setAttribute("alt", "");
        element.hidden = true;
      }
    });

    document
      .querySelectorAll("[data-demo-brand-fallback-mark]")
      .forEach((element) => {
        element.hidden = Boolean(logoUrl);
      });

    document
      .querySelectorAll("[data-demo-brand-initial]")
      .forEach((element) => {
        element.textContent =
          productName.trim().slice(0, 1).toUpperCase() || "?";
        element.hidden = Boolean(logoUrl);
      });
  }

  function applyPreset(state, id, options = {}) {
    const preset = findPreset(state, id);

    if (!preset) {
      return;
    }

    const theme = resolveTheme(state, preset, options.theme);
    const profile = profileForTheme(preset, theme);

    if (options.persistBrand) {
      storeBrandId(preset.id);
    }

    if (options.persistTheme) {
      storeTheme(theme);
    }

    state.currentBrandId = preset.id;
    state.currentTheme = theme;
    state.themeLocked = state.themeLocked || Boolean(options.persistTheme);

    document.documentElement.dataset.sigraDemoBrand = preset.id;
    document.documentElement.dataset.sigraDemoTheme = theme;

    for (const key of textKeys) {
      setText(document, key, profile[key]);
    }

    document
      .querySelectorAll("[data-demo-brand-description]")
      .forEach((element) => {
        element.textContent = preset.description || "";
      });

    document
      .querySelectorAll("[data-demo-brand-subject]")
      .forEach((element) => {
        element.textContent = preset.email_subject || "";
      });

    applyBrandAssets(profile);

    document
      .querySelectorAll("[data-demo-auth-preview], [data-demo-email-preview]")
      .forEach((element) => {
        applyVariantStyles(element, preset, theme, sigraStyleTokens);
      });

    document
      .querySelectorAll("[data-demo-brand-surface]")
      .forEach((element) => {
        applyVariantStyles(element, preset, theme, vaultrStyleTokens);
      });

    document.querySelectorAll("[data-demo-brand-select]").forEach((select) => {
      select.value = preset.id;
    });

    document.querySelectorAll("[data-demo-brand-theme]").forEach((input) => {
      input.checked = input.value === theme;
    });
  }

  function initDemoBranding() {
    const state = readBrandState();

    if (!state || state.presets.length === 0) {
      return;
    }

    const storedId = storedBrandId();
    const theme = storedTheme();
    state.themeLocked = Boolean(theme);
    applyPreset(state, storedId || state.defaultId, {
      theme,
      persistBrand: Boolean(storedId),
    });

    document.addEventListener("change", (event) => {
      const select = event.target?.closest?.("[data-demo-brand-select]");

      if (select) {
        applyPreset(state, select.value, {
          theme: state.themeLocked ? state.currentTheme : null,
          persistBrand: true,
        });
        return;
      }

      const themeInput = event.target?.closest?.("[data-demo-brand-theme]");

      if (themeInput) {
        state.themeLocked = true;
        applyPreset(state, state.currentBrandId, {
          theme: themeInput.value,
          persistTheme: true,
        });
      }
    });

    if (window.matchMedia) {
      const media = window.matchMedia("(prefers-color-scheme: dark)");
      const refreshSystemAssets = () => {
        if (state.currentTheme === "system") {
          applyPreset(state, state.currentBrandId, { theme: "system" });
        }
      };

      if (media.addEventListener) {
        media.addEventListener("change", refreshSystemAssets);
      } else if (media.addListener) {
        media.addListener(refreshSystemAssets);
      }
    }
  }

  document.addEventListener("DOMContentLoaded", initDemoBranding);
})();
