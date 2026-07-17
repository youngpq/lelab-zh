import React, { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useToast } from "@/hooks/use-toast";
import { Checkbox } from "@/components/ui/checkbox";
import {
  ArrowLeft,
  Upload as UploadIcon,
  Database,
  Tag,
  Eye,
  EyeOff,
  ExternalLink,
  CheckCircle,
  AlertCircle,
  Loader2,
  Trash2,
} from "lucide-react";
import { useApi } from "@/contexts/ApiContext";
import { DatasetSource } from "@/lib/replayApi";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { useTranslation } from "react-i18next";

interface DatasetInfo {
  dataset_repo_id: string;
  single_task: string;
  num_episodes: number;
  saved_episodes?: number;
  session_elapsed_seconds?: number;
  fps?: number;
  total_frames?: number;
  robot_type?: string;
  source?: DatasetSource;
}

interface UploadConfig {
  tags: string[];
  private: boolean;
}

const Upload = () => {
  const { t } = useTranslation();
  const location = useLocation();
  const navigate = useNavigate();
  const { toast } = useToast();
  const { baseUrl, fetchWithHeaders } = useApi();

  // Get initial dataset info from navigation state
  const initialDatasetInfo = location.state?.datasetInfo as DatasetInfo;

  // State for actual dataset info (will be loaded from backend)
  const [datasetInfo, setDatasetInfo] = useState<DatasetInfo | null>(null);
  const [isLoadingDatasetInfo, setIsLoadingDatasetInfo] = useState(true);

  // Upload configuration state
  const [uploadConfig, setUploadConfig] = useState<UploadConfig>({
    tags: ["robotics", "lerobot"],
    private: false,
  });

  const [tagsInput, setTagsInput] = useState(uploadConfig.tags.join(", "));
  const [isUploading, setIsUploading] = useState(false);
  const [uploadSuccess, setUploadSuccess] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  // Load actual dataset information from backend
  React.useEffect(() => {
    const loadDatasetInfo = async () => {
      if (!initialDatasetInfo?.dataset_repo_id) {
        toast({
          title: t("upload.noDatasetInfo"),
          description: t("upload.completeRecordingFirst"),
          variant: "destructive",
        });
        navigate("/");
        return;
      }

      try {
        const response = await fetchWithHeaders(`${baseUrl}/dataset-info`, {
          method: "POST",
          body: JSON.stringify({
            dataset_repo_id: initialDatasetInfo.dataset_repo_id,
          }),
        });

        const data = await response.json();

        if (response.ok && data.success) {
          // Merge the loaded dataset info with any session info we have
          setDatasetInfo({
            ...data,
            saved_episodes: data.num_episodes, // Use actual episodes from dataset
            session_elapsed_seconds:
              initialDatasetInfo.session_elapsed_seconds || 0,
            source: initialDatasetInfo.source,
          });
        } else {
          // Fallback to initial dataset info if backend fails
          toast({
            title: t("upload.warning"),
            description: t("upload.incompleteInfo"),
            variant: "destructive",
          });
          setDatasetInfo(initialDatasetInfo);
        }
      } catch (error) {
        console.error("Error loading dataset info:", error);
        // Fallback to initial dataset info
        toast({
          title: t("upload.warning"),
          description: t("upload.usingSessionData"),
          variant: "destructive",
        });
        setDatasetInfo(initialDatasetInfo);
      } finally {
        setIsLoadingDatasetInfo(false);
      }
    };

    loadDatasetInfo();
  }, [initialDatasetInfo, navigate, toast, t]);

  const openInHubViewer = (repoId: string) => {
    const spacePath = `/spaces/lerobot/visualize_dataset?path=${encodeURIComponent(`/${repoId}`)}`;
    // The user owns/manages the dataset (it appears under their hub
    // listing), so login-redirect always works whether public or
    // private. Avoids passing `private` through navigation state.
    const target = `https://huggingface.co/login?next=${encodeURIComponent(spacePath)}`;
    window.open(target, "_blank", "noopener,noreferrer");
  };

  const formatDuration = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours}h ${minutes}m ${secs}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${secs}s`;
    } else {
      return `${secs}s`;
    }
  };

  const handleUploadToHub = async () => {
    if (!datasetInfo) return;

    setIsUploading(true);
    try {
      // Parse tags from input
      const tags = tagsInput
        .split(",")
        .map((tag) => tag.trim())
        .filter((tag) => tag.length > 0);

      const response = await fetchWithHeaders(`${baseUrl}/upload-dataset`, {
        method: "POST",
        body: JSON.stringify({
          dataset_repo_id: datasetInfo.dataset_repo_id,
          tags,
          private: uploadConfig.private,
        }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        setUploadSuccess(true);
        toast({
          title: t("upload.uploaded"),
          description: t("upload.uploadedDescription"),
        });
      } else {
        const fallback = t("upload.uploadFailedDescription");
        toast({
          title: t("upload.uploadFailed"),
          description: data.docs_url ? (
            <span>
              {data.message || fallback}{" "}
              <a
                href={data.docs_url}
                target="_blank"
                rel="noopener noreferrer"
                className="underline font-medium"
              >
                {t("upload.openSetupGuide")}
              </a>
            </span>
          ) : (
            data.message || fallback
          ),
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error("Error uploading dataset:", error);
      toast({
        title: t("upload.connectionError"),
        description: t("upload.couldNotConnect"),
        variant: "destructive",
      });
    } finally {
      setIsUploading(false);
    }
  };

  const handleSkipUpload = () => {
    toast({
      title: t("upload.skipped"),
      description: t("upload.savedLocally"),
    });
    navigate("/");
  };

  const handleDeleteDataset = async () => {
    if (!datasetInfo) return;
    setIsDeleting(true);
    try {
      const response = await fetchWithHeaders(`${baseUrl}/delete-dataset`, {
        method: "POST",
        body: JSON.stringify({ dataset_repo_id: datasetInfo.dataset_repo_id }),
      });
      const data = await response.json();
      if (response.ok && data.success) {
        toast({
          title: t("upload.deleted"),
          description: t("upload.deletedDescription", { name: datasetInfo.dataset_repo_id }),
        });
        navigate("/");
      } else {
        toast({
          title: t("upload.deleteFailed"),
          description: data.message || t("upload.couldNotDelete"),
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: t("upload.connectionError"),
        description: t("upload.couldNotConnect"),
        variant: "destructive",
      });
    } finally {
      setIsDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  // Show loading state while fetching dataset info
  if (isLoadingDatasetInfo || !datasetInfo) {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p className="text-lg">{t("upload.loading")}</p>
        </div>
      </div>
    );
  }

  const isAlreadyOnHub = datasetInfo.source === "both";

  return (
    <div className="min-h-screen bg-black text-white p-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <Button
              onClick={() => navigate("/")}
              variant="outline"
              className="border-gray-500 hover:border-gray-200 text-gray-300 hover:text-white"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              {t("upload.backToHome")}
            </Button>
            <Button
              onClick={() => setShowDeleteConfirm(true)}
              variant="outline"
              size="icon"
              disabled={isDeleting}
              aria-label={t("upload.deleteFromDisk")}
              className="border-red-500/40 text-red-400 hover:border-red-400 hover:text-red-300 hover:bg-red-500/10"
            >
              <Trash2 className="w-4 h-4" />
            </Button>
          </div>

          <div className="flex items-center gap-3">
            {uploadSuccess ? (
              <CheckCircle className="w-8 h-8 text-green-500" />
            ) : (
              <Database className="w-8 h-8 text-blue-500" />
            )}
            <h1 className="text-3xl font-bold">
              {uploadSuccess ? t("upload.uploadComplete") : t("upload.datasetUpload")}
            </h1>
          </div>
        </div>

        {/* Success State */}
        {uploadSuccess && (
          <div className="bg-green-900/20 border border-green-600 rounded-lg p-6 mb-8">
            <div className="flex items-center gap-3 mb-4">
              <CheckCircle className="w-6 h-6 text-green-500" />
              <h2 className="text-xl font-semibold text-green-400">
                {t("upload.uploaded")}
              </h2>
            </div>
            <p className="text-gray-300 mb-4">
              {t("upload.uploadedDescription")}
            </p>
            <div className="flex flex-col sm:flex-row gap-4">
              <Button
                onClick={() => {
                  const spacePath = `/spaces/lerobot/visualize_dataset?path=${encodeURIComponent(
                    `/${datasetInfo.dataset_repo_id}`
                  )}`;
                  const target = uploadConfig.private
                    ? `https://huggingface.co/login?next=${encodeURIComponent(spacePath)}`
                    : `https://huggingface.co${spacePath}`;
                  window.open(target, "_blank", "noopener,noreferrer");
                }}
                className="bg-blue-500 hover:bg-blue-600 text-white"
              >
                <ExternalLink className="w-4 h-4 mr-2" />
                {t("upload.viewOnHub")}
              </Button>
              <Button
                onClick={() =>
                  navigate("/training", {
                    state: { datasetRepoId: datasetInfo.dataset_repo_id },
                  })
                }
                className="bg-purple-500 hover:bg-purple-600 text-white"
              >
                {t("training.start")}
              </Button>
            </div>
          </div>
        )}

        {/* Upload Form */}
        {!uploadSuccess && (
          <>
            {/* Dataset Summary */}
            <div className="bg-gray-900 rounded-lg p-6 border border-gray-700 mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">
                {t("upload.summary")}
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <div>
                    <span className="text-gray-400">{t("upload.repositoryId")}</span>
                    <p className="text-white font-mono text-lg">
                      {datasetInfo.dataset_repo_id}
                    </p>
                  </div>
                  <div>
                    <span className="text-gray-400">{t("upload.task")}</span>
                    <p className="text-white">{datasetInfo.single_task}</p>
                  </div>
                </div>
                <div className="space-y-3">
                  <div>
                    <span className="text-gray-400">{t("upload.episodesRecorded")}</span>
                    <p className="text-white text-2xl font-bold text-green-400">
                      {datasetInfo.saved_episodes || datasetInfo.num_episodes}
                    </p>
                    {datasetInfo.total_frames && (
                      <p className="text-gray-400 text-sm">
                        {t("upload.totalFrames", { count: datasetInfo.total_frames })}
                      </p>
                    )}
                  </div>
                  <div>
                    <span className="text-gray-400">{t("upload.sessionDuration")}</span>
                    <p className="text-white">
                      {formatDuration(datasetInfo.session_elapsed_seconds || 0)}
                    </p>
                    {datasetInfo.fps && (
                      <p className="text-gray-400 text-sm">
                        {datasetInfo.fps} FPS
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Upload Configuration */}
            {!isAlreadyOnHub && (
              <div className="bg-gray-900 rounded-lg p-6 border border-gray-700 mb-8">
                <h2 className="text-xl font-semibold text-white mb-6">
                  {t("upload.configuration")}
                </h2>

                <div className="space-y-6">
                  {/* Tags */}
                  <div>
                    <Label htmlFor="tags" className="text-gray-300 mb-2 block">
                      {t("upload.tags")}
                    </Label>
                    <Input
                      id="tags"
                      value={tagsInput}
                      onChange={(e) => setTagsInput(e.target.value)}
                      placeholder={t("upload.tagsPlaceholder")}
                      className="bg-gray-800 border-gray-600 text-white"
                    />
                    <p className="text-sm text-gray-500 mt-1">
                      {t("upload.tagsHint")}
                    </p>
                  </div>

                  {/* Privacy Setting */}
                  <div className="flex items-center space-x-3">
                    <Checkbox
                      id="private"
                      checked={uploadConfig.private}
                      onCheckedChange={(checked) =>
                        setUploadConfig({
                          ...uploadConfig,
                          private: checked as boolean,
                        })
                      }
                    />
                    <div className="flex items-center gap-2">
                      {uploadConfig.private ? (
                        <EyeOff className="w-4 h-4 text-gray-400" />
                      ) : (
                        <Eye className="w-4 h-4 text-gray-400" />
                      )}
                      <Label htmlFor="private" className="text-gray-300">
                        {t("upload.makePrivate")}
                      </Label>
                    </div>
                  </div>
                  <p className="text-sm text-gray-500 ml-6">
                    {uploadConfig.private
                      ? t("upload.privateHint")
                      : t("upload.publicHint")}
                  </p>
                </div>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              {isAlreadyOnHub ? (
                <Button
                  onClick={() => openInHubViewer(datasetInfo.dataset_repo_id)}
                  className="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-4 px-8 text-lg"
                >
                  <ExternalLink className="w-5 h-5 mr-2" />
                  {t("upload.viewOnHub")}
                </Button>
              ) : (
                <>
                  <Button
                    onClick={handleUploadToHub}
                    disabled={isUploading}
                    className="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-4 px-8 text-lg"
                  >
                    {isUploading ? (
                      <>
                        <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                        {t("upload.uploading")}
                      </>
                    ) : (
                      <>
                        <UploadIcon className="w-5 h-5 mr-2" />
                        {t("upload.uploadToHub")}
                      </>
                    )}
                  </Button>

                  <Button
                    onClick={handleSkipUpload}
                    disabled={isUploading}
                    variant="outline"
                    className="border-gray-600 text-gray-300 hover:bg-gray-800 hover:text-white py-4 px-8 text-lg"
                  >
                    {t("upload.skipUpload")}
                  </Button>
                </>
              )}
            </div>

            {/* Info Box */}
            {!isAlreadyOnHub && (
              <div className="mt-8 p-4 bg-blue-900/20 border border-blue-600 rounded-lg">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-blue-400 mt-0.5" />
                  <div>
                    <h3 className="font-semibold text-blue-400 mb-2">
                      {t("upload.aboutUpload")}
                    </h3>
                    <ul className="text-sm text-gray-300 space-y-1">
                      <li>
                        • {t("upload.aboutUpload1")}
                      </li>
                      <li>
                        • {t("upload.aboutUpload2")}
                      </li>
                      <li>
                        • {t("upload.aboutUpload3")}
                      </li>
                      <li>
                        • {t("upload.aboutUpload4")}
                      </li>
                    </ul>
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      <AlertDialog open={showDeleteConfirm} onOpenChange={setShowDeleteConfirm}>
        <AlertDialogContent className="bg-gray-900 border-gray-700 text-white">
          <AlertDialogHeader>
            <AlertDialogTitle>{t("upload.deleteQuestion")}</AlertDialogTitle>
            <AlertDialogDescription className="text-gray-400">
              {t("upload.deleteDescription", { name: datasetInfo.dataset_repo_id })}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel className="bg-gray-800 border-gray-700 text-white hover:bg-gray-700">
              {t("upload.keepDataset")}
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteDataset}
              disabled={isDeleting}
              className="bg-red-500 hover:bg-red-600 text-white"
            >
              {isDeleting ? t("upload.deleting") : t("common.delete")}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default Upload;
