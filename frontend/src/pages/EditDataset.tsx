
import React from 'react';
import { useTranslation } from "react-i18next";

const EditDataset = () => {
  const { t } = useTranslation();
  return (
    <div className="min-h-screen bg-black text-white flex flex-col items-center justify-center p-4">
      <h1 className="text-5xl font-bold tracking-tight">{t("common.editDataset")}</h1>
      <p className="mt-4 text-xl text-gray-400">
        {t("common.underConstruction")}
      </p>
    </div>
  );
};

export default EditDataset;
