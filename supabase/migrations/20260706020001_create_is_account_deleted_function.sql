-- is_account_deleted: ログイン中のユーザーが削除済みアカウント(users.deleted_at設定済み)かどうかを判定する。
-- SNS/メールいずれのログインでも、認証成立後にクライアントがこの関数を呼び出し、
-- true が返った場合は即座にサインアウトさせる(仕様書 3.1.3/6.1参照)。
create function public.is_account_deleted()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select deleted_at is not null from public.users where id = auth.uid()),
    false
  );
$$;

revoke execute on function public.is_account_deleted() from public;
grant execute on function public.is_account_deleted() to authenticated;
