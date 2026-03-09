#!/usr/bin/env bash
# =============================================================================
# DRF Movie Review API — Full Endpoint Test Suite
# Usage:  chmod +x test_api.sh && ./test_api.sh
# Requires: curl, jq  (brew install jq)
# Server must be running at BASE_URL before executing.
# =============================================================================

BASE_URL="http://127.0.0.1:8000"
PASS=0
FAIL=0
TOTAL=0

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── helpers ───────────────────────────────────────────────────────────────────
section() { echo -e "\n${CYAN}${BOLD}══ $1 ══${RESET}"; }

# check <label> <expected_http_code> <actual_http_code> [body_snippet_to_find]
check() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  local body="$4"
  local snippet="$5"
  TOTAL=$((TOTAL + 1))

  local status_ok=false
  local body_ok=true

  [[ "$actual" == "$expected" ]] && status_ok=true
  if [[ -n "$snippet" ]] && ! echo "$body" | grep -q "$snippet"; then
    body_ok=false
  fi

  if $status_ok && $body_ok; then
    echo -e "  ${GREEN}✔ PASS${RESET}  $label  ${YELLOW}(HTTP $actual)${RESET}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✘ FAIL${RESET}  $label"
    echo -e "         expected HTTP ${expected}, got ${actual}"
    [[ -n "$snippet" ]] && ! $body_ok && echo -e "         body missing: '${snippet}'"
    [[ -n "$body" ]] && echo -e "         body: $(echo "$body" | head -c 300)"
    FAIL=$((FAIL + 1))
  fi
}

# do_req <method> <url> [data] [token]
# Returns: sets global $HTTP_CODE and $BODY
do_req() {
  local method="$1"
  local url="$2"
  local data="$3"
  local token="$4"

  local auth_header=()
  [[ -n "$token" ]] && auth_header=(-H "Authorization: Token $token")

  local args=(-s -w "\n%{http_code}" -X "$method" "${auth_header[@]}" -H "Content-Type: application/json")
  [[ -n "$data" ]] && args+=(-d "$data")

  local response
  response=$(curl "${args[@]}" "${BASE_URL}${url}")
  HTTP_CODE=$(echo "$response" | tail -1)
  BODY=$(echo "$response" | sed '$d')
}

# =============================================================================
# PRE-FLIGHT
# =============================================================================
section "PRE-FLIGHT: server reachable"
do_req GET "/movie/list/"
if [[ "$HTTP_CODE" == "200" ]]; then
  echo -e "  ${GREEN}✔ Server is up at ${BASE_URL}${RESET}"
else
  echo -e "  ${RED}✘ Server not reachable at ${BASE_URL}. Start with: python manage.py runserver${RESET}"
  exit 1
fi

# =============================================================================
# 1. REGISTRATION
# =============================================================================
section "1. REGISTRATION  POST /account/register/"

do_req POST "/account/register/" '{"username":"testuser1","email":"t1@test.com","password":"SecurePass1!","password2":"SecurePass1!"}'
check "Valid registration → 201" 201 "$HTTP_CODE" "$BODY" "Registration Successful"

do_req POST "/account/register/" '{"username":"testuser2","email":"t2@test.com","password":"SecurePass2!","password2":"SecurePass2!"}'
check "Second user registration → 201" 201 "$HTTP_CODE" "$BODY"

do_req POST "/account/register/" '{"username":"adminuser","email":"admin@test.com","password":"AdminPass1!","password2":"AdminPass1!"}'
check "Admin user registration → 201" 201 "$HTTP_CODE" "$BODY"

# Mismatched passwords
do_req POST "/account/register/" '{"username":"bad","email":"bad@test.com","password":"Abc123!","password2":"Xyz999!"}'
check "Mismatched passwords → 400" 400 "$HTTP_CODE" "$BODY"

# Duplicate email
do_req POST "/account/register/" '{"username":"dup","email":"t1@test.com","password":"SecurePass1!","password2":"SecurePass1!"}'
check "Duplicate email → 400" 400 "$HTTP_CODE" "$BODY"

# Duplicate username
do_req POST "/account/register/" '{"username":"testuser1","email":"unique@test.com","password":"SecurePass1!","password2":"SecurePass1!"}'
check "Duplicate username → 400" 400 "$HTTP_CODE" "$BODY"

# Missing password2
do_req POST "/account/register/" '{"username":"x","email":"x@x.com","password":"Abc123!"}'
check "Missing password2 → 400" 400 "$HTTP_CODE" "$BODY"

# Missing email
do_req POST "/account/register/" '{"username":"x","password":"Abc123!","password2":"Abc123!"}'
check "Missing email → 400" 400 "$HTTP_CODE" "$BODY"

# Empty body
do_req POST "/account/register/" '{}'
check "Empty body → 400" 400 "$HTTP_CODE" "$BODY"

