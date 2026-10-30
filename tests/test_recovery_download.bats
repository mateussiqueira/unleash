#!/usr/bin/env bats

@test "Recovery download runs without a library directory" {
  local repo="$BATS_TEST_DIRNAME/.." artifact target="$BATS_TEST_TMPDIR/recovery"
  artifact=$(sed -n 's|^curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/\([^ ]*\) -o /tmp/unleash$|\1|p' "$repo/README.md")
  [ -n "$artifact" ]
  mkdir -p "$target"
  cp "$repo/$artifact" "$target/unleash"
  run env HOME="$target" XDG_CONFIG_HOME="$target/config" bash "$target/unleash" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"unleash"* ]]
  [ ! -d "$target/lib" ]
}
