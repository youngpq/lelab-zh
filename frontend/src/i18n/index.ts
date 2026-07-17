import i18n from "i18next";
import { initReactI18next } from "react-i18next";

import en from "./locales/en.json";
import zhCN from "./locales/zh-CN.json";

export const LANGUAGE_STORAGE_KEY = "lelab:language";
export const SUPPORTED_LANGUAGES = ["zh-CN", "en"] as const;

export type SupportedLanguage = (typeof SUPPORTED_LANGUAGES)[number];

const storedLanguage = localStorage.getItem(LANGUAGE_STORAGE_KEY);
const initialLanguage: SupportedLanguage = SUPPORTED_LANGUAGES.includes(
  storedLanguage as SupportedLanguage,
)
  ? (storedLanguage as SupportedLanguage)
  : "zh-CN";

i18n.use(initReactI18next).init({
  resources: {
    en: { translation: en },
    "zh-CN": { translation: zhCN },
  },
  lng: initialLanguage,
  fallbackLng: "en",
  supportedLngs: SUPPORTED_LANGUAGES,
  interpolation: { escapeValue: false },
  react: { useSuspense: false },
});

const syncDocumentLanguage = (language: string) => {
  document.documentElement.lang = language;
  document.title = i18n.t("meta.title");
  document
    .querySelector('meta[name="description"]')
    ?.setAttribute("content", i18n.t("meta.description"));
};

i18n.on("languageChanged", (language) => {
  localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
  syncDocumentLanguage(language);
});

syncDocumentLanguage(initialLanguage);

export default i18n;
