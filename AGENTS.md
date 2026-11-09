# AGENTS.md

Guidance for agents working in this repository.

## Project

One apt repository and one RPM repository, served from GitHub Pages for the
software published by @alaunay.

- `tools/build-repo.sh` assembles the site from the release assets.
- `projects.txt` lists the repositories to collect.
- `.github/workflows/publish.yml` collects, builds, and deploys.

Add a project by appending `owner/name` to `projects.txt`. The project must
publish `.deb` and `.rpm` files as assets of its latest release.

## Tests

The builder has a bats suite:

```
bats tests
```

It builds a signed apt repository and a signed rpm repository from
throwaway packages and a throwaway key, and skips a case only when the
distribution tooling for that format is absent.

## Commit rules

Every commit is signed with `git commit -s -S` and carries a
`Co-authored-by` trailer per contributing model.

## Secrets

`REPO_GPG_PRIVATE_KEY` and `REPO_GPG_KEY_ID`. Pages must use the GitHub
Actions source.