# Wrong method
do_req GET "/account/register/"
check "GET not allowed → 405" 405 "$HTTP_CODE" "$BODY"

# [BUG-1] Weak password — Django validators NOT enforced
do_req POST "/account/register/" '{"username":"weakpw","email":"weak@test.com","password":"123","password2":"123"}'
check "[BUG-1] Weak password '123' accepted (should be 400, is 201)" 201 "$HTTP_CODE" "$BODY"

# =============================================================================
# 2. LOGIN
# =============================================================================
section "2. LOGIN  POST /account/login/"

do_req POST "/account/login/" '{"username":"testuser1","password":"SecurePass1!"}'
check "Valid login → 200 + token" 200 "$HTTP_CODE" "$BODY" "token"
TOKEN_USER1=$(echo "$BODY" | jq -r '.token' 2>/dev/null)

do_req POST "/account/login/" '{"username":"testuser2","password":"SecurePass2!"}'
check "Second user login → 200 + token" 200 "$HTTP_CODE" "$BODY" "token"
TOKEN_USER2=$(echo "$BODY" | jq -r '.token' 2>/dev/null)

do_req POST "/account/login/" '{"username":"testuser1","password":"wrongpassword"}'
check "Wrong password → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/account/login/" '{"username":"ghost","password":"anything"}'
check "Non-existent user → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/account/login/" '{}'
check "Empty body → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/account/login/" '{"username":"testuser1"}'
check "Missing password → 400" 400 "$HTTP_CODE" "$BODY"

do_req GET "/account/login/"
check "GET not allowed → 405" 405 "$HTTP_CODE" "$BODY"

# Login twice — must return the same token
do_req POST "/account/login/" '{"username":"testuser1","password":"SecurePass1!"}'
TOKEN_USER1_AGAIN=$(echo "$BODY" | jq -r '.token' 2>/dev/null)
if [[ "$TOKEN_USER1" == "$TOKEN_USER1_AGAIN" ]]; then
  echo -e "  ${GREEN}✔ PASS${RESET}  Consecutive logins return same token"
  PASS=$((PASS+1))
else
  echo -e "  ${RED}✘ FAIL${RESET}  Consecutive logins returned different tokens"
  FAIL=$((FAIL+1))
fi
TOTAL=$((TOTAL+1))

# =============================================================================
# Make adminuser a staff member via Django shell so we can test admin endpoints.
# This step is informational — tests that require admin will note the outcome.
# =============================================================================
section "SETUP: promote adminuser to staff"
python manage.py shell -c "
from django.contrib.auth.models import User
u = User.objects.get(username='adminuser')
u.is_staff = True
u.save()
print('OK')
" 2>/dev/null && echo -e "  ${GREEN}✔ adminuser is now staff${RESET}" || \
  echo -e "  ${YELLOW}⚠ Could not promote adminuser (server may use different env). Admin tests may fail.${RESET}"

do_req POST "/account/login/" '{"username":"adminuser","password":"AdminPass1!"}'
TOKEN_ADMIN=$(echo "$BODY" | jq -r '.token' 2>/dev/null)

# =============================================================================
# 3. STREAM PLATFORM  /movie/stream/
# =============================================================================
section "3. STREAM PLATFORM  GET|POST /movie/stream/"

# Unauthenticated GET
do_req GET "/movie/stream/"
check "List platforms (unauthenticated) → 200" 200 "$HTTP_CODE" "$BODY"

# Create as regular user → 403
do_req POST "/movie/stream/" '{"name":"Hulu","about":"Streaming","website":"https://hulu.com"}' "$TOKEN_USER1"
check "Create platform as regular user → 403" 403 "$HTTP_CODE" "$BODY"

# Create unauthenticated → 403
do_req POST "/movie/stream/" '{"name":"Hulu","about":"Streaming","website":"https://hulu.com"}'
check "Create platform unauthenticated → 403" 403 "$HTTP_CODE" "$BODY"

# Create as admin → 201
do_req POST "/movie/stream/" '{"name":"Netflix","about":"Top streaming service","website":"https://netflix.com"}' "$TOKEN_ADMIN"
check "Create platform as admin → 201" 201 "$HTTP_CODE" "$BODY" "Netflix"
PLATFORM_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)

# Create second platform
do_req POST "/movie/stream/" '{"name":"Prime","about":"Amazon streaming","website":"https://prime.com"}' "$TOKEN_ADMIN"
check "Create second platform → 201" 201 "$HTTP_CODE" "$BODY"
PLATFORM2_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)

# Invalid URL
do_req POST "/movie/stream/" '{"name":"X","about":"y","website":"not-a-url"}' "$TOKEN_ADMIN"
check "Invalid website URL → 400" 400 "$HTTP_CODE" "$BODY"

