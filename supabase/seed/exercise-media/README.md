# `exercise-media/` — source images for the public catalog bucket

Drop exercise images here, regenerate the seed, upload. That's the whole loop.
This folder is the SOURCE; the served copies live in the public Supabase
Storage bucket `exercise-media` (see
`supabase/migrations/0009_exercise_media_bucket.sql`).

## Filename contract

    <exercise-name>.jpg

lowercase, spaces become `-`, every other character dropped. The generator
derives the same slug from each exercise's name in
`AuraFitness/Resources/gym_exercise_library.json`, so the filename is how an
image finds its exercise:

| Exercise name         | Filename                  |
| --------------------- | ------------------------- |
| `Barbell Bench Press` | `barbell-bench-press.jpg` |
| `Cable Crossover`     | `cable-crossover.jpg`     |
| `Seated Cable Row`    | `seated-cable-row.jpg`    |

A file whose slug matches no exercise is **reported and skipped** — it is not
uploaded and no row references it. Check the generator's output for
`no exercise matches` after adding images; a silent typo is the failure mode
this warning exists to catch.

Only `.jpg` is scanned. `.jpeg`, `.png`, `.webp` are ignored (with a warning) —
the object path is `<uuid>.jpg` and the bucket serves `image/jpeg`, so convert
before dropping the file in.

## Image requirements

- **≤ 200 KB each.** Oversized files WARN but still generate — the grid loads
  these on cellular, so treat a warning as a to-do, not noise.
- **4:3 or square.** `RemoteExerciseImage` renders `.fill` and clips, so a wildly
  different aspect ratio loses its subject to the crop.
- **Licensing must permit redistribution.** These are re-hosted on our own CDN
  and served publicly with no attribution surface. Anything that requires
  attribution or forbids re-hosting cannot go in this folder.

## Workflow

Once, before the first upload — create the bucket and apply the policy:

```bash
supabase storage buckets create exercise-media --public
supabase db push        # applies 0009_exercise_media_bucket.sql
```

Then, every time images change:

```bash
# 1. regenerate the catalog SQL with the public URLs baked in
python supabase/seed/generate_seed.py --project-ref <your-project-ref>

# 2. upload the images (generated; one `supabase storage cp` per image)
bash supabase/seed/upload_media.sh

# 3. apply the catalog SQL with the SERVICE ROLE
#    (Dashboard SQL editor, or psql with the connection string)
```

`--project-ref` is the subdomain of your Supabase URL —
`https://<project-ref>.supabase.co`. It is a CLI argument on purpose: the ref
differs per environment and is never hardcoded in the generator. Step 1 fails
loudly if this folder holds images and no ref was passed, rather than emitting
half-formed URLs.

Steps 2 and 3 must both run. Uploading without regenerating leaves rows
pointing at the old URL; regenerating without uploading points rows at objects
that 404.

## What a missing image does

Nothing bad. It is a NORMAL, permanent state — custom exercises and new catalog
entries will never have one. An exercise with no file here keeps whatever
`image_url` its library JSON entry already carries, and an empty URL or a 404
both land on `RemoteExerciseImage`'s muscle-tinted gradient, with no error UI
and no retry loop. Missing imagery is never an error surface.

## Replacing an image (cache caveat)

Uploading over the same path can keep serving the OLD bytes for the CDN's TTL —
Supabase sets a long `Cache-Control` on public objects. Acceptable for a
correction that isn't urgent.

To force a refresh, don't fight the cache: publish under a NEW path so the URL
itself changes. Rename the source file with a version suffix
(`barbell-bench-press-v2.jpg`) and add that suffixed slug to the exercise's
entry in the generator's alias table, then regenerate and re-upload. New path,
new URL, no stale bytes.

## Do not put user content here

The bucket is world-readable with no auth check whatsoever. Progress photos and
anything else user-owned belong in `progress-photos` (private, owner-only
policies — `0006_progress_photos_storage.sql`). This bucket is also
deliberately absent from `USER_BUCKETS` in
`supabase/functions/delete-account/index.ts`: it is shared, so purging it on one
account's deletion would destroy every other user's imagery.
