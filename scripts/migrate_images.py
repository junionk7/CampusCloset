#!/usr/bin/env python3
"""
One-time image migration for CampusCloset — shrinks what is already in Storage.

WHY THIS EXISTS
    Every photo in the `listingImages` and `avatars` buckets was uploaded at
    full camera resolution (1.5-6 MB) with Supabase's default one-hour cache
    header. The app downloads those originals to fill 120pt tiles, over and
    over, which is what exhausts the free plan's 5 GB/month cached egress.

    The app-side fix only helps users who install the updated build. This script
    fixes the bytes behind the URLs that every client -- including ones still
    running the old build -- is already requesting, so it takes effect the
    moment it finishes.

WHAT IT DOES, per listing photo:
    1. downloads the original
    2. re-encodes it at most `--full-max` px on the long edge  -> uploads it
       back to the SAME path, so existing URLs keep working
    3. builds a `--thumb-max` px thumbnail -> uploads it to `<name>_thumb.jpg`
    4. records the thumbnail URLs on the listing row (thumbnail_urls)
    Both uploads carry `Cache-Control: max-age=31536000`, so a device that has
    downloaded an image once does not download it again for a year.

    Avatars get the same treatment, except the path is left alone (the bucket's
    RLS policy may key on it) and `profiles.avatar_url` gains a `?v=<epoch>`
    marker instead, which is what makes a year-long cache safe for a file that
    can be overwritten.

REQUIREMENTS
    python3 and sips, both already on macOS. Nothing to install.

USAGE
    # 1. See what it would do -- no writes at all (this is the default):
    SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/migrate_images.py

    # 2. Try a couple of listings for real:
    SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/migrate_images.py --apply --limit 2

    # 3. Then the whole library:
    SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/migrate_images.py --apply

    The service_role key is in Supabase Dashboard -> Project Settings -> API.
    It bypasses RLS, so keep it in the environment: never commit it, never paste
    it into a chat window, and do not put it in your shell history (a leading
    space before the command keeps zsh from recording the line).

NOTES
    - Run `supabase/thumbnails.sql` FIRST. Without the thumbnail_urls column the
      row updates fail and the script stops before touching anything.
    - Safe to re-run. Listings that already have thumbnails are skipped, so an
      interrupted run resumes where it left off.
    - Downloading your library costs egress once. Run it just after your billing
      cycle resets, when you have the most headroom.
"""

import argparse
import json
import os
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

# The project URL is public (it ships inside the app binary); only the
# service_role key is secret, and that comes from the environment.
DEFAULT_SUPABASE_URL = "https://okfhhmlggallmzugfbgc.supabase.co"

LISTING_BUCKET = "listingImages"
AVATAR_BUCKET = "avatars"

# One year. Both buckets use content-addressed or version-marked URLs, so a
# cached copy can never be wrong: listing photos have immutable UUID names, and
# avatar URLs change their ?v= marker whenever the photo is replaced.
CACHE_CONTROL = "max-age=31536000"

PUBLIC_PREFIX = "/storage/v1/object/public/"


def _ssl_context():
    """
    A context with a CA bundle that actually exists.

    The python.org macOS builds ship without one until someone runs
    "Install Certificates.command", so out of the box every HTTPS call dies with
    CERTIFICATE_VERIFY_FAILED. certifi is preferred when installed; otherwise
    macOS's own bundle does the job. Verification is never disabled — this
    script carries a service_role key, and an unverified connection is exactly
    how you would leak it.
    """
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass

    for bundle in ("/etc/ssl/cert.pem", "/private/etc/ssl/cert.pem"):
        if os.path.exists(bundle):
            return ssl.create_default_context(cafile=bundle)

    return ssl.create_default_context()


SSL_CONTEXT = _ssl_context()


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------

def request(method, url, key, data=None, headers=None, timeout=120):
    """One authenticated call against Supabase. Returns (status, body bytes)."""
    all_headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
    }
    if headers:
        all_headers.update(headers)

    req = urllib.request.Request(url, data=data, method=method, headers=all_headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=SSL_CONTEXT) as response:
            return response.status, response.read(), dict(response.headers)
    except urllib.error.HTTPError as error:
        return error.code, error.read(), dict(error.headers or {})


