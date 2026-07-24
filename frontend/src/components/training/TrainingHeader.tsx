import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from "react-i18next";

const TrainingHeader: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useTranslation();
  return (
    <div className="flex items-center justify-between mb-8">
      <div className="flex items-center gap-4 text-3xl">
        <Button
          variant="ghost"
          size="icon"
          onClick={() => navigate('/')}
          className="text-slate-400 hover:bg-slate-800 hover:text-white rounded-lg"
        >
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <h1 className="font-bold text-white text-2xl">{t("training.title")}</h1>
      </div>
    </div>
  );
};

export default TrainingHeader;
