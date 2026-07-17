import React from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useInstallExtra } from "@/hooks/useInstallExtra";
import { useTranslation } from "react-i18next";
import {
  InstallProgress,
  InstallTitleIcon,
  RestartInstructions,
  installTitle,
} from "./InstallProgress";

interface Props {
  installHint: string;
}

const TrainingExtraGate: React.FC<Props> = ({ installHint }) => {
  const { t } = useTranslation();
  const install = useInstallExtra("system/training-extra");

  return (
    <div className="max-w-3xl mx-auto">
      <Card className="bg-slate-800/50 border-slate-700 rounded-xl">
        <CardHeader>
          <CardTitle className="flex items-center gap-3 text-white">
            <InstallTitleIcon state={install.state} />
            {installTitle(install.state, t("training.extraNotInstalled"), t)}
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <InstallProgress
            state={install.state}
            error={install.error}
            logs={install.logs}
            logBoxRef={install.logBoxRef}
            onInstall={install.handleInstall}
            onRetry={install.handleRetry}
            installHint={installHint}
            packageName="accelerate"
            idleTitle={t("training.extraNotInstalled")}
            idleDescription={
              <>
                {t("training.extraDescriptionBefore")}{" "}
                <code className="px-1 py-0.5 rounded bg-slate-900 text-sky-300">
                  accelerate
                </code>{" "}
                {t("training.extraDescriptionAfter")}
              </>
            }
            doneDescription={<RestartInstructions purpose={t("training.training")} />}
          />
        </CardContent>
      </Card>
    </div>
  );
};

export default TrainingExtraGate;