def download(url, timeout=120):
    """Fetch an image by its public URL. Returns bytes, or None on failure."""
    try:
        with urllib.request.urlopen(url, timeout=timeout, context=SSL_CONTEXT) as response:
            return response.read()
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as error:
        print(f"      ! download failed: {error}")
        return None


def served_cache_control(url, method="GET"):
    """
    Read back the Cache-Control a public URL is actually served with.

    `method="GET"` sends a one-byte ranged request rather than downloading the
    object, so checking costs nothing. HEAD is kept available because the two
    do not always agree — see --verify-headers.
    """
    headers = {"Range": "bytes=0-0"} if method == "GET" else {}
    try:
        req = urllib.request.Request(url, method=method, headers=headers)
        with urllib.request.urlopen(req, timeout=30, context=SSL_CONTEXT) as response:
            return response.headers.get("Cache-Control", "(none)")
    except urllib.error.HTTPError as error:
        served = dict(error.headers or {}).get("Cache-Control", "(none)")
        return f"HTTP {error.code} -> {served}"
    except (urllib.error.URLError, TimeoutError):
        return "(unreadable)"


def verify_headers(config):
    """
    Diagnostic: report what the CDN actually serves for already-migrated images,
    by both GET and HEAD, so a disagreement between the two is visible rather
    than mistaken for a broken upload.
    """
    listings = fetch_listings(config.base_url, config.key)
    migrated = [
        listing for listing in listings
        if (listing.get("thumbnail_urls") or []) and (listing.get("image_urls") or [])
    ]
    if not migrated:
        print("\nNo migrated listings yet — run with --apply first.")
        return

    print(f"\nChecking {min(3, len(migrated))} migrated listing(s):\n")
    for listing in migrated[:3]:
        full_url = listing["image_urls"][0]
        thumb_url = listing["thumbnail_urls"][0]
        print(f"  listing {listing['id']}")
        for label, url in (("full ", full_url), ("thumb", thumb_url)):
            print(f"    {label}  GET : {served_cache_control(url, 'GET')}")
            print(f"    {label}  HEAD: {served_cache_control(url, 'HEAD')}")
        print()

    print("  Expected: max-age=31536000 on the GET line.")
    print("  A GET that reads no-cache means the upload did not store the header.")


# ---------------------------------------------------------------------------
# Storage paths
# ---------------------------------------------------------------------------

def object_path(public_url, bucket):
    """
    Pull the storage path out of a public URL.
    .../storage/v1/object/public/listingImages/abc.jpg  ->  abc.jpg
    Returns None if the URL does not belong to this bucket.
    """
    marker = f"{PUBLIC_PREFIX}{bucket}/"
    if marker not in public_url:
        return None
    path = public_url.split(marker, 1)[1]
    path = path.split("?", 1)[0]          # drop any ?v= cache marker
    return urllib.parse.unquote(path)


def public_url_for(base_url, bucket, path):
    quoted = urllib.parse.quote(path, safe="/")
    return f"{base_url}{PUBLIC_PREFIX}{bucket}/{quoted}"


def thumb_path_for(path):
    """abc.jpg -> abc_thumb.jpg   (dir/abc.jpg -> dir/abc_thumb.jpg)"""
    if "." in path.rsplit("/", 1)[-1]:
        stem, _, extension = path.rpartition(".")
        return f"{stem}_thumb.{extension}"
    return f"{path}_thumb"


def upload(base_url, key, bucket, path, image_bytes, apply_changes):
    """Upsert an object with a long cache lifetime. Returns True on success."""
    if not apply_changes:
        return True

    quoted = urllib.parse.quote(path, safe="/")
    url = f"{base_url}/storage/v1/object/{bucket}/{quoted}"
    status, body, _ = request(
        "POST", url, key,
        data=image_bytes,
        headers={
            "Content-Type": "image/jpeg",
            "Cache-Control": CACHE_CONTROL,
            "x-upsert": "true",
        },
    )
    if status not in (200, 201):
        print(f"      ! upload failed ({status}): {body[:300].decode('utf-8', 'replace')}")
        return False
    return True


# ---------------------------------------------------------------------------
# Image processing (sips — built into macOS)
# ---------------------------------------------------------------------------

