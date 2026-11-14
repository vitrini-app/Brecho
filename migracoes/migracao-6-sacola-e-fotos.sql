-- Atualizacao 10: sacola atomica e edicao segura de fotos.
-- Execute uma unica vez, depois da migracao-5-logistica.sql.

create table if not exists public.pedidos_sacola (
  id uuid primary key default gen_random_uuid(),
  brecho_id uuid not null references public.brechos(id) on delete cascade,
  nome text not null,
  whats text not null,
  status text not null default 'ativo',
  expira_em timestamptz not null,
  criado_em timestamptz not null default now(),
  entrega text,
  metodo text,
  slot text,
  bairro text,
  cep text,
  uf text,
  endereco_entrega text,
  subtotal numeric not null,
  frete numeric not null default 0,
  total numeric,
  pagamento text not null default 'pix',
  pagamento_informado boolean not null default false,
  etapa text not null default 'aguardando',
  rastreio text,
  comprovante_url text,
  recebido boolean not null default false,
  constraint pedidos_sacola_status_check check (status in ('ativo','pago','expirado','cancelado')),
  constraint pedidos_sacola_pagamento_check check (pagamento in ('pix','retirada')),
  constraint pedidos_sacola_etapa_check check (etapa in ('aguardando','pago','preparando','enviado','pronto','entregue'))
);

create table if not exists public.pedidos_sacola_itens (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos_sacola(id) on delete cascade,
  peca_id uuid not null references public.pecas(id) on delete restrict,
  titulo text not null,
  preco numeric not null,
  constraint pedidos_sacola_itens_pedido_peca_key unique (pedido_id, peca_id)
);

create index if not exists pedidos_sacola_brecho_status_idx
  on public.pedidos_sacola (brecho_id, status);
create index if not exists pedidos_sacola_whats_status_idx
  on public.pedidos_sacola (brecho_id, whats, status);
create index if not exists pedidos_sacola_itens_peca_idx
  on public.pedidos_sacola_itens (peca_id);

alter table public.pedidos_sacola enable row level security;
alter table public.pedidos_sacola_itens enable row level security;

drop policy if exists "Dono le os pedidos de sacola" on public.pedidos_sacola;
create policy "Dono le os pedidos de sacola"
  on public.pedidos_sacola for select to authenticated
  using (exists (
    select 1 from public.brechos b
    where b.id = pedidos_sacola.brecho_id and b.owner = auth.uid()
  ));

drop policy if exists "Dono le itens da sacola" on public.pedidos_sacola_itens;
create policy "Dono le itens da sacola"
  on public.pedidos_sacola_itens for select to authenticated
  using (exists (
    select 1
    from public.pedidos_sacola ps
    join public.brechos b on b.id = ps.brecho_id
    where ps.id = pedidos_sacola_itens.pedido_id and b.owner = auth.uid()
  ));

create or replace function public.validar_limite_reservas()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_whats text;
begin
  v_whats := regexp_replace(coalesce(new.whats, ''), '[^0-9]', '', 'g');
  if length(v_whats) < 10 or length(v_whats) > 15 then
    raise exception 'whats_invalido';
  end if;
  new.whats := v_whats;
  perform pg_advisory_xact_lock(
    hashtextextended(new.brecho_id::text || ':' || v_whats, 0)
  );
  if (
    select count(*) from public.pedidos p
    where p.brecho_id = new.brecho_id
      and regexp_replace(coalesce(p.whats, ''), '[^0-9]', '', 'g') = v_whats
      and p.status = 'ativo'
  ) + (
    select count(*) from public.pedidos_sacola s
    where s.brecho_id = new.brecho_id
      and regexp_replace(coalesce(s.whats, ''), '[^0-9]', '', 'g') = v_whats
      and s.status = 'ativo'
  ) >= 2 then
    raise exception 'limite';
  end if;
  return new;
end
$function$;

drop trigger if exists pedidos_validar_limite_reservas on public.pedidos;
create trigger pedidos_validar_limite_reservas
before insert on public.pedidos
for each row execute function public.validar_limite_reservas();

drop trigger if exists pedidos_sacola_validar_limite_reservas on public.pedidos_sacola;
create trigger pedidos_sacola_validar_limite_reservas
before insert on public.pedidos_sacola
for each row execute function public.validar_limite_reservas();

alter table public.depoimentos
  alter column pedido_id drop not null;

alter table public.depoimentos
  add column if not exists pedido_sacola_id uuid
  references public.pedidos_sacola(id) on delete cascade;

create unique index if not exists depoimentos_pedido_sacola_uidx
  on public.depoimentos (pedido_sacola_id)
  where pedido_sacola_id is not null;

