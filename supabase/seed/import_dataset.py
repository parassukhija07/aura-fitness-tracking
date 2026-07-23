#!/usr/bin/env python3
"""Convert the upstream exercises-dataset into `gym_exercise_library.json`.

Run locally against a checkout or download of the upstream data, commit the
output:

    python supabase/seed/import_dataset.py --source path/to/exercises.json

Then regenerate the catalog seed from it, as usual:

    python supabase/seed/generate_seed.py

SOURCE: https://github.com/hasaneyldrm/exercises-dataset — 1,324 exercises with
muscle groups, equipment and step-by-step instructions in 10 languages. The
DATA is MIT licensed (see THIRD_PARTY_NOTICES.md at the repo root, which
carries the notice MIT requires us to retain).

MEDIA IS DELIBERATELY NOT IMPORTED. The upstream `images/` and `videos/`
directories are carved out of that MIT grant: they belong to Gym visual and are
present upstream under a permission that explicitly does not travel downstream
("cloning this repo is not a license"). So `image`, `gif_url`, `media_id` and
`attribution` are dropped here rather than mapped, and every record's
`image_url` is emitted EMPTY. Do not "fix" that by pointing it at their paths
or hotlinking their raw URLs — both are redistribution we have no licence for,
and the app already renders a muscle-tinted gradient for an empty URL. If
imagery is licensed later it arrives through the `exercise-media` bucket
(0009_exercise_media_bucket.sql), which is a separate, licensed path.

WHY A CONVERTER AND NOT A ONE-OFF EDIT: the upstream shape and ours disagree on
almost every field — their names are lowercase, their 10 body parts and 28
equipment values need collapsing onto our vocabulary, and they carry no warm-up
protocols, YouTube links or difficulty at all. Those gaps are filled by the
DERIVATION RULES below. Keeping them here, in one auditable place, means a
refreshed upstream drop can be re-imported by re-running this script rather
than by hand-reconciling 1,324 records.

KEEP IN SYNC: the output must satisfy `GymExerciseJSON` in
AuraFitness/Models/ExerciseDatabase.swift. Every field there is NON-OPTIONAL,
and Swift's synthesized `Codable` throws on a missing key rather than falling
back to a default — an omitted field silently costs the whole record, because
`jsonLibraryEntries()` decodes lossily and drops the ones that throw.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_JSON = REPO_ROOT / "AuraFitness" / "Resources" / "gym_exercise_library.json"

# Instructions ship in 10 languages upstream; the app is English-only, and
# carrying all 10 would take the bundled library from ~0.8 MB to ~15.5 MB for
# strings nothing reads.
LANGUAGE = "en"


# ---------------------------------------------------------------------------
# Vocabulary mapping — upstream values -> the vocabulary the app already uses
# ---------------------------------------------------------------------------
#
# The app derives its category filter chips from whatever values the entries
# carry (`ExerciseDatabase.categories`), so a new category here becomes a new
# chip rather than a crash. Equipment is stricter: `ActiveWorkoutData
# .equipmentFilters` is a hardcoded six, so anything mapping outside it stays
# reachable by search but not by that one legacy filter row.

CATEGORY_MAP = {
    "back": "Back",
    "cardio": "Cardio",
    "chest": "Chest",
    "lower arms": "Arms",
    "upper arms": "Arms",
    "lower legs": "Legs",
    "upper legs": "Legs",
    "neck": "Neck",
    "shoulders": "Shoulders",
    "waist": "Core",
}

EQUIPMENT_MAP = {
    "body weight": "Bodyweight",
    # Upstream "weighted" means a bodyweight movement loaded with a belt or
    # vest (weighted pull-up, weighted dip), not a distinct apparatus.
    "weighted": "Bodyweight",
    "assisted": "Assisted",
    "dumbbell": "Dumbbell",
    "cable": "Cable",
    "barbell": "Barbell",
    "ez barbell": "Barbell",
    "olympic barbell": "Barbell",
    "trap bar": "Barbell",
    "smith machine": "Smith Machine",
    "leverage machine": "Machine",
    "sled machine": "Machine",
    "hammer": "Machine",
    "band": "Band",
    "resistance band": "Band",
    "kettlebell": "Kettlebell",
    "medicine ball": "Medicine Ball",
    "stability ball": "Stability Ball",
    "bosu ball": "Bosu Ball",
    "rope": "Rope",
    "roller": "Roller",
    "wheel roller": "Roller",
    "tire": "Other",
    "elliptical machine": "Cardio Machine",
    "stationary bike": "Cardio Machine",
    "stepmill machine": "Cardio Machine",
    "skierg machine": "Cardio Machine",
    "upper body ergometer": "Cardio Machine",
}

# Equipment with a fixed path of motion — the same `type` rule
# `ExerciseDatabase.legacyEntries` already applies to its own records.
MACHINE_EQUIPMENT = frozenset({"Machine", "Smith Machine", "Cardio Machine", "Assisted"})

# Title-casing exceptions. Everything else is capitalised word by word.
CASING_OVERRIDES = {
    "ez": "EZ",
    "v": "V",
    "t": "T",
    "iso": "ISO",
    "pov": "POV",
    "bosu": "BOSU",
    "skierg": "SkiErg",
}

# Upstream suffixes 33 names with the demo model's gender — "(male)",
# "(female)" — because it ships two GIFs of the same movement. We import no
# media, so the suffix labels nothing and would read as a bizarre distinction
# in the exercise list. Stripping it collapses 8 pairs into 6 duplicates that
# already existed upstream plus 2 new ones, all reported by the dedupe below.
_GENDER_SUFFIX = re.compile(r"\s*\((?:male|female)\)", re.IGNORECASE)


# ---------------------------------------------------------------------------
# Name normalisation
# ---------------------------------------------------------------------------
#
# 1,318 of the 1,324 upstream names are entirely lowercase ("3/4 sit-up",
# "45 degree side bend"). The app renders names verbatim beside its own Title
# Case entries, so they are cased here rather than at every call site.
#
# LOAD-BEARING: the name is the seed for `StableID.exercise(name)`, the UUIDv5
# that keys every catalog row. Changing how a name is cased re-issues that id.
# Do not tweak these rules after a seed has shipped without accepting that
# every renamed exercise becomes a new row (the old one is kept, never deleted,
# so older clients can still resolve it).

_WORD_SPLIT = re.compile(r"([ /\-()])")


def title_case(name: str) -> str:
    """`3/4 sit-up` -> `3/4 Sit-Up`. Capitalises across spaces, slashes,
    hyphens and parentheses, leaving digits and symbols untouched, and drops
    the media-only gender suffix."""
    parts = _WORD_SPLIT.split(_GENDER_SUFFIX.sub("", name).strip())
    out = []
    for part in parts:
        low = part.lower()
        if low in CASING_OVERRIDES:
            out.append(CASING_OVERRIDES[low])
        elif part.isalpha():
            out.append(part.capitalize())
        elif part[:1].isalpha():
            # Mixed alphanumerics keep their shape but gain a capital ("1st"
            # stays "1st", "v2" becomes "V2").
            out.append(part[:1].upper() + part[1:])
        else:
            out.append(part)
    return "".join(out)


def muscles_for(record: dict) -> list[str]:
    """Primary target first, then synergist, then secondaries — deduplicated
    while preserving that order, because the app shows the first entry as the
    headline muscle."""
    ordered = [record.get("target"), record.get("muscle_group")]
    ordered += record.get("secondary_muscles") or []
    seen: dict[str, None] = {}
    for muscle in ordered:
        if muscle:
            seen.setdefault(title_case(muscle), None)
    return list(seen)


# ---------------------------------------------------------------------------
# Derivation rules — fields upstream simply does not have
# ---------------------------------------------------------------------------
#
# Upstream carries no warm-up protocol and no YouTube link. The protocol TYPE
# strings below are ones already present in the hand-written library, so the
# detail screen keeps rendering a vocabulary it knows rather than gaining an
# unstyled variant.
#
# These are heuristics standing in for a coach's judgement, and they are
# deliberately conservative: a heavy barbell lift gets the full ramp, an
# isolation movement gets one set, anything cardio gets none. They are NOT as
# good as the hand-tuned protocols the curated library carried, which is the
# real cost of replacing it wholesale.

MOBILITY_HINTS = ("stretch", "mobility", "foam roll", "rotation", "circle", "swing")


def warmup_protocol(name: str, category: str, equipment: str) -> dict:
    lowered = name.lower()

    if category == "Cardio" or equipment == "Cardio Machine":
        # Steady-state work warms up by starting easy; a set/rep ramp is
        # meaningless here, and the app renders an empty step list as
        # "No Warmup Required" without complaint.
        return {"type": "No Warmup Required", "steps": []}

    if any(hint in lowered for hint in MOBILITY_HINTS):
        return {
            "type": "Mobility Sequence",
            "steps": [
                {"set": 1, "intensity": "Bodyweight", "reps": 10,
                 "description": "Move slowly through the full range, no bouncing."},
            ],
        }

    if equipment in ("Barbell", "Smith Machine"):
        return {
            "type": "Full Progressive Protocol",
            "steps": [
                {"set": 1, "intensity": "Empty Bar", "reps": 12,
                 "description": "Groove the movement pattern before adding load."},
                {"set": 2, "intensity": "50% Target Weight", "reps": 8,
                 "description": "Explosive concentric phase."},
                {"set": 3, "intensity": "70% Target Weight", "reps": 4,
                 "description": "Acclimatize to load without fatigue."},
                {"set": 4, "intensity": "90% Target Weight", "reps": 1,
                 "description": "Single feeler rep to prepare the CNS."},
            ],
        }

    if equipment in ("Machine", "Cable", "Assisted"):
        return {
            "type": "2-Set Standard Protocol",
            "steps": [
                {"set": 1, "intensity": "50% Target Weight", "reps": 12,
                 "description": "Set the pin and confirm the seat and pad positions."},
                {"set": 2, "intensity": "75% Target Weight", "reps": 6,
                 "description": "One ramp set at working tempo."},
            ],
        }

    return {
        "type": "1-Set Direct Protocol",
        "steps": [
            {"set": 1, "intensity": "Light", "reps": 12,
             "description": "One light set to find the working range."},
        ],
    }


def exercise_type(equipment: str) -> str:
    """The app's `type` vocabulary is Compound / Machine / Warm Up. Upstream
    has no equivalent field, so it is inferred from the apparatus exactly as
    `ExerciseDatabase` already infers it for its own records."""
    return "Machine" if equipment in MACHINE_EQUIPMENT else "Compound"


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------


def convert(record: dict, warn) -> dict | None:
    name = (record.get("name") or "").strip()
    if not name:
        warn(f"record {record.get('id', '?')}: no name — skipped")
        return None

    raw_category = (record.get("category") or record.get("body_part") or "").lower()
    raw_equipment = (record.get("equipment") or "").lower()

    category = CATEGORY_MAP.get(raw_category)
    if category is None:
        # An unmapped value would otherwise reach the UI as a stray filter
        # chip, so it is reported, and the record still imported under a
        # title-cased passthrough rather than being lost.
        category = title_case(raw_category) if raw_category else "Other"
        warn(f"{name}: unmapped category '{raw_category}' — passed through as '{category}'")

    equipment = EQUIPMENT_MAP.get(raw_equipment)
    if equipment is None:
        equipment = title_case(raw_equipment) if raw_equipment else "Other"
        warn(f"{name}: unmapped equipment '{raw_equipment}' — passed through as '{equipment}'")

    steps = (record.get("instruction_steps") or {}).get(LANGUAGE) or []
    if not steps:
        warn(f"{name}: no '{LANGUAGE}' instruction steps — imported without pro tips")

    cased = title_case(name)
    return {
        "name": cased,
        "category": category,
        "equipment": equipment,
        "muscles_targeted": muscles_for(record),
        "type": exercise_type(equipment),
        # Upstream has no video. Empty is the app's "no link" state; the detail
        # screen hides the button rather than showing a dead one.
        "youtube_url": "",
        # NEVER populate from upstream media — see the module docstring.
        "image_url": "",
        # The step-by-step instructions are the closest upstream equivalent of
        # our coaching cues, and the detail screen renders `pro_tips` as a
        # bulleted list, which is the shape they already have.
        "pro_tips": [step.strip() for step in steps if step and step.strip()],
        "warmup_protocol": warmup_protocol(cased, category, equipment),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--source",
        required=True,
        type=Path,
        help="Path to the upstream data/exercises.json (origin in the module docstring).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be imported without writing the library JSON.",
    )
    args = parser.parse_args()

    records = json.loads(args.source.read_text(encoding="utf-8"))
    warnings: list[str] = []

    # Deduplicate by the CASED name, which is what `StableID.exercise` hashes.
    # Two records colliding there would collapse into one catalog row anyway,
    # so it happens here where it can be reported, rather than silently inside
    # the seed's upsert.
    by_name: dict[str, dict] = {}
    collisions = 0
    for record in records:
        entry = convert(record, warnings.append)
        if entry is None:
            continue
        if entry["name"] in by_name:
            collisions += 1
            warnings.append(f"{entry['name']}: duplicate name — later record dropped")
            continue
        by_name[entry["name"]] = entry

    entries = sorted(by_name.values(), key=lambda e: e["name"])
    payload = json.dumps(entries, ensure_ascii=False, indent=2) + "\n"

    print(f"Read    {len(records)} upstream record(s) from {args.source}")
    print(f"Import  {len(entries)} exercise(s)"
          + (f", {collisions} duplicate name(s) dropped" if collisions else ""))
    print(f"Size    {len(payload.encode('utf-8')) / 1024 / 1024:.2f} MB")
    print("Media   0 image/video references imported "
          "(upstream media is not MIT — see THIRD_PARTY_NOTICES.md)")

    if args.dry_run:
        print("\nDry run — nothing written.")
    else:
        OUTPUT_JSON.write_text(payload, encoding="utf-8")
        print(f"\nWrote {OUTPUT_JSON.relative_to(REPO_ROOT)}")
        print("Next: python supabase/seed/generate_seed.py   (regenerates the catalog seed SQL)")

    for warning in warnings:
        print(f"  WARNING: {warning}", file=sys.stderr)


if __name__ == "__main__":
    main()
