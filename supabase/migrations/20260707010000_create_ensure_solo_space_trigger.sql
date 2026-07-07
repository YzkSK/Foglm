-- ensure_solo_space: public.usersへの新規INSERT時(=初回サインアップ完了時)に、
-- 本人専用のソロモード空間(mode=solo)を自動作成し、本人をgroup_membersへ登録する
-- トリガー(仕様書 3.10/6.2参照)。招待や作成操作は不要で、以後の再実行は発生しない
-- (public.usersへのINSERTは初回サインアップ時の1度のみのため)。
create function public.ensure_solo_space()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
begin
  insert into public.groups (name, mode, created_by)
  values ('ソロ', 'solo', new.id)
  returning id into v_group_id;

  insert into public.group_members (group_id, user_id)
  values (v_group_id, new.id);

  return new;
end;
$$;

create trigger on_public_user_created
  after insert on public.users
  for each row execute function public.ensure_solo_space();