create or replace function public.editar_fotos_peca(p_id uuid, p_fotos text[])
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_fotos text[] := coalesce(p_fotos, array[]::text[]);
begin
  if cardinality(v_fotos) > 5 then
    raise exception 'limite_fotos';
  end if;
  if exists (
    select 1 from unnest(v_fotos) u(url)
    where url !~ '^https://'
  ) then
    raise exception 'url_invalida';
  end if;
  update public.pecas p
  set fotos = v_fotos,
      foto_url = case when cardinality(v_fotos) > 0 then v_fotos[1] else null end
  where p.id = p_id and p.status <> 'reservada'
    and exists (
      select 1 from public.brechos b
      where b.id = p.brecho_id and b.owner = auth.uid()
    );
  if not found then
    raise exception 'nao_permitido';
  end if;
end
$function$;

create or replace function public.reservar_sacola(
  p_pecas uuid[],
  p_nome text,
  p_whats text,
  p_metodo text default 'retirada',
  p_slot text default null,
  p_bairro text default null,
  p_uf text default null,
  p_cep text default null,
  p_endereco text default null,
  p_pagamento text default 'pix'
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_ids uuid[];
  v_p public.pecas;
  v_b public.brechos;
  v_id uuid;
  v_count integer := 0;
  v_subtotal numeric := 0;
  v_frete numeric := 0;
  v_taxa numeric;
  v_reg text;
  v_linha text;
  v_exp timestamptz;
  v_entrega text;
  v_whats text;
begin
  perform public.liberar_expiradas();
  if p_pecas is null or cardinality(p_pecas) < 1 or cardinality(p_pecas) > 10 then
    raise exception 'limite_pecas';
  end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'nome_invalido'; end if;
  v_whats := regexp_replace(coalesce(p_whats, ''), '[^0-9]', '', 'g');
  if length(v_whats) < 10 or length(v_whats) > 15 then
    raise exception 'whats_invalido';
  end if;
  if coalesce(p_pagamento, 'pix') not in ('pix', 'retirada') then
    raise exception 'pagamento_invalido';
  end if;
  select array_agg(distinct items.id order by items.id) into v_ids
  from unnest(p_pecas) as items(id);
  if cardinality(v_ids) <> cardinality(p_pecas) then
    raise exception 'pecas_repetidas';
  end if;

  for v_p in
    select p.* from public.pecas p
    where p.id = any(v_ids)
    order by p.id
    for update
  loop
    if v_count = 0 then
      select * into v_b from public.brechos where id = v_p.brecho_id;
      if not found then raise exception 'brecho_nao_encontrado'; end if;
    elsif v_p.brecho_id <> v_b.id then
      raise exception 'brechos_diferentes';
    end if;
    if v_p.status <> 'disponivel' then raise exception 'indisponivel'; end if;
    v_count := v_count + 1;
    v_subtotal := v_subtotal + v_p.preco;
  end loop;
  if v_count <> cardinality(v_ids) then raise exception 'peca_nao_encontrada'; end if;

  if (
    select count(*) from public.pedidos p
    where p.brecho_id = v_b.id
      and regexp_replace(coalesce(p.whats, ''), '[^0-9]', '', 'g') = v_whats
      and p.status = 'ativo'
  ) + (
    select count(*) from public.pedidos_sacola s
    where s.brecho_id = v_b.id
      and regexp_replace(coalesce(s.whats, ''), '[^0-9]', '', 'g') = v_whats
      and s.status = 'ativo'
  ) >= 2 then
    raise exception 'limite';
  end if;

  if p_metodo = 'retirada' and v_b.retirada_ativa then
    v_frete := 0;
    v_entrega := 'Retirada';
  elsif p_metodo = 'local' and v_b.entrega_local_ativa then
    v_taxa := null;
    for v_linha in
      select unnest(string_to_array(coalesce(v_b.entrega_local_tabela, ''), E'\n'))
    loop
      if lower(trim(split_part(v_linha, ':', 1))) = lower(trim(coalesce(p_bairro, '')))
         and trim(split_part(v_linha, ':', 2)) ~ '^[0-9]+([.,][0-9]+)?$' then
        v_taxa := replace(trim(split_part(v_linha, ':', 2)), ',', '.')::numeric;
      end if;
    end loop;
    if v_taxa is null then v_taxa := v_b.entrega_local_taxa; end if;
    if v_taxa is null then raise exception 'entrega_indisponivel'; end if;
    v_frete := v_taxa;
    v_entrega := 'Entrega local';
  elsif p_metodo = 'envio' and v_b.envio_ativo then
    v_reg := case upper(coalesce(p_uf, ''))
      when 'ES' then 'SE' when 'MG' then 'SE' when 'RJ' then 'SE' when 'SP' then 'SE'
      when 'PR' then 'S' when 'RS' then 'S' when 'SC' then 'S'
      when 'DF' then 'CO' when 'GO' then 'CO' when 'MT' then 'CO' when 'MS' then 'CO'
      when 'AL' then 'NE' when 'BA' then 'NE' when 'CE' then 'NE' when 'MA' then 'NE'
      when 'PB' then 'NE' when 'PE' then 'NE' when 'PI' then 'NE' when 'RN' then 'NE'
      when 'SE' then 'NE' when 'AC' then 'N' when 'AP' then 'N' when 'AM' then 'N'
      when 'PA' then 'N' when 'RO' then 'N' when 'RR' then 'N' when 'TO' then 'N'
      else null end;
    if v_reg is null or (v_b.envio_regioes ->> v_reg) is null then
      raise exception 'entrega_indisponivel';
    end if;
    v_frete := (v_b.envio_regioes ->> v_reg)::numeric;
    v_entrega := 'Envio';
  else
    raise exception 'metodo_invalido';
  end if;

  if p_metodo <> 'retirada' and v_b.frete_gratis_acima is not null
     and v_subtotal >= v_b.frete_gratis_acima then
    v_frete := 0;
  end if;
  if p_metodo <> 'retirada' and coalesce(trim(p_endereco), '') = '' then
    raise exception 'endereco_obrigatorio';
  end if;
  if p_pagamento = 'retirada'
     and not (p_metodo = 'retirada' and v_b.aceita_pagar_retirada) then
    raise exception 'pagamento_invalido';
  end if;

  v_exp := case when p_pagamento = 'retirada'
    then now() + interval '24 hours'
    else now() + make_interval(mins => v_b.reserva_min) end;
  insert into public.pedidos_sacola (
    brecho_id, nome, whats, status, expira_em, entrega, metodo, slot, bairro, cep,
    uf, endereco_entrega, subtotal, frete, total, pagamento
  ) values (
    v_b.id, left(trim(p_nome), 80), v_whats, 'ativo', v_exp,
    v_entrega, p_metodo, left(p_slot, 80), left(p_bairro, 80), left(p_cep, 9),
    upper(left(p_uf, 2)), left(p_endereco, 300), v_subtotal, v_frete,
    v_subtotal + v_frete, coalesce(p_pagamento, 'pix')
  ) returning id into v_id;

  insert into public.pedidos_sacola_itens (pedido_id, peca_id, titulo, preco)
  select v_id, p.id, p.titulo, p.preco
  from public.pecas p where p.id = any(v_ids);
  update public.pecas set status = 'reservada' where id = any(v_ids);
  return v_id;
end
$function$;

create or replace function public.notificar_reserva_sacola()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_chat text;
  v_itens text;
begin
  select a.telegram_chat_id into v_chat
  from public.avisos a where a.brecho_id = new.brecho_id;
  if v_chat is null then return new; end if;
  select string_agg(i.titulo, ', ' order by i.titulo) into v_itens
  from public.pedidos_sacola_itens i where i.pedido_id = new.id;
  perform public.enviar_telegram(
    v_chat,
    'Nova reserva de sacola (' || coalesce(v_itens, 'itens') || ')' || chr(10) ||
    new.nome || ' · ' || new.whats || chr(10) || 'Confirme o pagamento no painel.'
  );
  return new;
exception when others then
  raise warning 'Falha ao enviar aviso da sacola %: %', new.id, sqlerrm;
  return new;
end
$function$;

drop trigger if exists pedidos_sacola_aviso on public.pedidos_sacola;
create constraint trigger pedidos_sacola_aviso
after insert on public.pedidos_sacola
deferrable initially deferred
for each row execute function public.notificar_reserva_sacola();

create or replace function public.liberar_expiradas()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_ids uuid[];
begin
  with expirados as (
    update public.pedidos
    set status = 'expirado'
    where status = 'ativo' and expira_em < now()
    returning peca_id
  )
  update public.pecas
  set status = 'disponivel'
  where id in (select peca_id from expirados) and status = 'reservada';

  with expirados as (
    update public.pedidos_sacola
    set status = 'expirado'
    where status = 'ativo' and expira_em < now()
    returning id
  )
  select array_agg(i.peca_id) into v_ids
  from public.pedidos_sacola_itens i
  where i.pedido_id in (select id from expirados);

  if cardinality(v_ids) > 0 then
    update public.pecas
    set status = 'disponivel'
    where id = any(v_ids) and status = 'reservada';
  end if;
end
$function$;

create or replace function public.meu_pedido(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_s public.pedidos_sacola;
  v_o public.pedidos;
  v_b public.brechos;
  v_pc public.pecas;
  v_e public.enderecos;
  v_end jsonb := null;
  v_items jsonb;
begin
  perform public.liberar_expiradas();
  select * into v_s from public.pedidos_sacola where id = p_id;
  if found then
    select * into v_b from public.brechos where id = v_s.brecho_id;
    if not v_b.endereco_protegido or v_s.status = 'pago' then
      select * into v_e from public.enderecos where brecho_id = v_b.id;
      if found then
        v_end := jsonb_build_object('cep',v_e.cep,'rua',v_e.rua,'numero',v_e.numero,
          'complemento',v_e.complemento,'instrucoes',v_e.instrucoes);
      end if;
    end if;
    select jsonb_agg(jsonb_build_object('id',i.peca_id,'titulo',i.titulo,'preco',i.preco) order by i.titulo)
      into v_items
    from public.pedidos_sacola_itens i where i.pedido_id = p_id;
    return jsonb_build_object(
      'id',v_s.id,'status',v_s.status,'etapa',v_s.etapa,'expira_em',v_s.expira_em,
      'titulo','Sacola com '||(select count(*) from public.pedidos_sacola_itens where pedido_id=p_id)||
        case when (select count(*) from public.pedidos_sacola_itens where pedido_id=p_id)=1
          then ' peça' else ' peças' end,
      'itens',coalesce(v_items,'[]'::jsonb),'preco',v_s.subtotal,'frete',v_s.frete,'total',coalesce(v_s.total,v_s.subtotal),
      'metodo',v_s.metodo,'slot',v_s.slot,'entrega',v_s.entrega,'pagamento',v_s.pagamento,
      'pagamento_informado',v_s.pagamento_informado,'rastreio',v_s.rastreio,
      'comprovante_url',v_s.comprovante_url,'recebido',v_s.recebido,'endereco',v_end
    );
  end if;

  select * into v_o from public.pedidos where id = p_id;
  if not found then return null; end if;
  select * into v_b from public.brechos where id = v_o.brecho_id;
  select * into v_pc from public.pecas where id = v_o.peca_id;
  if not v_b.endereco_protegido or v_o.status = 'pago' then
    select * into v_e from public.enderecos where brecho_id = v_b.id;
    if found then
      v_end := jsonb_build_object('cep', v_e.cep, 'rua', v_e.rua, 'numero', v_e.numero,
                                  'complemento', v_e.complemento, 'instrucoes', v_e.instrucoes);
    end if;
  end if;
  return jsonb_build_object(
    'id', v_o.id, 'status', v_o.status, 'etapa', v_o.etapa, 'expira_em', v_o.expira_em,
    'titulo', v_pc.titulo, 'preco', v_pc.preco, 'frete', v_o.frete, 'total', coalesce(v_o.total, v_pc.preco),
    'metodo', v_o.metodo, 'slot', v_o.slot, 'entrega', v_o.entrega, 'pagamento', v_o.pagamento,
    'pagamento_informado', v_o.pagamento_informado, 'rastreio', v_o.rastreio,
    'comprovante_url', v_o.comprovante_url, 'recebido', v_o.recebido, 'endereco', v_end);
end
$function$;

create or replace function public.informar_pagamento(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update public.pedidos set pagamento_informado = true where id = p_id and status = 'ativo';
  update public.pedidos_sacola set pagamento_informado = true where id = p_id and status = 'ativo';
end
$function$;

create or replace function public.resolver_pedido(p_id uuid, p_acao text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_s public.pedidos_sacola;
  v_o public.pedidos;
begin
  if p_acao not in ('pago', 'cancelar') then raise exception 'acao_invalida'; end if;
  perform public.liberar_expiradas();
  select s.* into v_s from public.pedidos_sacola s
  join public.brechos b on b.id = s.brecho_id
  where s.id = p_id and b.owner = auth.uid() and s.status = 'ativo'
  for update of s;
  if found then
    if p_acao = 'pago' then
      update public.pedidos_sacola set status='pago',etapa='pago' where id=p_id;
      update public.pecas p set status='vendida'
      where p.id in (select i.peca_id from public.pedidos_sacola_itens i where i.pedido_id=p_id);
    else
      update public.pedidos_sacola set status='cancelado' where id=p_id;
      update public.pecas p set status='disponivel'
      where p.id in (select i.peca_id from public.pedidos_sacola_itens i where i.pedido_id=p_id)
        and p.status='reservada';
    end if;
    return;
  end if;

  select o.* into v_o from public.pedidos o
  join public.brechos b on b.id=o.brecho_id
  where o.id=p_id and b.owner=auth.uid() and o.status='ativo'
  for update of o;
  if not found then raise exception 'nao_permitido'; end if;
  if p_acao='pago' then
    update public.pedidos set status='pago',etapa='pago' where id=p_id;
    update public.pecas set status='vendida' where id=v_o.peca_id;
  else
    update public.pedidos set status='cancelado' where id=p_id;
    update public.pecas set status='disponivel' where id=v_o.peca_id;
  end if;
end
$function$;

create or replace function public.atualizar_pedido(
  p_id uuid,p_etapa text,p_rastreio text default null,p_comprovante text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if p_etapa not in ('preparando','enviado','pronto','entregue') then
    raise exception 'etapa_invalida';
  end if;
  update public.pedidos_sacola s set etapa=p_etapa,
    rastreio=coalesce(left(p_rastreio,60),s.rastreio),
    comprovante_url=case when p_comprovante ~ '^https://' then p_comprovante else s.comprovante_url end
  where s.id=p_id and s.status='pago'
    and exists(select 1 from public.brechos b where b.id=s.brecho_id and b.owner=auth.uid());
  if found then return; end if;
  update public.pedidos o set etapa=p_etapa,
    rastreio=coalesce(left(p_rastreio,60),o.rastreio),
    comprovante_url=case when p_comprovante ~ '^https://' then p_comprovante else o.comprovante_url end
  where o.id=p_id and o.status='pago'
    and exists(select 1 from public.brechos b where b.id=o.brecho_id and b.owner=auth.uid());
  if not found then raise exception 'nao_permitido'; end if;
end
$function$;

create or replace function public.endereco_loja(p_brecho uuid,p_pedido uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_b public.brechos;
  v_e public.enderecos;
  v_ok boolean := false;
begin
  select * into v_b from public.brechos where id=p_brecho;
  if not found then return null; end if;
  if not v_b.endereco_protegido then
    v_ok := true;
  elsif p_pedido is not null then
    select exists(
      select 1 from public.pedidos
      where id=p_pedido and brecho_id=p_brecho and status='pago'
      union all
      select 1 from public.pedidos_sacola
      where id=p_pedido and brecho_id=p_brecho and status='pago'
    ) into v_ok;
  end if;
  if not v_ok then return null; end if;
  select * into v_e from public.enderecos where brecho_id=p_brecho;
  if not found then return null; end if;
  return jsonb_build_object('cep',v_e.cep,'rua',v_e.rua,'numero',v_e.numero,
    'complemento',v_e.complemento,'instrucoes',v_e.instrucoes);
end
$function$;

create or replace function public.confirmar_recebimento(
  p_id uuid,p_texto text default null,p_nota integer default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_s public.pedidos_sacola;
  v_o public.pedidos;
begin
  select * into v_s from public.pedidos_sacola
  where id=p_id and status='pago' and etapa in ('enviado','pronto','entregue')
  for update;
  if found then
    update public.pedidos_sacola set recebido=true,etapa='entregue' where id=p_id;
    if (p_texto is not null and length(trim(p_texto))>0) or p_nota is not null then
      insert into public.depoimentos (brecho_id,pedido_id,pedido_sacola_id,nome,texto,nota)
      values (v_s.brecho_id,null,p_id,left(v_s.nome,position(' ' in v_s.nome||' ')-1),
        nullif(left(trim(coalesce(p_texto,'')),400),''),
        case when p_nota between 1 and 5 then p_nota end)
      on conflict (pedido_sacola_id) where pedido_sacola_id is not null do nothing;
    end if;
    return;
  end if;

  select * into v_o from public.pedidos
  where id=p_id and status='pago' and etapa in ('enviado','pronto','entregue')
  for update;
  if not found then raise exception 'nao_permitido'; end if;
  update public.pedidos set recebido=true,etapa='entregue' where id=p_id;
  if (p_texto is not null and length(trim(p_texto))>0) or p_nota is not null then
    insert into public.depoimentos (brecho_id,pedido_id,nome,texto,nota)
    values (v_o.brecho_id,p_id,split_part(v_o.nome,' ',1),
      nullif(left(trim(coalesce(p_texto,'')),400),''),
      case when p_nota between 1 and 5 then p_nota end)
    on conflict (pedido_id) do nothing;
  end if;
end
$function$;
