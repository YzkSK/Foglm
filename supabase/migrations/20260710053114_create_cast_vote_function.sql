-- cast_vote: 「今日の1枚」投票の登録・更新RPC(仕様書 3.5/5.1/6.4参照)。
-- 1人1票、再投票可(最後の一票のみ有効)で、vote_entriesのUNIQUE (daily_vote_id, user_id)
-- を利用したUPSERTで実現する。
-- vote_entriesへの直接INSERT/UPDATEはRLSの列単位grantだけでは「締切前か」
-- 「同一グループ・同一投票対象日の写真か」を検証できないため、本関数(security definer)
-- 経由のみに限定する(直接書き込みの禁止は次のマイグレーションで行う)。
create function public.cast_vote(p_photo_id uuid)
returns public.vote_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  v_photo public.photos;
  v_daily_vote public.daily_votes;
  v_vote_entry public.vote_entries;
begin
  if auth.uid() is null then
    raise exception 'cast_vote: authentication required';
  end if;

  select * into v_photo from public.photos where id = p_photo_id;

  if v_photo.id is null then
    raise exception 'cast_vote: photo not found';
  end if;

  -- 権限チェック(現役メンバーか)を業務ルールチェック(投票期間か)より先に行う。
  -- 逆順だと非メンバーが例外の内容から対象グループの状態を間接的に推測できてしまう。
  if not public.is_active_member(v_photo.group_id, auth.uid()) then
    raise exception 'cast_vote: caller is not an active member of the group';
  end if;

  select * into v_daily_vote
  from public.daily_votes
  where group_id = v_photo.group_id
    and vote_date = v_photo.taken_date;

  if v_daily_vote.id is null then
    raise exception 'cast_vote: voting is not open for this photo';
  end if;

  if v_daily_vote.status <> 'open' then
    raise exception 'cast_vote: voting has already closed';
  end if;

  insert into public.vote_entries (daily_vote_id, user_id, photo_id)
  values (v_daily_vote.id, auth.uid(), p_photo_id)
  on conflict (daily_vote_id, user_id) do update
    set photo_id = excluded.photo_id,
        voted_at = now()
  returning * into v_vote_entry;

  return v_vote_entry;
end;
$$;

revoke execute on function public.cast_vote(uuid) from public;
grant execute on function public.cast_vote(uuid) to authenticated;
