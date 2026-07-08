-- dissolve_group_data: グループ解散時の完全削除処理を共通化した内部ヘルパー(#16)。
-- dissolve_group(作成者による明示的な解散)と leave_group(メンバー0人になった際の即座解散)の
-- 両方から呼び出される。写真の原本・ボヤけ版をStorageから削除した上で groups 行を削除し、
-- ON DELETE CASCADEにより photos・daily_votes・vote_entries・reactions・comments・
-- group_members・invite_codes を全て完全に削除する(仕様書 3.2.1/6.2参照)。
-- 呼び出し元のRPCのみから利用する内部関数のため、authenticated/anonへは実行権限を付与しない。
create function public.dissolve_group_data(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- storage.objectsへの直接DELETEはstorage.protect_deleteトリガーで拒否されるため、
  -- このセッション(トランザクション内)に限りstorage.allow_delete_queryを許可する。
  perform set_config('storage.allow_delete_query', 'true', true);

  delete from storage.objects
  where bucket_id in ('photo-originals', 'photo-blurred')
    and name in (
      select original_storage_path from public.photos where group_id = p_group_id
      union
      select blurred_storage_path from public.photos where group_id = p_group_id
    );

  delete from public.groups where id = p_group_id;
end;
$$;

revoke execute on function public.dissolve_group_data(uuid) from public;

-- dissolve_group: 固定グループ(mode=group)限定・作成者のみ実行可能な解散RPC(仕様書 3.2.1/6.2参照)。
-- グループに紐づく写真・原本・ボヤけ版・投票データ・リアクション・コメントを全て完全削除(復元不可)した上で、
-- グループ自体も削除する。解散後、全メンバーは即座にグループへアクセスできなくなる。
create function public.dissolve_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'dissolve_group: authentication required';
  end if;

  if p_group_id is null then
    raise exception 'dissolve_group: group_id must not be null';
  end if;

  select * into v_group from public.groups where id = p_group_id;

  if v_group.id is null then
    raise exception 'dissolve_group: group not found';
  end if;

  if v_group.mode <> 'group' then
    raise exception 'dissolve_group: only fixed groups (mode=group) can be dissolved';
  end if;

  if v_group.created_by <> auth.uid() then
    raise exception 'dissolve_group: only the creator can dissolve this group';
  end if;

  perform public.dissolve_group_data(p_group_id);
end;
$$;

revoke execute on function public.dissolve_group(uuid) from public;
grant execute on function public.dissolve_group(uuid) to authenticated;
