-- ============================================================================
-- CampusCloset — Row-Level Security (RLS) hardening
-- ============================================================================
-- HOW TO APPLY:  Supabase Dashboard → SQL Editor → New query → paste ALL of
-- this → Run.  (This cannot be applied from the app repo; it changes the live
-- database.)  This script is safe to re-run: it drops each policy before
-- recreating it.
--
-- WHAT IT FIXES:
--   Critical #1  deleteListing — anyone could soft-delete any listing
--   High     #4  updateListing — anyone could edit any listing
--   High     #5  updateListingStatus — anyone could re-status any listing
--   High     #6  addListing — anyone could post under another user's id
--   High     #8  updateProfile — anyone could overwrite any profile
--   High     #7  notifications — anyone could plant notifications in any feed
--   High    #10  systemic — server now enforces ownership, not just the app
--
-- >>> CAUTION: enabling RLS on a LIVE app is the risky step. Do this first on a
--     Supabase branch or during low traffic, then run the VERIFICATION block at
--     the bottom and manually test: post / edit / mark-sold / delete your OWN
--     listing, edit your profile, send a message, view notifications.
-- >>> ROLLBACK for any table:  alter table public.<table> disable row level security;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- LISTINGS  —  a user may only write to rows they own.
-- One UPDATE policy covers editListing, updateListingStatus AND the soft-delete
-- (all three are UPDATEs). The INSERT policy stops posting under a forged id.
-- Fixes #1, #4, #5, #6.
-- ----------------------------------------------------------------------------
alter table public.listings enable row level security;

-- Signed-in users can read listings (feed, search, profile joins).
drop policy if exists listings_select_authenticated on public.listings;
create policy listings_select_authenticated on public.listings
  for select to authenticated
  using (true);

-- You can only create a listing attributed to yourself.               [#6]
drop policy if exists listings_insert_own on public.listings;
create policy listings_insert_own on public.listings
  for insert to authenticated
  with check (auth.uid() = user_id);

-- You can only edit / re-status / soft-delete your OWN listings.  [#1, #4, #5]
drop policy if exists listings_update_own on public.listings;
create policy listings_update_own on public.listings
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- (No DELETE policy: the app only soft-deletes via UPDATE, so hard deletes
--  from clients stay blocked.)


-- ----------------------------------------------------------------------------
-- PROFILES  —  a user may only edit their own profile.
-- Fixes #8.
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;

-- Signed-in users can read profiles (needed for the listing→seller-name join
-- and for people-search).
drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated on public.profiles
  for select to authenticated
  using (true);

-- You can only update your own profile row.                           [#8]
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- You can only insert your own profile row (the sign-up path).
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (auth.uid() = id);

-- >>> IMPORTANT — SIGN-UP MAY DEPEND ON THIS:
--     The app creates the profile row from the client right after sign-up.
--     That works ONLY if a session exists at that moment, i.e. if email
--     confirmation is OFF. If your project has email confirmation ON, the
--     insert above will run before a session exists and sign-up will fail.
--     In that case, DO NOT rely on the client insert — instead uncomment the
--     trigger below (it creates the profile server-side, bypassing RLS) and
--     tell me, so I can adjust the Swift sign-up to pass the name via metadata
--     and stop inserting the row itself.
--
-- create or replace function public.handle_new_user()
-- returns trigger language plpgsql security definer set search_path = public as $$
-- begin
--   insert into public.profiles (id, full_name)
--   values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
--   on conflict (id) do nothing;
--   return new;
-- end; $$;
--
-- drop trigger if exists on_auth_user_created on auth.users;
-- create trigger on_auth_user_created
--   after insert on auth.users
--   for each row execute function public.handle_new_user();


-- ----------------------------------------------------------------------------
-- NOTIFICATIONS  —  read/update only your own; NObody can insert from a client.
-- The send-message Edge Function (service role) is the only writer, so a user
-- can no longer plant a notification in someone else's feed.
-- Fixes #7 (with the updated Edge Function).
-- ----------------------------------------------------------------------------
alter table public.notifications enable row level security;

-- You can only read your own notifications.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select to authenticated
  using (auth.uid() = user_id);

-- You can only mark your own notifications read.
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- NOTE: there is intentionally NO insert policy for the `authenticated` role.
-- Clients therefore cannot insert notifications at all; only the service-role
-- Edge Function (which bypasses RLS) creates them. This is what closes #7.


-- ============================================================================
-- VERIFICATION — run this after the above to confirm the policies are in place.
-- ============================================================================
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('listings', 'profiles', 'notifications')
order by tablename, cmd, policyname;

-- Confirm RLS is actually enabled (rowsecurity = true for all three):
select relname as table, relrowsecurity as rls_enabled
from pg_class
where relname in ('listings', 'profiles', 'notifications');


-- ============================================================================
-- FOLLOW-UP (NOT included here — these are Medium-severity, out of the
-- Critical/High scope you asked for). Apply the same owner-scoped pattern to:
--   reports          → insert with check (auth.uid() = reporter_id)
--   blocked_users    → insert/select with check/using (auth.uid() = blocker_id)
--   deletion_requests→ insert with check (auth.uid() = user_id)
-- Leaving them untouched keeps those features behaving exactly as they do today.
-- ============================================================================
