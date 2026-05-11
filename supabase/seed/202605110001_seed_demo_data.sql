-- Run this after creating three Supabase Auth users with these emails:
-- 13800000001@school-bus.local / 123456
-- 13800000002@school-bus.local / 123456
-- 13800000003@school-bus.local / 123456

with auth_profiles as (
  select id, email
  from auth.users
  where email in (
    '13800000001@school-bus.local',
    '13800000002@school-bus.local',
    '13800000003@school-bus.local'
  )
)
insert into profiles (id, name, phone, role, credit_score)
select
  id,
  case email
    when '13800000001@school-bus.local' then '张同学'
    when '13800000002@school-bus.local' then '王师傅'
    when '13800000003@school-bus.local' then '李管理员'
  end,
  split_part(email, '@', 1),
  case email
    when '13800000001@school-bus.local' then 'passenger'::user_role
    when '13800000002@school-bus.local' then 'driver'::user_role
    when '13800000003@school-bus.local' then 'admin'::user_role
  end,
  case email
    when '13800000001@school-bus.local' then 96
    else 100
  end
from auth_profiles
on conflict (id) do update set
  name = excluded.name,
  phone = excluded.phone,
  role = excluded.role,
  credit_score = excluded.credit_score;

insert into vehicles (id, plate_no, model, seat_count, status) values
  ('00000000-0000-0000-0000-000000000101', '校A·1028', '宇通 ZK6908', 45, 'running'),
  ('00000000-0000-0000-0000-000000000102', '校A·2036', '金龙 XMQ6802', 38, 'idle'),
  ('00000000-0000-0000-0000-000000000103', '校A·3099', '中通 LCK6720', 32, 'running'),
  ('00000000-0000-0000-0000-000000000104', '校A·4017', '比亚迪 K8', 28, 'maintenance')
on conflict (id) do update set
  plate_no = excluded.plate_no,
  model = excluded.model,
  seat_count = excluded.seat_count,
  status = excluded.status;

insert into drivers (id, profile_id, name, phone, license_no, bound_vehicle_id)
select
  '00000000-0000-0000-0000-000000000201'::uuid,
  p.id,
  '王师傅',
  '13800000002',
  'A1-310101-8891',
  '00000000-0000-0000-0000-000000000101'::uuid
from profiles p
where p.phone = '13800000002'
on conflict (id) do update set
  profile_id = excluded.profile_id,
  name = excluded.name,
  phone = excluded.phone,
  license_no = excluded.license_no,
  bound_vehicle_id = excluded.bound_vehicle_id;

insert into drivers (id, name, phone, license_no, bound_vehicle_id) values
  ('00000000-0000-0000-0000-000000000202', '赵师傅', '13800001002', 'A1-310101-2710', '00000000-0000-0000-0000-000000000102'),
  ('00000000-0000-0000-0000-000000000203', '钱师傅', '13800001003', 'A1-310101-5532', '00000000-0000-0000-0000-000000000103')
on conflict (id) do update set
  name = excluded.name,
  phone = excluded.phone,
  license_no = excluded.license_no,
  bound_vehicle_id = excluded.bound_vehicle_id;

insert into trips (
  id, trip_no, route_name, origin, destination, vehicle_id, driver_id,
  departure_time, total_seats, booked_seats, fare, distance_km, status
) values
  ('00000000-0000-0000-0000-000000000301', 'D-20260501-01', '大学城早班线', '南门学生公寓', '综合教学楼', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201', now() + interval '1 hour 40 minutes', 45, 18, 3, 8.6, 'scheduled'),
  ('00000000-0000-0000-0000-000000000302', 'D-20260501-02', '科技园通勤线', '图书馆广场', '科技园东门', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000202', now() + interval '3 hours 15 minutes', 38, 29, 5, 12.4, 'scheduled'),
  ('00000000-0000-0000-0000-000000000303', 'D-20260501-03', '晚间返校线', '附属医院站', '北区宿舍', '00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000203', now() + interval '6 hours 20 minutes', 32, 12, 4, 15.8, 'scheduled'),
  ('00000000-0000-0000-0000-000000000304', 'D-20260501-04', '校区环线', '体育馆', '创新中心', '00000000-0000-0000-0000-000000000104', null, now() + interval '1 day 1 hour', 28, 28, 2, 4.2, 'scheduled')
on conflict (id) do update set
  departure_time = excluded.departure_time,
  booked_seats = excluded.booked_seats,
  status = excluded.status;

insert into dispatch_demands (id, route_name, origin, destination, passenger_count, departure_time, status) values
  ('00000000-0000-0000-0000-000000000401', '大学城早班线', '南门学生公寓', '综合教学楼', 36, now() + interval '1 hour 20 minutes', 'pending'),
  ('00000000-0000-0000-0000-000000000402', '科技园通勤线', '图书馆广场', '科技园东门', 28, now() + interval '2 hours 10 minutes', 'pending'),
  ('00000000-0000-0000-0000-000000000403', '晚间返校线', '附属医院站', '北区宿舍', 18, now() + interval '6 hours', 'pending')
on conflict (id) do update set
  passenger_count = excluded.passenger_count,
  departure_time = excluded.departure_time,
  status = excluded.status;

insert into vehicle_locations (id, vehicle_id, trip_no, driver_id, lat, lng, speed, updated_at) values
  ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000101', 'D-20260501-01', '00000000-0000-0000-0000-000000000201', 31.2304, 121.4737, 32, now() - interval '12 seconds'),
  ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000103', 'D-20260501-03', '00000000-0000-0000-0000-000000000203', 31.2378, 121.4821, 28, now() - interval '21 seconds')
on conflict (id) do update set
  lat = excluded.lat,
  lng = excluded.lng,
  speed = excluded.speed,
  updated_at = excluded.updated_at;
