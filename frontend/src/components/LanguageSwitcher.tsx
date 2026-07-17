import { Languages } from "lucide-react";
import { useTranslation } from "react-i18next";

const LanguageSwitcher = () => {
  const { i18n, t } = useTranslation();
  const value = i18n.resolvedLanguage === "en" ? "en" : "zh-CN";

  return (
    <label className="flex items-center gap-1.5 text-sm text-gray-300" title={t("language.label")}>
      <Languages className="h-4 w-4" aria-hidden="true" />
      <select
        aria-label={t("language.label")}
        value={value}
        onChange={(event) => void i18n.changeLanguage(event.target.value)}
        className="cursor-pointer bg-transparent text-sm text-gray-200 outline-none hover:text-white"
      >
        <option value="zh-CN" className="bg-gray-900">{t("language.zhCN")}</option>
        <option value="en" className="bg-gray-900">{t("language.en")}</option>
      </select>
    </label>
  );
};

export default LanguageSwitcher;
