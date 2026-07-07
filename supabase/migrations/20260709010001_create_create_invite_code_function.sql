-- create_invite_code: 固定グループ(mode=group)の招待コードを発行するRPC(仕様書 3.2/6.2 create_invite_code参照)。
-- 現役メンバー全員が実行可能(作成者限定にしない)。既発行済みの場合はinvite_codesの既存行をUPSERTして
-- 新しいコードに置き換える。invite_codesへの直接INSERT/UPDATEはRLSで許可していないため、
-- 発行操作は必ずこの関数(security definer)を経由する。
create function public.create_invite_code(p_group_id uuid)
returns public.invite_codes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
  v_code text;
  v_invite public.invite_codes;
begin
  if auth.uid() is null then
    raise exception 'create_invite_code: authentication required';
  end if;

  select * into v_group from public.groups where id = p_group_id;

  if v_group.id is null or v_group.mode <> 'group' then
    raise exception 'create_invite_code: fixed group not found';
  end if;

  if v_group.status <> 'active' then
    raise exception 'create_invite_code: group is not active';
  end if;

  if not public.is_active_member(p_group_id, auth.uid()) then
    raise exception 'create_invite_code: caller is not an active member of the group';
  end if;

  -- 招待コードはグループへの参加権限を持つベアラートークンなので、予測可能な
  -- md5(random())ではなくpgcryptoのCSPRNG(gen_random_bytes)で十分なエントロピー
  -- (10バイト=80bit)を確保する。
  loop
    v_code := upper(encode(extensions.gen_random_bytes(10), 'hex'));
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;

  insert into public.invite_codes (group_id, code, created_by)
  values (p_group_id, v_code, auth.uid())
  on conflict (group_id) do update
    set code = excluded.code,
        created_by = excluded.created_by,
        created_at = now()
  returning * into v_invite;

  return v_invite;
end;
$$;

revoke execute on function public.create_invite_code(uuid) from public;
grant execute on function public.create_invite_code(uuid) to authenticated;
