#!/bin/sh
# Regression tests for key substitution. Run from any working directory.
set -eu
umask 077
LC_ALL=C
export LC_ALL

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d "${DELTA_SCRATCH_DIR:-${TMPDIR:-/tmp}}/cliproxyapi-test.XXXXXX")
trap 'rm -rf "$tmp"' 0
trap 'exit 1' HUP INT TERM

# Ignore the caller's credentials and path overrides.
HOME="$tmp/home"
CLIPROXYAPI_BIN="$tmp/bin"
CLIPROXYAPI_CONFIG="$tmp/template.yaml"
CLIPROXYAPI_KEY_DIR="$tmp/keys"
CLIPROXYAPI_STATE="$tmp/state"
export HOME CLIPROXYAPI_BIN CLIPROXYAPI_CONFIG CLIPROXYAPI_KEY_DIR CLIPROXYAPI_STATE
unset CLIPROXYAPI_KEY_FILE
mkdir -p "$HOME" "$CLIPROXYAPI_KEY_DIR" "$CLIPROXYAPI_STATE"
cat > "$CLIPROXYAPI_BIN" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$CLIPROXYAPI_STATE/args"
EOF
chmod 700 "$CLIPROXYAPI_BIN"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

run() {
  sh "$dir/cliproxyapi" "$@" > "$tmp/stdout" 2> "$tmp/stderr"
}

expect_failure() {
  if run; then
    fail "$1"
  fi
  # A failed render must neither replace the last good config nor start the server.
  diff -u "$tmp/expected.yaml" "$CLIPROXYAPI_STATE/config.yaml"
  diff -u "$tmp/args" "$CLIPROXYAPI_STATE/args"
}

printf '%s\n' 'client-dummy._~123' > "$CLIPROXYAPI_KEY_DIR/client-api-key"
printf '%s\n' 'tp-mimo-dummy-456' > "$CLIPROXYAPI_KEY_DIR/mimo-api-key"
printf '%s\n' 'other-dummy-789' > "$CLIPROXYAPI_KEY_DIR/other-api-key2"
cat > "$CLIPROXYAPI_CONFIG" <<'EOF'
# Full-line "@CLIENT_API_KEY@" and @COMMENT_ONLY@ stay literal.
access:
  api-keys:
    - "@CLIENT_API_KEY@" # Inline "@MIMO_API_KEY@" and @COMMENT_ONLY@
api-keys:
  claude:
    - keys:
        - api-key: "@MIMO_API_KEY@" # Inline "@CLIENT_API_KEY@" stays literal.
        - api-key: "@MIMO_API_KEY@"
        - api-key: "@OTHER_API_KEY2@"   # Another provider's key file.
headers:
  X-Note: "Keep # hashes and @COMMENT_ONLY@ inside ordinary text."
# Commented-out providers do not need a key file.
# api-key: "@MISSING_API_KEY@"
  # - "@MISSING_API_KEY@"
EOF
cat > "$tmp/expected.yaml" <<'EOF'
# Full-line "@CLIENT_API_KEY@" and @COMMENT_ONLY@ stay literal.
access:
  api-keys:
    - "client-dummy._~123" # Inline "@MIMO_API_KEY@" and @COMMENT_ONLY@
api-keys:
  claude:
    - keys:
        - api-key: "tp-mimo-dummy-456" # Inline "@CLIENT_API_KEY@" stays literal.
        - api-key: "tp-mimo-dummy-456"
        - api-key: "other-dummy-789"   # Another provider's key file.
headers:
  X-Note: "Keep # hashes and @COMMENT_ONLY@ inside ordinary text."
# Commented-out providers do not need a key file.
# api-key: "@MISSING_API_KEY@"
  # - "@MISSING_API_KEY@"
EOF
run --local-model
diff -u "$tmp/expected.yaml" "$CLIPROXYAPI_STATE/config.yaml"
printf '%s\n' --config "$CLIPROXYAPI_STATE/config.yaml" --local-model > "$tmp/args"
diff -u "$tmp/args" "$CLIPROXYAPI_STATE/args"
[ "$(stat -c '%a' "$CLIPROXYAPI_STATE/config.yaml")" = 600 ] ||
  fail 'rendered configuration is not mode 0600'
printf 'PASS: replace values, preserve comments and text, forward arguments, mode 0600\n'

mv "$CLIPROXYAPI_KEY_DIR/mimo-api-key" "$tmp/mimo-api-key"
expect_failure 'started without an active provider key'
printf 'PASS: missing active key fails without replacing the configuration\n'
mv "$tmp/mimo-api-key" "$CLIPROXYAPI_KEY_DIR/mimo-api-key"

for bad_key in '' 'has space' 'contains&sed' 'contains|delimiter' \
  'contains!delimiter' 'contains"quote'; do
  printf '%s\n' "$bad_key" > "$CLIPROXYAPI_KEY_DIR/mimo-api-key"
  expect_failure 'started with an invalid key'
done
printf 'first-line\nsecond-line\n' > "$CLIPROXYAPI_KEY_DIR/mimo-api-key"
expect_failure 'started with a multiline key'
printf '%s\n' 'tp-mimo-dummy-456' > "$CLIPROXYAPI_KEY_DIR/mimo-api-key"
printf 'PASS: empty, malformed, and multiline keys fail\n'

printf '%s\n' 'client-override' > "$tmp/client-key"
CLIPROXYAPI_KEY_FILE="$tmp/client-key"
export CLIPROXYAPI_KEY_FILE
sed 's/client-dummy._~123/client-override/' "$tmp/expected.yaml" > "$tmp/override.yaml"
run
diff -u "$tmp/override.yaml" "$CLIPROXYAPI_STATE/config.yaml"
unset CLIPROXYAPI_KEY_FILE
printf 'PASS: legacy client-key path override\n'

cat > "$CLIPROXYAPI_CONFIG" <<'EOF'
# No active placeholders. Do not read either key file.
# api-key: "@MIMO_API_KEY@"
host: "127.0.0.1" # "@CLIENT_API_KEY@"
EOF
rm "$CLIPROXYAPI_KEY_DIR/client-api-key" "$CLIPROXYAPI_KEY_DIR/mimo-api-key"
run
diff -u "$CLIPROXYAPI_CONFIG" "$CLIPROXYAPI_STATE/config.yaml"
printf 'PASS: commented-out placeholders require no key files\n'

# Exercise the actual example as well as the focused regression fixture.
printf '%s\n' 'client-dummy._~123' > "$CLIPROXYAPI_KEY_DIR/client-api-key"
printf '%s\n' 'tp-mimo-dummy-456' > "$CLIPROXYAPI_KEY_DIR/mimo-api-key"
CLIPROXYAPI_CONFIG="$dir/config.example.yaml"
run
grep -Fq -- '- "client-dummy._~123"' "$CLIPROXYAPI_STATE/config.yaml"
grep -Fq -- 'api-key: "tp-mimo-dummy-456"' "$CLIPROXYAPI_STATE/config.yaml"
grep -Fq -- 'https://token-plan-sgp.xiaomimimo.com/anthropic' "$CLIPROXYAPI_STATE/config.yaml"
grep '^#' "$CLIPROXYAPI_CONFIG" > "$tmp/comments.expected"
grep '^#' "$CLIPROXYAPI_STATE/config.yaml" > "$tmp/comments.actual"
diff -u "$tmp/comments.expected" "$tmp/comments.actual"
printf 'PASS: render the deployed example with dummy credentials\n'
