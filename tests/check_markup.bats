#!/usr/bin/env bats
#
# Tests for tools/check-markup.sh. Stub checkers stand in for the Nu checker
# and the W3C CSS service, so the cases need no network. The cases that build
# the throwaway site skip only when the packaging tools are absent.

setup() {
	ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	WORK="${BATS_TEST_TMPDIR}"
	STUB="${WORK}/bin"

	mkdir -p "$STUB"

	# Stand-in for the Nu HTML Checker. VNU_EMPTY breaks it the way a crash
	# does, BAD_PAGE reports one error on that page, VNU_STDERR writes the
	# report to stderr behind noise, the way the real image does.
	cat > "$STUB/vnu" <<'STUB_VNU'
#!/bin/sh
for arg do
	file=$arg
done

if [ "${VNU_EMPTY:-0}" = 1 ]; then
	echo "vnu: cannot start" >&2
	exit 1
fi

if [ "${BAD_PAGE:-}" = "$file" ]; then
	report='{"messages":[{"type":"error","lastLine":1,"message":"test error"}]}'
	status=1
else
	report='{"messages":[]}'
	status=0
fi

if [ "${VNU_STDERR:-0}" = 1 ]; then
	printf 'Picked up JAVA_TOOL_OPTIONS: \n%s\n' "$report" >&2
else
	printf '%s\n' "$report"
fi
exit "$status"
STUB_VNU

	# Stand-in for curl, which now only carries the CSS request.
	# CSS_EMPTY_FIRST blanks the first call, CSS_EMPTY blanks them all.
	cat > "$STUB/curl" <<'STUB_CURL'
#!/bin/sh
count_file="${CURL_LOG}"
count=$(cat "$count_file" 2>/dev/null || echo 0)
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"

if [ "${CSS_EMPTY:-0}" = 1 ]; then
	exit 0
fi
if [ "${CSS_EMPTY_FIRST:-0}" = 1 ] && [ "$count" = 1 ]; then
	exit 0
fi

printf '{"cssvalidation":{"result":{"errorcount":0,"warningcount":0},"errors":[]}}'
STUB_CURL

	chmod +x "$STUB/vnu" "$STUB/curl"

	export CURL_LOG="${WORK}/css-calls"
	export PATH="${STUB}:${PATH}"
	export VNU="${STUB}/vnu"
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
	[[ "$output" == *"valid HTML: rpm/el10/index.html"* ]]
	[[ "$output" == *"valid CSS: style.css"* ]]
}

@test "reports invalid markup" {
	require_tools

	BAD_PAGE=index.html run "$ROOT/tools/check-markup.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"line 1: test error"* ]]
	[[ "$output" == *"invalid HTML:"* ]]
	[[ "$output" == *"/index.html"* ]]
}

@test "reads a report written to stderr behind noise" {
	require_tools

	VNU_STDERR=1 run "$ROOT/tools/check-markup.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"valid HTML: index.html"* ]]
	[[ "$output" != *"validator unavailable"* ]]
}

@test "retries an empty CSS reply" {
	require_tools

	CSS_EMPTY_FIRST=1 run "$ROOT/tools/check-markup.sh"

	[ "$status" -eq 0 ]
	[[ "$output" == *"attempt 1/3: no JSON from"* ]]
	[[ "$output" == *"valid CSS: style.css"* ]]
}

@test "reports a checker outage instead of invalid markup" {
	require_tools

	VNU_EMPTY=1 run "$ROOT/tools/check-markup.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"validator unavailable:"* ]]
	[[ "$output" == *"/index.html"* ]]
	[[ "$output" == *"vnu: cannot start"* ]]
	[[ "$output" != *"invalid HTML"* ]]
}

@test "reports a CSS outage instead of invalid styling" {
	require_tools

	CSS_EMPTY=1 VALIDATOR_ATTEMPTS=2 run "$ROOT/tools/check-markup.sh"

	[ "$status" -ne 0 ]
	[[ "$output" == *"validator unavailable:"* ]]
	[[ "$output" == *"/style.css"* ]]
	[[ "$output" != *"invalid CSS"* ]]
}
