#!/bin/sh
#
# Assemble one apt repository and one rpm repository from the release
# artifacts of every project listed in projects.txt.
#
# usage: REPO_GPG_KEY_ID=... tools/build-repo.sh DIST OUT
#
# DIST holds the .deb and .rpm files, in any layout. OUT receives the site
# tree: /deb, /rpm, /keys.

set -eu

# Directory of this script, to find the templates
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
templates="$script_dir/../templates"

dist=${1:?usage: build-repo.sh DIST OUT}
out=${2:?usage: build-repo.sh DIST OUT}
key=${REPO_GPG_KEY_ID:-}
origin=${REPO_ORIGIN:-alaunay}
label=${REPO_LABEL:-Alaunay packages}
base=${REPO_BASE_URL:-https://alaunay.github.io/packages}

mkdir -p "$out/deb/dists/stable/main/binary-amd64" "$out/deb/pool/main" \
	"$out/rpm/el10" "$out/keys"

sign() {
	if [ -z "$key" ]; then
		echo "warning: REPO_GPG_KEY_ID is not set, metadata stays unsigned" >&2
		return 1
	fi

	gpg --batch --yes --local-user "$key" "$@"
}

# ---- Debian -----------------------------------------------------------
find "$dist" -name '*.deb' -exec cp {} "$out/deb/pool/main/" \;

(
	cd "$out/deb"
	dpkg-scanpackages --multiversion pool > dists/stable/main/binary-amd64/Packages
	gzip -9cf dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz
)

cat > "$out/deb/apt-ftparchive.conf" <<EOF
APT::FTPArchive::Release::Origin "$origin";
APT::FTPArchive::Release::Label "$label";
APT::FTPArchive::Release::Suite "stable";
APT::FTPArchive::Release::Codename "stable";
APT::FTPArchive::Release::Architectures "amd64";
APT::FTPArchive::Release::Components "main";
APT::FTPArchive::Release::Description "$label";
EOF

apt-ftparchive -c "$out/deb/apt-ftparchive.conf" release "$out/deb/dists/stable" \
	> "$out/deb/dists/stable/Release"

if sign --clearsign -o "$out/deb/dists/stable/InRelease" "$out/deb/dists/stable/Release"; then
	sign --armor --detach-sign -o "$out/deb/dists/stable/Release.gpg" \
		"$out/deb/dists/stable/Release"
fi

# ---- RPM --------------------------------------------------------------
find "$dist" -name '*.rpm' -exec cp {} "$out/rpm/el10/" \;

if find "$out/rpm/el10" -maxdepth 1 -name '*.rpm' | grep -q .; then
	if ! command -v createrepo_c >/dev/null 2>&1; then
		echo "createrepo_c is required for the rpm repository" >&2
		exit 1
	fi

	if [ -n "$key" ]; then
		find "$out/rpm/el10" -maxdepth 1 -name '*.rpm' -exec \
			rpmsign --addsign --define "_gpg_name $key" {} \; >/dev/null
	fi

	createrepo_c --quiet --database "$out/rpm/el10"

	if [ -n "$key" ]; then
		sign --armor --detach-sign -o "$out/rpm/el10/repodata/repomd.xml.asc" \
			"$out/rpm/el10/repodata/repomd.xml"
	fi
fi

# ---- Published packages ----------------------------------------------
# shellcheck disable=SC2016
# the awk program uses $1 and $2, which the shell must not expand
escape_rows='function esc(v) {
	gsub(/&/, "\\&amp;", v); gsub(/</, "\\&lt;", v)
	gsub(/>/, "\\&gt;", v); gsub(/"/, "\\&quot;", v)
	return v
}
{ printf "<tr><td><code>%s</code></td><td>%s</td></tr>\n", esc($1), esc($2) }'

deb_rows=$(awk '/^Package: /{name=$2} /^Version: /{print name, $2}' \
	"$out/deb/dists/stable/main/binary-amd64/Packages" | awk "$escape_rows")

rpm_rows=
if find "$out/rpm/el10" -maxdepth 1 -name '*.rpm' | grep -q .; then
	rpm_rows=$(rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' \
		"$out/rpm/el10"/*.rpm 2>/dev/null | awk "$escape_rows")
fi

fingerprint=
if [ -n "$key" ]; then
	fingerprint=$(gpg --with-colons --fingerprint "$key" |
		awk -F: '/^fpr/ { print $10; exit }')
fi

# ---- Keys and landing page -------------------------------------------
if [ -n "$key" ]; then
	gpg --armor --export "$key" > "$out/keys/repo.asc"
fi

# ---- Pages ------------------------------------------------------------
# shellcheck disable=SC2016
# envsubst takes the list of variables, not the shell
render() {
	envsubst '${LABEL} ${ORIGIN} ${BASE} ${DEB_ROWS} ${RPM_ROWS} ${FINGERPRINT} ${FINGERPRINT_PRETTY} ${CSS_VERSION}' \
		< "$templates/$1" > "$2"
}

LABEL=$label
ORIGIN=$origin
BASE=$base
DEB_ROWS=$deb_rows
RPM_ROWS=$rpm_rows
FINGERPRINT=$fingerprint
FINGERPRINT_PRETTY=$(printf '%s' "$fingerprint" | sed 's/.\{4\}/& /g' | sed 's/ $//')
CSS_VERSION=$(cksum < "$templates/style.css" | awk '{ print $1 }')
export LABEL ORIGIN BASE DEB_ROWS RPM_ROWS FINGERPRINT FINGERPRINT_PRETTY CSS_VERSION

cp "$templates/style.css" "$out/style.css"
render deb.html "$out/deb/index.html"
render rpm.html "$out/rpm/el10/index.html"

cat > "$out/$origin.repo" <<EOF
[$origin]
name=$label
baseurl=$base/rpm/el10
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$base/keys/repo.asc
EOF

render index.html "$out/index.html"
