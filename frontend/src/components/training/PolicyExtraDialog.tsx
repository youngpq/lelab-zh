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
  policyType: string;
  packageName: string; // the probed module, e.g. "transformers"
  installTarget: string; // e.g. "lerobot[smolvla]"
  installHint: string; // e.g. "pip install 'lerobot[smolvla]'"
}

// Some policies (smolvla, pi0, pi0_fast, diffusion) need an optional LeRobot
// extra. This catches the missing package before training starts and offers a
// one-click install, instead of the run dying with a buried ImportError.
const PolicyExtraDialog: React.FC<Props> = ({
  open,
  onOpenChange,
  policyType,
  packageName,
  installTarget,
  installHint,
}) => {
  const { t } = useTranslation();
  const install = useInstallExtra(`system/policy-extra/${policyType}`, open);
  const title = t("training.policyNeedsExtra", { policy: policyType.toUpperCase() });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="bg-slate-800 border-slate-700 text-white max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-3 text-white">
            <InstallTitleIcon state={install.state} />
            {installTitle(install.state, title, t)}
          </DialogTitle>
          <DialogDescription className="sr-only">
            {t("training.policyInstallDescription", { target: installTarget, policy: policyType })}
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
            packageName={installTarget}
            idleTitle={title}
            idleDescription={
              <>
                {t("training.policyDescription", {
                  policy: policyType,
                  package: packageName,
                  target: installTarget,
                })}
              </>
            }
            doneDescription={<RestartInstructions purpose={t("training.policyTraining", { policy: policyType })} />}
          />
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default PolicyExtraDialog;
