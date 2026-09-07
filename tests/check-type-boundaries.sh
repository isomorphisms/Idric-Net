#!/bin/sh

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
idric_bin=${IDRIC:-idris2}
boundary_tmp=$(mktemp -d)

cleanup() {
  if [ -n "${boundary_tmp:-}" ] && [ -d "$boundary_tmp" ]; then
    rm -r -- "$boundary_tmp"
  fi
}
trap cleanup EXIT HUP INT TERM

ln -s "$project_dir/Network" "$boundary_tmp/Network"

expect_rejected() {
  fixture=$1
  expected_text=$2
  fixture_name=$(basename -- "$fixture")
  linked_fixture="$boundary_tmp/$fixture_name"
  log="$boundary_tmp/$fixture_name.log"

  ln -s "$project_dir/$fixture" "$linked_fixture"
  if (cd "$boundary_tmp" &&
      "$idric_bin" --check --build-dir "$boundary_tmp/build" "$fixture_name") \
      >"$log" 2>&1; then
    echo "FAIL: $fixture unexpectedly compiled"
    exit 1
  fi
  if ! grep -F "$expected_text" "$log" >/dev/null; then
    echo "FAIL: $fixture failed for an unexpected reason"
    sed -n '1,120p' "$log"
    exit 1
  fi
  echo "ok: $fixture rejected at its intended type boundary"
}

expect_rejected \
  tests/rejected/InvalidDestinationPort.idric \
  "Network.Types.MkDestinationPort is private"
expect_rejected \
  tests/rejected/InvalidHTTPStatusCode.idric \
  "Network.HTTP.MkHTTPStatusCode is private"
