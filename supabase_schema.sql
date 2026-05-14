-- ══════════════════════════════════════════════════════════
-- NKK — Nasz Kochany Kamper — Supabase Schema
-- Wklej do: Supabase > SQL Editor > New Query
-- ══════════════════════════════════════════════════════════

-- MEMBERS (linked to auth.users)
create table public.members (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users(id) on delete cascade,
  name          text not null,
  email         text,
  share_pct     numeric(5,2) default 33.33,
  care_style    text check (care_style in ('pedant','user','niechluj')),
  response_style text check (response_style in ('proactive','reactive')),
  joined_at     timestamptz default now(),
  unique (user_id)
);

-- RESERVATIONS
create table public.reservations (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid references public.members(id) on delete cascade,
  start_date  date not null,
  end_date    date not null,
  status      text default 'confirmed' check (status in ('confirmed','pending','cancelled')),
  notes       text,
  created_at  timestamptz default now()
);

-- EXPENSES (serwis, opony, naprawy itp.)
create table public.expenses (
  id           uuid primary key default gen_random_uuid(),
  member_id    uuid references public.members(id) on delete cascade,
  category     text not null check (category in ('service','tires','repair','insurance','other')),
  description  text not null,
  amount       numeric(10,2) not null,
  date         date not null,
  invoice_url  text,
  created_at   timestamptz default now()
);

-- CONTRIBUTIONS (składki)
create table public.contributions (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid references public.members(id) on delete cascade,
  amount      numeric(10,2) not null,
  date        date not null,
  status      text default 'paid' check (status in ('paid','pending')),
  notes       text,
  created_at  timestamptz default now()
);

-- BUDGET (singleton row)
create table public.budget (
  id              uuid primary key default gen_random_uuid(),
  current_balance numeric(12,2) default 0,
  target_balance  numeric(12,2) default 10000,
  forecast_2yr    numeric(12,2) default 10000,
  updated_at      timestamptz default now()
);
insert into public.budget (current_balance, target_balance, forecast_2yr)
values (0, 10000, 10000);

-- DOCUMENTS
create table public.documents (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid references public.members(id),
  title       text not null,
  type        text not null check (type in ('cooperative','vehicle','invoice')),
  file_url    text not null,
  created_at  timestamptz default now()
);

-- VEHICLE HISTORY
create table public.vehicle_history (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid references public.members(id),
  type        text not null check (type in ('service','repair','tires','inspection','note','purchase')),
  title       text not null,
  description text,
  date        date not null,
  mileage     integer,
  created_at  timestamptz default now()
);

-- ── RPC: add contribution to budget ─────────────────────
create or replace function add_to_budget(amount_add numeric)
returns void language plpgsql as $$
begin
  update public.budget set
    current_balance = current_balance + amount_add,
    updated_at = now();
end;
$$;

-- ── RLS: Row Level Security ──────────────────────────────
alter table public.members          enable row level security;
alter table public.reservations     enable row level security;
alter table public.expenses         enable row level security;
alter table public.contributions    enable row level security;
alter table public.budget           enable row level security;
alter table public.documents        enable row level security;
alter table public.vehicle_history  enable row level security;

-- Only authenticated users can read/write (all members = trusted)
create policy "members_all"         on public.members         for all using (auth.role() = 'authenticated');
create policy "reservations_all"    on public.reservations    for all using (auth.role() = 'authenticated');
create policy "expenses_all"        on public.expenses        for all using (auth.role() = 'authenticated');
create policy "contributions_all"   on public.contributions   for all using (auth.role() = 'authenticated');
create policy "budget_all"          on public.budget          for all using (auth.role() = 'authenticated');
create policy "documents_all"       on public.documents       for all using (auth.role() = 'authenticated');
create policy "vehicle_history_all" on public.vehicle_history for all using (auth.role() = 'authenticated');

-- ── STORAGE BUCKET ───────────────────────────────────────
-- W Supabase > Storage > New bucket: "documents" (private)
-- Policies: authenticated users read/write
