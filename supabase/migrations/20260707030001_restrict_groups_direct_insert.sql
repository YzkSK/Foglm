-- groups_insert_own(20260706010001)の列単位grantにより、認証済みユーザーはcreate_event_group関数の
-- バリデーション(空文字/null名前、開始日・終了日のnull/順序チェック)を経由せずgroupsへ直接INSERT
-- できてしまう。また直接INSERTした場合group_membersへの自動登録もスキップされ、
-- 作成者が現役メンバーでない空のグループが作れてしまう。
-- groupsへのINSERTはcreate_event_group関数(security definer)経由のみに限定する。
revoke insert on public.groups from authenticated;
