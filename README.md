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

## Requirements for a project

Publish the `.deb` and `.rpm` as release assets. Nothing else is needed: the
package names, versions, and contents come from the release.

## Licence

[GPL-3.0](LICENSE).
