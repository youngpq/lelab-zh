import React from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useInstallExtra } from "@/hooks/useInstallExtra";
import { useTranslation } from "react-i18next";
import {
  InstallProgress,
  InstallTitleIcon,
  RestartInstructions,
  installTitle,
} from "./InstallProgress";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  installHint: string;
}

const WandbInstallDialog: React.FC<Props> = ({ open, onOpenChange, installHint }) => {
  const { t } = useTranslation();
  const install = useInstallExtra("system/wandb-extra", open);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="bg-slate-800 border-slate-700 text-white max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-3 text-white">
            <InstallTitleIcon state={install.state} />
            {installTitle(install.state, t("training.wandbNotInstalled"), t)}
          </DialogTitle>
          <DialogDescription className="sr-only">
            {t("training.wandbInstallDescription")}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <InstallProgress
            state={install.state}
            error={install.error}
            logs={install.logs}
            logBoxRef={install.logBoxRef}
            onInstall={install.handleInstall}
            onRetry={install.handleRetry}
            installHint={installHint}
            packageName="wandb"
            idleTitle={t("training.wandbNotInstalled")}
            idleDescription={
              <>
                {t("training.wandbDescriptionBefore")}{" "}
                <code className="px-1 py-0.5 rounded bg-slate-900 text-sky-300">
                  wandb
                </code>{" "}
                {t("training.wandbDescriptionAfter")}
              </>
            }
            doneDescription={<RestartInstructions purpose={t("training.wandbLogging")} />}
          />
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default WandbInstallDialog;
