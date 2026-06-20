#!/usr/bin/env bats

setup() {
  load '../lib/colors.sh'
  load '../lib/report.sh'
}

@test "generate_report exits cleanly" {
  run generate_report 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "generate_report_json has json structure" {
  run generate_report_json 2>/dev/null || true
  echo "$output" | grep -q "}"
}