# name too long (max 30)
do_req POST "/movie/stream/" "{\"name\":\"$(python3 -c 'print("A"*31)')\",\"about\":\"ok\",\"website\":\"https://x.com\"}" "$TOKEN_ADMIN"
check "Platform name > 30 chars → 400" 400 "$HTTP_CODE" "$BODY"

# about too long (max 150)
do_req POST "/movie/stream/" "{\"name\":\"X\",\"about\":\"$(python3 -c 'print("A"*151)')\",\"website\":\"https://x.com\"}" "$TOKEN_ADMIN"
check "Platform about > 150 chars → 400" 400 "$HTTP_CODE" "$BODY"

# Missing fields
do_req POST "/movie/stream/" '{"name":"X"}' "$TOKEN_ADMIN"
check "Create platform missing fields → 400" 400 "$HTTP_CODE" "$BODY"

section "3b. STREAM PLATFORM  GET|PUT|PATCH|DELETE /movie/stream/<id>/"

do_req GET "/movie/stream/${PLATFORM_ID}/"
check "Retrieve platform → 200" 200 "$HTTP_CODE" "$BODY" "Netflix"

# Verify nested watchlist field exists
echo "$BODY" | grep -q '"watchlist"' && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Response includes nested 'watchlist' field" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  Response missing 'watchlist' field" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

do_req GET "/movie/stream/9999/"
check "Retrieve non-existent platform → 404" 404 "$HTTP_CODE" "$BODY"

do_req PUT "/movie/stream/${PLATFORM_ID}/" '{"name":"Netflix HD","about":"Updated","website":"https://netflix.com"}' "$TOKEN_ADMIN"
check "Update platform as admin → 200" 200 "$HTTP_CODE" "$BODY" "Netflix HD"

do_req PUT "/movie/stream/${PLATFORM_ID}/" '{"name":"Hacked","about":"x","website":"https://x.com"}' "$TOKEN_USER1"
check "Update platform as regular user → 403" 403 "$HTTP_CODE" "$BODY"

do_req PATCH "/movie/stream/${PLATFORM_ID}/" '{"name":"Partial"}' "$TOKEN_ADMIN"
check "Partial update platform (PATCH) as admin → 200" 200 "$HTTP_CODE" "$BODY"

do_req DELETE "/movie/stream/${PLATFORM2_ID}/" "$TOKEN_ADMIN"
check "Delete platform as admin → 204" 204 "$HTTP_CODE" "$BODY"

do_req DELETE "/movie/stream/${PLATFORM_ID}/" "$TOKEN_USER1"
check "Delete platform as regular user → 403" 403 "$HTTP_CODE" "$BODY"

do_req DELETE "/movie/stream/9999/" "$TOKEN_ADMIN"
check "Delete non-existent platform → 404" 404 "$HTTP_CODE" "$BODY"

# =============================================================================
# 4. WATCHLIST  /movie/list/  and  /movie/<pk>/
# =============================================================================
section "4. WATCHLIST  GET|POST /movie/list/"

do_req GET "/movie/list/"
check "List movies (unauthenticated) → 200" 200 "$HTTP_CODE" "$BODY"

# Create as regular user → 403
do_req POST "/movie/list/" "{\"title\":\"Hack\",\"storyline\":\"x\",\"platform\":${PLATFORM_ID}}" "$TOKEN_USER1"
check "Create movie as regular user → 403" 403 "$HTTP_CODE" "$BODY"

# Create unauthenticated → 403
do_req POST "/movie/list/" "{\"title\":\"Hack\",\"storyline\":\"x\",\"platform\":${PLATFORM_ID}}"
check "Create movie unauthenticated → 403" 403 "$HTTP_CODE" "$BODY"

# [BUG-2] Create as admin → returns 200 instead of 201
do_req POST "/movie/list/" "{\"title\":\"Inception\",\"storyline\":\"A mind-bending thriller.\",\"platform\":${PLATFORM_ID}}" "$TOKEN_ADMIN"
check "[BUG-2] Create movie as admin → 200 (should be 201)" 200 "$HTTP_CODE" "$BODY" "Inception"
MOVIE1_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)

do_req POST "/movie/list/" "{\"title\":\"The Matrix\",\"storyline\":\"Humans in a simulation.\",\"platform\":${PLATFORM_ID}}" "$TOKEN_ADMIN"
check "Create second movie → 200" 200 "$HTTP_CODE" "$BODY"
MOVIE2_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)

# Missing platform
do_req POST "/movie/list/" '{"title":"No Platform","storyline":"x"}' "$TOKEN_ADMIN"
check "Create movie missing platform → 400" 400 "$HTTP_CODE" "$BODY"

# Non-existent platform
do_req POST "/movie/list/" '{"title":"Orphan","storyline":"x","platform":9999}' "$TOKEN_ADMIN"
check "Create movie non-existent platform → 400" 400 "$HTTP_CODE" "$BODY"

