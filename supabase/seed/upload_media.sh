#!/usr/bin/env bash
# upload_media.sh — GENERATED FILE, DO NOT EDIT BY HAND.
#
# Regenerate with:  python supabase/seed/generate_seed.py --project-ref <ref>
# Source folder:    supabase/seed/exercise-media/  (see its README.md)
# Images:           0
#
# Uploads every matched image to the PUBLIC `exercise-media` bucket. Run
# once after creating the bucket, with the project linked:
#     supabase storage buckets create exercise-media --public
#     supabase link --project-ref <ref>
#     bash supabase/seed/upload_media.sh
#
# Writing needs the SERVICE ROLE — 0009_exercise_media_bucket.sql grants
# anon/authenticated read only, so an anon-key run fails with 403.
#
# Re-runnable: `cp` overwrites the same object path. Beware the CDN cache
# when replacing an image — see the README's versioning note.

set -euo pipefail

# Paths below are relative to this script's own directory, so it runs the
# same from anywhere.
cd "$(dirname "${BASH_SOURCE[0]}")"

echo 'No images in exercise-media/ — nothing to upload.'
exit 0
