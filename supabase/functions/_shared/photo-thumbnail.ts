import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const PHOTO_ORIGINALS_BUCKET = "photo-originals";
const SIGNED_URL_EXPIRES_IN_SECONDS = 3600;

/** 現像済み写真の原本(photo-originalsバケット)へ、通知のサムネイル表示用の署名付きURLを発行する。 */
export async function createPhotoThumbnailUrl(
  supabase: SupabaseClient,
  storagePath: string,
): Promise<string> {
  const { data, error } = await supabase.storage
    .from(PHOTO_ORIGINALS_BUCKET)
    .createSignedUrl(storagePath, SIGNED_URL_EXPIRES_IN_SECONDS);

  if (error || !data) {
    throw new Error(
      `サムネイルの署名付きURL発行に失敗しました: ${error?.message ?? "unknown error"}`,
    );
  }

  return data.signedUrl;
}
