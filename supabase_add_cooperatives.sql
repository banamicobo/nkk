-- ══════════════════════════════════════════════════════════
-- NKK — dodaj obsługę wielu spółdzielni (multi-tenant)
-- Wklej do: Supabase > SQL Editor > New Query
-- ══════════════════════════════════════════════════════════

-- TABELA SPÓŁDZIELNI
create table public.cooperatives (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  slug            text unique,
  vehicle_make    text,
  vehicle_model   text,
  vehicle_year    integer,
  vehicle_plate   text,
  vehicle_vin     text,
  purchase_price  numeric(12,2),
  purchase_date   date,
  created_by      uuid references auth.users(id),
  created_at      timestamptz default now()
);

-- DODAJ cooperative_id DO MEMBERS
alter table public.members
  add column if not exists cooperative_id uuid references public.cooperatives(id) on delete cascade;

-- DODAJ cooperative_id DO BUDGET
alter table public.budget
  add column if not exists cooperative_id uuid references public.cooperatives(id) on delete cascade;

-- RLS
alter table public.cooperatives enable row level security;
create policy "cooperatives_all" on public.cooperatives for all using (auth.role() = 'authenticated');

-- RPC: utwórz spółdzielnię i pierwszego członka w jednej transakcji
create or replace function create_cooperative(
  p_name          text,
  p_slug          text,
  p_vehicle_make  text,
  p_vehicle_model text,
  p_vehicle_year  integer,
  p_vehicle_plate text,
  p_vehicle_vin   text,
  p_purchase_price numeric,
  p_purchase_date date,
  p_member_name   text,
  p_member_email  text,
  p_budget_target numeric,
  p_forecast_2yr  numeric
) returns uuid language plpgsql security definer as $$
declare
  v_coop_id uuid;
  v_member_id uuid;
begin
  -- Stwórz spółdzielnię
  insert into public.cooperatives (name, slug, vehicle_make, vehicle_model, vehicle_year, vehicle_plate, vehicle_vin, purchase_price, purchase_date, created_by)
  values (p_name, p_slug, p_vehicle_make, p_vehicle_model, p_vehicle_year, p_vehicle_plate, p_vehicle_vin, p_purchase_price, p_purchase_date, auth.uid())
  returning id into v_coop_id;

  -- Stwórz założyciela jako pierwszego członka (100% na start)
  insert into public.members (user_id, cooperative_id, name, email, share_pct)
  values (auth.uid(), v_coop_id, p_member_name, p_member_email, 100)
  returning id into v_member_id;

  -- Stwórz budżet spółdzielni
  insert into public.budget (cooperative_id, current_balance, target_balance, forecast_2yr)
  values (v_coop_id, 0, p_budget_target, p_forecast_2yr);

  return v_coop_id;
end;
$$;
