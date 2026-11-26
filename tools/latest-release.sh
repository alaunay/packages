#!/bin/sh
#
# Print the tag of the newest published release of a project.
#
# usage: tools/latest-release.sh OWNER/NAME
#
# "Newest" is by publication date, not by the release GitHub marks as the
# latest one. Projects such as anomalyco/opencode keep that mark on an older
# line so that their installer resolves the combined release, and the newer
# line would never be collected.

set -eu

project=${1:?usage: latest-release.sh OWNER/NAME}

gh api "repos/$project/releases?per_page=100" \
	--jq '[.[] | select(.draft | not) | select(.prerelease | not)]
		| sort_by(.published_at) | last | .tag_name // empty'
