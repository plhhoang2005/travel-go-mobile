-- Member 3: public place reviews.
-- place_id is the published catalogue string (for example da-nang/my-khe).
-- The current schema has no public places table, so it is intentionally not
-- declared as a foreign key. The client/backend validates it against the
-- published catalogue before reading or inserting.

begin;

create table if not exists public.place_reviews (
  id uuid primary key default gen_random_uuid(),
  place_id text not null check (length(trim(place_id)) between 1 and 200),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- Display-only snapshot. Authorization always uses user_id/auth.uid().
  user_name text not null check (length(trim(user_name)) between 1 and 200),
  rating integer not null check (rating between 1 and 5),
  comment text check (comment is null or length(comment) <= 1000),
  created_at timestamptz not null default now()
);

create index if not exists place_reviews_place_created_idx
  on public.place_reviews (place_id, created_at desc);

alter table public.place_reviews enable row level security;

drop policy if exists "Public read place reviews" on public.place_reviews;
create policy "Public read place reviews"
  on public.place_reviews
  for select
  using (true);

drop policy if exists "Authenticated users can create reviews" on public.place_reviews;
create policy "Authenticated users can create reviews"
  on public.place_reviews
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- No UPDATE/DELETE policy is created intentionally: PostgreSQL RLS defaults
-- those operations to deny, matching the approved Member 3 scope.

commit;
