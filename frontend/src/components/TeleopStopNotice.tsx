import { useEffect } from "react";
import { useToast } from "@/hooks/use-toast";
import { useTranslation } from "react-i18next";

const FLAG = "lelab:teleop-stopped";

/**
 * One-time confirmation that teleoperation was stopped during the previous
 * page's unload (a browser navigation, reload, or tab close from the
 * teleoperation page set a sessionStorage flag, since React cleanup can't run
 * in those cases). On the next fresh load we surface a toast wherever the user
 * landed, then clear the flag. In-app navigation away from teleop toasts
 * directly and never sets the flag, so this never double-fires.
 */
const TeleopStopNotice = () => {
  const { toast } = useToast();
  const { t } = useTranslation();

  useEffect(() => {
    let stopped = false;
    try {
      stopped = sessionStorage.getItem(FLAG) === "1";
      if (stopped) sessionStorage.removeItem(FLAG);
    } catch {
      /* sessionStorage unavailable — nothing to show */
    }
    if (stopped) {
      toast({
        title: t("teleoperation.stopped"),
        description: t("teleoperation.disconnected"),
      });
    }
  }, [toast, t]);

  return null;
};

export default TeleopStopNotice;
