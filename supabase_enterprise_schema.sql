-- ==============================================================================
-- TRAVEL-GO ENTERPRISE OTA CLOUD POSTGRESQL SCHEMA (SUPABASE)
-- Fully compliant with TravelGO Master PRD (54 Features, Roles: Customer/Partner/Admin)
-- Features: Destinations, Services, Rooms, Flights, Buses, Tours, Bookings,
--           Payments, Cancellations, AI Planner, Favorites, Reviews, Vouchers, RLS
-- ==============================================================================

-- 0. EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ==============================================================================
-- 1. PROFILES & USER IDENTITY (Customer, Partner, Admin)
-- ==============================================================================
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  phone text,
  email text,
  role text default 'customer' check (role in ('customer', 'partner', 'admin')),
  avatar_url text,
  address text,
  created_at timestamptz default timezone('utc'::text, now()) not null,
  updated_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Trigger auto-creating profile when user signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'role', 'customer')
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    phone = excluded.phone;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ==============================================================================
-- 2. TRAVELERS (My Travelers Management for Quick Checkout)
-- ==============================================================================
create table if not exists public.travelers (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  full_name text not null,
  date_of_birth date,
  gender text check (gender in ('male', 'female', 'other')),
  nationality text default 'Việt Nam',
  id_card_masked text, -- Masked: 079099****88
  is_primary boolean default false,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.travelers enable row level security;

create policy "Users can view own travelers"
  on public.travelers for select using (auth.uid() = user_id);

create policy "Users can insert own travelers"
  on public.travelers for insert with check (auth.uid() = user_id);

create policy "Users can update own travelers"
  on public.travelers for update using (auth.uid() = user_id);

create policy "Users can delete own travelers"
  on public.travelers for delete using (auth.uid() = user_id);


-- ==============================================================================
-- 3. PARTNER PROFILES (Hotel, Bus, Tour Suppliers)
-- ==============================================================================
create table if not exists public.partner_profiles (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade unique not null,
  business_name text not null,
  business_type text check (business_type in ('hotel', 'bus', 'tour', 'combo', 'airline')),
  tax_code text,
  contact_email text,
  contact_phone text,
  address text,
  bank_name text,
  bank_account_number text,
  bank_account_name text,
  status text default 'pending' check (status in ('pending', 'approved', 'rejected')),
  commission_rate numeric default 0.10,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.partner_profiles enable row level security;

create policy "Approved partners are viewable by everyone"
  on public.partner_profiles for select using (true);

create policy "Partners can update own business info"
  on public.partner_profiles for update using (auth.uid() = user_id);


-- ==============================================================================
-- 4. DESTINATIONS (14 Key Locations in Vietnam)
-- ==============================================================================
create table if not exists public.destinations (
  id text primary key, -- slug: da-nang, da-lat, phu-quoc, ...
  name text not null,
  region text not null check (region in ('Bắc', 'Trung', 'Nam', 'Tây Nguyên')),
  description text,
  image_url text,
  weather_cached_temp numeric default 26.0,
  is_popular boolean default true,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.destinations enable row level security;
create policy "Destinations are viewable by everyone" on public.destinations for select using (true);


-- ==============================================================================
-- 5. SERVICES (Base Polymorphic OTA Catalog)
-- ==============================================================================
create table if not exists public.services (
  id text primary key,
  partner_id uuid references public.partner_profiles(id) on delete set null,
  destination_id text references public.destinations(id) on delete cascade not null,
  service_type text not null check (service_type in ('hotel', 'flight', 'bus', 'tour', 'combo')),
  title text not null,
  description text,
  location text,
  base_price numeric not null default 0,
  rating numeric default 5.0,
  review_count int default 0,
  cancellation_policy text default 'Miễn phí hủy trước 48h',
  is_active boolean default true,
  is_featured boolean default false,
  images text[] default '{}',
  amenities text[] default '{}',
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.services enable row level security;
create policy "Active services viewable by everyone" on public.services for select using (is_active = true);


-- ==============================================================================
-- 6. ROOMS (Hotel Rooms & Inventory)
-- ==============================================================================
create table if not exists public.rooms (
  id uuid default gen_random_uuid() primary key,
  service_id text references public.services(id) on delete cascade not null,
  room_type text not null,
  capacity_adults int default 2,
  capacity_children int default 1,
  bed_type text default '1 Giường đôi King',
  price_per_night numeric not null,
  total_rooms int default 10,
  available_rooms int default 8,
  cancellation_policy text default 'Miễn phí hủy trước 48h',
  amenities text[] default '{}',
  images text[] default '{}',
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.rooms enable row level security;
create policy "Rooms viewable by everyone" on public.rooms for select using (true);


-- ==============================================================================
-- 7. FLIGHT SCHEDULES (Airlines & Routes)
-- ==============================================================================
create table if not exists public.flight_schedules (
  id uuid default gen_random_uuid() primary key,
  service_id text references public.services(id) on delete cascade not null,
  airline text not null,
  flight_number text not null,
  origin text not null,
  destination text not null,
  departure_time timestamptz not null,
  arrival_time timestamptz not null,
  duration_minutes int default 75,
  stops int default 0,
  baggage_kg int default 20,
  fare_class text default 'Eco',
  price numeric not null,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.flight_schedules enable row level security;
create policy "Flights viewable by everyone" on public.flight_schedules for select using (true);


-- ==============================================================================
-- 8. BUS SCHEDULES & SEATS (Bus Operator & Seat Layout)
-- ==============================================================================
create table if not exists public.bus_schedules (
  id uuid default gen_random_uuid() primary key,
  service_id text references public.services(id) on delete cascade not null,
  operator_name text not null,
  bus_type text default 'Limousine Giường Phòng 34 chỗ',
  origin text not null,
  destination text not null,
  pickup_point text,
  dropoff_point text,
  departure_time timestamptz not null,
  arrival_time timestamptz not null,
  price numeric not null,
  total_seats int default 34,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.bus_schedules enable row level security;
create policy "Buses viewable by everyone" on public.bus_schedules for select using (true);

create table if not exists public.bus_seats (
  id uuid default gen_random_uuid() primary key,
  bus_schedule_id uuid references public.bus_schedules(id) on delete cascade not null,
  seat_code text not null,
  floor int default 1,
  status text default 'available' check (status in ('available', 'selected', 'occupied')),
  unique(bus_schedule_id, seat_code)
);

alter table public.bus_seats enable row level security;
create policy "Seats viewable by everyone" on public.bus_seats for select using (true);


-- ==============================================================================
-- 9. TOUR PACKAGES
-- ==============================================================================
create table if not exists public.tour_packages (
  id uuid default gen_random_uuid() primary key,
  service_id text references public.services(id) on delete cascade not null,
  duration_days int default 1,
  meeting_point text,
  itinerary_json jsonb default '[]'::jsonb,
  included_services text[] default '{}',
  excluded_services text[] default '{}',
  max_participants int default 25,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.tour_packages enable row level security;
create policy "Tours viewable by everyone" on public.tour_packages for select using (true);


-- ==============================================================================
-- 10. VOUCHERS & LOYALTY
-- ==============================================================================
create table if not exists public.vouchers (
  id text primary key, -- Code: HELLO25, SUMMER2026
  title text not null,
  discount_amount numeric default 0,
  discount_percent numeric default 0,
  min_order_value numeric default 0,
  max_discount numeric,
  applicable_services text[] default '{hotel, flight, bus, tour, combo}',
  expiry_date timestamptz not null,
  is_active boolean default true,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.vouchers enable row level security;
create policy "Active vouchers viewable by everyone" on public.vouchers for select using (is_active = true);

create table if not exists public.user_vouchers (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  voucher_id text references public.vouchers(id) on delete cascade not null,
  status text default 'available' check (status in ('available', 'used', 'expired')),
  used_at timestamptz,
  unique(user_id, voucher_id)
);

alter table public.user_vouchers enable row level security;
create policy "Users view own vouchers" on public.user_vouchers for select using (auth.uid() = user_id);
create policy "Users claim voucher" on public.user_vouchers for insert with check (auth.uid() = user_id);


-- ==============================================================================
-- 11. BOOKINGS & CHECKOUT
-- ==============================================================================
create table if not exists public.bookings (
  id uuid default gen_random_uuid() primary key,
  booking_code text unique not null,
  user_id uuid references auth.users on delete cascade not null,
  total_amount numeric not null default 0,
  discount_amount numeric default 0,
  voucher_id text references public.vouchers(id) on delete set null,
  status text default 'pending' check (status in ('pending', 'confirmed', 'completed', 'cancelled')),
  contact_name text not null,
  contact_phone text not null,
  contact_email text not null,
  special_requests text,
  created_at timestamptz default timezone('utc'::text, now()) not null,
  updated_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.bookings enable row level security;

create policy "Users view own bookings" on public.bookings for select using (auth.uid() = user_id);
create policy "Users create own bookings" on public.bookings for insert with check (auth.uid() = user_id);
create policy "Users update own bookings" on public.bookings for update using (auth.uid() = user_id);

create table if not exists public.booking_items (
  id uuid default gen_random_uuid() primary key,
  booking_id uuid references public.bookings(id) on delete cascade not null,
  service_id text references public.services(id) on delete set null,
  service_type text not null check (service_type in ('hotel', 'flight', 'bus', 'tour', 'combo')),
  unit_price numeric not null default 0,
  quantity int default 1,
  start_date timestamptz,
  end_date timestamptz,
  details_json jsonb default '{}'::jsonb,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.booking_items enable row level security;
create policy "Users view own booking items" on public.booking_items for select using (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
);
create policy "Users insert booking items" on public.booking_items for insert with check (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
);


-- ==============================================================================
-- 12. PAYMENTS & CANCELLATIONS
-- ==============================================================================
create table if not exists public.payments (
  id uuid default gen_random_uuid() primary key,
  booking_id uuid references public.bookings(id) on delete cascade unique not null,
  payment_method text not null check (payment_method in ('vietqr', 'momo', 'vnpay', 'credit_card')),
  amount numeric not null,
  status text default 'pending' check (status in ('pending', 'success', 'failed', 'expired')),
  transaction_code text,
  qr_code_url text,
  expired_at timestamptz default (timezone('utc'::text, now()) + interval '15 minutes'),
  paid_at timestamptz,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.payments enable row level security;
create policy "Users view own payments" on public.payments for select using (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
);
create policy "Users create payment" on public.payments for insert with check (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
);

create table if not exists public.cancellations (
  id uuid default gen_random_uuid() primary key,
  booking_id uuid references public.bookings(id) on delete cascade unique not null,
  reason text not null,
  cancellation_fee numeric default 0,
  refund_amount numeric default 0,
  status text default 'pending' check (status in ('pending', 'processed', 'rejected')),
  created_at timestamptz default timezone('utc'::text, now()) not null,
  processed_at timestamptz
);

alter table public.cancellations enable row level security;
create policy "Users view own cancellations" on public.cancellations for select using (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
);
create policy "Users request cancellation" on public.cancellations for insert with check (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
);


-- ==============================================================================
-- 13. TRIPS & AI ITINERARY (AI Travel Planner & Multi-service Trip Builder)
-- ==============================================================================
create table if not exists public.trips (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  title text not null,
  destination_name text not null,
  num_days int default 3,
  budget_total numeric default 0,
  start_date timestamptz,
  end_date timestamptz,
  status text default 'planning' check (status in ('planning', 'booked', 'completed')),
  ai_plan_data jsonb default '{}'::jsonb,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.trips enable row level security;
create policy "Users view own trips" on public.trips for select using (auth.uid() = user_id);
create policy "Users create own trips" on public.trips for insert with check (auth.uid() = user_id);
create policy "Users update own trips" on public.trips for update using (auth.uid() = user_id);
create policy "Users delete own trips" on public.trips for delete using (auth.uid() = user_id);

create table if not exists public.trip_activities (
  id uuid default gen_random_uuid() primary key,
  trip_id uuid references public.trips(id) on delete cascade not null,
  day_number int not null default 1,
  start_time text not null,
  end_time text,
  title text not null,
  description text,
  service_id text references public.services(id) on delete set null,
  cost numeric default 0,
  has_conflict boolean default false,
  conflict_reason text,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.trip_activities enable row level security;
create policy "Users manage own trip activities" on public.trip_activities for all using (
  exists (select 1 from public.trips t where t.id = trip_id and t.user_id = auth.uid())
);


-- ==============================================================================
-- 14. ENGAGEMENT: FAVORITES, RECENTLY VIEWED, NOTIFICATIONS
-- ==============================================================================
create table if not exists public.favorites (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  service_id text references public.services(id) on delete cascade not null,
  service_type text default 'hotel',
  created_at timestamptz default timezone('utc'::text, now()) not null,
  unique(user_id, service_id)
);

alter table public.favorites enable row level security;
create policy "Users view own favorites" on public.favorites for select using (auth.uid() = user_id);
create policy "Users add favorites" on public.favorites for insert with check (auth.uid() = user_id);
create policy "Users remove favorites" on public.favorites for delete using (auth.uid() = user_id);

create table if not exists public.recently_viewed (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  service_id text references public.services(id) on delete cascade not null,
  viewed_at timestamptz default timezone('utc'::text, now()) not null,
  unique(user_id, service_id)
);

alter table public.recently_viewed enable row level security;
create policy "Users view own recently viewed" on public.recently_viewed for select using (auth.uid() = user_id);
create policy "Users upsert recently viewed" on public.recently_viewed for all using (auth.uid() = user_id);

create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  category text default 'promotion' check (category in ('booking', 'payment', 'promotion', 'voucher', 'review')),
  title text not null,
  body text not null,
  is_read boolean default false,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.notifications enable row level security;
create policy "Users view own notifications" on public.notifications for select using (auth.uid() = user_id);
create policy "Users update own notifications" on public.notifications for update using (auth.uid() = user_id);


-- ==============================================================================
-- 15. REVIEWS (Rule 3A: Only completed bookings can be reviewed)
-- ==============================================================================
create table if not exists public.reviews (
  id uuid default gen_random_uuid() primary key,
  booking_id uuid references public.bookings(id) on delete cascade unique not null,
  service_id text references public.services(id) on delete cascade not null,
  user_id uuid references auth.users on delete cascade not null,
  rating numeric check (rating >= 1 and rating <= 5) not null,
  comment text not null,
  images text[] default '{}',
  partner_reply text,
  partner_replied_at timestamptz,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

alter table public.reviews enable row level security;
create policy "Reviews viewable by everyone" on public.reviews for select using (true);

-- Enforce Rule 3A: check that booking status is 'completed'
create or replace function public.check_review_eligibility()
returns trigger as $$
declare
  b_status text;
  b_user uuid;
begin
  select status, user_id into b_status, b_user from public.bookings where id = new.booking_id;
  if b_status is null or b_status != 'completed' then
    raise exception 'Chỉ có thể đánh giá những chuyến đi đã hoàn thành (status = completed).';
  end if;
  if b_user != new.user_id then
    raise exception 'Bạn chỉ có thể đánh giá đơn đặt chỗ của chính mình.';
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_check_review on public.reviews;
create trigger trigger_check_review
  before insert on public.reviews
  for each row execute procedure public.check_review_eligibility();

create policy "Eligible users can insert reviews"
  on public.reviews for insert with check (auth.uid() = user_id);


-- ==============================================================================
-- 16. SEED DATA (Rule 2A: Realistic Vietnam Mock Data for TravelGO)
-- ==============================================================================

-- 14 Destinations
insert into public.destinations (id, name, region, description, image_url, weather_cached_temp)
values
  ('da-nang', 'Đà Nẵng', 'Trung', 'Thành phố đáng sống với biển Mỹ Khê và Cầu Vàng Bà Nà Hills', 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800', 28.5),
  ('da-lat', 'Đà Lạt', 'Tây Nguyên', 'Thành phố ngàn hoa với khí hậu se lạnh và cảnh sắc thơ mộng', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800', 20.0),
  ('phu-quoc', 'Phú Quốc', 'Nam', 'Đảo ngọc hoang sơ với bãi biển cát trắng và hoàng hôn rực rỡ', 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800', 30.0),
  ('nha-trang', 'Nha Trang', 'Trung', 'Vịnh biển tuyệt đẹp với nhiều rạn san hô và hải sản tươi sống', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800', 29.0),
  ('hoi-an', 'Hội An', 'Trung', 'Phố cổ đèn lồng di sản thế giới lung linh bên dòng sông Hoài', 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800', 28.0),
  ('ha-long', 'Hạ Long', 'Bắc', 'Kỳ quan thiên nhiên thế giới với hàng ngàn đảo đá vôi kỳ vĩ', 'https://images.unsplash.com/photo-1528181304800-259b08848526?w=800', 24.5),
  ('sa-pa', 'Sa Pa', 'Bắc', 'Thung lũng Mường Hoa, đỉnh Fansipan và ruộng bậc thang hùng vĩ', 'https://images.unsplash.com/photo-1570789210967-2cac24afeb00?w=800', 16.0),
  ('hue', 'Huế', 'Trung', 'Cố đô ngàn năm văn hiến bên bờ sông Hương êm đềm', 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800', 27.0),
  ('vung-tau', 'Vũng Tàu', 'Nam', 'Thành phố biển gần Sài Gòn, hải sản tươi ngon và ngọn hải đăng', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800', 29.5),
  ('quy-nhon', 'Quy Nhơn', 'Trung', 'Biển xanh hoang sơ Kỳ Co - Eo Gió với cảnh quan ngoạn mục', 'https://images.unsplash.com/photo-1544644181-1484b3fdfc62?w=800', 28.0),
  ('phan-thiet', 'Phan Thiết', 'Nam', 'Đồi cát bay Mũi Né và các khu nghỉ dưỡng ven biển đẳng cấp', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800', 30.5),
  ('can-tho', 'Cần Thơ', 'Nam', 'Thủ phủ miền Tây sông nước với chợ nổi Cái Răng trứ danh', 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800', 29.0),
  ('ha-noi', 'Hà Nội', 'Bắc', 'Thủ đô nghìn năm văn hiến, 36 phố phường và ẩm thực tinh hoa', 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800', 25.0),
  ('tphcm', 'TP. Hồ Chí Minh', 'Nam', 'Đô thị năng động nhất Việt Nam, trung tâm thương mại và dịch vụ', 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800', 31.0)
on conflict (id) do nothing;

-- Core Services
insert into public.services (id, destination_id, service_type, title, description, location, base_price, rating, review_count, cancellation_policy, is_featured, images, amenities)
values
  ('furama-resort-da-nang', 'da-nang', 'hotel', 'Furama Resort Đà Nẵng', 'Khu nghỉ dưỡng 5 sao ven biển Mỹ Khê với hồ bơi vô cực và ẩm thực đa dạng.', 'Võ Nguyên Giáp, Ngũ Hành Sơn, Đà Nẵng', 2200000, 4.8, 128, 'Miễn phí hủy trước 48h', true,
   ARRAY['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800', 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800'],
   ARRAY['Hồ bơi vô cực', 'Giáp biển', 'Bữa sáng miễn phí', 'Spa & Massage', 'Wifi tốc độ cao']),

  ('edensee-resort-da-lat', 'da-lat', 'hotel', 'Dalat Edensee Lake Resort & Spa', 'Nghỉ dưỡng phong cách châu Âu bên bờ hồ Tuyền Lâm mộng mơ.', 'Khu du lịch Hồ Tuyền Lâm, Đà Lạt', 1850000, 4.7, 95, 'Miễn phí hủy trước 24h', true,
   ARRAY['https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800'],
   ARRAY['Bên hồ', 'Bữa sáng', 'Xe đưa đón', 'Sân tennis']),

  ('vinpearl-resort-phu-quoc', 'phu-quoc', 'hotel', 'Vinpearl Resort & Spa Phú Quốc', 'Khu nghỉ dưỡng sang trọng với bãi biển riêng và công viên nước.', 'Bãi Dài, Gành Dầu, Phú Quốc', 2900000, 4.9, 310, 'Miễn phí hủy trước 72h', true,
   ARRAY['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800'],
   ARRAY['Bãi biển riêng', 'Công viên nước', 'Hồ bơi lớn', 'Buffet quốc tế']),

  ('vietjet-sgn-dad-01', 'da-nang', 'flight', 'Chuyến bay VietJet Air VJ624 (SGN - DAD)', 'Chuyến bay thẳng khởi hành từ sân bay Tân Sơn Nhất đến Đà Nẵng.', 'Sân bay Tân Sơn Nhất (SGN)', 950000, 4.5, 412, 'Hỗ trợ đổi ngày bay có phí', true,
   ARRAY['https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=800'],
   ARRAY['Bay thẳng', 'Hành lý xách tay 7kg', 'Ghế da êm ái']),

  ('futa-bus-sgn-dalat-01', 'da-lat', 'bus', 'Xe khách Phương Trang Limousine (SGN - Đà Lạt)', 'Xe phòng nằm cao cấp đời mới, nước uống, wifi và sạc điện thoại.', 'Bến xe Miền Tây / Miền Đông', 300000, 4.6, 520, 'Miễn phí đổi vé trước 12h', false,
   ARRAY['https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=800'],
   ARRAY['Giường nằm VIP', 'Ổ cắm sạc', 'Nước suối & khăn lạnh', 'Điều hòa']),

  ('tour-bana-hills-01', 'da-nang', 'tour', 'Tour Bà Nà Hills - Cầu Vàng Trọn Gói 1 Ngày', 'Khám phá Cầu Vàng huyền thoại, Làng Pháp và thưởng thức buffet trưa 100 món.', 'Đón tại khách sạn trung tâm Đà Nẵng', 1150000, 4.9, 840, 'Miễn phí hủy trước 24h', true,
   ARRAY['https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800'],
   ARRAY['Vé cáp treo khứ hồi', 'Buffet trưa', 'Hướng dẫn viên nhiệt tình', 'Xe đưa đón tận nơi'])
on conflict (id) do nothing;

-- Rooms for Furama Resort
insert into public.rooms (service_id, room_type, capacity_adults, capacity_children, bed_type, price_per_night, total_rooms, available_rooms, amenities, images)
values
  ('furama-resort-da-nang', 'Phòng Deluxe Hướng Biển (Ocean View)', 2, 1, '1 Giường đôi King size', 2200000, 15, 12,
   ARRAY['Ban công riêng', 'Bồn tắm', 'View biển trực diện', 'Minibar', 'Máy pha cafe'],
   ARRAY['https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800']),
  ('furama-resort-da-nang', 'Phòng Suite Gia Đình 2 Phòng Ngủ', 4, 2, '2 Giường King + 1 Giường đơn', 4500000, 5, 3,
   ARRAY['Phòng khách rộng', 'Bếp tiện nghi', 'Hồ bơi riêng', 'View vườn nhiệt đới'],
   ARRAY['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800'])
on conflict do nothing;

-- Bus Seats for Phương Trang
do $$
declare
  b_id uuid;
  seat_name text;
begin
  -- create bus schedule if not exists
  if not exists (select 1 from public.bus_schedules where service_id = 'futa-bus-sgn-dalat-01') then
    insert into public.bus_schedules (service_id, operator_name, bus_type, origin, destination, departure_time, arrival_time, price, total_seats)
    values ('futa-bus-sgn-dalat-01', 'Phương Trang FUTA Bus Lines', 'Limousine Giường Phòng', 'TP. Hồ Chí Minh', 'Đà Lạt',
            timezone('utc'::text, now()) + interval '1 day', timezone('utc'::text, now()) + interval '1 day 6 hours', 300000, 10)
    returning id into b_id;

    -- populate sample seats
    for i in 1..10 loop
      seat_name := 'A0' || i;
      insert into public.bus_seats (bus_schedule_id, seat_code, floor, status)
      values (b_id, seat_name, 1, case when i in (2, 5) then 'occupied' else 'available' end);
    end loop;
  end if;
end $$;

-- Vouchers
insert into public.vouchers (id, title, discount_amount, discount_percent, min_order_value, max_discount, expiry_date, is_active)
values
  ('HELLO25', 'Ưu đãi chào bạn mới mừng năm 2026', 200000, 0, 1000000, 200000, timezone('utc'::text, now()) + interval '90 days', true),
  ('SUMMER2026', 'Ưu đãi hè rực rỡ giảm 10% toàn bộ dịch vụ', 0, 10, 2000000, 500000, timezone('utc'::text, now()) + interval '60 days', true),
  ('MINH150', 'Mã tri ân khách hàng thân thiết TravelGO', 150000, 0, 800000, 150000, timezone('utc'::text, now()) + interval '30 days', true)
on conflict (id) do nothing;
