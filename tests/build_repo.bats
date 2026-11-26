#!/usr/bin/env bats
#
# Tests for tools/build-repo.sh. The package fixtures need the distribution
# tools, so a test skips only when the tooling for that format is absent.

setup() {
	ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	WORK="${BATS_TEST_TMPDIR}"
	DIST="${WORK}/dist"
	SITE="${WORK}/site"

	mkdir -p "$DIST"

	export GNUPGHOME="${WORK}/gnupg"
	mkdir -p "$GNUPGHOME"
	chmod 700 "$GNUPGHOME"
}

make_deb() {
	local root="${WORK}/deb"
	mkdir -p "$root/DEBIAN"
	cat > "$root/DEBIAN/control" <<'EOF'
Package: testpkg
Version: 1.0.0
Architecture: all
Maintainer: Test <test@example.org>
Description: test package
EOF
	dpkg-deb --build "$root" "$DIST/testpkg_1.0.0_all.deb" >/dev/null
}

make_deb_arch() {
	local arch=$1
	local root="${WORK}/deb-${arch}"
	mkdir -p "$root/DEBIAN"
	cat > "$root/DEBIAN/control" <<EOF
Package: archpkg
Version: 1.0.0
Architecture: ${arch}
Maintainer: Test <test@example.org>
Description: test package for ${arch}
EOF
	dpkg-deb --build "$root" "$DIST/archpkg-1.0.0-${arch}.deb" >/dev/null
}

