-- Controle administrativo de acesso às lojas e períodos de teste.
-- Execute depois de schema.sql e das migrações 1 a 6.

create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;
revoke all on table public.platform_admins from public, anon, authenticated;

create table if not exists public.platform_brecho_access (
  brecho_id uuid primary key references public.brechos(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'suspended')),
  trial_ends_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.platform_brecho_access enable row level security;
revoke all on table public.platform_brecho_access from public, anon, authenticated;

create table if not exists public.platform_brecho_audit (
  id bigint generated always as identity primary key,
  brecho_id uuid,
  brecho_nome text not null,
  admin_email text,
  status_before text not null,
  status_after text not null,
  trial_ends_before timestamptz,
  trial_ends_after timestamptz,
  created_at timestamptz not null default now()
);

alter table public.platform_brecho_audit enable row level security;
revoke all on table public.platform_brecho_audit from public, anon, authenticated;

insert into public.platform_brecho_access (brecho_id)
select id from public.brechos
on conflict (brecho_id) do nothing;

create or replace function public.platform_criar_acesso_brecho()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.platform_brecho_access (brecho_id)
  values (new.id)
  on conflict (brecho_id) do nothing;
  return new;
end;
$$;

revoke all on function public.platform_criar_acesso_brecho() from public, anon, authenticated;

drop trigger if exists platform_brecho_criar_acesso on public.brechos;
create trigger platform_brecho_criar_acesso
after insert on public.brechos
for each row execute function public.platform_criar_acesso_brecho();

create or replace function public.brecho_publico_ativo(p_brecho_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.platform_brecho_access a
    where a.brecho_id = p_brecho_id
      and a.status = 'active'
      and (a.trial_ends_at is null or a.trial_ends_at > now())
  );
$$;

revoke all on function public.brecho_publico_ativo(uuid) from public, anon, authenticated;
grant execute on function public.brecho_publico_ativo(uuid) to anon, authenticated;

-- Recria as políticas documentadas para que lojas suspensas não sejam públicas.
do $$
declare
  p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('brechos', 'pecas', 'depoimentos')
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end;
$$;

create policy brechos_publico_ativo_ou_dono
on public.brechos
for select to anon, authenticated
using (owner = auth.uid() or public.brecho_publico_ativo(id));

create policy brechos_dono_insere
on public.brechos
for insert to authenticated
with check (owner = auth.uid());

create policy brechos_dono_atualiza
on public.brechos
for update to authenticated
using (owner = auth.uid())
with check (owner = auth.uid());

create policy pecas_publicas_ativas_ou_dono
on public.pecas
for select to anon, authenticated
using (
  exists (
    select 1
    from public.brechos b
    where b.id = pecas.brecho_id
      and (b.owner = auth.uid() or public.brecho_publico_ativo(b.id))
  )
);

create policy pecas_dono_insere
on public.pecas
for insert to authenticated
with check (
  exists (
    select 1
    from public.brechos b
    where b.id = pecas.brecho_id and b.owner = auth.uid()
  )
);

create policy pecas_dono_apaga_disponivel
on public.pecas
for delete to authenticated
using (
  status = 'disponivel'
  and exists (
    select 1
    from public.brechos b
    where b.id = pecas.brecho_id and b.owner = auth.uid()
  )
);

create policy depoimentos_publicos_ativos_ou_dono
on public.depoimentos
for select to anon, authenticated
using (
  public.brecho_publico_ativo(brecho_id)
  or exists (
    select 1
    from public.brechos b
    where b.id = depoimentos.brecho_id and b.owner = auth.uid()
  )
);

create policy depoimentos_dono_apaga
on public.depoimentos
for delete to authenticated
using (
  exists (
    select 1
    from public.brechos b
    where b.id = depoimentos.brecho_id and b.owner = auth.uid()
  )
);

create or replace function public.brecho_acesso_proprio()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'status', a.status,
    'trial_ends_at', a.trial_ends_at,
    'public_access', public.brecho_publico_ativo(a.brecho_id)
  )
  from public.brechos b
  join public.platform_brecho_access a on a.brecho_id = b.id
  where b.owner = auth.uid()
  limit 1;
$$;

create or replace function public.admin_is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.platform_admins a where a.user_id = auth.uid()
  );
$$;

