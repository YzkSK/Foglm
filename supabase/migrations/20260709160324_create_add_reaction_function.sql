-- add_reaction: 現像済み写真へのリアクション追加RPC(仕様書 3.7/5.1/6.6参照)。
-- 対象は固定グループ・イベントグループの写真のみ(ソロモードの写真には使用しない)。
-- 1人1枚につき1リアクションまでで、再選択時はUPSERTで上書きする(UNIQUE (photo_id, user_id))。
-- reactionsへの直接INSERT/UPDATEはRLSの列単位grantだけでは「現像済み写真か」
-- 「ソロモードでないか」を検証できないため、本関数(security definer)経由のみに限定する
-- (直接書き込みの禁止は20260709160327で行う)。
create function public.add_reaction(p_photo_id uuid, p_emoji text)
returns public.reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_photo public.photos;
  v_group public.groups;
  v_reaction public.reactions;
begin
  if auth.uid() is null then
    raise exception 'add_reaction: authentication required';
  end if;

  if p_emoji is null or btrim(p_emoji) = '' then
    raise exception 'add_reaction: emoji must not be empty';
  end if;

  select * into v_photo from public.photos where id = p_photo_id;

  if v_photo.id is null then
    raise exception 'add_reaction: photo not found';
  end if;

  select * into v_group from public.groups where id = v_photo.group_id;

  -- 権限チェック(現役メンバーか)を業務ルールチェック(ソロモード対象外・現像済みか)より
  -- 先に行う。逆順だと非メンバーが例外の内容(ソロモードかどうか)から対象グループの
  -- 性質を間接的に推測できてしまう。
  if not public.is_active_member(v_photo.group_id, auth.uid()) then
    raise exception 'add_reaction: caller is not an active member of the group';
  end if;

  if v_group.mode = 'solo' then
    raise exception 'add_reaction: reactions are not available for solo mode photos';
  end if;

  if v_photo.status <> 'developed' then
    raise exception 'add_reaction: photo is not developed yet';
  end if;

  insert into public.reactions (photo_id, user_id, emoji)
  values (p_photo_id, auth.uid(), p_emoji)
  on conflict (photo_id, user_id) do update
    set emoji = excluded.emoji,
        created_at = now()
  returning * into v_reaction;

  return v_reaction;
end;
$$;

revoke execute on function public.add_reaction(uuid, text) from public;
grant execute on function public.add_reaction(uuid, text) to authenticated;
