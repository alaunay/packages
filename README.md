# packages

One apt repository and one RPM repository for the software published by
[@alaunay](https://github.com/alaunay), served from GitHub Pages.

- apt: <https://alaunay.github.io/packages/deb>
- rpm: <https://alaunay.github.io/packages/rpm/el10>
- key: <https://alaunay.github.io/packages/keys/repo.asc>

## Install

Debian and Ubuntu:

```console
$ curl -fsSL https://alaunay.github.io/packages/keys/repo.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/alaunay.gpg
$ echo "deb [signed-by=/usr/share/keyrings/alaunay.gpg] \
https://alaunay.github.io/packages/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/alaunay.list
$ sudo apt update
$ sudo apt install euromillions
```

CentOS and RHEL:

```console
$ sudo curl -fsSL -o /etc/yum.repos.d/alaunay.repo \
    https://alaunay.github.io/packages/alaunay.repo
$ sudo dnf install euromillions
```

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