make_rpm() {
	local top="${WORK}/rpmbuild"
	mkdir -p "$top"
	cat > "${WORK}/testpkg.spec" <<'EOF'
Name: testpkg
Version: 1.0.0
Release: 1
Summary: test package
License: MIT
BuildArch: noarch
%description
test package
%install
install -Dm644 /dev/null %{buildroot}/usr/share/testpkg/file
%files
/usr/share/testpkg/file
%changelog
EOF
	rpmbuild -bb "${WORK}/testpkg.spec" --define "_topdir $top" >/dev/null
	cp "$top"/RPMS/noarch/*.rpm "$DIST/"
}

make_key() {
	gpg --batch --pinentry-mode loopback --passphrase '' \
		--quick-generate-key 'Repo Test <repo@example.org>' rsa2048 sign 1d >/dev/null 2>&1
	gpg --list-secret-keys --with-colons | awk -F: '/^sec/ { print $5; exit }'
}

@test "prints usage without arguments" {
	run "$ROOT/tools/build-repo.sh"
	[ "$status" -ne 0 ]
}

@test "warns without a signing key" {
	command -v dpkg-scanpackages >/dev/null || skip "dpkg-scanpackages is missing"
	command -v apt-ftparchive >/dev/null || skip "apt-ftparchive is missing"

	run env -u REPO_GPG_KEY_ID REPO_ORIGIN=test REPO_LABEL=test REPO_NAME=test \
		"$ROOT/tools/build-repo.sh" "$DIST" "$SITE"

	[ "$status" -eq 0 ]
	[[ "$output" == *"stays unsigned"* ]]
	[ -f "$SITE/index.html" ]
	[ -f "$SITE/test.repo" ]
}

@test "builds a signed apt repository" {
	command -v dpkg-deb >/dev/null || skip "dpkg-deb is missing"
	command -v dpkg-scanpackages >/dev/null || skip "dpkg-scanpackages is missing"
	command -v apt-ftparchive >/dev/null || skip "apt-ftparchive is missing"
	command -v gpg >/dev/null || skip "gpg is missing"

	make_deb
	key=$(make_key)

	run env REPO_GPG_KEY_ID="$key" REPO_ORIGIN=test REPO_LABEL=test REPO_NAME=test \
		"$ROOT/tools/build-repo.sh" "$DIST" "$SITE"

	[ "$status" -eq 0 ]
	[ -f "$SITE/deb/dists/stable/InRelease" ]
	grep -q '^Package: testpkg$' "$SITE/deb/dists/stable/main/binary-amd64/Packages"
	grep -q '<code>testpkg</code>' "$SITE/index.html"
	[ -f "$SITE/deb/index.html" ]
	[ -f "$SITE/style.css" ]
	gpg --verify "$SITE/deb/dists/stable/InRelease" >/dev/null 2>&1
}

@test "builds a signed rpm repository" {
	command -v rpmbuild >/dev/null || skip "rpmbuild is missing"
	command -v createrepo_c >/dev/null || skip "createrepo_c is missing"
	command -v gpg >/dev/null || skip "gpg is missing"

	make_rpm
	key=$(make_key)

	run env REPO_GPG_KEY_ID="$key" REPO_ORIGIN=test REPO_LABEL=test REPO_NAME=test \
		"$ROOT/tools/build-repo.sh" "$DIST" "$SITE"

	[ "$status" -eq 0 ]
	[ -f "$SITE/rpm/el10/repodata/repomd.xml" ]
	[ -f "$SITE/rpm/el10/repodata/repomd.xml.asc" ]
	grep -q '<code>testpkg</code>' "$SITE/index.html"
	gpg --verify "$SITE/rpm/el10/repodata/repomd.xml.asc" \
		"$SITE/rpm/el10/repodata/repomd.xml" >/dev/null 2>&1

	rpm --dbpath "${WORK}/rpmdb" --initdb
	gpg --armor --export "$key" > "${WORK}/key.asc"
	rpm --dbpath "${WORK}/rpmdb" --import "${WORK}/key.asc"
	run rpm --dbpath "${WORK}/rpmdb" --checksig "$SITE"/rpm/el10/*.rpm
	[[ "$output" == *"signatures OK"* ]]
}

@test "indexes every configured architecture" {
	command -v dpkg-deb >/dev/null || skip "dpkg-deb is missing"
	command -v dpkg-scanpackages >/dev/null || skip "dpkg-scanpackages is missing"
	command -v apt-ftparchive >/dev/null || skip "apt-ftparchive is missing"
	command -v gpg >/dev/null || skip "gpg is missing"

	make_deb_arch amd64
	make_deb_arch arm64
	make_deb
	key=$(make_key)

	run env REPO_GPG_KEY_ID="$key" REPO_ORIGIN=test REPO_LABEL=test \
		REPO_ARCHES="amd64 arm64" \
		"$ROOT/tools/build-repo.sh" "$DIST" "$SITE"

	[ "$status" -eq 0 ]
	grep -q '^Architectures: amd64 arm64$' "$SITE/deb/dists/stable/Release"
	grep -q '^Package: archpkg$' "$SITE/deb/dists/stable/main/binary-amd64/Packages"
	grep -q '^Package: archpkg$' "$SITE/deb/dists/stable/main/binary-arm64/Packages"
	[ -f "$SITE/deb/dists/stable/main/binary-arm64/Packages.gz" ]

	# An arm64 build must not be offered to amd64 clients, nor the reverse.
	run grep -q '^Architecture: arm64$' "$SITE/deb/dists/stable/main/binary-amd64/Packages"
	[ "$status" -ne 0 ]
	run grep -q '^Architecture: amd64$' "$SITE/deb/dists/stable/main/binary-arm64/Packages"
	[ "$status" -ne 0 ]

	# One row per package and version, not one per architecture.
	[ "$(grep -c '<code>archpkg</code>' "$SITE/index.html")" -eq 1 ]

	# An architecture-independent package belongs to every index.
	grep -q '^Package: testpkg$' "$SITE/deb/dists/stable/main/binary-amd64/Packages"
	grep -q '^Package: testpkg$' "$SITE/deb/dists/stable/main/binary-arm64/Packages"
	[ "$(grep -c '<code>testpkg</code>' "$SITE/index.html")" -eq 1 ]
}

@test "latest-release prints usage without a project" {
	run "$ROOT/tools/latest-release.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *"usage: latest-release.sh OWNER/NAME"* ]]
}

@test "latest-release picks the newest published release" {
	command -v jq >/dev/null || skip "jq is missing"

	stub="${WORK}/bin"
	mkdir -p "$stub"
	cat > "$stub/gh" <<'STUB'
#!/bin/sh
# Stand-in for gh api --jq EXPR: prints the releases, then applies EXPR.
expr=
while [ $# -gt 0 ]; do
	case $1 in
	--jq)
		expr=$2
		shift 2
		;;
	*) shift ;;
	esac
done
jq -r "$expr" <<'JSON'
[
  {"tag_name": "v1.9.0", "draft": false, "prerelease": false, "published_at": "2026-03-01T00:00:00Z"},
  {"tag_name": "v2.0.0", "draft": false, "prerelease": false, "published_at": "2026-01-01T00:00:00Z"},
  {"tag_name": "v3.0.0", "draft": true, "prerelease": false, "published_at": "2026-04-01T00:00:00Z"},
  {"tag_name": "v4.0.0-rc1", "draft": false, "prerelease": true, "published_at": "2026-05-01T00:00:00Z"}
]
JSON
STUB
	chmod +x "$stub/gh"

	run env PATH="${stub}:${PATH}" "$ROOT/tools/latest-release.sh" example/project

	[ "$status" -eq 0 ]
	[ "$output" = "v1.9.0" ]
}
