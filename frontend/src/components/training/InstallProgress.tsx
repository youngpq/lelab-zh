import React from "react";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { useTranslation } from "react-i18next";
import {
  AlertTriangle,
  CheckCircle2,
  Copy,
  Loader2,
  XCircle,
} from "lucide-react";
import type { InstallState, LogEntry } from "@/hooks/useInstallExtra";

interface InstallProgressProps {
  state: InstallState;
  error: string | null;
  logs: LogEntry[];
  logBoxRef: React.RefObject<HTMLDivElement>;
  onInstall: () => void;
  onRetry: () => void;

  installHint: string;
  packageName: string;
  idleTitle: string;
  idleDescription: React.ReactNode;
  doneDescription: React.ReactNode;
}

export function installTitle(
  state: InstallState,
  idleTitle: string,
  t: (key: string) => string,
): string {
  switch (state) {
    case "done":
      return t("training.installComplete");
    case "error":
      return t("training.installFailedTitle");
    case "installing":
      return t("training.installing");
    default:
      return idleTitle;
  }
}

export function InstallTitleIcon({ state }: { state: InstallState }) {
  if (state === "done") return <CheckCircle2 className="w-6 h-6 text-green-400" />;
  if (state === "error") return <XCircle className="w-6 h-6 text-red-400" />;
  if (state === "installing")
    return <Loader2 className="w-6 h-6 text-sky-400 animate-spin" />;
  return <AlertTriangle className="w-6 h-6 text-amber-400" />;
}

export const InstallProgress: React.FC<InstallProgressProps> = ({
  state,
  error,
  logs,
  logBoxRef,
  onInstall,
  onRetry,
  installHint,
  packageName,
  idleDescription,
  doneDescription,
}) => {
  const { toast } = useToast();
  const { t } = useTranslation();

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(installHint);
      toast({ title: t("training.installCopied"), description: installHint });
    } catch {
      toast({
        title: t("training.installCopyFailed"),
        description: t("training.installCopyManually"),
        variant: "destructive",
      });
    }
  };

  return (
    <>
      {state === "idle" && (
        <>
          <p className="text-slate-300">{idleDescription}</p>
          <div className="flex items-center gap-2">
            <code className="flex-1 bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-200 font-mono">
              {installHint}
            </code>
            <Button
              variant="ghost"
              size="icon"
              onClick={handleCopy}
              className="text-slate-400 hover:text-white"
              aria-label={t("training.copyInstallCommand")}
            >
              <Copy className="w-4 h-4" />
            </Button>
          </div>
          <Button
            onClick={onInstall}
            className="bg-green-500 hover:bg-green-600 text-white font-semibold"
          >
            {t("training.installNow")}
          </Button>
        </>
      )}

      {state === "installing" && (
        <p className="text-slate-300">
          {t("training.installing")} {" "}
          <code className="px-1 py-0.5 rounded bg-slate-900 text-sky-300">
            {packageName}
          </code>
          . {t("training.installDurationHint")}
        </p>
      )}

      {state === "done" && (
        <div className="space-y-3 text-slate-300">{doneDescription}</div>
      )}

      {state === "error" && (
        <>
          <p className="text-red-300">{error || t("training.installFailed")}</p>
          <Button
            onClick={onRetry}
            className="bg-slate-700 hover:bg-slate-600 text-white"
          >
            {t("common.retry")}
          </Button>
        </>
      )}

      {state === "error" && logs.length > 0 && (
        <div
          ref={logBoxRef}
          className="bg-slate-900 rounded-lg p-3 h-48 overflow-y-auto font-mono text-xs border border-slate-700 text-slate-300 whitespace-pre-wrap break-words"
        >
          {logs.map((log, idx) => (
            <div key={idx}>{log.message}</div>
          ))}
        </div>
      )}
    </>
  );
};

export const RestartInstructions: React.FC<{ purpose: string }> = ({ purpose }) => {
  const { t } = useTranslation();
  return <>
    <p>
      {t("training.restartIntro", { purpose })}{" "}
      <code className="px-1 py-0.5 rounded bg-slate-900 text-sky-300">
        lelab
      </code>{" "}
      {t("training.restartToEnable", { purpose })}
    </p>
    <ol className="list-decimal list-inside space-y-2 pl-1">
      <li>
        {t("training.restartStepOne")}{" "}
        <kbd className="px-1.5 py-0.5 rounded bg-slate-900 border border-slate-600 text-xs font-mono text-slate-200">
          Ctrl+C
        </kbd>{" "}
        {t("training.restartTerminal")}{" "}
        <code className="px-1 py-0.5 rounded bg-slate-900 text-sky-300">
          lelab
        </code>
        {t("common.period")}
      </li>
      <li>
        {t("training.restartStepTwo")}{" "}
        <code className="px-1 py-0.5 rounded bg-slate-900 text-sky-300">
          lelab
        </code>{" "}
        {t("training.restartAgain")}
      </li>
    </ol>
  </>;
};