def dimensions(path):
    """(width, height) of an image on disk, or None if sips cannot read it."""
    try:
        output = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", path],
            capture_output=True, text=True, check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

    width = height = None
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("pixelWidth:"):
            width = int(line.split(":")[1])
        elif line.startswith("pixelHeight:"):
            height = int(line.split(":")[1])
    if width and height:
        return width, height
    return None


def resize(source, destination, max_edge, quality):
    """
    Re-encode as JPEG, capped at `max_edge` on the long side.

    sips -Z would happily ENLARGE a small image, so the cap is only applied when
    the image is actually bigger than it. An image that is already small still
    gets re-encoded, because the quality setting alone usually saves real bytes.
    """
    command = ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality)]

    size = dimensions(source)
    if size and max(size) > max_edge:
        command += ["-Z", str(max_edge)]

    command += [source, "--out", destination]
    try:
        subprocess.run(command, capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        print(f"      ! sips failed: {error}")
        return False
    return os.path.exists(destination)


def process(image_bytes, workdir, tag, max_edge, quality):
    """Bytes in, resized JPEG bytes out. Returns None if the image is unusable."""
    source = os.path.join(workdir, f"{tag}_in.jpg")
    destination = os.path.join(workdir, f"{tag}_out.jpg")
    with open(source, "wb") as handle:
        handle.write(image_bytes)

    if not resize(source, destination, max_edge, quality):
        return None
    with open(destination, "rb") as handle:
        return handle.read()


# ---------------------------------------------------------------------------
# Listings
# ---------------------------------------------------------------------------

def fetch_listings(base_url, key):
    url = (
        f"{base_url}/rest/v1/listings"
        "?select=id,image_urls,thumbnail_urls"
        "&status=neq.deleted"
        "&order=created_at.asc"
    )
    status, body, _ = request("GET", url, key)
    if status != 200:
        message = body.decode("utf-8", "replace")
        if "thumbnail_urls" in message and "does not exist" in message:
            sys.exit(
                "\n  The thumbnail_urls column is missing.\n"
                "  Run supabase/thumbnails.sql in the Supabase SQL Editor first,\n"
                "  then re-run this script.\n"
            )
        sys.exit(f"Could not read listings ({status}): {message[:500]}")
    return json.loads(body)


def save_thumbnails(base_url, key, listing_id, thumbnail_urls, apply_changes):
    if not apply_changes:
        return True
    url = f"{base_url}/rest/v1/listings?id=eq.{listing_id}"
    status, body, _ = request(
        "PATCH", url, key,
        data=json.dumps({"thumbnail_urls": thumbnail_urls}).encode(),
        headers={"Content-Type": "application/json", "Prefer": "return=minimal"},
    )
    if status not in (200, 204):
        print(f"    ! row update failed ({status}): {body[:300].decode('utf-8', 'replace')}")
        return False
    return True


def migrate_listings(config):
    listings = fetch_listings(config.base_url, config.key)
    pending = []
    for listing in listings:
        images = listing.get("image_urls") or []
        thumbs = listing.get("thumbnail_urls") or []
        if images and len(thumbs) < len(images):
            pending.append(listing)

    total = len(pending)
    skipped = len(listings) - total
    print(f"\nListings: {total} to migrate, {skipped} already done or without photos.")
    if config.limit:
        pending = pending[: config.limit]
        print(f"  (--limit {config.limit}: processing the first {len(pending)})")

    stats = {"before": 0, "after": 0, "images": 0, "failed": 0, "rows": 0}
    checked_cache_header = False

    for index, listing in enumerate(pending, start=1):
        listing_id = listing["id"]
        images = listing["image_urls"]
        print(f"\n[{index}/{len(pending)}] listing {listing_id} — {len(images)} photo(s)")

        thumbnail_urls = []
        row_ok = True

        with tempfile.TemporaryDirectory() as workdir:
            for position, image_url in enumerate(images):
                path = object_path(image_url, LISTING_BUCKET)
                if path is None:
                    print(f"    - photo {position + 1}: not a {LISTING_BUCKET} URL, left alone")
                    thumbnail_urls.append(image_url)
                    continue

                original = download(image_url)
                if original is None:
                    stats["failed"] += 1
                    thumbnail_urls.append(image_url)   # keep the arrays aligned
                    row_ok = False
                    continue

                full = process(original, workdir, f"{position}_full",
                               config.full_max, config.quality)
                thumb = process(original, workdir, f"{position}_thumb",
                                config.thumb_max, config.thumb_quality)
                if full is None or thumb is None:
                    stats["failed"] += 1
                    thumbnail_urls.append(image_url)
                    row_ok = False
                    continue

                # Never make a file bigger: if the original was already smaller
                # than our re-encode, keep the original bytes and just refresh
                # the cache header.
                if len(full) >= len(original):
                    full = original

                thumb_path = thumb_path_for(path)
                uploaded_full = upload(config.base_url, config.key, LISTING_BUCKET,
                                       path, full, config.apply)
                uploaded_thumb = upload(config.base_url, config.key, LISTING_BUCKET,
                                        thumb_path, thumb, config.apply)
                if not (uploaded_full and uploaded_thumb):
                    stats["failed"] += 1
                    thumbnail_urls.append(image_url)
                    row_ok = False
                    continue

                thumbnail_urls.append(
                    public_url_for(config.base_url, LISTING_BUCKET, thumb_path)
                )
                stats["before"] += len(original)
                stats["after"] += len(full) + len(thumb)
                stats["images"] += 1
                print(
                    f"    - photo {position + 1}: "
                    f"{human(len(original))} -> {human(len(full))} full "
                    f"+ {human(len(thumb))} thumb"
                )

                if config.apply and not checked_cache_header:
                    checked_cache_header = True
                    served = served_cache_control(image_url)
                    print(f"      cache header now served: {served}")

        if save_thumbnails(config.base_url, config.key, listing_id,
                           thumbnail_urls, config.apply):
            if row_ok:
                stats["rows"] += 1
        else:
            stats["failed"] += 1

    return stats


# ---------------------------------------------------------------------------
# Avatars
# ---------------------------------------------------------------------------

def migrate_avatars(config):
    url = f"{config.base_url}/rest/v1/profiles?select=id,avatar_url&avatar_url=not.is.null"
    status, body, _ = request("GET", url, config.key)
    if status != 200:
        print(f"\nCould not read profiles ({status}) — skipping avatars.")
        return {"before": 0, "after": 0, "images": 0, "failed": 0, "rows": 0}

    profiles = [p for p in json.loads(body) if p.get("avatar_url")]
    pending = [p for p in profiles if "?v=" not in p["avatar_url"]]
    print(f"\nAvatars: {len(pending)} to migrate, {len(profiles) - len(pending)} already done.")
    if config.limit:
        pending = pending[: config.limit]

    stats = {"before": 0, "after": 0, "images": 0, "failed": 0, "rows": 0}

    for index, profile in enumerate(pending, start=1):
        avatar_url = profile["avatar_url"]
        path = object_path(avatar_url, AVATAR_BUCKET)
        if path is None:
            continue

        print(f"[{index}/{len(pending)}] avatar {path}")
        original = download(avatar_url)
        if original is None:
            stats["failed"] += 1
            continue

        with tempfile.TemporaryDirectory() as workdir:
            resized = process(original, workdir, "avatar",
                              config.avatar_max, config.quality)
        if resized is None:
            stats["failed"] += 1
            continue
        if len(resized) >= len(original):
            resized = original

        if not upload(config.base_url, config.key, AVATAR_BUCKET,
                      path, resized, config.apply):
            stats["failed"] += 1
            continue

        # The path stays put (the bucket policy may depend on it); the URL gets
        # a version marker so a year-long cache can never serve a stale face.
        versioned = f"{public_url_for(config.base_url, AVATAR_BUCKET, path)}?v={int(time.time())}"
        if config.apply:
            patch_url = f"{config.base_url}/rest/v1/profiles?id=eq.{profile['id']}"
            patch_status, patch_body, _ = request(
                "PATCH", patch_url, config.key,
                data=json.dumps({"avatar_url": versioned}).encode(),
                headers={"Content-Type": "application/json", "Prefer": "return=minimal"},
            )
            if patch_status not in (200, 204):
                print(f"    ! profile update failed ({patch_status}): "
                      f"{patch_body[:200].decode('utf-8', 'replace')}")
                stats["failed"] += 1
                continue

        stats["before"] += len(original)
        stats["after"] += len(resized)
        stats["images"] += 1
        stats["rows"] += 1
        print(f"    {human(len(original))} -> {human(len(resized))}")

    return stats


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def human(byte_count):
    if byte_count >= 1024 * 1024:
        return f"{byte_count / 1024 / 1024:.1f} MB"
    if byte_count >= 1024:
        return f"{byte_count / 1024:.0f} KB"
    return f"{byte_count} B"


def main():
    parser = argparse.ArgumentParser(
        description="Shrink CampusCloset's existing Storage images and build thumbnails.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--apply", action="store_true",
                        help="actually upload and update rows (default is a dry run)")
    parser.add_argument("--dry-run", action="store_true",
                        help="explicit no-op flag; a dry run is the default anyway")
    parser.add_argument("--limit", type=int, default=0,
                        help="process at most this many listings (and avatars)")
    parser.add_argument("--listings-only", action="store_true")
    parser.add_argument("--avatars-only", action="store_true")
    parser.add_argument("--verify-headers", action="store_true",
                        help="report the Cache-Control already-migrated images are served with, then exit")
    parser.add_argument("--full-max", type=int, default=1400,
                        help="long edge for the full-size image (default 1400)")
    parser.add_argument("--thumb-max", type=int, default=400,
                        help="long edge for the thumbnail (default 400)")
    parser.add_argument("--avatar-max", type=int, default=300,
                        help="long edge for avatars (default 300)")
    parser.add_argument("--quality", type=int, default=65,
                        help="JPEG quality 0-100 for full images (default 65)")
    parser.add_argument("--thumb-quality", type=int, default=60,
                        help="JPEG quality 0-100 for thumbnails (default 60)")
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    config = parser.parse_args()

    if config.dry_run:
        config.apply = False

    config.base_url = config.url.rstrip("/")
    config.key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not config.key:
        sys.exit(
            "\n  SUPABASE_SERVICE_ROLE_KEY is not set.\n"
            "  Find it in Supabase Dashboard -> Project Settings -> API, then run:\n"
            "    SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/migrate_images.py\n"
        )

    if subprocess.run(["which", "sips"], capture_output=True).returncode != 0:
        sys.exit("  sips was not found. This script needs macOS.")

    print("=" * 68)
    print("CampusCloset image migration")
    print("=" * 68)
    print(f"  project     : {config.base_url}")
    print(f"  full images : <= {config.full_max}px, quality {config.quality}")
    print(f"  thumbnails  : <= {config.thumb_max}px, quality {config.thumb_quality}")
    print(f"  avatars     : <= {config.avatar_max}px")
    print(f"  cache header: {CACHE_CONTROL}")
    print(f"  mode        : {'APPLY (writes to Storage and the database)' if config.apply else 'DRY RUN (no writes)'}")

    if config.verify_headers:
        verify_headers(config)
        return

    totals = {"before": 0, "after": 0, "images": 0, "failed": 0, "rows": 0}

    if not config.avatars_only:
        for key, value in migrate_listings(config).items():
            totals[key] += value
    if not config.listings_only:
        for key, value in migrate_avatars(config).items():
            totals[key] += value

    print("\n" + "=" * 68)
    print(f"  images processed : {totals['images']}")
    print(f"  rows updated     : {totals['rows']}")
    print(f"  failures         : {totals['failed']}")
    print(f"  bytes before     : {human(totals['before'])}")
    print(f"  bytes after      : {human(totals['after'])}  (full + thumbnail)")
    if totals["before"]:
        saved = 100 * (1 - totals["after"] / totals["before"])
        print(f"  size reduction   : {saved:.0f}%")
        if totals["images"]:
            feed_before = totals["before"] / totals["images"]
            feed_after = (totals["after"] / totals["images"]) * 0.25  # thumb share
            print(f"  a feed image was : {human(int(feed_before))} -> about "
                  f"{human(int(feed_after))} as a thumbnail")
    if not config.apply:
        print("\n  Dry run only — nothing was written. Re-run with --apply.")
    print("=" * 68)


if __name__ == "__main__":
    main()
