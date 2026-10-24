-- RIFA GLAMOUR: cole todo este arquivo no SQL Editor do Supabase e execute.
create extension if not exists pgcrypto;

create table if not exists public.raffle_numbers (
  number integer primary key check (number between 1 and 50),
  status text not null default 'available' check (status in ('available','pending','paid')),
  purchase_id uuid null,
  updated_at timestamptz not null default now()
);

insert into public.raffle_numbers(number)
select generate_series(1,50)
on conflict (number) do nothing;

create table if not exists public.raffle_purchases (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  cpf text not null check (cpf ~ '^[0-9]{11}$'),
  phone text,
  status text not null default 'pending' check (status in ('pending','paid','released')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.raffle_purchase_numbers (
  purchase_id uuid not null references public.raffle_purchases(id) on delete cascade,
  number integer not null references public.raffle_numbers(number),
  primary key (purchase_id, number),
  unique (number)
);

create table if not exists public.raffle_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.raffle_numbers enable row level security;
alter table public.raffle_purchases enable row level security;
alter table public.raffle_purchase_numbers enable row level security;
alter table public.raffle_admins enable row level security;

drop policy if exists "Public can read number statuses" on public.raffle_numbers;
create policy "Public can read number statuses" on public.raffle_numbers
for select to anon, authenticated using (true);

create or replace function public.is_raffle_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.raffle_admins where user_id = auth.uid()); $$;

-- Cria um pedido pendente e bloqueia todos os números de forma atômica.
create or replace function public.create_raffle_purchase(
  p_full_name text, p_cpf text, p_phone text, p_numbers integer[]
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare new_id uuid; n integer; requested_count integer;
begin
  if length(trim(coalesce(p_full_name,''))) < 3 then raise exception 'Informe o nome completo.'; end if;
  if p_cpf !~ '^[0-9]{11}$' then raise exception 'CPF inválido.'; end if;
  if p_numbers is null or cardinality(p_numbers) < 1 or cardinality(p_numbers) > 50 then raise exception 'Selecione números.'; end if;
  if exists(select 1 from unnest(p_numbers) x group by x having count(*) > 1) then raise exception 'Há números repetidos.'; end if;
  requested_count := cardinality(p_numbers);
  -- Locks em ordem para reduzir disputas entre compradores simultâneos.
  perform 1 from public.raffle_numbers where number = any(p_numbers) order by number for update;
  if (select count(*) from public.raffle_numbers where number = any(p_numbers) and status = 'available') <> requested_count then
    raise exception 'Um ou mais números não estão mais disponíveis. Atualize a página e escolha novamente.';
  end if;
  insert into public.raffle_purchases(full_name,cpf,phone,status)
  values(trim(p_full_name),p_cpf,nullif(trim(coalesce(p_phone,'')),''),'pending') returning id into new_id;
  insert into public.raffle_purchase_numbers(purchase_id,number)
  select new_id, x from unnest(p_numbers) x;
  update public.raffle_numbers set status='pending',purchase_id=new_id,updated_at=now() where number=any(p_numbers);
  return new_id;
end $$;

-- Consulta limitada: retorna apenas pedido, números e status para o CPF exato.
create or replace function public.lookup_raffle_by_cpf(p_cpf text)
returns table(purchase_id uuid, numbers integer[], status text)
language sql security definer set search_path = public
as $$
  select p.id, array_agg(pn.number order by pn.number), p.status
  from public.raffle_purchases p
  join public.raffle_purchase_numbers pn on pn.purchase_id=p.id
  where p.cpf=p_cpf and p_cpf ~ '^[0-9]{11}$'
  group by p.id,p.status
  order by max(p.created_at) desc;
$$;

create or replace function public.admin_list_raffle_purchases()
returns table(id uuid,full_name text,cpf text,phone text,status text,created_at timestamptz,numbers integer[])
language plpgsql security definer set search_path = public
as $$
begin
 if not public.is_raffle_admin() then raise exception 'Acesso restrito.'; end if;
 return query
 select p.id,p.full_name,p.cpf,p.phone,p.status,p.created_at,
        coalesce(array_agg(pn.number order by pn.number) filter(where pn.number is not null),'{}'::integer[])
 from public.raffle_purchases p
 left join public.raffle_purchase_numbers pn on pn.purchase_id=p.id
 group by p.id order by p.created_at desc;
end $$;

create or replace function public.admin_update_raffle_purchase(p_purchase_id uuid,p_action text)
returns boolean language plpgsql security definer set search_path = public
as $$
declare p_status text; nums integer[];
begin
 if not public.is_raffle_admin() then raise exception 'Acesso restrito.'; end if;
 if p_action not in ('confirm','release') then raise exception 'Ação inválida.'; end if;
 select status into p_status from public.raffle_purchases where id=p_purchase_id for update;
 if p_status is null then raise exception 'Pedido não encontrado.'; end if;
 if p_status <> 'pending' then raise exception 'Este pedido já foi processado.'; end if;
 select array_agg(number) into nums from public.raffle_purchase_numbers where purchase_id=p_purchase_id;
 if p_action='confirm' then
   update public.raffle_purchases set status='paid',updated_at=now() where id=p_purchase_id;
   update public.raffle_numbers set status='paid',updated_at=now() where purchase_id=p_purchase_id;
 else
   update public.raffle_purchases set status='released',updated_at=now() where id=p_purchase_id;
   delete from public.raffle_purchase_numbers where purchase_id=p_purchase_id;
   update public.raffle_numbers set status='available',purchase_id=null,updated_at=now() where number=any(coalesce(nums,'{}'::integer[])) and status='pending' and purchase_id=p_purchase_id;
 end if;
 return true;
end $$;

revoke all on function public.create_raffle_purchase(text,text,text,integer[]) from public;
grant execute on function public.create_raffle_purchase(text,text,text,integer[]) to anon, authenticated;
revoke all on function public.lookup_raffle_by_cpf(text) from public;
grant execute on function public.lookup_raffle_by_cpf(text) to anon, authenticated;
revoke all on function public.admin_list_raffle_purchases() from public;
grant execute on function public.admin_list_raffle_purchases() to authenticated;
revoke all on function public.admin_update_raffle_purchase(uuid,text) from public;
grant execute on function public.admin_update_raffle_purchase(uuid,text) to authenticated;
revoke all on function public.is_raffle_admin() from public;
grant execute on function public.is_raffle_admin() to authenticated;

-- Não crie políticas públicas para ler raffle_purchases ou raffle_purchase_numbers.
-- A leitura de dados pessoais fica apenas nas funções controladas acima.
