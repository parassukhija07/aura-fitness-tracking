#!/usr/bin/env bash
#
# RLS isolation test for the pull_changes(since) RPC (backend phase1-01).
#
# Verifies empirically what `security invoker` + the per-table owner_all policy
# are supposed to guarantee: user B calling pull_changes can never see user A's
# rows, no matter what `since` value B forges.
#
# Uses ONLY the anon key — no service_role key is required or accepted.
#
# TWO CONSEQUENCES OF THAT, both deliberate:
#
#   1. Users are created with the public /auth/v1/signup endpoint, which only
#      returns a session when the project has email confirmation DISABLED
#      (Dashboard > Authentication > Sign In / Providers > "Confirm email").
#      With confirmation ON, signup yields no access token, there is nothing to
#      authenticate as, and this script FAILS LOUDLY rather than exiting green
#      without having verified anything. A verification job that silently
#      verifies nothing is worse than one that fails.
#
#   2. Cleanup can delete the two test ROWS (the owner_all policy permits an
#      owner to delete its own rows) but NOT the two test USERS, which requires
#      admin privileges. Two throwaway users are therefore LEFT BEHIND in
#      auth.users on every run. They are named aura-rls-{a,b}-<stamp>@example.com
#      so you can find and purge them from the Dashboard.
#
# Required env:
#   SUPABASE_URL       https://<project-ref>.supabase.co
#   SUPABASE_ANON_KEY  anon/publishable key
#
# WARNING: runs against whatever project SUPABASE_URL points at, and leaves two
# auth users behind there. Do not point it at a project where that matters.

set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

BASE="${SUPABASE_URL%/}"
EPOCH="1970-01-01T00:00:00.000Z"
PASSWORD="rls-test-$(date +%s)-Aa1!"

new_uuid() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  else
    python3 -c 'import uuid; print(uuid.uuid4())'
  fi
}

JWT_A=""
JWT_B=""
ROW_A=""
ROW_B=""
EMAIL_A=""
EMAIL_B=""

