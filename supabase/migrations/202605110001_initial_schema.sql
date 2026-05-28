create extension if not exists pgcrypto;

create type user_role as enum ('passenger', 'driver', 'admin');
create type trip_status as enum ('scheduled', 'running', 'completed', 'cancelled');
create type booking_status as enum ('pending', 'completed', 'cancelled');
create type booking_payment_status as enum ('unpaid', 'processing', 'paid', 'refunded');
create type payment_method as enum ('wechat', 'alipay', 'manual');
create type payment_status as enum ('processing', 'paid', 'failed', 'refunded');
create type vehicle_status as enum ('idle', 'running', 'maintenance');
create type dispatch_demand_status as enum ('pending', 'assigned');
create type notification_type as enum ('booking', 'payment', 'credit', 'system');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  phone text not null unique,
  role user_role not null,
  credit_score integer not null default 100 check (credit_score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table vehicles (
  id uuid primary key default gen_random_uuid(),
  plate_no text not null unique,
  model text not null,
  seat_count integer not null check (seat_count > 0),
  status vehicle_status not null default 'idle',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table drivers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) on delete set null,
  name text not null,
  phone text not null unique,
  license_no text not null unique,
  bound_vehicle_id uuid unique references vehicles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table trips (
  id uuid primary key default gen_random_uuid(),
  trip_no text not null unique,
  route_name text not null,
  origin text not null,
  destination text not null,
  vehicle_id uuid references vehicles(id) on delete set null,
  driver_id uuid references drivers(id) on delete set null,
  departure_time timestamptz not null,
  total_seats integer not null check (total_seats > 0),
  booked_seats integer not null default 0 check (booked_seats >= 0),
  fare numeric(10, 2) not null default 0 check (fare >= 0),
  distance_km numeric(10, 2) not null default 0 check (distance_km >= 0),
  status trip_status not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (booked_seats <= total_seats)
);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  trip_id uuid not null references trips(id) on delete cascade,
  seat_no integer not null check (seat_no > 0),
  status booking_status not null default 'pending',
  fare numeric(10, 2) not null default 0 check (fare >= 0),
  payment_status booking_payment_status not null default 'unpaid',
  payment_method payment_method,
  credit_penalty integer not null default 0 check (credit_penalty >= 0),
  pickup_point text,
  passenger_lat numeric(10, 6),
  passenger_lng numeric(10, 6),
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  amount numeric(10, 2) not null check (amount >= 0),
  method payment_method not null,
  status payment_status not null default 'processing',
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table dispatch_demands (
  id uuid primary key default gen_random_uuid(),
  route_name text not null,
  origin text not null,
  destination text not null,
  passenger_count integer not null check (passenger_count > 0),
  departure_time timestamptz not null,
  status dispatch_demand_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table dispatch_plans (
  id uuid primary key default gen_random_uuid(),
  demand_id uuid not null references dispatch_demands(id) on delete cascade,
  route_name text not null,
  vehicle_id uuid not null references vehicles(id) on delete restrict,
  driver_id uuid not null references drivers(id) on delete restrict,
  passenger_count integer not null check (passenger_count > 0),
  departure_time timestamptz not null,
  load_rate numeric(5, 4) not null check (load_rate >= 0),
  is_ai_generated boolean not null default false,
  is_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table vehicle_locations (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  trip_no text not null,
  driver_id uuid references drivers(id) on delete set null,
  lat numeric(10, 6) not null,
  lng numeric(10, 6) not null,
  speed numeric(6, 2) not null default 0,
  updated_at timestamptz not null default now()
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  message text not null,
  type notification_type not null default 'system',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index bookings_user_id_idx on bookings(user_id);
create index bookings_trip_id_idx on bookings(trip_id);
create unique index bookings_active_seat_unique_idx on bookings(trip_id, seat_no) where status <> 'cancelled';
create unique index bookings_active_user_trip_unique_idx on bookings(user_id, trip_id) where status <> 'cancelled';
create index trips_departure_time_idx on trips(departure_time);
create index vehicle_locations_vehicle_id_idx on vehicle_locations(vehicle_id);
create index notifications_user_id_idx on notifications(user_id);

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_set_updated_at before update on profiles for each row execute function set_updated_at();
create trigger vehicles_set_updated_at before update on vehicles for each row execute function set_updated_at();
create trigger drivers_set_updated_at before update on drivers for each row execute function set_updated_at();
create trigger trips_set_updated_at before update on trips for each row execute function set_updated_at();
create trigger bookings_set_updated_at before update on bookings for each row execute function set_updated_at();
create trigger dispatch_demands_set_updated_at before update on dispatch_demands for each row execute function set_updated_at();
create trigger dispatch_plans_set_updated_at before update on dispatch_plans for each row execute function set_updated_at();

create or replace function current_user_role()
returns user_role as $$
  select role from profiles where id = auth.uid();
$$ language sql stable security definer set search_path = public;

create or replace function is_admin()
returns boolean as $$
  select current_user_role() = 'admin'::user_role;
$$ language sql stable security definer set search_path = public;

create or replace function is_driver()
returns boolean as $$
  select current_user_role() = 'driver'::user_role;
$$ language sql stable security definer set search_path = public;

alter table profiles enable row level security;
alter table vehicles enable row level security;
alter table drivers enable row level security;
alter table trips enable row level security;
alter table bookings enable row level security;
alter table payments enable row level security;
alter table dispatch_demands enable row level security;
alter table dispatch_plans enable row level security;
alter table vehicle_locations enable row level security;
alter table notifications enable row level security;

create policy "profiles_select_own_or_admin" on profiles for select using (id = auth.uid() or is_admin());
create policy "profiles_update_own_or_admin" on profiles for update using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());

create policy "vehicles_select_authenticated" on vehicles for select using (auth.role() = 'authenticated');
create policy "vehicles_write_admin" on vehicles for all using (is_admin()) with check (is_admin());

create policy "drivers_select_authenticated" on drivers for select using (auth.role() = 'authenticated');
create policy "drivers_write_admin" on drivers for all using (is_admin()) with check (is_admin());

create policy "trips_select_authenticated" on trips for select using (auth.role() = 'authenticated');
create policy "trips_write_admin" on trips for all using (is_admin()) with check (is_admin());
create policy "trips_update_assigned_driver" on trips for update using (
  exists (
    select 1 from drivers d where d.id = trips.driver_id and d.profile_id = auth.uid()
  )
) with check (
  exists (
    select 1 from drivers d where d.id = trips.driver_id and d.profile_id = auth.uid()
  )
);

create policy "bookings_select_owner_driver_admin" on bookings for select using (
  user_id = auth.uid()
  or is_admin()
  or exists (
    select 1
    from trips t
    join drivers d on d.id = t.driver_id
    where t.id = bookings.trip_id and d.profile_id = auth.uid()
  )
);
create policy "bookings_insert_owner" on bookings for insert with check (user_id = auth.uid());
create policy "bookings_update_owner_or_admin" on bookings for update using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid() or is_admin());

create policy "payments_select_owner_or_admin" on payments for select using (
  is_admin()
  or exists (select 1 from bookings b where b.id = payments.booking_id and b.user_id = auth.uid())
);
create policy "payments_insert_owner" on payments for insert with check (
  exists (select 1 from bookings b where b.id = payments.booking_id and b.user_id = auth.uid())
);
create policy "payments_update_owner_or_admin" on payments for update using (
  is_admin()
  or exists (select 1 from bookings b where b.id = payments.booking_id and b.user_id = auth.uid())
) with check (
  is_admin()
  or exists (select 1 from bookings b where b.id = payments.booking_id and b.user_id = auth.uid())
);

create policy "dispatch_demands_select_admin" on dispatch_demands for select using (is_admin());
create policy "dispatch_demands_write_admin" on dispatch_demands for all using (is_admin()) with check (is_admin());

create policy "dispatch_plans_select_admin" on dispatch_plans for select using (is_admin());
create policy "dispatch_plans_write_admin" on dispatch_plans for all using (is_admin()) with check (is_admin());

create policy "vehicle_locations_select_authenticated" on vehicle_locations for select using (auth.role() = 'authenticated');
create policy "vehicle_locations_insert_driver_or_admin" on vehicle_locations for insert with check (is_driver() or is_admin());
create policy "vehicle_locations_update_driver_or_admin" on vehicle_locations for update using (is_driver() or is_admin()) with check (is_driver() or is_admin());

create policy "notifications_select_owner_or_admin" on notifications for select using (user_id = auth.uid() or is_admin());
create policy "notifications_insert_owner_or_admin" on notifications for insert with check (user_id = auth.uid() or is_admin());
create policy "notifications_update_owner_or_admin" on notifications for update using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid() or is_admin());
