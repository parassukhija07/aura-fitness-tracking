#!/usr/bin/env python3
"""Generate `seed_exercise_catalog.sql` from the bundled exercise library.

Run locally, commit the output:

    python supabase/seed/generate_seed.py

Then apply the generated SQL to the project with the service role (Supabase
Dashboard SQL editor, or `psql` with the connection string) — anon and
authenticated cannot write these tables, by design. See the write-path note in
`supabase/migrations/0008_exercise_catalog.sql`.

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

import json
import uuid
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Bump this when shipping a catalog update, then regenerate and re-run the
# seed. Clients store the version they last applied and refetch the whole
# catalog whenever the remote value differs from it.
CATALOG_VERSION = "1"

# FROZEN. This is `StableID.namespace` from AuraFitness/Models/SeedData.swift,
# byte for byte. Changing it re-issues every catalog id and orphans every row
# already seeded — the client would see 137 unknown ids and 137 stale ones.
NAMESPACE = uuid.UUID("6B1D4E9A-3F27-4C58-9A0E-2D8C7B5F1A34")

REPO_ROOT = Path(__file__).resolve().parents[2]
LIBRARY_JSON = REPO_ROOT / "AuraFitness" / "Resources" / "gym_exercise_library.json"
OUTPUT_SQL = Path(__file__).resolve().parent / "seed_exercise_catalog.sql"

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


def entry_for(raw: dict) -> dict:
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
        "imageURL": raw["image_url"],
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


def build_sql(entries: list[dict]) -> str:
    lines: list[str] = []
    add = lines.append

    add("-- seed_exercise_catalog.sql — GENERATED FILE, DO NOT EDIT BY HAND.")
    add("--")
    add("-- Regenerate with:  python supabase/seed/generate_seed.py")
    add("-- Source of truth:  AuraFitness/Resources/gym_exercise_library.json")
    add(f"-- Catalog version:  {CATALOG_VERSION}")
    add(f"-- Rows:             {len(entries)}")
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
    raw_entries = json.loads(LIBRARY_JSON.read_text(encoding="utf-8"))

    # Deduplicate by id (i.e. by name). Two rows sharing a primary key abort
    # the whole INSERT with "ON CONFLICT DO UPDATE command cannot affect row a
    # second time", so a repeated name in the bundled JSON would otherwise
    # take the entire seed down. Last occurrence wins, matching what a plain
    # re-run of the upsert would settle on.
    by_id: dict[str, dict] = {}
    for raw in raw_entries:
        entry = entry_for(raw)
        by_id[entry["id"]] = entry
    entries = sorted(by_id.values(), key=lambda e: e["name"])

    dropped = len(raw_entries) - len(entries)
    OUTPUT_SQL.write_text(build_sql(entries), encoding="utf-8")
    print(f"Wrote {OUTPUT_SQL.relative_to(REPO_ROOT)} — {len(entries)} rows, version {CATALOG_VERSION}.")
    if dropped:
        print(f"  ({dropped} duplicate name(s) collapsed.)")


if __name__ == "__main__":
    main()
