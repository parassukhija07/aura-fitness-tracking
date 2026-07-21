#!/usr/bin/env bash
#
# RLS isolation test for the pull_changes(since) RPC (backend phase1-01).
#
# Verifies empirically what `security invoker` + the per-table owner_all policy
# are supposed to guarantee: user B calling pull_changes can never see user A's
# rows, no matter what `since` value B forges.
#
# Creates two throwaway confirmed users, writes one row as each, calls the RPC
# as each, asserts isolation, then deletes both users. `aura_*.user_id` is
# `references auth.users(id) on delete cascade`, so deleting the users removes
# their rows too — the trap below runs cleanup even when an assertion fails.
#
# Required env:
#   SUPABASE_URL               https://<project-ref>.supabase.co
#   SUPABASE_ANON_KEY          anon/publishable key (acts as the client)
#   SUPABASE_SERVICE_ROLE_KEY  service_role key (admin user create/delete only)
#
# WARNING: this runs against whatever project SUPABASE_URL points at. It briefly
# creates two auth users and two rows, then removes them. Do not point it at a
# project where that is unacceptable.

set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is required}"

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

USER_A_ID=""
USER_B_ID=""

cleanup() {
  local code=$?
  set +e
  for uid in "$USER_A_ID" "$USER_B_ID"; do
    [ -n "$uid" ] || continue
    curl --silent --show-error --output /dev/null \
      -X DELETE "$BASE/auth/v1/admin/users/$uid" \
      -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
      -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
    echo "cleanup: deleted test user $uid (cascade removed its aura_* rows)"
  done
  exit $code
}
trap cleanup EXIT

# Creates a confirmed user and echoes its uuid. email_confirm bypasses the
# signup confirmation flow, which would otherwise withhold a session.
admin_create_user() {
  local email="$1"
  curl --silent --show-error --fail \
    -X POST "$BASE/auth/v1/admin/users" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\",\"email_confirm\":true}" \
    | jq -r '.id'
}

# Echoes a user access token. Never logged — it is a live credential.
sign_in() {
  local email="$1"
  curl --silent --show-error --fail \
    -X POST "$BASE/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\"}" \
    | jq -r '.access_token'
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

fail() { echo "FAIL: $*" >&2; exit 1; }

stamp="$(date +%s)-$RANDOM"
EMAIL_A="aura-rls-a-$stamp@example.com"
EMAIL_B="aura-rls-b-$stamp@example.com"

echo "==> creating two throwaway users"
USER_A_ID="$(admin_create_user "$EMAIL_A")"
USER_B_ID="$(admin_create_user "$EMAIL_B")"
[ -n "$USER_A_ID" ] && [ "$USER_A_ID" != "null" ] || fail "could not create user A"
[ -n "$USER_B_ID" ] && [ "$USER_B_ID" != "null" ] || fail "could not create user B"
echo "    A=$USER_A_ID"
echo "    B=$USER_B_ID"

JWT_A="$(sign_in "$EMAIL_A")"
JWT_B="$(sign_in "$EMAIL_B")"
[ -n "$JWT_A" ] && [ "$JWT_A" != "null" ] || fail "could not sign in as user A"
[ -n "$JWT_B" ] && [ "$JWT_B" != "null" ] || fail "could not sign in as user B"

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
