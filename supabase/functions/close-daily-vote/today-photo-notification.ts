import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  type FcmNotification,
  type FcmSendResult,
  getFcmAccessToken,
  sendFcmMessage,
} from "../_shared/fcm.ts";
import { getActiveGroupMemberFcmTokens } from "../_shared/notification-targets.ts";
import { createPhotoThumbnailUrl } from "../_shared/photo-thumbnail.ts";

const TITLE = "今日の1枚が現像されました";
const BODY = "アプリを開いて確認しよう";

export interface TodayPhotoNotificationResult {
  sentCount: number;
  failedCount: number;
}

export type TodayPhotoNotifier = (
  groupId: string,
  winnerPhotoId: string,
) => Promise<TodayPhotoNotificationResult>;

export interface TodayPhotoNotificationDependencies {
  getTokens: typeof getActiveGroupMemberFcmTokens;
  createThumbnailUrl: typeof createPhotoThumbnailUrl;
  getAccessToken: typeof getFcmAccessToken;
  sendMessage: (
    accessToken: string,
    projectId: string,
    token: string,
    notification: FcmNotification,
  ) => Promise<FcmSendResult>;
  logError: (message: string) => void;
}

const defaultDependencies: TodayPhotoNotificationDependencies = {
  getTokens: getActiveGroupMemberFcmTokens,
  createThumbnailUrl: createPhotoThumbnailUrl,
  getAccessToken: getFcmAccessToken,
  sendMessage: sendFcmMessage,
  logError: console.error,
};

interface FirebaseServiceAccount {
  project_id: string;
}

function parseProjectId(serviceAccountJson: string): string {
  const value = JSON.parse(serviceAccountJson) as Partial<FirebaseServiceAccount>;
  if (typeof value.project_id !== "string" || value.project_id.length === 0) {
    throw new Error("FIREBASE_SERVICE_ACCOUNTにproject_idがありません");
  }
  return value.project_id;
}

async function getOriginalStoragePath(
  supabase: SupabaseClient,
  photoId: string,
): Promise<string> {
  const { data, error } = await supabase
    .from("photos")
    .select("original_storage_path")
    .eq("id", photoId)
    .single();
  if (error || !data) {
    throw new Error(`当選写真の取得に失敗しました: ${error?.message ?? "not found"}`);
  }
  return data.original_storage_path as string;
}

export function createTodayPhotoNotifier(
  supabase: SupabaseClient,
  serviceAccountJson: string,
  dependencies: TodayPhotoNotificationDependencies = defaultDependencies,
): TodayPhotoNotifier {
  let credentialsPromise: Promise<{ accessToken: string; projectId: string }> | undefined;

  function getCredentials(): Promise<{ accessToken: string; projectId: string }> {
    credentialsPromise ??= (async () => {
      const projectId = parseProjectId(serviceAccountJson);
      const accessToken = await dependencies.getAccessToken(serviceAccountJson);
      return { accessToken, projectId };
    })();
    return credentialsPromise;
  }

  return async (groupId, winnerPhotoId) => {
    const tokens = await dependencies.getTokens(supabase, groupId);
    if (tokens.length === 0) return { sentCount: 0, failedCount: 0 };

    const storagePath = await getOriginalStoragePath(supabase, winnerPhotoId);
    const [imageUrl, credentials] = await Promise.all([
      dependencies.createThumbnailUrl(supabase, storagePath),
      getCredentials(),
    ]);
    const results = await Promise.all(
      tokens.map((token) =>
        dependencies.sendMessage(credentials.accessToken, credentials.projectId, token, {
          title: TITLE,
          body: BODY,
          imageUrl,
        })
      ),
    );

    for (const result of results) {
      if (!result.ok) {
        dependencies.logError(
          `今日の1枚通知の送信に失敗しました: ${result.error ?? "unknown"}`,
        );
      }
    }
    const sentCount = results.filter((result) => result.ok).length;
    return { sentCount, failedCount: results.length - sentCount };
  };
}