create or replace function public.admin_list_brechos()
returns table (
  brecho_id uuid,
  nome text,
  slug text,
  owner_email text,
  criado_em timestamptz,
  access_status text,
  trial_ends_at timestamptz,
  public_access boolean
)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.admin_is_platform_admin() then
    raise exception 'nao_autorizado' using errcode = '42501';
  end if;

  return query
  select
    b.id,
    b.nome,
    b.slug,
    u.email::text,
    b.criado_em,
    a.status,
    a.trial_ends_at,
    public.brecho_publico_ativo(b.id)
  from public.brechos b
  join public.platform_brecho_access a on a.brecho_id = b.id
  left join auth.users u on u.id = b.owner
  order by b.criado_em desc;
end;
$$;

create or replace function public.admin_list_brecho_audit(p_limit integer default 25)
returns table (
  brecho_id uuid,
  brecho_nome text,
  admin_email text,
  status_before text,
  status_after text,
  trial_ends_before timestamptz,
  trial_ends_after timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.admin_is_platform_admin() then
    raise exception 'nao_autorizado' using errcode = '42501';
  end if;

  return query
  select
    a.brecho_id,
    a.brecho_nome,
    a.admin_email,
    a.status_before,
    a.status_after,
    a.trial_ends_before,
    a.trial_ends_after,
    a.created_at
  from public.platform_brecho_audit a
  order by a.created_at desc
  limit least(greatest(coalesce(p_limit, 25), 1), 100);
end;
$$;

create or replace function public.admin_set_brecho_acesso(
  p_brecho_id uuid,
  p_status text,
  p_trial_ends_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_nome text;
  v_admin_email text;
  v_status_before text;
  v_trial_ends_before timestamptz;
begin
  if not public.admin_is_platform_admin() then
    raise exception 'nao_autorizado' using errcode = '42501';
  end if;

  if p_status is null or p_status not in ('active', 'suspended') then
    raise exception 'status_invalido' using errcode = '22023';
  end if;

  select b.nome into v_nome
  from public.brechos b
  where b.id = p_brecho_id;

  if not found then
    raise exception 'brecho_nao_encontrado' using errcode = 'P0002';
  end if;

  select a.status, a.trial_ends_at
  into v_status_before, v_trial_ends_before
  from public.platform_brecho_access a
  where a.brecho_id = p_brecho_id
  for update;

  if not found then
    raise exception 'acesso_nao_encontrado' using errcode = 'P0002';
  end if;

  select u.email::text into v_admin_email
  from auth.users u
  where u.id = auth.uid();

  update public.platform_brecho_access
  set status = p_status,
      trial_ends_at = p_trial_ends_at,
      updated_at = now(),
      updated_by = auth.uid()
  where brecho_id = p_brecho_id;

  insert into public.platform_brecho_audit (
    brecho_id, brecho_nome, admin_email,
    status_before, status_after,
    trial_ends_before, trial_ends_after
  )
  values (
    p_brecho_id, v_nome, v_admin_email,
    v_status_before, p_status,
    v_trial_ends_before, p_trial_ends_at
  );

  return true;
end;
$$;

create or replace function public.bloquear_reserva_brecho_indisponivel()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.brecho_publico_ativo(new.brecho_id) then
    raise exception 'brecho_indisponivel' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.bloquear_reserva_brecho_indisponivel() from public, anon, authenticated;

drop trigger if exists pedidos_brecho_publico_ativo on public.pedidos;
create trigger pedidos_brecho_publico_ativo
before insert on public.pedidos
for each row execute function public.bloquear_reserva_brecho_indisponivel();

drop trigger if exists pedidos_sacola_brecho_publico_ativo on public.pedidos_sacola;
create trigger pedidos_sacola_brecho_publico_ativo
before insert on public.pedidos_sacola
for each row execute function public.bloquear_reserva_brecho_indisponivel();

revoke all on function public.brecho_acesso_proprio() from public, anon, authenticated;
grant execute on function public.brecho_acesso_proprio() to authenticated;

revoke all on function public.admin_is_platform_admin() from public, anon, authenticated;
grant execute on function public.admin_is_platform_admin() to authenticated;

revoke all on function public.admin_list_brechos() from public, anon, authenticated;
grant execute on function public.admin_list_brechos() to authenticated;

revoke all on function public.admin_list_brecho_audit(integer) from public, anon, authenticated;
grant execute on function public.admin_list_brecho_audit(integer) to authenticated;

revoke all on function public.admin_set_brecho_acesso(uuid, text, timestamptz) from public, anon, authenticated;
grant execute on function public.admin_set_brecho_acesso(uuid, text, timestamptz) to authenticated;
