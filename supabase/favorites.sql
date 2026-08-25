-- ============================================================================
-- CampusCloset — Saved Items (favorites)
-- ============================================================================
-- STATUS: APPLIED to the live database on 2026-08-25, and verified in the app
-- (saved a listing, confirmed the heart survived a pull-to-refresh).
--
-- WHAT IT ADDS:
--   A `favorites` table backing the heart button on listings and the "Saved"
--   section of the profile tab. One row per (user, listing) pair.
--
-- WHY THIS FILE STAYS IN THE REPO: it is the record of this schema. The
-- Dashboard shows what the policies are today, not when they changed or why.
-- Re-run this to rebuild the table on a new or staging Supabase project.
--
-- HOW TO APPLY (again, elsewhere):  Supabase Dashboard → SQL Editor → New
-- query → paste ALL of this → Run.  It cannot be applied from the app repo,
-- because it changes the live database. Safe to re-run: it is idempotent.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- TABLE
-- ----------------------------------------------------------------------------
create table if not exists public.favorites (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id)      on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),

  -- Saving the same listing twice is a no-op, not a duplicate row.
  unique (user_id, listing_id)
);

-- The two lookups the app actually makes: "everything I saved" (profile tab)
-- and the cascade/uniqueness checks on listing_id.
create index if not exists favorites_user_id_idx    on public.favorites (user_id);
create index if not exists favorites_listing_id_idx on public.favorites (listing_id);


-- ----------------------------------------------------------------------------
-- ROW-LEVEL SECURITY  —  a user may only see and change their OWN saves.
-- Same owner-scoped pattern as listings/profiles/notifications in
-- security_rls.sql. Saves are private: nobody can read whose items you saved,
-- and nobody can stuff rows into someone else's saved list.
-- ----------------------------------------------------------------------------
alter table public.favorites enable row level security;

-- You can only read your own saves.
drop policy if exists favorites_select_own on public.favorites;
create policy favorites_select_own on public.favorites
  for select to authenticated
  using (auth.uid() = user_id);

-- You can only save on your own behalf.
drop policy if exists favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites
  for insert to authenticated
  with check (auth.uid() = user_id);

-- You can only un-save your own saves.
drop policy if exists favorites_delete_own on public.favorites;
create policy favorites_delete_own on public.favorites
  for delete to authenticated
  using (auth.uid() = user_id);

-- (No UPDATE policy: a save is created or removed, never edited.)


-- ============================================================================
-- VERIFICATION — run this after the above to confirm the table and policies.
-- ============================================================================
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'favorites'
order by cmd, policyname;

-- Confirm RLS is actually enabled (rls_enabled = true):
select relname as table_name, relrowsecurity as rls_enabled
from pg_class
where relname = 'favorites';
