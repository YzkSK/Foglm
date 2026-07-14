-- 注意(#209): 本ファイルは並行ブランチのマージ事故により、
-- 20260711034030_grant_service_role_public_tables.sql と完全に同一内容で重複している。
-- 適用済みマイグレーションの改変は履歴不整合のリスクがあるため、あえて修正せずそのまま残す。
-- 詳細はdocs/setup/supabase.mdおよびissue #209を参照。
--
-- service_role(#181): publicスキーマの全テーブルに対し、service_roleへのGRANTが1件も
-- 存在しなかった(既存マイグレーションではauthenticatedロールへのGRANTのみが明示的に
-- 行われていた)。service_roleはEdge Function等の信頼されたサーバー側処理から使う想定の
-- ロールであり、public スキーマの全テーブルにフルアクセスできる必要があるため付与する。
-- 今後 public スキーマに新規テーブルを追加する場合も、既存の to authenticated と同様に
-- このテーブルへ to service_role のGRANTを追加すること。
grant select, insert, update, delete on public.users to service_role;
grant select, insert, update, delete on public.groups to service_role;
grant select, insert, update, delete on public.group_members to service_role;
grant select, insert, update, delete on public.photos to service_role;
grant select, insert, update, delete on public.daily_votes to service_role;
grant select, insert, update, delete on public.vote_entries to service_role;
grant select, insert, update, delete on public.reactions to service_role;
grant select, insert, update, delete on public.comments to service_role;
grant select, insert, update, delete on public.invite_codes to service_role;
