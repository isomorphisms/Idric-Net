#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
idric_repo=${IDRIC_REPO:-"$repo_root/.tools/Idric"}
compiler_ref=${IDRIC_COMPILER_REF:-Idriç}
scheme=${IDRIC_SCHEME:-scheme}
case "$scheme" in
  */*) PATH="$(dirname -- "$scheme"):$PATH"; export PATH ;;
esac
compiler="$idric_repo/build/exec/idris2"
idris_prefix=${IDRIS2_PREFIX:-"$idric_repo/bootstrap-build"}
LD_LIBRARY_PATH="$idris_prefix/idris2-0.8.0/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export IDRIS2_PREFIX="$idris_prefix" LD_LIBRARY_PATH
receipt="$repo_root/build/current-head-receipt.tsv"
log="$repo_root/build/current-head.log"
current_stage=compiler_build
passed='compiler_checkout'

mkdir -p "$repo_root/build"
: > "$log"

project_sha=$(git -C "$repo_root" rev-parse HEAD)
compiler_sha=$(git -C "$idric_repo" rev-parse HEAD)
project_dirty=$(if git -C "$repo_root" status --porcelain | grep -q .; then printf dirty; else printf clean; fi)
compiler_dirty=$(if git -C "$idric_repo" status --porcelain | grep -q .; then printf dirty; else printf clean; fi)

write_receipt() {
  outcome=$1
  diagnostic=${2:-none}
  {
    printf 'CURRENT_HEAD_COMPATIBILITY\t1\n'
    printf 'repository\tisomorphisms/Idric-Net\n'
    printf 'requested_ref\t%s\n' "${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-local}}"
    printf 'resolved_sha\t%s\n' "$project_sha"
    printf 'dirty_state\t%s\n' "$project_dirty"
    printf 'dependent_repository\tisomorphisms/Idric\n'
    printf 'dependent_requested_ref\t%s\n' "$compiler_ref"
    printf 'dependent_resolved_sha\t%s\n' "$compiler_sha"
    printf 'dependent_dirty_state\t%s\n' "$compiler_dirty"
    for stage in compiler_checkout compiler_build library_build semantic_tests; do
      if [[ " $passed " == *" $stage "* ]]; then
        printf 'stage\t%s\tPASS\n' "$stage"
      elif [[ $stage == "$current_stage" ]]; then
        printf 'stage\t%s\t%s\n' "$stage" "$outcome"
      else
        printf 'stage\t%s\tSKIP\tprerequisite_not_met\n' "$stage"
      fi
    done
    if [[ $outcome == FAIL ]]; then
      printf 'first_failure\t%s\t%s\n' "$current_stage" "$diagnostic"
    else
      printf 'first_failure\tnone\n'
    fi
  } > "$receipt"
}

fail_receipt() {
  status=$?
  trap - ERR
  diagnostic=$(grep -E '(^FAIL|^Error:|^usage:|unsupported|rejected|not found|No such file)' "$log" | tail -n 1 || true)
  [[ -n $diagnostic ]] || diagnostic=$(tail -n 1 "$log" | tr '\t\r\n' '   ')
  write_receipt FAIL "${diagnostic:-exit_$status}"
  cat "$receipt" >&2
  exit "$status"
}
trap fail_receipt ERR

current_stage=compiler_build
if [[ ! -x "$compiler" ]]; then
  make -C "$idric_repo" bootstrap SCHEME="$scheme" 2>&1 | tee -a "$log"
fi
"$compiler" --version 2>&1 | tee -a "$log"
passed="$passed compiler_build"

current_stage=library_build
make -C "$repo_root" all IDRIC="$compiler" 2>&1 | tee -a "$log"
passed="$passed library_build"

current_stage=semantic_tests
make -C "$repo_root" test IDRIC="$compiler" 2>&1 | tee -a "$log"
passed="$passed semantic_tests"
current_stage=complete
write_receipt PASS none
trap - ERR
cat "$receipt"