# Deletes each test row as its own owner. Runs even when an assertion fails.
# Cannot remove the users themselves without admin rights — see header.
cleanup() {
  local code=$?
  set +e
  if [ -n "$JWT_A" ] && [ -n "$ROW_A" ]; then
    curl --silent --show-error --output /dev/null \
      -X DELETE "$BASE/rest/v1/aura_workout_logs?id=eq.$ROW_A" \
      -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT_A"
    echo "cleanup: deleted row $ROW_A"
  fi
  if [ -n "$JWT_B" ] && [ -n "$ROW_B" ]; then
    curl --silent --show-error --output /dev/null \
      -X DELETE "$BASE/rest/v1/aura_workout_logs?id=eq.$ROW_B" \
      -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT_B"
    echo "cleanup: deleted row $ROW_B"
  fi
  if [ -n "$EMAIL_A" ] || [ -n "$EMAIL_B" ]; then
    echo "NOTE: these throwaway users remain in auth.users and need manual"
    echo "      removal from the Dashboard (no admin key available here):"
    [ -n "$EMAIL_A" ] && echo "      $EMAIL_A"
    [ -n "$EMAIL_B" ] && echo "      $EMAIL_B"
  fi
  exit $code
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Signs up a user and echoes "<uuid> <access_token>". GoTrue returns the token
# at the top level on some versions and under .session on others; when email
# confirmation is enabled it returns neither, which the caller treats as fatal.
signup() {
  local email="$1" body
  body="$(curl --silent --show-error --fail \
    -X POST "$BASE/auth/v1/signup" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\"}")"
  echo "$body" | jq -r '
    [ (.id // .user.id // ""),
      (.access_token // .session.access_token // "") ] | join(" ")'
}

insert_log_row() {
  local jwt="$1" uid="$2" row_id="$3"
  curl --silent --show-error --fail --output /dev/null \
    -X POST "$BASE/rest/v1/aura_workout_logs" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $jwt" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"$row_id\",\"user_id\":\"$uid\",\"payload\":{\"rls_probe\":true}}"
}

call_pull_changes() {
  local jwt="$1" since="$2"
  curl --silent --show-error --fail \
    -X POST "$BASE/rest/v1/rpc/pull_changes" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $jwt" \
    -H "Content-Type: application/json" \
    -d "{\"since\":\"$since\"}"
}

stamp="$(date +%s)-$RANDOM"
EMAIL_A="aura-rls-a-$stamp@example.com"
EMAIL_B="aura-rls-b-$stamp@example.com"

echo "==> signing up two throwaway users"
read -r USER_A_ID TOKEN_A <<<"$(signup "$EMAIL_A")"
read -r USER_B_ID TOKEN_B <<<"$(signup "$EMAIL_B")"

if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ]; then
  echo "Signup returned no access token." >&2
  echo "This project almost certainly has email confirmation ENABLED, so a new" >&2
  echo "user has no session until the emailed link is clicked, and there is no" >&2
  echo "identity to run the isolation test as." >&2
  echo >&2
  echo "To run this test, temporarily turn off Dashboard > Authentication >" >&2
  echo "Sign In / Providers > 'Confirm email', re-run, then turn it back on." >&2
  fail "cannot authenticate as test users; nothing was verified"
fi
[ -n "$USER_A_ID" ] && [ "$USER_A_ID" != "null" ] || fail "signup A returned no user id"
[ -n "$USER_B_ID" ] && [ "$USER_B_ID" != "null" ] || fail "signup B returned no user id"

# Assign only after the tokens are known good, so the trap never fires DELETEs
# with an empty Authorization header.
JWT_A="$TOKEN_A"
JWT_B="$TOKEN_B"
echo "    A=$USER_A_ID"
echo "    B=$USER_B_ID"

ROW_A="$(new_uuid)"
ROW_B="$(new_uuid)"
echo "==> writing one aura_workout_logs row as each user"
insert_log_row "$JWT_A" "$USER_A_ID" "$ROW_A"
insert_log_row "$JWT_B" "$USER_B_ID" "$ROW_B"

echo "==> calling pull_changes(since=$EPOCH) as each user"
RESP_A="$(call_pull_changes "$JWT_A" "$EPOCH")"
RESP_B="$(call_pull_changes "$JWT_B" "$EPOCH")"

# --- Assertion 1: each user sees its OWN row. Without this, assertion 2 could
# pass trivially because the RPC returned nothing at all.
echo "$RESP_A" | jq -e --arg id "$ROW_A" \
  '.aura_workout_logs | map(.id) | index($id) != null' >/dev/null \
  || fail "user A's own row $ROW_A missing from its pull_changes response"
echo "$RESP_B" | jq -e --arg id "$ROW_B" \
  '.aura_workout_logs | map(.id) | index($id) != null' >/dev/null \
  || fail "user B's own row $ROW_B missing from its pull_changes response"
echo "    ok: each user sees its own row"

# --- Assertion 2: the isolation claim itself, checked in both directions.
echo "$RESP_B" | jq -e --arg id "$ROW_A" \
  '.aura_workout_logs | map(.id) | index($id) == null' >/dev/null \
  || fail "LEAK: user B's pull_changes response contained user A's row $ROW_A"
echo "$RESP_A" | jq -e --arg id "$ROW_B" \
  '.aura_workout_logs | map(.id) | index($id) == null' >/dev/null \
  || fail "LEAK: user A's pull_changes response contained user B's row $ROW_B"
echo "    ok: neither user sees the other's row"

# --- Assertion 3: the response shape the Swift decoder depends on. The client's
# PullChangesResponse declares all 12 keys non-optional, so a missing key is a
# decode failure that silently degrades every sync to a full pull.
EXPECTED_KEYS='["aura_body_stats","aura_day_overrides","aura_exercises","aura_measurements","aura_personal_records","aura_plans","aura_preferences","aura_programs","aura_progress_photos","aura_quick_logs","aura_user_profile","aura_workout_logs"]'
echo "$RESP_B" | jq -e --argjson want "$EXPECTED_KEYS" \
  '(keys | sort) == ($want | sort)' >/dev/null \
  || fail "response keys != the 12 aura_* tables the Swift decoder requires: $(echo "$RESP_B" | jq -c 'keys')"
echo "    ok: all 12 table keys present"

# --- Assertion 4: a forged far-future `since` must narrow to nothing, never
# widen or fall back to returning everything.
FUTURE_RESP="$(call_pull_changes "$JWT_B" "2999-01-01T00:00:00.000Z")"
echo "$FUTURE_RESP" | jq -e '.aura_workout_logs | length == 0' >/dev/null \
  || fail "a far-future since returned rows; the '> since' filter is not applied"
echo "    ok: far-future since returns nothing"

echo
echo "PASS: pull_changes enforces per-user isolation (security invoker + RLS)."
