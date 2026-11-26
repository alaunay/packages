#!/usr/bin/env bats
#
# Tests for tools/check-markup.sh. A stub curl stands in for the W3C services,
# so the cases need no network. The cases that build the throwaway site skip
# only when the packaging tools are absent.

setup() {
	ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	WORK="${BATS_TEST_TMPDIR}"
	STUB="${WORK}/bin"

	mkdir -p "$STUB"
	cat > "$STUB/curl" <<'STUB_CURL'
#!/bin/sh
# Stand-in for curl: answer the Nu checker and the CSS validator. The URL is
# the last argument of both calls. EMPTY_FIRST blanks the first call of each
# endpoint, ALWAYS_EMPTY blanks them all, the way the services fail now and
# then.
for arg do
	url=$arg
done

case $url in
*nu/*) key=html ;;
*) key=css ;;
esac

count_file="${CURL_LOG}.${key}"
count=$(cat "$count_file" 2>/dev/null || echo 0)
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"

if [ "${ALWAYS_EMPTY:-0}" = 1 ]; then
	exit 0
fi
if [ "${EMPTY_FIRST:-0}" = 1 ] && [ "$count" = 1 ]; then
	exit 0
fi

case $key in
html) printf '{"messages":[]}' ;;
css) printf '{"cssvalidation":{"result":{"errorcount":0,"warningcount":0},"errors":[]}}' ;;
esac
STUB_CURL
	chmod +x "$STUB/curl"

	export CURL_LOG="${WORK}/calls"
	export PATH="${STUB}:${PATH}"
	export VALIDATOR_DELAY=0
}

require_tools() {
	command -v dpkg-deb >/dev/null || skip "dpkg-deb is missing"
	command -v dpkg-scanpackages >/dev/null || skip "dpkg-scanpackages is missing"
	command -v apt-ftparchive >/dev/null || skip "apt-ftparchive is missing"
	command -v rpmbuild >/dev/null || skip "rpmbuild is missing"
	command -v createrepo_c >/dev/null || skip "createrepo_c is missing"
	command -v envsubst >/dev/null || skip "envsubst is missing"
	command -v python3 >/dev/null || skip "python3 is missing"
}

@test "accepts valid pages" {
	require_tools

	run "$ROOT/tools/check-markup.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"valid HTML: index.html"* ]]
	[[ "$output" == *"valid CSS: style.css"* ]]
}

@test "retries an empty reply" {
	require_tools

	EMPTY_FIRST=1 run "$ROOT/tools/check-markup.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"attempt 1/3: no JSON from"* ]]
	[[ "$output" == *"valid HTML: index.html"* ]]
}

@test "reports a validator outage instead of invalid markup" {
	require_tools

	ALWAYS_EMPTY=1 VALIDATOR_ATTEMPTS=2 run "$ROOT/tools/check-markup.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"validator unavailable: "*/index.html ]]
	[[ "$output" != *"invalid HTML"* ]]
}
