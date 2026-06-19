-- =====================================================================
--  Nutzwertanalyse / Stärken- & Kompetenzprofil – Datenbank & Sicherheit
--  Diesen kompletten Inhalt im Supabase-Dashboard unter
--  "SQL Editor" -> "New query" einfügen und auf "Run" klicken.
--  Er legt alle Tabellen an und schützt die Daten serverseitig.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) PRAXEN
--    Eine Praxis gehört genau einer Führungskraft (FK = Supabase-Login-Konto).
--    join_code ist der kurze Code, den die FK ihren Mitarbeitern gibt,
--    damit diese ihre Praxis beim Login finden.
-- ---------------------------------------------------------------------
create table if not exists public.practices (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  join_code   text not null unique,
  logo        text,                 -- Praxis-Logo als Data-URL (base64), optional
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2) MITARBEITER
--    Jeder Mitarbeiter hat ein verstecktes "Schatten"-Anmeldekonto
--    (auth_uid). Sein Zugangscode ist das Passwort dieses Kontos und wird
--    NUR von den Server-Funktionen gesetzt – nie im Browser.
-- ---------------------------------------------------------------------
create table if not exists public.employees (
  id          uuid primary key default gen_random_uuid(),
  practice_id uuid not null references public.practices (id) on delete cascade,
  auth_uid    uuid references auth.users (id) on delete set null,
  name        text not null,
  position    text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists employees_practice_idx on public.employees (practice_id);
create index if not exists employees_auth_idx     on public.employees (auth_uid);

-- ---------------------------------------------------------------------
-- 3) BEWERTUNGSZYKLEN
--    status steuert den ganzen Ablauf:
--      'draft'     = FK arbeitet, MA sieht NICHTS
--      'released'  = von FK freigegeben, MA darf Selbsteinschätzung bearbeiten
--      'locked'    = MA-Bearbeitung von FK gesperrt (MA sieht nur noch, kann nicht ändern)
--      'completed' = abgeschlossen, FK kann Word erzeugen
-- ---------------------------------------------------------------------
create table if not exists public.cycles (
  id          uuid primary key default gen_random_uuid(),
  practice_id uuid not null references public.practices (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  title       text,
  period      text,
  status      text not null default 'draft'
              check (status in ('draft','released','locked','completed')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists cycles_employee_idx on public.cycles (employee_id);

-- ---------------------------------------------------------------------
-- 4) BEWERTUNG DER FÜHRUNGSKRAFT  (Gewichtung G + Bewertung B)
--    GETRENNTE Tabelle, damit Mitarbeiter darauf gar keinen Zugriff
--    bekommen können – das ist die technische Garantie für
--    "MA darf FK-Bewertung nicht sehen".
-- ---------------------------------------------------------------------
create table if not exists public.fk_ratings (
  cycle_id  uuid not null references public.cycles (id) on delete cascade,
  item_key  text not null,
  g         smallint check (g between 0 and 3),
  b         smallint check (b between 0 and 5),
  primary key (cycle_id, item_key)
);

-- ---------------------------------------------------------------------
-- 5) SELBSTEINSCHÄTZUNG DES MITARBEITERS  (Bewertung B)
-- ---------------------------------------------------------------------
create table if not exists public.ma_ratings (
  cycle_id  uuid not null references public.cycles (id) on delete cascade,
  item_key  text not null,
  b         smallint check (b between 0 and 5),
  primary key (cycle_id, item_key)
);

-- ---------------------------------------------------------------------
-- 6) EIGENE (zusätzliche) KRITERIEN, die FK oder MA ergänzen
-- ---------------------------------------------------------------------
create table if not exists public.custom_items (
  id          uuid primary key default gen_random_uuid(),
  cycle_id    uuid not null references public.cycles (id) on delete cascade,
  item_key    text not null,
  section     text not null,
  criterion   text not null,
  description text,
  author      text not null check (author in ('fk','ma'))
);

-- =====================================================================
--  HILFSFUNKTIONEN
-- =====================================================================

-- Praxis-Id des aktuell eingeloggten Mitarbeiters (über sein Schattenkonto)
create or replace function public.my_employee_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.employees where auth_uid = auth.uid() limit 1;
$$;

