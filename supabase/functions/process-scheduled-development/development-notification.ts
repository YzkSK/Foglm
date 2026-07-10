import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  type FcmNotification,
  type FcmSendResult,
  getFcmAccessToken,
  sendFcmMessage,
} from "../_shared/fcm.ts";
import { getActiveGroupMemberFcmTokens } from "../_shared/notification-targets.ts";

const BODY = "アプリを開いて確認しよう";

/** 現像件数から通知タイトルを組み立てる(1枚のみの場合と複数枚の場合で文言を変える)。 */
export function buildDevelopmentNotificationTitle(developedCount: number): string {
  return developedCount === 1
    ? "1枚の写真が現像されました"
    : `${developedCount}枚の写真が現像されました`;
}

export interface DevelopmentNotificationResult {
  sentCount: number;
  failedCount: number;
}

export type DevelopmentNotifier = (
  groupId: string,
  developedCount: number,
) => Promise<DevelopmentNotificationResult>;

export interface DevelopmentNotificationDependencies {
  getTokens: typeof getActiveGroupMemberFcmTokens;
  getAccessToken: typeof getFcmAccessToken;
  sendMessage: (
    accessToken: string,
    projectId: string,
    token: string,
    notification: FcmNotification,
  ) => Promise<FcmSendResult>;
  logError: (message: string) => void;
}

const defaultDependencies: DevelopmentNotificationDependencies = {
  getTokens: getActiveGroupMemberFcmTokens,
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

export function createDevelopmentNotifier(
  supabase: SupabaseClient,
  serviceAccountJson: string,
  dependencies: DevelopmentNotificationDependencies = defaultDependencies,
): DevelopmentNotifier {
  let credentialsPromise: Promise<{ accessToken: string; projectId: string }> | undefined;

  function getCredentials(): Promise<{ accessToken: string; projectId: string }> {
    credentialsPromise ??= (async () => {
      const projectId = parseProjectId(serviceAccountJson);
      const accessToken = await dependencies.getAccessToken(serviceAccountJson);
      return { accessToken, projectId };
    })();
    return credentialsPromise;
  }

  return async (groupId, developedCount) => {
    const tokens = await dependencies.getTokens(supabase, groupId);
    if (tokens.length === 0) return { sentCount: 0, failedCount: 0 };

    const credentials = await getCredentials();
    const results = await Promise.all(
      tokens.map((token) =>
        dependencies.sendMessage(credentials.accessToken, credentials.projectId, token, {
          title: buildDevelopmentNotificationTitle(developedCount),
          body: BODY,
        })
      ),
    );

    for (const result of results) {
      if (!result.ok) {
        dependencies.logError(
          `集約現像通知の送信に失敗しました: ${result.error ?? "unknown"}`,
        );
      }
    }
    const sentCount = results.filter((result) => result.ok).length;
    return { sentCount, failedCount: results.length - sentCount };
  };
}
