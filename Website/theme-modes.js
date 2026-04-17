const modeStorageKey = "essays_theme_mode";
const modeClassPrefix = "mode-";
const availableModes = ["night", "moonlight", "day", "sunny", "rainy", "snowy"];
const keyModeMap = {
  n: "night",
  m: "moonlight",
  d: "day",
  s: "sunny",
  r: "rainy",
  w: "snowy"
};

const modeButtons = document.querySelectorAll("[data-mode]");

const clearModes = () => {
  availableModes.forEach((mode) => {
    document.documentElement.classList.remove(`${modeClassPrefix}${mode}`);
  });
};

const setActiveButton = (mode) => {
  modeButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === mode);
  });
};

const setMode = (mode, persist) => {
  clearModes();
  document.documentElement.classList.add(`${modeClassPrefix}${mode}`);
  setActiveButton(mode);
  if (persist) {
    window.localStorage.setItem(modeStorageKey, mode);
  }
};

const pickInitialMode = () => {
  const stored = window.localStorage.getItem(modeStorageKey);
  if (stored && availableModes.includes(stored)) {
    return stored;
  }
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  return prefersDark ? "night" : "day";
};

modeButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const nextMode = button.dataset.mode;
    if (nextMode && availableModes.includes(nextMode)) {
      setMode(nextMode, true);
    }
  });
});

document.addEventListener("keydown", (event) => {
  if (event.defaultPrevented) {
    return;
  }
  const activeElement = document.activeElement;
  if (activeElement && ["INPUT", "TEXTAREA"].includes(activeElement.tagName)) {
    return;
  }
  const key = event.key.toLowerCase();
  const nextMode = keyModeMap[key];
  if (nextMode) {
    setMode(nextMode, true);
  }
});

setMode(pickInitialMode(), false);
