#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/build-dolphin.yml"

require_self_trigger() {
  local event="$1"
  if ! awk -v event="$event" '
    $0 == "  " event ":" { in_event = 1; next }
    in_event && /^  [[:alnum:]_-]+:/ { in_event = 0 }
    in_event && index($0, "\".github/workflows/build-dolphin.yml\"") { found = 1 }
    END { exit !found }
  ' "$WORKFLOW"; then
    echo "native Dolphin workflow must include its own file in the $event path filter" >&2
    exit 1
  fi
}

require_self_trigger push
require_self_trigger pull_request
echo "[OK] native Dolphin workflow changes trigger the native build on push and pull_request"

ANDROMEDA_WORKFLOW="$ROOT/.github/workflows/build-muos-andromeda.yml"
grep -Fq "publish_release:" "$ANDROMEDA_WORKFLOW"
grep -Fq "default: false" "$ANDROMEDA_WORKFLOW"
grep -Fq "type: boolean" "$ANDROMEDA_WORKFLOW"
grep -Fq "github.event_name == 'workflow_dispatch' && inputs.publish_release == true" "$ANDROMEDA_WORKFLOW"
if grep -Fq "if: github.event_name == 'push'" "$ANDROMEDA_WORKFLOW"; then
  echo "muOS release publication must never run automatically on push" >&2
  exit 1
fi
echo "[OK] muOS stable release publication requires an explicit manual workflow_dispatch input"
