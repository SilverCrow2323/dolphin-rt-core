#!/usr/bin/env bash
# Runs muOS Andromeda's OWN archive checks (SAFE_ARCHIVE / VERIFY_UPDATE / INSTALL_UPDATE from the 2606.0 tag)
# against a .muxupd, installing into a throw-away root. Needs git + network (fetches MustardOS/internal at the tag).
set -uo pipefail
ARCHIVE="$(readlink -f "${1:?usage: verify-muxupd.sh <file.muxupd>}")"
TAG="${MUOS_TAG:-2606.0_Andromeda}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
RAW="https://raw.githubusercontent.com/MustardOS/internal/$TAG/script"
curl -fsSL "$RAW/var/zip.sh" -o zip.sh || { echo "cannot fetch zip.sh for $TAG"; exit 2; }
curl -fsSL "$RAW/mux/extract.sh" -o extract.sh || { echo "cannot fetch extract.sh for $TAG"; exit 2; }
sed -n '/^VERIFY_UPDATE()/,/^}/p' extract.sh > verify.sh
sed -n '/^INSTALL_UPDATE()/,/^}/p' extract.sh \
  | sed 's|"/\${UPDATE_DIR#\./}"|"$FAKEROOT/${UPDATE_DIR#./}"|; s|UPDATE_DEST="/\$UPDATE_FILE"|UPDATE_DEST="$FAKEROOT/$UPDATE_FILE"|' > install.sh
grep -q FAKEROOT install.sh || { echo "could not adapt INSTALL_UPDATE for $TAG"; exit 2; }
LOG_INFO(){ :; }; LOG_ERROR(){ :; }; LOG_WARN(){ :; }; LOG_DEBUG(){ :; }
TASK_STATUS(){ :; }; TASK_DETAIL(){ :; }; TASK_PROGRESS(){ :; }; GET_VAR(){ echo 0; }
# shellcheck disable=SC1091
. ./zip.sh 2>/dev/null; . ./verify.sh; . ./install.sh
export FAKEROOT="$W/root"; mkdir -p "$FAKEROOT"
fail=0
SAFE_ARCHIVE "$ARCHIVE";  rc=$?; echo "SAFE_ARCHIVE   rc=$rc"; [ $rc -eq 0 ] || fail=1
ARCHIVE="$ARCHIVE" VERIFY_UPDATE; rc=$?; echo "VERIFY_UPDATE  rc=$rc mode=${UPDATE_INSTALL_MODE:-}"; [ $rc -eq 0 ] || fail=1
if [ $fail -eq 0 ]; then INSTALL_UPDATE; rc=$?; echo "INSTALL_UPDATE rc=$rc"; [ $rc -eq 0 ] || fail=1; fi
[ -n "${UPDATE_STAGE:-}" ] && rm -rf "$UPDATE_STAGE"
exit $fail
