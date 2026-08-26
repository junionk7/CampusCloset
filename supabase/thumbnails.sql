-- ============================================================================
-- CampusCloset — Listing thumbnails (egress reduction)
-- ============================================================================
-- STATUS: NOT YET APPLIED. Run this BEFORE shipping the app build that writes
-- thumbnails, and before running scripts/migrate_images.py.
--
-- WHAT IT ADDS:
--   A `thumbnail_urls` column on `listings`, holding one small (~400px) image
--   per entry in `image_urls`, in the same order. The feed, the search rows and
--   the profile grids load these instead of the full-size photos.
--
-- WHY: every image surface in the app was downloading the full-size original —
--   a multi-megabyte camera photo — to fill a 120pt tile. That is what burns
--   the free plan's 5 GB/month cached egress allowance in a week or two.
--   Supabase's server-side image transformations would solve this without a new
--   column, but they are Pro-plan-only, so the thumbnails are generated on the
--   client at upload time and stored alongside the originals.
--
-- SAFE TO RUN ON A LIVE DATABASE: the column is nullable and additive. Existing
--   rows keep working — the app falls back to `image_urls` whenever
--   `thumbnail_urls` is null or short, so listings posted by users who have not
--   updated the app yet still show their photos.
--
-- WHY THIS FILE STAYS IN THE REPO: it is the record of this schema change. The
-- Dashboard shows what the columns are today, not when they changed or why.
--
-- HOW TO APPLY:  Supabase Dashboard → SQL Editor → New query → paste ALL of
-- this → Run. It cannot be applied from the app repo, because it changes the
-- live database. Safe to re-run: it is idempotent.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- COLUMN
-- ----------------------------------------------------------------------------
-- `thumbnail_urls` is created with exactly the same type as `image_urls`
-- (text[] or jsonb, depending on how the table was originally built) so the two
-- always decode identically in the Swift `Listing` model. Copying the type
-- rather than hard-coding it means this file cannot silently create a mismatch.
do $$
declare
  image_urls_type text;
begin
  select format_type(a.atttypid, a.atttypmod)
    into image_urls_type
    from pg_attribute a
   where a.attrelid = 'public.listings'::regclass
     and a.attname  = 'image_urls'
     and a.attnum   > 0
     and not a.attisdropped;

  if image_urls_type is null then
    raise exception
      'public.listings.image_urls was not found — is this the CampusCloset database?';
  end if;

  execute format(
    'alter table public.listings add column if not exists thumbnail_urls %s',
    image_urls_type
  );

  raise notice 'thumbnail_urls is ready (type: %)', image_urls_type;
end $$;


comment on column public.listings.thumbnail_urls is
  'Small (~400px) versions of image_urls, same order, one per photo. Written by '
  'the app at upload time and backfilled by scripts/migrate_images.py. Null on '
  'rows posted before this change — readers must fall back to image_urls.';


-- ----------------------------------------------------------------------------
-- POLICIES
-- ----------------------------------------------------------------------------
-- None needed. RLS on `listings` is enforced per-row, not per-column, so the
-- existing select/insert/update policies already cover the new column. See
-- security_rls.sql for those.


-- ============================================================================
-- VERIFICATION — run this after the above.
-- ============================================================================
-- Both columns should appear with the SAME data_type.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name   = 'listings'
  and column_name in ('image_urls', 'thumbnail_urls')
order by column_name;

-- Backfill progress. Before running the migration script this reads 0 migrated;
-- afterwards `missing_thumbnails` should be 0 for every listing that has photos.
-- (to_jsonb() is used so this counts correctly whether the columns are text[]
-- or jsonb.)
select
  count(*) filter (where jsonb_array_length(to_jsonb(image_urls)) > 0)
    as listings_with_photos,
  count(*) filter (where jsonb_array_length(to_jsonb(thumbnail_urls)) > 0)
    as migrated,
  count(*) filter (where jsonb_array_length(to_jsonb(image_urls)) > 0
                     and coalesce(jsonb_array_length(to_jsonb(thumbnail_urls)), 0) = 0)
    as missing_thumbnails
from public.listings
where status <> 'deleted';
