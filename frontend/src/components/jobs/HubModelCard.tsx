import React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { HubModel } from "@/lib/jobsApi";
import { ExternalLink, Lock, Upload } from "lucide-react";
import { useTranslation } from "react-i18next";

interface Props {
  model: HubModel;
}

function relativeTime(iso: string | null, t: (key: string, options?: Record<string, unknown>) => string): string {
  if (!iso) return "—";
  const timestamp = Date.parse(iso);
  if (Number.isNaN(timestamp)) return "—";
  const diff = Math.max(0, (Date.now() - timestamp) / 1000);
  if (diff < 60) return t("jobs.secondsAgo", { count: Math.floor(diff) });
  if (diff < 3600) return t("jobs.minutesAgo", { count: Math.floor(diff / 60) });
  if (diff < 86400) return t("jobs.hoursAgo", { count: Math.floor(diff / 3600) });
  return t("jobs.daysAgo", { count: Math.floor(diff / 86400) });
}

const HubModelCard: React.FC<Props> = ({ model }) => {
  const { t } = useTranslation();
  const url = `https://huggingface.co/${model.repo_id}`;
  const shortName = model.repo_id.includes("/")
    ? model.repo_id.split("/").slice(1).join("/")
    : model.repo_id;

  return (
    <Card
      onClick={() => window.open(url, "_blank", "noopener,noreferrer")}
      className="bg-slate-800/50 border-slate-700 rounded-xl cursor-pointer hover:border-slate-500 transition-colors"
    >
      <CardContent className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-1.5 text-xs font-semibold text-sky-400">
            <Upload className="w-3.5 h-3.5" />
            {t("jobs.uploaded")}
          </div>
          <Button
            variant="ghost"
            size="icon"
            asChild
            className="h-7 w-7 text-slate-400 hover:text-white"
            aria-label={t("jobs.viewOnHub")}
          >
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
            >
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </Button>
        </div>
        <div>
          <div
            className="text-white font-semibold truncate flex items-center gap-1.5"
            title={model.repo_id}
          >
            {model.private ? (
              <Lock className="w-3.5 h-3.5 text-slate-400 shrink-0" />
            ) : null}
            <span className="truncate">{shortName}</span>
          </div>
          <div className="text-xs text-slate-400 truncate" title={model.repo_id}>
            {model.repo_id} · {t("jobs.updatedAgo", { time: relativeTime(model.last_modified, t) })}
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default HubModelCard;