-- Trägt die FK als Eigentümer? (für die übergebene Praxis)
create or replace function public.owns_practice(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.practices where id = p and owner = auth.uid());
$$;

-- =====================================================================
--  ROW LEVEL SECURITY  (serverseitige Zugriffsregeln)
-- =====================================================================
alter table public.practices    enable row level security;
alter table public.employees    enable row level security;
alter table public.cycles       enable row level security;
alter table public.fk_ratings   enable row level security;
alter table public.ma_ratings   enable row level security;
alter table public.custom_items enable row level security;

-- ----- PRACTICES -----
-- FK darf ihre eigene Praxis voll verwalten.
create policy practices_fk_all on public.practices
  for all using (owner = auth.uid()) with check (owner = auth.uid());
-- MA darf nur seine eigene Praxis sehen (zum Anzeigen des Namens).
create policy practices_ma_select on public.practices
  for select using (id = (select practice_id from public.employees where auth_uid = auth.uid()));

-- ----- EMPLOYEES -----
-- FK verwaltet die Mitarbeiter ihrer Praxis.
create policy employees_fk_all on public.employees
  for all using (public.owns_practice(practice_id))
  with check (public.owns_practice(practice_id));
-- MA darf seinen eigenen Datensatz sehen.
create policy employees_ma_select on public.employees
  for select using (auth_uid = auth.uid());

-- ----- CYCLES -----
-- FK verwaltet alle Zyklen ihrer Praxis.
create policy cycles_fk_all on public.cycles
  for all using (public.owns_practice(practice_id))
  with check (public.owns_practice(practice_id));
-- MA darf NUR seine eigenen Zyklen sehen und auch erst, wenn sie
-- freigegeben (oder gesperrt/abgeschlossen) sind – niemals 'draft'.
create policy cycles_ma_select on public.cycles
  for select using (
    employee_id = public.my_employee_id()
    and status in ('released','locked','completed')
  );

-- ----- FK_RATINGS -----
-- NUR die FK. Es gibt bewusst KEINE Policy für Mitarbeiter -> kein Zugriff.
create policy fk_ratings_fk_all on public.fk_ratings
  for all using (
    public.owns_practice((select practice_id from public.cycles c where c.id = cycle_id))
  ) with check (
    public.owns_practice((select practice_id from public.cycles c where c.id = cycle_id))
  );

-- ----- MA_RATINGS -----
-- FK darf die Selbsteinschätzung lesen/verwalten.
create policy ma_ratings_fk_all on public.ma_ratings
  for all using (
    public.owns_practice((select practice_id from public.cycles c where c.id = cycle_id))
  ) with check (
    public.owns_practice((select practice_id from public.cycles c where c.id = cycle_id))
  );
-- MA darf seine Selbsteinschätzung lesen ...
create policy ma_ratings_ma_select on public.ma_ratings
  for select using (
    (select c.employee_id from public.cycles c where c.id = cycle_id) = public.my_employee_id()
  );
-- ... und nur bearbeiten, solange der Zyklus 'released' (freigegeben) ist.
create policy ma_ratings_ma_write on public.ma_ratings
  for insert with check (
    (select c.employee_id from public.cycles c where c.id = cycle_id) = public.my_employee_id()
    and (select c.status from public.cycles c where c.id = cycle_id) = 'released'
  );
create policy ma_ratings_ma_update on public.ma_ratings
  for update using (
    (select c.employee_id from public.cycles c where c.id = cycle_id) = public.my_employee_id()
    and (select c.status from public.cycles c where c.id = cycle_id) = 'released'
  );

-- ----- CUSTOM_ITEMS -----
create policy custom_fk_all on public.custom_items
  for all using (
    public.owns_practice((select practice_id from public.cycles c where c.id = cycle_id))
  ) with check (
    public.owns_practice((select practice_id from public.cycles c where c.id = cycle_id))
  );
create policy custom_ma_rw on public.custom_items
  for all using (
    (select c.employee_id from public.cycles c where c.id = cycle_id) = public.my_employee_id()
  ) with check (
    (select c.employee_id from public.cycles c where c.id = cycle_id) = public.my_employee_id()
    and author = 'ma'
    and (select c.status from public.cycles c where c.id = cycle_id) = 'released'
  );

-- Fertig. Wenn dieser Block ohne Fehler durchläuft, ist die Datenbank bereit.
