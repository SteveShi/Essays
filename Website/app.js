const contentRoot = "/content";
const state = {
  locale: "en"
};

const elements = {
  metaDescription: document.querySelector("meta[name='description']"),
  brand: document.querySelector("[data-bind='brand']"),
  navDownload: document.querySelector("[data-bind='navDownload']"),
  navGitHub: document.querySelector("[data-bind='navGitHub']"),
  heroHeadline: document.querySelector("[data-bind='heroHeadline']"),
  heroSubhead: document.querySelector("[data-bind='heroSubhead']"),
  heroPrimary: document.querySelector("[data-bind='heroPrimary']"),
  heroSecondary: document.querySelector("[data-bind='heroSecondary']"),
  storyTitle: document.querySelector("[data-bind='storyTitle']"),
  storyLead: document.querySelector("[data-bind='storyLead']"),
  storyList: document.querySelector("[data-bind='storyList']"),
  featuresTitle: document.querySelector("[data-bind='featuresTitle']"),
  featuresList: document.querySelector("[data-bind='featuresList']"),
  assistantTitle: document.querySelector("[data-bind='assistantTitle']"),
  assistantBody: document.querySelector("[data-bind='assistantBody']"),
  assistantList: document.querySelector("[data-bind='assistantList']"),
  downloadTitle: document.querySelector("[data-bind='downloadTitle']"),
  downloadBody: document.querySelector("[data-bind='downloadBody']"),
  downloadCta: document.querySelector("[data-bind='downloadCta']"),
  footerCopyright: document.querySelector("[data-bind='footerCopyright']"),
  langToggle: document.querySelector("[data-bind='langToggle']"),
  linkRelease: document.querySelector("[data-bind='linkRelease']"),
  linkGitHub: document.querySelector("[data-bind='linkGitHub']"),
  linkReleaseNav: document.querySelector("[data-bind='linkReleaseNav']"),
  linkGitHubNav: document.querySelector("[data-bind='linkGitHubNav']"),
  linkReleaseDownload: document.querySelector("[data-bind='linkReleaseDownload']")
};


const pickInitialLocale = () => {
  const forced = document.documentElement.dataset.defaultLocale;
  if (forced) {
    return forced;
  }
  const stored = window.localStorage.getItem("essays_locale");
  if (stored) {
    return stored;
  }
  const preferred = navigator.language || "en";
  return preferred.startsWith("zh") ? "zh-Hans" : "en";
};

const setLocale = (locale) => {
  state.locale = locale;
  window.localStorage.setItem("essays_locale", locale);
  languageButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.lang === locale);
  });
};

const renderCardList = (listElement, items) => {
  listElement.innerHTML = "";
  items.forEach((item) => {
    const card = document.createElement("div");
    card.className = "feature";

    const title = document.createElement("h3");
    title.textContent = item.title;

    card.appendChild(title);
    if (item.body) {
      const body = document.createElement("p");
      body.textContent = item.body;
      card.appendChild(body);
    }
    listElement.appendChild(card);
  });
};

const renderStoryList = (listElement, items) => {
  listElement.innerHTML = "";
  items.forEach((item) => {
    const section = document.createElement("div");
    section.className = "story-item";

    const media = document.createElement("div");
    media.className = "story-media";
    const image = document.createElement("img");
    image.src = item.image;
    image.alt = item.alt;
    image.loading = "lazy";
    media.appendChild(image);

    const text = document.createElement("div");
    text.className = "story-text";
    const title = document.createElement("h3");
    title.textContent = item.title;
    const body = document.createElement("p");
    body.textContent = item.body;
    text.appendChild(title);
    text.appendChild(body);

    section.appendChild(media);
    section.appendChild(text);
    listElement.appendChild(section);
  });
};

const applyContent = (content) => {
  document.documentElement.lang = content.meta.lang;
  document.title = content.meta.title;
  if (elements.metaDescription) {
    elements.metaDescription.setAttribute("content", content.meta.description);
  }

  elements.brand.textContent = content.meta.title;
  elements.navDownload.textContent = content.nav.download;
  elements.navGitHub.textContent = content.nav.github;

  elements.heroHeadline.textContent = content.hero.headline;
  elements.heroSubhead.textContent = content.hero.subhead;
  elements.heroPrimary.textContent = content.hero.primaryCta;
  elements.heroSecondary.textContent = content.hero.secondaryCta;

  elements.storyTitle.textContent = content.story.title;
  elements.storyLead.textContent = content.story.lead;
  renderStoryList(elements.storyList, content.story.items);

  elements.featuresTitle.textContent = content.features.title;
  renderCardList(elements.featuresList, content.features.items);

  elements.assistantTitle.textContent = content.assistant.title;
  elements.assistantBody.textContent = content.assistant.body;
  renderCardList(elements.assistantList, content.assistant.items);

  elements.downloadTitle.textContent = content.download.title;
  elements.downloadBody.textContent = content.download.body;
  elements.downloadCta.textContent = content.download.cta;

  elements.footerCopyright.textContent = content.footer.copyright;

  if (elements.langToggle) {
    const nextLocale = state.locale === "en" ? "zh-Hans" : "en";
    const nextLabel =
      state.locale === "en"
        ? content.language.toggle.chinese
        : content.language.toggle.english;
    elements.langToggle.textContent = nextLabel;
    elements.langToggle.setAttribute("aria-label", content.language.label);
    elements.langToggle.dataset.lang = nextLocale;
  }

  elements.linkRelease.href = content.links.releases;
  elements.linkGitHub.href = content.links.github;
  elements.linkReleaseNav.href = content.links.releases;
  elements.linkGitHubNav.href = content.links.github;
  elements.linkReleaseDownload.href = content.links.releases;
};

const loadContent = async () => {
  const response = await fetch(`${contentRoot}/${state.locale}.json`);
  if (!response.ok) {
    throw new Error();
  }
  return response.json();
};

const start = async () => {
  setLocale(pickInitialLocale());
  const content = await loadContent();
  applyContent(content);
};

if (elements.langToggle) {
  elements.langToggle.addEventListener("click", async () => {
    const nextLocale = elements.langToggle.dataset.lang;
    setLocale(nextLocale);
    const content = await loadContent();
    applyContent(content);
    const targetPath =
      content && content.language && content.language.paths
        ? content.language.paths[nextLocale]
        : null;
    if (targetPath && window.location.pathname !== targetPath) {
      window.location.pathname = targetPath;
    }
  });
}

start();
