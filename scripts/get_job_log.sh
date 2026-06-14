#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Download Ansible Automation Platform / AWX job output for a given job ID.

Options:
  -h               Show this help message and exit
  -b BASE_URL      Base URL of the Automation Platform API (e.g. https://aap.example.com)
  -j JOB_ID        Job ID to download logs for
  -U USERNAME      Username for basic auth
  -P PASSWORD      Password for basic auth
  -t TOKEN         API Bearer token
  -o OUTPUT_FILE   Write logs to this file (default: stdout)
  -f FORMAT        Output format: txt or json (default: txt)
  -q               Quiet mode (raw download output only)

Example:
  $(basename "$0") -b https://aap.example.com -j 42 -t TOKEN -o job-42.log
  $(basename "$0") -b https://aap.example.com -j 42 -U admin -P secret
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

BASE_URL=""
JOB_ID=""
USERNAME=""
PASSWORD=""
TOKEN=""
OUTPUT_FILE=""
FORMAT="txt"
QUIET=0

while getopts ":hb:j:U:P:t:o:f:q" opt; do
  case "$opt" in
    h)
      usage
      exit 0
      ;;
    b)
      BASE_URL="$OPTARG"
      ;;
    j)
      JOB_ID="$OPTARG"
      ;;
    U)
      USERNAME="$OPTARG"
      ;;
    P)
      PASSWORD="$OPTARG"
      ;;
    t)
      TOKEN="$OPTARG"
      ;;
    o)
      OUTPUT_FILE="$OPTARG"
      ;;
    f)
      FORMAT="$OPTARG"
      ;;
    q)
      QUIET=1
      ;;
    \?)
      echo "Error: invalid option -$OPTARG" >&2
      usage
      exit 2
      ;;
    :) 
      echo "Error: option -$OPTARG requires an argument." >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$BASE_URL" ]]; then
  echo "Error: BASE_URL is required." >&2
  usage
  exit 2
fi

if [[ -z "$JOB_ID" ]]; then
  echo "Error: JOB_ID is required." >&2
  usage
  exit 2
fi

if [[ -z "$TOKEN" && -z "$USERNAME" ]]; then
  echo "Error: either TOKEN or USERNAME/PASSWORD must be provided." >&2
  usage
  exit 2
fi

if [[ -z "$TOKEN" && -z "$PASSWORD" ]]; then
  echo "Error: PASSWORD is required when using USERNAME authentication." >&2
  usage
  exit 2
fi

if [[ "$FORMAT" != "txt" && "$FORMAT" != "json" ]]; then
  echo "Error: FORMAT must be either txt or json." >&2
  usage
  exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

API_URL="${BASE_URL%/}/api/controller/v2/jobs/${JOB_ID}/stdout/"
if [[ "$FORMAT" == "txt" ]]; then
  API_URL+="?format=txt"
else
  API_URL+="?format=json"
fi

CURL_ARGS=(--silent --show-error --fail)

if [[ -n "$TOKEN" ]]; then
  CURL_ARGS+=(--header "Authorization: Bearer ${TOKEN}")
else
  CURL_ARGS+=(--user "${USERNAME}:${PASSWORD}")
fi

if [[ -n "$OUTPUT_FILE" ]]; then
  if [[ "$QUIET" -eq 1 ]]; then
    curl "${CURL_ARGS[@]}" "$API_URL" > "$OUTPUT_FILE"
  else
    echo "Downloading job ${JOB_ID} logs to ${OUTPUT_FILE}..."
    curl "${CURL_ARGS[@]}" "$API_URL" > "$OUTPUT_FILE"
    echo "Saved job logs to ${OUTPUT_FILE}."
  fi
else
  curl "${CURL_ARGS[@]}" "$API_URL"
fi
