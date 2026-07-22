#!/usr/bin/env python3
"""Generate `seed_exercise_catalog.sql` from the bundled exercise library.

Run locally, commit the output:

    python supabase/seed/generate_seed.py [--project-ref <ref>]

Then apply the generated SQL to the project with the service role (Supabase
Dashboard SQL editor, or `psql` with the connection string) — anon and
authenticated cannot write these tables, by design. See the write-path note in
`supabase/migrations/0008_exercise_catalog.sql`.

IMAGES (phase5-02): any `.jpg` dropped into `supabase/seed/exercise-media/` is
matched to an exercise by filename slug, and that exercise's `payload.imageURL`
is rewritten to the public URL of its object in the `exercise-media` Storage
bucket. A second output, `supabase/seed/upload_media.sh`, carries the matching
`supabase storage cp` commands. Both halves must ship together — SQL alone
points rows at objects that 404, uploads alone leave rows on the old URL. The
folder contract lives in `supabase/seed/exercise-media/README.md`; the bucket
and its policy in `supabase/migrations/0009_exercise_media_bucket.sql`.

WHY A GENERATOR: the catalog rows have to carry the SAME ids and the SAME field
shape the Swift client computes for the bundled JSON, or a pulled row would
duplicate its bundled counterpart instead of replacing it. Hand-writing 137
rows twice is how those two drift apart, so the SQL is derived from the exact
same JSON the app bundles, by the transform below, which mirrors
`GymExerciseJSON.toEntry()` in AuraFitness/Models/ExerciseDatabase.swift.

KEEP IN SYNC: if `ExerciseEntry`, `WarmupStep`, or `GymExerciseJSON.toEntry()`
changes shape in Swift, change `entry_for` / `warmup_steps` here and
regenerate. Swift's synthesized `Codable` does NOT fall back to a property's
default value when a key is absent — it throws — so every field of
`ExerciseEntry` must be emitted, including the ones that look like they have
defaults (`isCustom`, `notes`, `isFavorite`, `pulley`, `plannedSets`, `hint`).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import uuid
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Bump this when shipping a catalog update, then regenerate and re-run the
# seed. Clients store the version they last applied and refetch the whole
# catalog whenever the remote value differs from it.
CATALOG_VERSION = "2"

# Rows per chunk file. The catalog outgrew a single paste when it went from 137
# hand-written exercises to the 1,316 imported ones (~1.6 MB of SQL), and the
# Dashboard SQL editor is not a place to paste megabytes. `catalog_chunks/`
# holds the same statements split into files a person can actually apply one at
# a time; the single full file remains for `psql`, which has no such problem.
CHUNK_ROWS = 250

# FROZEN. This is `StableID.namespace` from AuraFitness/Models/SeedData.swift,
# byte for byte. Changing it re-issues every catalog id and orphans every row
# already seeded — the client would see 137 unknown ids and 137 stale ones.
NAMESPACE = uuid.UUID("6B1D4E9A-3F27-4C58-9A0E-2D8C7B5F1A34")

REPO_ROOT = Path(__file__).resolve().parents[2]
SEED_DIR = Path(__file__).resolve().parent
LIBRARY_JSON = REPO_ROOT / "AuraFitness" / "Resources" / "gym_exercise_library.json"
OUTPUT_SQL = SEED_DIR / "seed_exercise_catalog.sql"
CHUNK_DIR = SEED_DIR / "catalog_chunks"

# phase5-02 — exercise imagery. Source files in, upload script out.
MEDIA_DIR = SEED_DIR / "exercise-media"
UPLOAD_SCRIPT = SEED_DIR / "upload_media.sh"
MEDIA_BUCKET = "exercise-media"
# WARN, never fail: an oversized image still works, it just costs the user
# cellular data on a grid that loads dozens at once. Blocking the whole seed
# over it would be worse than shipping the warning.
MAX_IMAGE_BYTES = 200 * 1024

# Extra filename slugs that map onto an exercise's canonical slug. The escape
# hatch for the CDN-cache problem: replacing an image at the same object path
# can serve stale bytes for the cache TTL, so a corrected image ships under a
# NEW filename (hence a new object path and a new URL) and is aliased here.
#   "barbell-bench-press-v2": "barbell-bench-press",
# An alias wins over the canonical slug when both files exist.
MEDIA_ALIASES: dict[str, str] = {}

# `GymExerciseJSON.toEntry()` hardcodes this for every JSON-sourced entry. It
# is an EN DASH (U+2013), not a hyphen — rep ranges are compared as strings in
# places, so the character matters.
DEFAULT_REP_RANGE = "8–12"
DEFAULT_PLANNED_SETS = 3


# ---------------------------------------------------------------------------
# Deterministic ids — RFC 4122 §4.3 name-based UUID, SHA-1 flavour (version 5)
# ---------------------------------------------------------------------------
#
# `uuid.uuid5` is bit-for-bit identical to `StableID.v5` in SeedData.swift:
# both SHA-1 the namespace's 16 bytes followed by the UTF-8 name, truncate to
# 16 bytes, and stamp the version/variant bits. The NAME STRINGS must match
# too, hence the same "exercise:" / "warmupstep:" prefixes used there.


def exercise_id(name: str) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, "exercise:" + name)


def warmup_step_id(exercise_name: str, index: int) -> uuid.UUID:
    # Keyed by position, not by the record's own `set` number: a malformed
    # entry can repeat a set number, and two steps in one exercise sharing an
    # id would collapse in any id-keyed SwiftUI list.
    return uuid.uuid5(NAMESPACE, f"warmupstep:{exercise_name}#{index}")


# ---------------------------------------------------------------------------
# Exercise imagery — supabase/seed/exercise-media/ -> public bucket URLs
# ---------------------------------------------------------------------------
#
# There is no DB column joining an exercise to its image. The OBJECT NAME is
# the join: an exercise's image lives at `exercise-media/{its uuid}.jpg`, and
# the catalog row's `payload.imageURL` is that object's public URL. One id,
# derived once, used for both — so the two cannot drift.
#
# On disk the file is named after the EXERCISE, not the uuid, because a human
# has to drop it in the folder and recognise it later. `slugify` is the bridge.

_NON_SLUG = re.compile(r"[^a-z0-9]+")


def slugify(name: str) -> str:
    """`Barbell Bench Press` -> `barbell-bench-press`.

    Lowercase, every run of non-alphanumerics collapsed to one `-`, no leading
    or trailing `-`. Deliberately lossy: `Cable Fly (High-to-Low)` and
    `Cable Fly High to Low` slug identically, which is what a human naming a
    file would expect. A collision between two DIFFERENT exercises is reported
    at generation time rather than silently giving one of them the other's
    picture."""
    return _NON_SLUG.sub("-", name.lower()).strip("-")


def media_object_name(entry_id: str, alias: str | None = None) -> str:
    """Object path within the bucket. Lowercase uuid — object names are
    case-sensitive in Storage, so this one helper is the single place the
    casing is decided, for both the URL and the upload command.

    An `alias` (a versioned replacement image, see MEDIA_ALIASES) is appended
    so the object lands on a NEW path: the CDN caches public objects for a long
    TTL, and overwriting in place can keep serving the old bytes."""
    stem = entry_id.lower()
    if alias:
        stem = f"{stem}-{alias}"
    return f"{stem}.jpg"


def public_image_url(project_ref: str, object_name: str) -> str:
    """Anon-readable, CDN-cached, no auth header. Shape is fixed by Supabase
    Storage; only the project ref varies, and it arrives as a CLI argument
    because it differs per environment and must never be committed here."""
    return (
        f"https://{project_ref}.supabase.co"
        f"/storage/v1/object/public/{MEDIA_BUCKET}/{object_name}"
    )


def scan_media(known_slugs: set[str], warn) -> dict[str, tuple[Path, str | None]]:
    """Map canonical exercise slug -> (source file, alias or None).

    Every anomaly WARNS and skips rather than raising: an unmatched or
    oversized file must not be able to take down a 137-row catalog seed. The
    warnings are the whole point — a typo'd filename is otherwise invisible,
    showing up months later as one exercise that never got a picture."""
    if not MEDIA_DIR.is_dir():
        return {}

    canonical: dict[str, Path] = {}
    aliased: dict[str, tuple[Path, str]] = {}

    for path in sorted(MEDIA_DIR.iterdir()):
        if not path.is_file() or path.name.lower() == "readme.md":
            continue
        if path.suffix.lower() != ".jpg":
            warn(f"{path.name}: not a .jpg — skipped (convert it; the bucket serves image/jpeg)")
            continue

        file_slug = slugify(path.stem)
        alias_target = MEDIA_ALIASES.get(file_slug)
        slug = alias_target or file_slug
        if slug not in known_slugs:
            hint = " — alias target is not an exercise slug" if alias_target else ""
            warn(f"{path.name}: no exercise matches slug '{slug}'{hint} — skipped")
            continue

        size = path.stat().st_size
        if size > MAX_IMAGE_BYTES:
            warn(
                f"{path.name}: {size / 1024:.0f} KB exceeds the "
                f"{MAX_IMAGE_BYTES // 1024} KB budget — still generated"
            )

        # Two files landing on the same exercise is ambiguous, so the second
        # one loses and says so. Alias vs canonical is NOT that case: an alias
        # exists precisely to supersede the canonical file, handled below.
        taken = aliased if alias_target else canonical
        if slug in taken:
            other = taken[slug][0] if alias_target else taken[slug]
            warn(f"{path.name}: also matches '{slug}', already taken by {other.name} — skipped")
            continue
        if alias_target:
            aliased[slug] = (path, file_slug)
        else:
            canonical[slug] = path

    matched: dict[str, tuple[Path, str | None]] = {s: (p, None) for s, p in canonical.items()}
    matched.update(aliased)  # an alias supersedes the canonical file
    return matched


def build_upload_script(uploads: list[tuple[Path, str]]) -> str:
    """One `supabase storage cp` per image, for the owner to run once after the
    bucket exists. Not run automatically: it writes to a public shared bucket
    with the service role, which is not something a generator should do as a
    side effect of producing SQL."""
    lines = [
        "#!/usr/bin/env bash",
        "# upload_media.sh — GENERATED FILE, DO NOT EDIT BY HAND.",
        "#",
        "# Regenerate with:  python supabase/seed/generate_seed.py --project-ref <ref>",
        "# Source folder:    supabase/seed/exercise-media/  (see its README.md)",
        f"# Images:           {len(uploads)}",
        "#",
        "# Uploads every matched image to the PUBLIC `exercise-media` bucket. Run",
        "# once after creating the bucket, with the project linked:",
        "#     supabase storage buckets create exercise-media --public",
        "#     supabase link --project-ref <ref>",
        "#     bash supabase/seed/upload_media.sh",
        "#",
        "# Writing needs the SERVICE ROLE — 0009_exercise_media_bucket.sql grants",
        "# anon/authenticated read only, so an anon-key run fails with 403.",
        "#",
        "# Re-runnable: `cp` overwrites the same object path. Beware the CDN cache",
        "# when replacing an image — see the README's versioning note.",
        "",
        "set -euo pipefail",
        "",
        "# Paths below are relative to this script's own directory, so it runs the",
        "# same from anywhere.",
        'cd "$(dirname "${BASH_SOURCE[0]}")"',
        "",
    ]

    if not uploads:
        lines += [
            "echo 'No images in exercise-media/ — nothing to upload.'",
            "exit 0",
            "",
        ]
        return "\n".join(lines)

    for source, object_name in uploads:
        lines.append(
            f'supabase storage cp "./{MEDIA_DIR.name}/{source.name}" '
            f'"ss:///{MEDIA_BUCKET}/{object_name}"'
        )
    lines += ["", f"echo 'Uploaded {len(uploads)} image(s) to {MEDIA_BUCKET}.'", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# JSON -> ExerciseEntry (mirror of GymExerciseJSON.toEntry())
# ---------------------------------------------------------------------------


def difficulty_for(name: str) -> str:
    n = name.lower()
    if "deadlift" in n or "squat" in n or "bulgarian" in n:
        return "Advanced"
    if "barbell" in n or "overhead" in n:
        return "Intermediate"
    return "Beginner"


def warmup_steps(exercise_name: str, raw_steps: list[dict]) -> list[dict]:
    return [
        {
            "id": str(warmup_step_id(exercise_name, i)).upper(),
            "set": step["set"],
            "intensity": step["intensity"],
            "reps": step["reps"],
            "description": step["description"],
        }
        for i, step in enumerate(raw_steps)
    ]


def entry_for(raw: dict, image_url: str | None = None) -> dict:
    """`image_url` overrides the library JSON's `image_url` when this exercise
    has a file in exercise-media/. Without one the JSON value is kept as-is —
    dropping to `""` would blank out every thumbnail the app shows today, and
    an empty URL and a first-party one are equally valid to the client: both
    end at `RemoteExerciseImage`, which shows the gradient for empty/invalid
    URLs and for 404s alike."""
    name = raw["name"]
    equipment = raw["equipment"]
    protocol = raw["warmup_protocol"]
    return {
        # Swift encodes UUID as an uppercase string; match it so a payload
        # round-trips through the client unchanged.
        "id": str(exercise_id(name)).upper(),
        "name": name,
        "category": raw["category"],
        "equipment": equipment,
        "musclesTargeted": raw["muscles_targeted"],
        "type": raw["type"],
        "difficulty": difficulty_for(name),
        "repRange": DEFAULT_REP_RANGE,
        "youtubeURL": raw["youtube_url"],
        "imageURL": image_url if image_url is not None else raw["image_url"],
        "proTips": raw["pro_tips"],
        "warmupProtocol": {
            "type": protocol["type"],
            "steps": warmup_steps(name, protocol["steps"]),
        },
        "isCable": equipment.lower() == "cable",
        "pulley": "single",
        # Catalog rows are library content by definition. `isCustom == true`
        # here would make the client treat a global row as a user's own
        # exercise and start syncing it up to `aura_exercises`.
        "isCustom": False,
        # Per-user state. The client re-applies its local values for these on
        # top of a refreshed row (see `applyRemoteCatalog`); the seed just has
        # to emit something decodable.
        "notes": "",
        "isFavorite": False,
        "plannedSets": DEFAULT_PLANNED_SETS,
        "hint": "",
    }


# ---------------------------------------------------------------------------
# SQL emission
# ---------------------------------------------------------------------------


def sql_string(value: str) -> str:
    """Single-quoted SQL literal. Doubling `'` is the only escape a standard
    string literal needs; `standard_conforming_strings` is on by default in
    Postgres, so backslashes are literal and need no handling."""
    return "'" + value.replace("'", "''") + "'"


def build_sql(entries: list[dict], part: int | None = None, parts: int | None = None) -> str:
    """One transaction of upserts.

    `part`/`parts` produce a chunk of a multi-file split. The VERSION MARKER is
    written only by the final chunk, and that ordering is load-bearing: clients
    refetch the whole catalog when the remote version differs from the one they
    last applied, so bumping it while rows are still missing would advertise a
    catalog that is only half there. Applied in order, the marker lands last;
    stop halfway and clients simply keep the version they already had."""
    is_final = part is None or part == parts
    lines: list[str] = []
    add = lines.append

    name = "seed_exercise_catalog.sql" if part is None else f"catalog_chunks/{part:02d}.sql"
    add(f"-- {name} — GENERATED FILE, DO NOT EDIT BY HAND.")
    add("--")
    add("-- Regenerate with:  python supabase/seed/generate_seed.py")
    add("-- Source of truth:  AuraFitness/Resources/gym_exercise_library.json")
    add(f"-- Catalog version:  {CATALOG_VERSION}")
    if part is None:
        add(f"-- Rows:             {len(entries)}")
    else:
        add(f"-- Rows:             {len(entries)} (chunk {part} of {parts})")
    add("--")
    add("-- Apply with the SERVICE ROLE (Dashboard SQL editor or psql). RLS on")
    add("-- these tables grants SELECT only; anon/authenticated writes fail with")
    add("-- 42501. See supabase/migrations/0008_exercise_catalog.sql.")
    add("--")
    add("-- Idempotent and re-runnable: every row is an upsert keyed on the")
    add("-- deterministic id, and the version marker is upserted on `key`.")
    add("--")
    add("-- Rows are never DELETED here. An exercise dropped from the bundled")
    add("-- JSON keeps its catalog row on purpose: ids are derived from the")
    add("-- name, so an older client that still references it can resolve it.")
    if part is not None:
        add("--")
        add(f"-- APPLY THE CHUNKS IN ORDER, 01 through {parts:02d}. Only the last one")
        add("-- bumps catalog_version, so an interrupted run leaves clients on the")
        add("-- previous catalog rather than on a partial one.")
    add("")
    add("begin;")
    add("")
    add("insert into aura_exercise_catalog (id, payload, updated_at) values")

    row_sql = []
    for entry in entries:
        payload = json.dumps(entry, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        row_sql.append(f"  ('{entry['id']}'::uuid, {sql_string(payload)}::jsonb, now())")
    add(",\n".join(row_sql))
    add("on conflict (id) do update set")
    add("  payload    = excluded.payload,")
    add("  updated_at = now();")
    add("")

    if is_final:
        add("insert into aura_catalog_meta (key, value, updated_at) values")
        add(f"  ('catalog_version', {sql_string(CATALOG_VERSION)}, now())")
        add("on conflict (key) do update set")
        add("  value      = excluded.value,")
        add("  updated_at = now();")
        add("")

    add("commit;")
    add("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--project-ref",
        help=(
            "Supabase project ref (the subdomain of https://<ref>.supabase.co). "
            "Required only when exercise-media/ holds images, since it is what "
            "makes their public URLs. Never hardcoded: it differs per environment."
        ),
    )
    args = parser.parse_args()

    raw_entries = json.loads(LIBRARY_JSON.read_text(encoding="utf-8"))

    warnings: list[str] = []
    slug_to_name: dict[str, str] = {}
    for raw in raw_entries:
        slug = slugify(raw["name"])
        clash = slug_to_name.get(slug)
        if clash and clash != raw["name"]:
            # Both would claim the same filename, so one would silently wear
            # the other's picture. Renaming one exercise is the fix.
            warnings.append(
                f"slug collision: '{clash}' and '{raw['name']}' both slug to '{slug}' — "
                f"an image named {slug}.jpg is ambiguous"
            )
        slug_to_name[slug] = raw["name"]

    media = scan_media(set(slug_to_name), warnings.append)
    if media and not args.project_ref:
        parser.error(
            f"{len(media)} image(s) in {MEDIA_DIR.relative_to(REPO_ROOT)} but no "
            "--project-ref, so their public URLs cannot be built. Pass "
            "--project-ref <ref>, or empty the folder to seed without imagery."
        )

    # Deduplicate by id (i.e. by name). Two rows sharing a primary key abort
    # the whole INSERT with "ON CONFLICT DO UPDATE command cannot affect row a
    # second time", so a repeated name in the bundled JSON would otherwise
    # take the entire seed down. Last occurrence wins, matching what a plain
    # re-run of the upsert would settle on.
    by_id: dict[str, dict] = {}
    uploads: list[tuple[Path, str]] = []
    for raw in raw_entries:
        match = media.get(slugify(raw["name"]))
        image_url = None
        if match:
            source, alias = match
            object_name = media_object_name(str(exercise_id(raw["name"])), alias)
            image_url = public_image_url(args.project_ref, object_name)
            # A name repeated in the JSON collapses to one row (below); its
            # image must not be uploaded twice.
            if (source, object_name) not in uploads:
                uploads.append((source, object_name))
        entry = entry_for(raw, image_url)
        by_id[entry["id"]] = entry
    entries = sorted(by_id.values(), key=lambda e: e["name"])

    dropped = len(raw_entries) - len(entries)
    OUTPUT_SQL.write_text(build_sql(entries), encoding="utf-8")

    # Chunked copies of the same statements, for applying by hand in the
    # Dashboard. Regenerated from scratch each run so a shrinking catalog
    # cannot leave a stale trailing chunk behind that would re-insert rows the
    # current library no longer has.
    chunks = [entries[i:i + CHUNK_ROWS] for i in range(0, len(entries), CHUNK_ROWS)]
    if CHUNK_DIR.exists():
        for stale in CHUNK_DIR.glob("*.sql"):
            stale.unlink()
    CHUNK_DIR.mkdir(parents=True, exist_ok=True)
    for index, chunk in enumerate(chunks, start=1):
        (CHUNK_DIR / f"{index:02d}.sql").write_text(
            build_sql(chunk, part=index, parts=len(chunks)), encoding="utf-8"
        )
    # newline="" keeps the LF endings verbatim. Generated on Windows without
    # it, every line would end CRLF and bash would choke on the stray \r
    # ("$'\r': command not found").
    with open(UPLOAD_SCRIPT, "w", encoding="utf-8", newline="") as fh:
        fh.write(build_upload_script(uploads))
    size_mb = OUTPUT_SQL.stat().st_size / 1024 / 1024
    print(f"Wrote {OUTPUT_SQL.relative_to(REPO_ROOT)} — {len(entries)} rows, "
          f"version {CATALOG_VERSION}, {size_mb:.2f} MB.")
    if dropped:
        print(f"  ({dropped} duplicate name(s) collapsed.)")
    print(f"Wrote {CHUNK_DIR.relative_to(REPO_ROOT)}/ — {len(chunks)} chunk(s) of "
          f"up to {CHUNK_ROWS} rows, for pasting into the Dashboard SQL editor.")
    print(f"Wrote {UPLOAD_SCRIPT.relative_to(REPO_ROOT)} — {len(uploads)} image(s).")
    if uploads:
        print("  Next: bash supabase/seed/upload_media.sh, then apply the SQL with the service role.")

    # Last, so they are the final thing on screen rather than scrolled past.
    for warning in warnings:
        print(f"  WARNING: {warning}", file=sys.stderr)


if __name__ == "__main__":
    main()
