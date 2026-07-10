-- add_comment: 現像済み写真へのコメント追加RPC(仕様書 3.7/5.1/6.6参照)。
-- 対象は固定グループ・イベントグループの写真のみ(ソロモードの写真には使用しない)。
-- リアクションと異なり1人が複数件投稿できるため、単純なINSERTのみでUPSERTは行わない。
-- commentsへの直接INSERTはRLSの列単位grantだけでは「現像済み写真か」「ソロモードでないか」を
-- 検証できないため、本関数(security definer)経由のみに限定する
-- (直接書き込みの禁止は20260710050130で行う)。
create function public.add_comment(p_photo_id uuid, p_body text)
returns public.comments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_photo public.photos;
  v_group public.groups;
  v_comment public.comments;
begin
  if auth.uid() is null then
    raise exception 'add_comment: authentication required';
  end if;

  if p_body is null or btrim(p_body) = '' then
    raise exception 'add_comment: body must not be empty';
  end if;

  select * into v_photo from public.photos where id = p_photo_id;

  if v_photo.id is null then
    raise exception 'add_comment: photo not found';
  end if;

  select * into v_group from public.groups where id = v_photo.group_id;

  -- 権限チェック(現役メンバーか)を業務ルールチェック(ソロモード対象外・現像済みか)より
  -- 先に行う。逆順だと非メンバーが例外の内容(ソロモードかどうか)から対象グループの
  -- 性質を間接的に推測できてしまう。
  if not public.is_active_member(v_photo.group_id, auth.uid()) then
    raise exception 'add_comment: caller is not an active member of the group';
  end if;

  if v_group.mode = 'solo' then
    raise exception 'add_comment: comments are not available for solo mode photos';
  end if;

  if v_photo.status <> 'developed' then
    raise exception 'add_comment: photo is not developed yet';
  end if;

  insert into public.comments (photo_id, user_id, body)
  values (p_photo_id, auth.uid(), btrim(p_body))
  returning * into v_comment;

  return v_comment;
end;
$$;

revoke execute on function public.add_comment(uuid, text) from public;
grant execute on function public.add_comment(uuid, text) to authenticated;
