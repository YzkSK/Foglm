-- add_rls_reactions_comments(20260706010005)の列単位grantにより、認証済みユーザーは
-- add_reaction/add_comment関数のバリデーション(現像済み写真か・ソロモードでないか)を
-- 経由せずreactions/commentsへ直接書き込みできてしまう。
-- 書き込みはadd_reaction関数(security definer)・add_comment関数(security definer)
-- 経由のみに限定する(閲覧は既存のSELECTポリシーのまま許可する)。
revoke insert, update, delete on public.reactions from authenticated;
revoke insert on public.comments from authenticated;
