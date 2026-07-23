# Third-Party Notices

Third-party material redistributed in this repository, and the terms it carries.

---

## Exercise library data — `AuraFitness/Resources/gym_exercise_library.json`

Derived from **[hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)**
by importing `data/exercises.json` through `supabase/seed/import_dataset.py`,
which maps the upstream fields onto this app's schema. Exercise names,
categories, equipment, muscle groups and instructions originate there; the
warm-up protocols and difficulty ratings are derived locally by that script.

The upstream **data** is MIT licensed. MIT requires its copyright notice and
permission notice to be retained in redistributions, so the upstream `LICENSE`
is reproduced verbatim at `supabase/seed/UPSTREAM_LICENSE`, and its copyright
line is:

> Copyright (c) 2026 Hasan Emir Yıldırım

The MIT permission notice, warranty disclaimer and liability disclaimer in that
file apply to the imported data and travel with it.

### The upstream images and videos are NOT imported, and must not be

That MIT grant explicitly excludes the upstream `images/` and `videos/`
directories. Those files are the property of **Gym visual**
(https://gymvisual.com/) and appear upstream under a permission granted to that
repository specifically. Upstream's own `NOTICE.md` states that *"cloning this
repo is not a license"* and that the repository *"does not grant you any rights
to the media beyond what Gym visual's terms allow."*

We therefore import **none** of it. `import_dataset.py` drops the `image`,
`gif_url`, `media_id` and `attribution` fields, and writes every record's
`image_url` as an empty string; the app renders a muscle-tinted gradient in
place of a missing image.

Do not populate those fields from upstream paths, and do not hotlink their raw
GitHub URLs — both redistribute media we hold no licence for, into a bucket
(`exercise-media`) that is world-readable and carries no attribution surface.

Licensing that imagery means agreeing terms directly with Gym visual, under
their Terms & Conditions:
https://gymvisual.com/content/3-terms-and-conditions-of-use

Licensed imagery, if it is ever obtained, belongs in
`supabase/seed/exercise-media/` — see that folder's `README.md` and
`supabase/migrations/0009_exercise_media_bucket.sql`.
