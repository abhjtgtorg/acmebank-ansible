#!/usr/bin/env bash
#set -x
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Connect to Ansible Automation Platform / AWX API and retrieve recent job history.

Options:
  -h               Show this help message and exit
  -b BASE_URL      Base URL of the Automation Platform API (e.g. https://aap.example.com)
  -U USERNAME      Username for basic auth
  -P PASSWORD      Password for basic auth
  -t TOKEN         API Bearer token
  -o ORDER         Order jobs by field (default: -finished)
  -p PAGE_SIZE     Number of jobs to return per page (default: 50)
  -q              Use quiet output (raw JSON only)

Example:
  $(basename "$0") -b https://aap.example.com -U admin -P secret
  $(basename "$0") -b https://aap.example.com -t ABCDEF123456
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

BASE_URL=""
USERNAME=""
PASSWORD=""
TOKEN=""
ORDER_BY='-finished'
PAGE_SIZE=50
QUIET=0

while getopts ":hb:U:P:t:o:p:q" opt; do
  case "$opt" in
    h)
      usage
      exit 0
      ;;
    b)
      BASE_URL="$OPTARG"
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
      ORDER_BY="$OPTARG"
      ;;
    p)
      PAGE_SIZE="$OPTARG"
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

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

API_URL="${BASE_URL%/}/api/controller/v2/jobs/"
QUERY="?order_by=${ORDER_BY}&page_size=${PAGE_SIZE}"
ENDPOINT="${API_URL}${QUERY}"

CURL_ARGS=(--silent --show-error --fail)

if [[ -n "$TOKEN" ]]; then
  CURL_ARGS+=(--header "Authorization: Bearer ${TOKEN}")
else
  CURL_ARGS+=(--user "${USERNAME}:${PASSWORD}")
fi

CURL_ARGS+=("$ENDPOINT")

if [[ "$QUIET" -eq 1 ]]; then
  curl "${CURL_ARGS[@]}"
  exit 0
fi

RESPONSE=$(curl "${CURL_ARGS[@]}")

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq '.'
else
  echo "$RESPONSE"
fi
