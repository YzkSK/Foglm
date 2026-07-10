-- add_rls_vote_entries(20260706010004)の列単位grantにより、認証済みユーザーは
-- cast_vote関数(security definer)のバリデーション(締切前か・同一グループ/投票対象日の
-- 写真か)を経由せずvote_entriesへ直接書き込みできてしまう。
-- 書き込みはcast_vote関数経由のみに限定する(閲覧は既存のSELECTポリシーのまま許可する)。
revoke insert, update on public.vote_entries from authenticated;
