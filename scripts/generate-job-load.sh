#!/usr/bin/env bash
set -u

BASE_URL="http://localhost:8081"
TOTAL=1000
CONCURRENCY=30
DELAY_SECONDS=20
TIMEOUT_SECONDS=10
SLEEP_MS=0
JITTER_MS=0

usage() {
  cat <<USAGE
Generate high load against JobRunr demo endpoints.

Usage:
  $(basename "$0") [options]

Options:
  --base-url URL          Default: http://localhost:8081
  --total N               Total number of jobs to trigger. Default: 1000
  --concurrency N         Parallel requests. Default: 30
  --delay-seconds N       delaySeconds for delayed jobs. Default: 20
  --timeout-seconds N     curl timeout per request. Default: 10
  --sleep-ms N            Fixed sleep before each request in ms. Default: 0
  --jitter-ms N           Random extra sleep [0..N] ms before each request. Default: 0
  -h, --help              Show this help

Distribution (random weighted):
  enqueue=40% delayed=20% slow=15% fail=15% fail-once=10%
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      BASE_URL="$2"; shift 2 ;;
    --total)
      TOTAL="$2"; shift 2 ;;
    --concurrency)
      CONCURRENCY="$2"; shift 2 ;;
    --delay-seconds)
      DELAY_SECONDS="$2"; shift 2 ;;
    --timeout-seconds)
      TIMEOUT_SECONDS="$2"; shift 2 ;;
    --sleep-ms)
      SLEEP_MS="$2"; shift 2 ;;
    --jitter-ms)
      JITTER_MS="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

is_num='^[0-9]+$'
if ! [[ "$TOTAL" =~ $is_num && "$CONCURRENCY" =~ $is_num && "$DELAY_SECONDS" =~ $is_num && "$TIMEOUT_SECONDS" =~ $is_num && "$SLEEP_MS" =~ $is_num && "$JITTER_MS" =~ $is_num ]]; then
  echo "All numeric options must be non-negative integers." >&2
  exit 1
fi

if (( TOTAL == 0 )); then
  echo "Nothing to do: --total 0"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

health_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT_SECONDS" "$BASE_URL/actuator/health" || true)
if [[ ! "$health_code" =~ ^2 ]]; then
  echo "App is not reachable at $BASE_URL (health HTTP $health_code). Start the app first." >&2
  exit 1
fi

jobs_file=$(mktemp)
results_file=$(mktemp)
trap 'rm -f "$jobs_file" "$results_file"' EXIT

for ((i=1; i<=TOTAL; i++)); do
  r=$((RANDOM % 100))
  if (( r < 40 )); then
    echo "enqueue" >> "$jobs_file"
  elif (( r < 60 )); then
    echo "delayed" >> "$jobs_file"
  elif (( r < 75 )); then
    echo "slow" >> "$jobs_file"
  elif (( r < 90 )); then
    echo "fail" >> "$jobs_file"
  else
    echo "fail-once" >> "$jobs_file"
  fi
done

export BASE_URL DELAY_SECONDS TIMEOUT_SECONDS SLEEP_MS JITTER_MS results_file

worker() {
  local kind="$1"
  local url
  case "$kind" in
    enqueue)   url="$BASE_URL/jobs/enqueue" ;;
    delayed)   url="$BASE_URL/jobs/delayed?delaySeconds=$DELAY_SECONDS" ;;
    slow)      url="$BASE_URL/jobs/slow" ;;
    fail)      url="$BASE_URL/jobs/fail" ;;
    fail-once) url="$BASE_URL/jobs/fail-once" ;;
    *)
      echo "ERR unknown 000" >> "$results_file"
      return
      ;;
  esac

  local total_sleep_ms="$SLEEP_MS"
  if (( JITTER_MS > 0 )); then
    total_sleep_ms=$(( total_sleep_ms + (RANDOM % (JITTER_MS + 1)) ))
  fi

  if (( total_sleep_ms > 0 )); then
    sleep_sec=$(( total_sleep_ms / 1000 ))
    sleep_ms_remainder=$(( total_sleep_ms % 1000 ))
    sleep "${sleep_sec}.$(printf '%03d' "$sleep_ms_remainder")"
  fi

  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT_SECONDS" -X POST "$url" || echo "000")
  if [[ "$code" =~ ^2 ]]; then
    echo "OK $kind" >> "$results_file"
  else
    echo "ERR $kind $code" >> "$results_file"
  fi
}

export -f worker

start_ts=$(date +%s)
cat "$jobs_file" | xargs -P "$CONCURRENCY" -n 1 bash -lc 'worker "$@"' _
end_ts=$(date +%s)

ok_total=$(grep -c '^OK ' "$results_file" || true)
err_total=$(grep -c '^ERR ' "$results_file" || true)

count_kind() {
  local prefix="$1"
  local kind="$2"
  grep -c "^${prefix} ${kind}\b" "$results_file" || true
}

echo "--- Load Generation Summary ---"
echo "Base URL:      $BASE_URL"
echo "Total planned: $TOTAL"
echo "Concurrency:   $CONCURRENCY"
echo "Sleep ms:      $SLEEP_MS"
echo "Jitter ms:     $JITTER_MS"
echo "Duration sec:  $((end_ts - start_ts))"
echo "Success:       $ok_total"
echo "Errors:        $err_total"
echo
echo "Success by case:"
echo "  enqueue:   $(count_kind OK enqueue)"
echo "  delayed:   $(count_kind OK delayed)"
echo "  slow:      $(count_kind OK slow)"
echo "  fail:      $(count_kind OK fail)"
echo "  fail-once: $(count_kind OK fail-once)"

if (( err_total > 0 )); then
  echo
  echo "Error codes (top 10):"
  awk '/^ERR / {print $3}' "$results_file" | sort | uniq -c | sort -nr | head -n 10
fi

echo
echo "Dashboard: http://localhost:8000/dashboard"