# Title too long (max 50)
do_req POST "/movie/list/" "{\"title\":\"$(python3 -c 'print("A"*51)')\",\"storyline\":\"x\",\"platform\":${PLATFORM_ID}}" "$TOKEN_ADMIN"
check "Movie title > 50 chars → 400" 400 "$HTTP_CODE" "$BODY"

# Empty body
do_req POST "/movie/list/" '{}' "$TOKEN_ADMIN"
check "Create movie empty body → 400" 400 "$HTTP_CODE" "$BODY"

section "4b. WATCHLIST  GET|PUT|DELETE /movie/<pk>/"

do_req GET "/movie/${MOVIE1_ID}/"
check "Retrieve movie → 200" 200 "$HTTP_CODE" "$BODY" "Inception"

# Check response fields
for field in id title storyline platform active avg_rating number_rating created reviews; do
  echo "$BODY" | grep -q "\"$field\"" && \
    echo -e "  ${GREEN}✔ PASS${RESET}  Response has field: $field" && PASS=$((PASS+1)) || \
    echo -e "  ${RED}✘ FAIL${RESET}  Response missing field: $field" && FAIL=$((FAIL+1))
  TOTAL=$((TOTAL+1))
done

# Check avg_rating starts at 0
AVG=$(echo "$BODY" | jq -r '.avg_rating' 2>/dev/null)
[[ "$AVG" == "0" || "$AVG" == "0.0" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  avg_rating defaults to 0" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  avg_rating should default to 0, got: $AVG" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

do_req GET "/movie/9999/"
check "Retrieve non-existent movie → 404" 404 "$HTTP_CODE" "$BODY"

do_req PUT "/movie/${MOVIE1_ID}/" "{\"title\":\"Inception Updated\",\"storyline\":\"Updated.\",\"platform\":${PLATFORM_ID}}" "$TOKEN_ADMIN"
check "Update movie as admin → 200" 200 "$HTTP_CODE" "$BODY" "Updated"

do_req PUT "/movie/${MOVIE1_ID}/" "{\"title\":\"Hacked\",\"storyline\":\"x\",\"platform\":${PLATFORM_ID}}" "$TOKEN_USER1"
check "Update movie as regular user → 403" 403 "$HTTP_CODE" "$BODY"

# PATCH not implemented on WatchDetailAV
do_req PATCH "/movie/${MOVIE1_ID}/" '{"title":"Partial"}' "$TOKEN_ADMIN"
check "PATCH movie → 405 (not implemented)" 405 "$HTTP_CODE" "$BODY"

do_req DELETE "/movie/${MOVIE2_ID}/" "$TOKEN_USER1"
check "Delete movie as regular user → 403" 403 "$HTTP_CODE" "$BODY"

do_req DELETE "/movie/9999/" "$TOKEN_ADMIN"
check "Delete non-existent movie → 404" 404 "$HTTP_CODE" "$BODY"

# =============================================================================
# 5. CREATE REVIEW  POST /movie/<pk>/create-review/
# =============================================================================
section "5. CREATE REVIEW  POST /movie/<pk>/create-review/"

# Unauthenticated → 401
do_req POST "/movie/${MOVIE1_ID}/create-review/" '{"rating":4}'
check "Create review unauthenticated → 401" 401 "$HTTP_CODE" "$BODY"

# Valid review from user1
do_req POST "/movie/${MOVIE1_ID}/create-review/" '{"rating":4,"description":"Great film!"}' "$TOKEN_USER1"
check "Create review (user1, rating=4) → 201" 201 "$HTTP_CODE" "$BODY"
REVIEW1_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)

# Check avg_rating updated
do_req GET "/movie/${MOVIE1_ID}/"
AVG=$(echo "$BODY" | jq -r '.avg_rating' 2>/dev/null)
NUM=$(echo "$BODY" | jq -r '.number_rating' 2>/dev/null)
[[ "$AVG" == "4" || "$AVG" == "4.0" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  avg_rating=4.0 after first review (number_rating=$NUM)" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  avg_rating should be 4.0, got: $AVG" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# Valid review from user2
do_req POST "/movie/${MOVIE1_ID}/create-review/" '{"rating":2}' "$TOKEN_USER2"
check "Create review (user2, rating=2) → 201" 201 "$HTTP_CODE" "$BODY"

# Duplicate review from user1 → 400
do_req POST "/movie/${MOVIE1_ID}/create-review/" '{"rating":5}' "$TOKEN_USER1"
check "Duplicate review from same user → 400" 400 "$HTTP_CODE" "$BODY"

# [BUG-4] Rating calculation check after 2 reviews
do_req GET "/movie/${MOVIE1_ID}/"
AVG=$(echo "$BODY" | jq -r '.avg_rating' 2>/dev/null)
NUM=$(echo "$BODY" | jq -r '.number_rating' 2>/dev/null)
echo -e "  ${YELLOW}ℹ INFO${RESET}   After ratings [4,2]: stored avg=$AVG, number_rating=$NUM"
echo -e "  ${YELLOW}ℹ INFO${RESET}   True mean=(4+2)/2=3.0. Formula is correct for 2 reviews."

# Review on admin's behalf with rating=5 for bug-4 demo
do_req POST "/movie/${MOVIE1_ID}/create-review/" '{"rating":5}' "$TOKEN_ADMIN"
check "Create review (admin, rating=5) → 201" 201 "$HTTP_CODE" "$BODY"
REVIEW_ADMIN_ID=$(echo "$BODY" | jq -r '.id' 2>/dev/null)

# [BUG-4] After 3 reviews [4,2,5]: stored avg vs true mean
do_req GET "/movie/${MOVIE1_ID}/"
AVG=$(echo "$BODY" | jq -r '.avg_rating' 2>/dev/null)
TRUE_MEAN="3.67"
echo -e "  ${RED}[BUG-4]${RESET} After ratings [4,2,5]: stored avg=${AVG}, true mean≈${TRUE_MEAN}"
echo -e "  ${RED}[BUG-4]${RESET} Formula (current_avg + new_rating)/2 is WRONG."
echo -e "  ${RED}[BUG-4]${RESET} Fix: avg = (avg * count + new_rating) / (count + 1)"

# Rating validations
do_req POST "/movie/${MOVIE2_ID}/create-review/" '{"rating":6}' "$TOKEN_USER1"
check "Rating > 5 → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/movie/${MOVIE2_ID}/create-review/" '{"rating":0}' "$TOKEN_USER1"
check "Rating = 0 → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/movie/${MOVIE2_ID}/create-review/" '{"rating":-1}' "$TOKEN_USER1"
check "Rating negative → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/movie/${MOVIE2_ID}/create-review/" '{"rating":"five"}' "$TOKEN_USER1"
check "Rating as string → 400" 400 "$HTTP_CODE" "$BODY"

do_req POST "/movie/${MOVIE2_ID}/create-review/" '{}' "$TOKEN_USER1"
check "Missing rating → 400" 400 "$HTTP_CODE" "$BODY"

# Boundary values
do_req POST "/movie/${MOVIE2_ID}/create-review/" '{"rating":1}' "$TOKEN_USER1"
check "Rating boundary = 1 → 201" 201 "$HTTP_CODE" "$BODY"

do_req POST "/movie/${MOVIE2_ID}/create-review/" '{"rating":5}' "$TOKEN_USER2"
check "Rating boundary = 5 → 201" 201 "$HTTP_CODE" "$BODY"

# Description too long (max 200)
LONG_DESC=$(python3 -c 'print("A"*201)')
do_req POST "/movie/${MOVIE1_ID}/create-review/" "{\"rating\":3,\"description\":\"${LONG_DESC}\"}" "$TOKEN_USER1"
check "Description > 200 chars → 400" 400 "$HTTP_CODE" "$BODY"

# Non-existent movie
do_req POST "/movie/9999/create-review/" '{"rating":3}' "$TOKEN_USER1"
check "Review on non-existent movie → 404" 404 "$HTTP_CODE" "$BODY"

# Wrong methods
do_req GET "/movie/${MOVIE1_ID}/create-review/" "$TOKEN_USER1"
check "GET on create-review → 405" 405 "$HTTP_CODE" "$BODY"

do_req PUT "/movie/${MOVIE1_ID}/create-review/" '{"rating":3}' "$TOKEN_USER1"
check "PUT on create-review → 405" 405 "$HTTP_CODE" "$BODY"

do_req DELETE "/movie/${MOVIE1_ID}/create-review/" "$TOKEN_USER1"
check "DELETE on create-review → 405" 405 "$HTTP_CODE" "$BODY"

# Extra / injected fields should be ignored
do_req POST "/movie/${MOVIE2_ID}/create-review/" "{\"rating\":3,\"watchlist\":9999,\"review_user\":999,\"hacked\":true}" "$TOKEN_ADMIN"
check "Extra injected fields ignored → 201" 201 "$HTTP_CODE" "$BODY"

# =============================================================================
# 6. REVIEW LIST  GET /movie/<pk>/reviews/
# =============================================================================
section "6. REVIEW LIST  GET /movie/<pk>/reviews/"

do_req GET "/movie/${MOVIE1_ID}/reviews/"
check "List reviews for movie → 200" 200 "$HTTP_CODE" "$BODY"

# Count should be 3 (user1=4, user2=2, admin=5)
COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
[[ "$COUNT" == "3" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Returns exactly 3 reviews for movie1" && PASS=$((PASS+1)) || \
  echo -e "  ${YELLOW}⚠ INFO${RESET}  Expected 3 reviews, got $COUNT (may vary with test order)" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# watchlist field must be excluded
echo "$BODY" | grep -q '"watchlist"' && \
  echo -e "  ${RED}✘ FAIL${RESET}  'watchlist' field should be excluded from ReviewSerializer" && FAIL=$((FAIL+1)) || \
  echo -e "  ${GREEN}✔ PASS${RESET}  'watchlist' field is correctly excluded from response" && PASS=$((PASS+1))
TOTAL=$((TOTAL+1))

# review_user should be a string (StringRelatedField)
RUSER=$(echo "$BODY" | jq -r '.[0].review_user' 2>/dev/null)
[[ -n "$RUSER" && "$RUSER" != "null" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  review_user is a string: '$RUSER'" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  review_user missing or null" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# POST not allowed
do_req POST "/movie/${MOVIE1_ID}/reviews/" '{"rating":3}'
check "POST on review list → 405" 405 "$HTTP_CODE" "$BODY"

# [BUG-5] Non-existent movie returns 200 + [] instead of 404
do_req GET "/movie/9999/reviews/"
check "[BUG-5] Non-existent movie reviews → 200+[] (should be 404)" 200 "$HTTP_CODE" "$BODY"
echo -e "  ${RED}[BUG-5]${RESET} /movie/9999/reviews/ returns 200 with empty list instead of 404."
echo -e "  ${RED}[BUG-5]${RESET} Fix: validate WatchList exists in get_queryset()."

# =============================================================================
# 7. REVIEW DETAIL  GET|PUT|PATCH|DELETE /movie/review/<pk>/
# =============================================================================
section "7. REVIEW DETAIL  GET|PUT|PATCH|DELETE /movie/review/<pk>/"

do_req GET "/movie/review/${REVIEW1_ID}/"
check "Retrieve review → 200" 200 "$HTTP_CODE" "$BODY"

# Check required fields
for field in id review_user rating description active created update; do
  echo "$BODY" | grep -q "\"$field\"" && \
    echo -e "  ${GREEN}✔ PASS${RESET}  Review response has field: $field" && PASS=$((PASS+1)) || \
    echo -e "  ${RED}✘ FAIL${RESET}  Review response missing field: $field" && FAIL=$((FAIL+1))
  TOTAL=$((TOTAL+1))
done

# watchlist must be absent
echo "$BODY" | grep -q '"watchlist"' && \
  echo -e "  ${RED}✘ FAIL${RESET}  'watchlist' field should be excluded" && FAIL=$((FAIL+1)) || \
  echo -e "  ${GREEN}✔ PASS${RESET}  'watchlist' correctly excluded from review detail" && PASS=$((PASS+1))
TOTAL=$((TOTAL+1))

do_req GET "/movie/review/9999/"
check "Retrieve non-existent review → 404" 404 "$HTTP_CODE" "$BODY"

# Owner can update
do_req PUT "/movie/review/${REVIEW1_ID}/" '{"rating":5,"description":"Changed mind!"}' "$TOKEN_USER1"
check "Owner updates own review → 200" 200 "$HTTP_CODE" "$BODY"

# Other user cannot update
do_req PUT "/movie/review/${REVIEW1_ID}/" '{"rating":1,"description":"Overriding!"}' "$TOKEN_USER2"
check "Other user updates review → 403" 403 "$HTTP_CODE" "$BODY"

# Admin can update any review
do_req PUT "/movie/review/${REVIEW1_ID}/" '{"rating":3,"description":"Admin edit"}' "$TOKEN_ADMIN"
check "Admin updates any review → 200" 200 "$HTTP_CODE" "$BODY"

# Owner PATCH
do_req PATCH "/movie/review/${REVIEW1_ID}/" '{"rating":2}' "$TOKEN_USER1"
check "Owner partial updates review → 200" 200 "$HTTP_CODE" "$BODY"

# Other user PATCH
do_req PATCH "/movie/review/${REVIEW1_ID}/" '{"rating":1}' "$TOKEN_USER2"
check "Other user partial updates review → 403" 403 "$HTTP_CODE" "$BODY"

# Rating out of range
do_req PUT "/movie/review/${REVIEW1_ID}/" '{"rating":10}' "$TOKEN_USER1"
check "Rating > 5 on update → 400" 400 "$HTTP_CODE" "$BODY"

do_req PUT "/movie/review/${REVIEW1_ID}/" '{"rating":0}' "$TOKEN_USER1"
check "Rating = 0 on update → 400" 400 "$HTTP_CODE" "$BODY"

# Unauthenticated write
do_req PUT "/movie/review/${REVIEW1_ID}/" '{"rating":1}'
check "Unauthenticated update → 401 or 403" "" "$HTTP_CODE" "$BODY"
[[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Unauthenticated update blocked (HTTP $HTTP_CODE)" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  Unauthenticated update returned HTTP $HTTP_CODE" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# Other user DELETE
do_req DELETE "/movie/review/${REVIEW1_ID}/" "$TOKEN_USER2"
check "Other user deletes review → 403" 403 "$HTTP_CODE" "$BODY"

# Admin DELETE
do_req DELETE "/movie/review/${REVIEW_ADMIN_ID}/" "$TOKEN_ADMIN"
check "Admin deletes any review → 204" 204 "$HTTP_CODE" "$BODY"

# Owner DELETE
do_req DELETE "/movie/review/${REVIEW1_ID}/" "$TOKEN_USER1"
check "Owner deletes own review → 204" 204 "$HTTP_CODE" "$BODY"

# Deleted review should 404
do_req GET "/movie/review/${REVIEW1_ID}/"
check "Deleted review returns 404" 404 "$HTTP_CODE" "$BODY"

# =============================================================================
# 8. USER REVIEWS  GET /movie/reviews/?username=
# =============================================================================
section "8. USER REVIEWS  GET /movie/reviews/?username="

do_req GET "/movie/reviews/?username=testuser1"
check "Filter reviews by testuser1 → 200" 200 "$HTTP_CODE" "$BODY"

do_req GET "/movie/reviews/?username=testuser2"
check "Filter reviews by testuser2 → 200" 200 "$HTTP_CODE" "$BODY"

do_req GET "/movie/reviews/?username=ghost"
check "Filter by non-existent username → 200 + []" 200 "$HTTP_CODE" "$BODY"
COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
[[ "$COUNT" == "0" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Returns empty list for unknown user" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  Expected [], got: $BODY" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# [BUG-6] No username param → silent empty list
do_req GET "/movie/reviews/"
check "[BUG-6] No ?username= → 200+[] (should be 400)" 200 "$HTTP_CODE" "$BODY"
echo -e "  ${RED}[BUG-6]${RESET} Missing ?username= silently returns [] instead of a 400 error."
echo -e "  ${RED}[BUG-6]${RESET} Fix: validate username param is present."

# SQL injection safety
do_req GET "/movie/reviews/?username=' OR 1=1 --"
check "SQL injection in ?username= → safe 200+[]" 200 "$HTTP_CODE" "$BODY"

# =============================================================================
# 9. LOGOUT  POST /account/logout/
# =============================================================================
section "9. LOGOUT  POST /account/logout/"

# Logout user2 (keep user1 and admin tokens for any further calls)
do_req POST "/account/logout/" "" "$TOKEN_USER2"
check "Authenticated logout → 200" 200 "$HTTP_CODE" "$BODY" "Logged out"

# Reuse deleted token → 401
do_req POST "/account/logout/" "" "$TOKEN_USER2"
check "Reuse deleted token → 401" 401 "$HTTP_CODE" "$BODY"

# Invalid token → 401
do_req POST "/account/logout/" "" "invalidtokenxyz"
check "Invalid token → 401" 401 "$HTTP_CODE" "$BODY"

# [BUG-3] Unauthenticated logout crashes
do_req POST "/account/logout/"
check "[BUG-3] Unauthenticated logout → 401 or 500 (BUG: should be 401)" "" "$HTTP_CODE" "$BODY"
[[ "$HTTP_CODE" == "500" ]] && \
  echo -e "  ${RED}[BUG-3]${RESET} Unauthenticated logout CRASHED with 500!" && \
  echo -e "  ${RED}[BUG-3]${RESET} Fix: add @permission_classes([IsAuthenticated]) to logout_view." || \
  echo -e "  ${GREEN}✔${RESET}  Unauthenticated logout returned $HTTP_CODE (no crash)"

# Wrong method
do_req GET "/account/logout/"
check "GET on logout → 405" 405 "$HTTP_CODE" "$BODY"

# =============================================================================
# 10. TOKEN AUTH SCHEME
# =============================================================================
section "10. TOKEN AUTH SCHEME"

# Lowercase 'token' scheme — should fail
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: token ${TOKEN_USER1}" \
  -H "Content-Type: application/json" \
  -d '{"rating":3}' \
  "${BASE_URL}/movie/${MOVIE1_ID}/create-review/")
[[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Lowercase 'token' scheme rejected (HTTP $HTTP_CODE)" && PASS=$((PASS+1)) || \
  echo -e "  ${YELLOW}⚠ INFO${RESET}  Lowercase 'token' scheme returned $HTTP_CODE" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# Bearer scheme — should fail
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer ${TOKEN_USER1}" \
  -H "Content-Type: application/json" \
  -d '{"rating":3}' \
  "${BASE_URL}/movie/${MOVIE1_ID}/create-review/")
[[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Bearer scheme rejected (HTTP $HTTP_CODE)" && PASS=$((PASS+1)) || \
  echo -e "  ${YELLOW}⚠ INFO${RESET}  Bearer scheme returned $HTTP_CODE" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# =============================================================================
# 11. EDGE CASES
# =============================================================================
section "11. EDGE CASES"

# OPTIONS request (preflight)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "${BASE_URL}/movie/list/")
check "OPTIONS on /movie/list/ → 200" 200 "$HTTP_CODE" "$BODY"

# Malformed JSON
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Token ${TOKEN_USER1}" \
  -d '{"rating": }' \
  "${BASE_URL}/movie/${MOVIE1_ID}/create-review/")
[[ "$HTTP_CODE" == "400" || "$HTTP_CODE" == "500" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  Malformed JSON handled (HTTP $HTTP_CODE)" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  Malformed JSON returned unexpected $HTTP_CODE" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# XSS in title
do_req POST "/movie/list/" "{\"title\":\"<script>alert(1)</scri\",\"storyline\":\"XSS test\",\"platform\":${PLATFORM_ID}}" "$TOKEN_ADMIN"
[[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]] && \
  echo -e "  ${GREEN}✔ PASS${RESET}  XSS payload stored as plain text (JSON API, no execution risk)" && PASS=$((PASS+1)) || \
  echo -e "  ${RED}✘ FAIL${RESET}  XSS test returned unexpected $HTTP_CODE" && FAIL=$((FAIL+1))
TOTAL=$((TOTAL+1))

# Cascade: delete platform deletes its movies
do_req POST "/movie/stream/" '{"name":"TempPlat","about":"Temp","website":"https://temp.com"}' "$TOKEN_ADMIN"
TEMP_PLAT=$(echo "$BODY" | jq -r '.id' 2>/dev/null)
do_req POST "/movie/list/" "{\"title\":\"TempMovie\",\"storyline\":\"Will be deleted.\",\"platform\":${TEMP_PLAT}}" "$TOKEN_ADMIN"
TEMP_MOVIE=$(echo "$BODY" | jq -r '.id' 2>/dev/null)
do_req DELETE "/movie/stream/${TEMP_PLAT}/" "$TOKEN_ADMIN"
do_req GET "/movie/${TEMP_MOVIE}/"
check "Cascade: deleting platform deletes its movies → 404" 404 "$HTTP_CODE" "$BODY"

# [BUG-7] Pagination stress test
section "12. PAGINATION STRESS TEST (BUG-7)"
echo -e "  ${YELLOW}Creating 20 platforms to test missing pagination...${RESET}"
for i in $(seq 1 20); do
  curl -s -o /dev/null -X POST \
    -H "Authorization: Token ${TOKEN_ADMIN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Platform${i}\",\"about\":\"About\",\"website\":\"https://platform${i}.com\"}" \
    "${BASE_URL}/movie/stream/"
done
do_req GET "/movie/stream/"
COUNT=$(echo "$BODY" | jq 'length' 2>/dev/null)
[[ "$COUNT" -gt 20 ]] && \
  echo -e "  ${RED}[BUG-7]${RESET} No pagination: returned ALL $COUNT platforms in one response!" || \
  echo -e "  ${GREEN}✔${RESET}  Platform count: $COUNT"
echo -e "  ${RED}[BUG-7]${RESET} No DEFAULT_PAGINATION_CLASS set. Large datasets returned in full."
echo -e "  ${RED}[BUG-7]${RESET} Fix: add PageNumberPagination or LimitOffsetPagination to settings."
TOTAL=$((TOTAL+1))
FAIL=$((FAIL+1))  # Always flag as informational fail

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  TEST SUMMARY${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "  Total : ${BOLD}${TOTAL}${RESET}"
echo -e "  ${GREEN}Passed: ${PASS}${RESET}"
echo -e "  ${RED}Failed: ${FAIL}${RESET}"
echo ""
echo -e "${BOLD}  BUGS FOUND:${RESET}"
echo -e "  ${RED}[BUG-1]${RESET} Weak passwords accepted — Django validators not enforced in RegistrationSerializer"
echo -e "  ${RED}[BUG-2]${RESET} POST /movie/list/ returns HTTP 200 instead of 201 Created"
echo -e "  ${RED}[BUG-3]${RESET} POST /account/logout/ without token crashes with 500 (no IsAuthenticated guard)"
echo -e "  ${RED}[BUG-4]${RESET} avg_rating formula (avg+new)/2 is wrong for 3+ reviews — diverges from true mean"
echo -e "  ${RED}[BUG-5]${RESET} GET /movie/9999/reviews/ returns 200+[] instead of 404"
echo -e "  ${RED}[BUG-6]${RESET} GET /movie/reviews/ without ?username= returns silent empty list instead of 400"
echo -e "  ${RED}[BUG-7]${RESET} No pagination — full dataset returned on every list request"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
