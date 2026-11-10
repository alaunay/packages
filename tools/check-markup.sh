#!/bin/sh
#
# Validate the generated pages and stylesheet against the W3C services.
#
# usage: tools/check-markup.sh
#
# Builds a throwaway site from tiny packages, then checks every page with
# the Nu HTML Checker and the stylesheet with the CSS validator. Both are
# the reference implementations run by the W3C.

set -eu

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

dist="$work/dist"
site="$work/site"
mkdir -p "$dist"

# A minimal .deb, so the apt table is not empty
deb_root="$work/deb"
mkdir -p "$deb_root/DEBIAN"
cat > "$deb_root/DEBIAN/control" <<'EOF'
Package: markup-test
Version: 1.0.0
Architecture: all
Maintainer: Test <test@example.org>
Description: markup test package
EOF
dpkg-deb --build "$deb_root" "$dist/markup-test_1.0.0_all.deb" >/dev/null 2>&1

# A minimal .rpm, so the rpm table is not empty
rpm_root="$work/rpmbuild"
mkdir -p "$rpm_root"
cat > "$work/markup-test.spec" <<'EOF'
Name: markup-test
Version: 1.0.0
Release: 1
Summary: markup test package
License: MIT
BuildArch: noarch
%description
markup test package
%install
install -Dm644 /dev/null %{buildroot}/usr/share/markup-test/file
%files
/usr/share/markup-test/file
%changelog
EOF
rpmbuild -bb "$work/markup-test.spec" --define "_topdir $rpm_root" >/dev/null 2>&1
cp "$rpm_root"/RPMS/noarch/*.rpm "$dist/"

REPO_ORIGIN=markup REPO_LABEL="Markup test" \
	REPO_BASE_URL="https://example.org/packages" \
	"$root/tools/build-repo.sh" "$dist" "$site" >/dev/null 2>&1

check_html() {
	page=$1
	response=$(curl -sS --retry 3 \
		-H 'Content-Type: text/html; charset=utf-8' \
		--data-binary "@$page" 'https://validator.w3.org/nu/?out=json')

	if ! printf '%s' "$response" | python3 -c '
import json
import sys

document = json.load(sys.stdin)
messages = document.get("messages", [])
errors = [message for message in messages if message.get("type") == "error"]
for message in errors:
    print(f"line {message.get("lastLine")}: {message.get("message")}", file=sys.stderr)
sys.exit(1 if errors else 0)
'; then
		echo "invalid HTML: $page" >&2
		return 1
	fi

	echo "valid HTML: ${page#"$site"/}"
}

check_css() {
	stylesheet=$1
	response=$(curl -sS --retry 3 -X POST \
		-F "text=<$stylesheet" -F 'output=json' -F 'profile=css3svg' \
		'https://jigsaw.w3.org/css-validator/validator')

	if ! printf '%s' "$response" | python3 -c '
import json
import sys

document = json.load(sys.stdin)
result = document["cssvalidation"]["result"]
for error in document["cssvalidation"].get("errors", []):
    print(error.get("message", "error"), file=sys.stderr)
if result.get("errorcount", 0):
    sys.exit(1)
print(f"warnings: {result.get("warningcount", 0)}", file=sys.stderr)
'; then
		echo "invalid CSS: $stylesheet" >&2
		return 1
	fi

	echo "valid CSS: ${stylesheet#"$site"/}"
}

check_html "$site/index.html"
check_html "$site/deb/index.html"
check_html "$site/rpm/el10/index.html"
check_css "$site/style.css"
