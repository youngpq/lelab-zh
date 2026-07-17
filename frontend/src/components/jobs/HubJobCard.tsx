import React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { HubJob } from "@/lib/jobsApi";
import {
  ExternalLink,
  AlertTriangle,
  CheckCircle2,
  Loader2,
  XCircle,
  Clock,
  HelpCircle,
} from "lucide-react";
import { useTranslation } from "react-i18next";

interface Props {
  job: HubJob;
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

interface StagePresentation {
  label: string;
  color: string;
  Icon: React.ComponentType<{ className?: string }>;
  spin?: boolean;
}

const stagePresentation: Record<string, StagePresentation> = {
  RUNNING: { label: "Running", color: "text-green-400", Icon: Loader2, spin: true },
  QUEUED: { label: "Queued", color: "text-amber-400", Icon: Clock },
  SCHEDULING: { label: "Scheduling", color: "text-amber-400", Icon: Clock },
  COMPLETED: { label: "Done", color: "text-slate-400", Icon: CheckCircle2 },
  FAILED: { label: "Failed", color: "text-red-400", Icon: XCircle },
  // HF API uses "CANCELED" (single L); accept both spellings.
  CANCELED: { label: "Cancelled", color: "text-amber-400", Icon: AlertTriangle },
  CANCELLED: { label: "Cancelled", color: "text-amber-400", Icon: AlertTriangle },
};

const HubJobCard: React.FC<Props> = ({ job }) => {
  const { t } = useTranslation();
  const stage = job.status?.stage?.toUpperCase() ?? "";
  const present: StagePresentation = stagePresentation[stage] ?? {
    label: stage || t("common.unknown"),
    color: "text-slate-400",
    Icon: HelpCircle,
  };
  const Icon = present.Icon;
  const title =
    job.docker_image ?? job.space_id ?? `Job ${job.id.slice(0, 12)}…`;

  return (
    <Card
      onClick={() => window.open(job.url, "_blank", "noopener,noreferrer")}
      className="bg-slate-800/50 border-slate-700 rounded-xl cursor-pointer hover:border-slate-500 transition-colors"
    >
      <CardContent className="p-4 space-y-3">
        <div className="flex items-start justify-between gap-2">
          <div className={`flex items-center gap-1.5 text-xs font-semibold ${present.color}`}>
            <Icon className={`w-3.5 h-3.5 ${present.spin ? "animate-spin" : ""}`} />
            {present.label}
          </div>
          <Button
            variant="ghost"
            size="icon"
            asChild
            className="h-7 w-7 text-slate-400 hover:text-white"
            aria-label={t("jobs.viewOnHub")}
          >
            <a
              href={job.url}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
            >
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </Button>
        </div>
        <div>
          <div className="text-white font-semibold truncate" title={title}>
            {title}
          </div>
          <div className="text-xs text-slate-400 truncate">
            {job.flavor ?? "—"} · {relativeTime(job.created_at, t)}
            {job.owner ? ` · ${job.owner}` : ""}
          </div>
        </div>
        {job.status?.message ? (
          <div className="text-xs text-slate-500 truncate" title={job.status.message}>
            {job.status.message}
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
};

export default HubJobCard;
