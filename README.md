# packages

One apt repository and one RPM repository for the software published by
[@alaunay](https://github.com/alaunay), served from GitHub Pages.

- [Install](#install)
- [Published packages](#published-packages)
- [Contents](#contents)
- [Requirements for a project](#requirements-for-a-project)
- [Licence](#licence)

## Install

Add the repository once, then install any package by name.

### Debian and Ubuntu

```console
$ curl -fsSL https://alaunay.github.io/packages/keys/repo.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/alaunay.gpg
$ echo "deb [signed-by=/usr/share/keyrings/alaunay.gpg] \
https://alaunay.github.io/packages/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/alaunay.list
$ sudo apt update
$ sudo apt install PACKAGE
```

### CentOS and RHEL

```console
$ sudo curl -fsSL -o /etc/yum.repos.d/alaunay.repo \
    https://alaunay.github.io/packages/alaunay.repo
$ sudo dnf install PACKAGE
```

Replace `PACKAGE` with one of the names below. The landing page at
<https://alaunay.github.io/packages/> lists the current versions.

## Published packages

| Package | What it does | Source |
| --- | --- | --- |
| `euromillions` | Draws EuroMillions grids in the terminal | [alaunay/euromillions](https://github.com/alaunay/euromillions) |
| `terminal-svg-demo` | Renders a terminal session as animated SVG | [alaunay/terminal-svg-demo](https://github.com/alaunay/terminal-svg-demo) |

The same names exist in both formats. `github.com/alaunay/packages` is not
itself a package.

## Contents

`projects.txt` lists the repositories to publish. The workflow collects the
assets of each latest release, rebuilds both repositories, and deploys them
on a schedule, on demand, and on a `release` repository dispatch.

A project dispatches on every release when its `PACKAGES_TOKEN` secret is
set; the token needs write access here. Without it the daily run picks the
release up within a day.

## Key rotation

The signing key expires in November 2028 and its revocation certificate is
kept offline. Rotate before the expiry:

1. Generate a new key with `gpg --quick-generate-key 'alaunay repository
   <asl@launay.org>' rsa4096 sign 2y` and publish its fingerprint.
2. Sign both repositories with the new key, keeping the old one available
   until the last package signed with it is replaced.
3. Update `REPO_GPG_KEY_ID` and `REPO_GPG_PRIVATE_KEY` in the repository
   secrets, rebuild, and tell users to re-run the key verification.

If the key were compromised, publish the revocation certificate first:
`gpg --import revoke.asc && gpg --export > keys/repo.asc`.

## Requirements for a project

Publish the `.deb` and `.rpm` as release assets. Nothing else is needed: the
package names, versions, and contents come from the release.

## Licence

[GPL-3.0](LICENSE).
