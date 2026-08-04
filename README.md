# mirror-pulumi

OCX mirror for [Pulumi](https://github.com/pulumi/pulumi), the
infrastructure-as-code engine. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [pulumi](https://github.com/pulumi/pulumi) | [`pulumi/mirror.yml`](pulumi/mirror.yml) | `ghcr.io/ocx-contrib/pulumi/pulumi` | [`ocx.sh/pulumi/pulumi`](https://index.ocx.sh/pulumi/pulumi) | `Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

The GitHub org is the project's own brand, so the org names the namespace and
the tool names the package: `pulumi/pulumi`.

## Layout

```
pulumi/
├── mirror.yml                   the spec — never at the repo root
├── metadata.json                bundle interface (linux + darwin)
├── metadata-windows.json        windows/amd64 — bin/ layout, 13 binaries
├── metadata-windows-arm64.json  windows/arm64 — bin/ layout, 12 binaries
├── CATALOG.md                   → ocx package describe
├── logo.svg / logo.png          describe assets, 512px PNG
└── tests/smoke.star             Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. The logo is **not** — it
lives beside the spec, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

There is no `mirror-base.yml` and no `extends:`. Every key is package-owned and
the platform matrix is downstream of a per-package libc measurement, so a base
would only recreate the shallow-merge trap for no gain.

## This bundle ships thirteen executables

Not one. `pulumi` launches the language hosts and dynamic-provider hosts as
subprocesses, so upstream's archive puts all of them on one directory and the
whole set must land on `PATH` together:

```
pulumi                          pulumi-language-pcl
pulumi-language-bun             pulumi-language-python
pulumi-language-dotnet          pulumi-language-python-exec   (Python script)
pulumi-language-go              pulumi-language-yaml
pulumi-language-java            pulumi-resource-pulumi-nodejs (sh script)
pulumi-language-nodejs          pulumi-resource-pulumi-python (sh script)
pulumi-watch
```

Around 120 MB compressed per platform, ~360 MB expanded. `bin_scan: verify`
checks the hand-written list against what each archive actually contains, which
is the mode for a **platform-asymmetric** set — upstream ships no
`pulumi-watch.exe` for `windows/arm64`, so that zip holds twelve entries and
every other archive holds thirteen. `entrypoints` is not declared, per the
fleet rule: these are self-contained binaries exposed through `PATH`.

Language *runtimes* are not bundled. The hosts are launchers — a TypeScript
program still needs `node`, a Python program still needs `python`.

## Archive layout differs between unix and windows

| Platform | Archive shape | `strip_components` | `PATH` |
|---|---|---|---|
| linux, darwin | `pulumi/<13 executables>` — wrapper dir, **no `bin/`** | `0` | `${installPath}/pulumi` |
| windows | `pulumi/bin/<executables>` — wrapper dir **with** `bin/` | `1` | `${installPath}/bin` |

The unix case is the "top dir but no `bin/`" shape: the wrapper must survive,
because stripping it hoists thirteen executables to the content root and forces
a bare `${installPath}` PATH, which the `bin_scan` load-time gate rejects at
exit 65.

## Platforms — this package requires glibc

Upstream ships six platform archives: both Linux arches, both macOS arches and
both Windows arches. All six resolve to exactly one asset on every in-range
release, verified in both directions (a pattern matching zero is silently
skipped rather than reported, so the check is not optional).

Both Linux keys carry **`+libc.glibc`**, and that is measured, not assumed.
Twelve of the thirteen binaries are static Go builds — but `pulumi-watch` is a
prebuilt from 2022 that is dynamically linked:

```
$ file pulumi-v3.255.0-linux-x64/pulumi/pulumi-watch
ELF 64-bit LSB pie executable, x86-64, ... dynamically linked,
interpreter /lib64/ld-linux-x86-64.so.2
$ ldd ... → libgcc_s.so.1 libpthread.so.0 libm.so.6 libdl.so.2 libc.so.6
$ readelf -V ... | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1 → GLIBC_2.29
```

and on arm64 it requests `/lib/ld-linux-aarch64.so.1`. Cross-checked by running
the real archive under docker:

| Image | `pulumi version` | `pulumi-watch --help` |
|---|---|---|
| `alpine:3.20` | `v3.255.0`, exit 0 | **exit 127**, `not found` |
| `ubuntu:24.04` | `v3.255.0`, exit 0 | exit 0 |

`os.features` states what an artifact requires *of the host*. One declared
binary here cannot exec without a glibc loader, so a bare key would be a false
universality claim that resolved this package onto musl hosts where
`pulumi-watch` dies at load time. Container legs are `ubuntu:24.04` and
`fedora:40` — two glibc vintages, both well above the 2.29 floor — and
deliberately **no alpine**: the renderer rejects an alpine leg under a
`+libc.glibc` key, and it would red for a reason the spec already states.

Publishing a second, bare key alongside is not applicable: there is no static
build of `pulumi-watch` to put behind it.

### What is not mirrored

Every release also ships `sdk-nodejs-pulumi-pulumi-<V>.tgz`,
`sdk-npm-pulumi-<V>.tgz` and `sdk-python-pulumi-<V>-py3-none-any.whl`. Those
are npm/PyPI **language SDK packages** consumed by a Pulumi program, not CLI
binaries, and are not installable as a tool. Every asset pattern is anchored at
both ends, so no pattern can reach them — nor the per-asset `.sig` sidecars,
nor the whole-release `B3SUMS` / `SHA512SUMS` / `pulumi-<V>-checksums.txt` and
their signatures.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `pulumi/mirror.yml` | hand | yes — see below |
| `pulumi/{metadata*.json,CATALOG.md,logo.*}` | hand | — |
| `pulumi/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec pulumi/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The smoke test

`pulumi/tests/smoke.star` drives a **real stack lifecycle** against the local
file backend, entirely offline (measured under `docker run --network none`):
`pulumi login --local`, write a `Pulumi.yaml` with `runtime: yaml`,
`pulumi stack init`, then assert `pulumi stack ls --json` reports exactly one
stack, named as created, with zero resources. `--json` because plain stdout is
a colorized table that would break a substring match token by token. Selecting
a stack that was never created is asserted non-zero as the negative control.

A thirteen-binary bundle where only `pulumi` runs would prove very little, so
two further checks reach the language hosts. `pulumi about --json` makes the
CLI discover and *execute* `pulumi-language-yaml` and read its version over
gRPC — that version string comes out of the binary, not a filename — and the
host is then invoked directly off the composed `PATH` for exit polarity (good
flag 0, unknown flag non-zero) rather than usage prose. `pulumi-watch`, the one
dynamically linked binary and the reason for the `+libc.glibc` keys, is
exercised the same way, skipped only on `windows/arm64` where upstream ships
it not at all.

`HOME`, `USERPROFILE` and `PULUMI_HOME` are set into the test scratch sandbox.
pulumi persists credentials and stack state under the user's home directory,
and container legs run with `HOME` unset or unwritable — a tool in that class
exits 1 there. `PULUMI_SKIP_UPDATE_CHECK` keeps the CLI's background version
probe from reaching the network at all.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
Upstream's archives ship no `LICENSE` file of their own, so `NOTICE.md` carries
the attribution for the redistributed bytes. The logo reproduces upstream's own
mark, unmodified apart from scaling, solely to identify the software being
mirrored.
