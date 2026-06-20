#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/demo.sh'
}

@test "run_demo exits cleanly" {
  run run_demo 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "run_demo contains demo steps" {
  run run_demo 2>/dev/null || true
  echo "$output" | grep -qi "demo"
}
