# AGENTS.md

Guidance for agents working in this repository.

## Project

One apt repository and one RPM repository, served from GitHub Pages for the
software published by @alaunay.

- `tools/build-repo.sh` assembles the site from the release assets.
- `tools/latest-release.sh` picks the newest published release of a project,
  by publication date rather than by GitHub's "latest" mark.
- `templates/` holds the HTML pages and their stylesheet; the script
  renders the pages with `envsubst` and copies `style.css`. Never embed
  HTML in the script.
- `projects.txt` lists the repositories to collect.
- `.github/workflows/publish.yml` collects, builds, and deploys, and records
  the collected versions in `projects.json` on the site.
- `.github/workflows/watch.yml` polls the upstream releases and starts the
  publish when one is newer than `projects.json`.

Add a project by appending `owner/name` to `projects.txt`. The project must
publish `.deb` and `.rpm` files as assets of its newest published release.
Debian builds must target `amd64` or `arm64`, the two architectures the apt
repository indexes.

Release selection follows publication date, not GitHub's "latest" mark.
Projects such as `anomalyco/opencode` keep that mark on an older line so
their installer resolves the combined release, while the desktop packages
ship on the newer one.

## Tests

The builder has a bats suite, and the shellcheck converter a unittest
suite:

```
bats tests/
ruff check tools tests
python3 -m unittest discover -s tests
tools/check-markup.sh
```

The bats cases build a signed apt repository and a signed rpm repository
from throwaway packages and a throwaway key, and skip a case only when the
distribution tooling for that format is absent. The markup cases stand stub
checkers in place of the Nu checker and the CSS service, so they need no
network and no container.

## Commit rules

Every commit is signed with `git commit -s -S` and carries a
`Co-authored-by` trailer per contributing model.

## Checks

CI runs bats, the Python lint and tests, the markup validation, the
shellcheck-to-SARIF code scanning, and the commit trailer check. All of
them are required on `master`.

`tools/check-markup.sh` builds a throwaway site, then validates every page
with the Nu HTML Checker run from its published image, and the stylesheet
with the CSS validator run by the W3C. The HTML check is local, so a W3C
outage cannot block it. The CSS check needs network access; an empty or
non-JSON reply is retried, then reported as `validator unavailable`, so an
outage never reads as invalid styling. Rerun the job when it says so.

## Secrets

`REPO_GPG_PRIVATE_KEY` and `REPO_GPG_KEY_ID`. Pages must use the GitHub
Actions source.

Projects send a `release` repository dispatch with their own
`PACKAGES_TOKEN`; the token needs write access to this repository.
