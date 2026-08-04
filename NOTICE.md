# NOTICE

This repository packages and redistributes upstream software published by the
[Pulumi](https://github.com/pulumi/pulumi) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

The package logo in this repository reproduces the **upstream project's own
mark** at 512 px, unmodified apart from scaling, solely to identify the
software being mirrored. No endorsement or affiliation is implied, and no
trademark right is claimed.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `pulumi` | `ghcr.io/ocx-contrib/pulumi/pulumi` | `Apache-2.0` |

---

## `pulumi`

Upstream: <https://github.com/pulumi/pulumi>
Published to `ghcr.io/ocx-contrib/pulumi/pulumi`.

| Component | SPDX | Holder |
|---|---|---|
| Pulumi CLI and language hosts | **Apache-2.0** | Copyright Pulumi Corporation |

The Apache License 2.0 grants redistribution in source and object form, on the
conditions that recipients receive a copy of the License, that modified files
carry a change notice, and that any `NOTICE` text from the source form is
reproduced.

**Upstream's release archives contain only the executables — no `LICENSE` and
no `NOTICE` file travels inside them** (verified by `tar tzf` / `unzip -Z1` on
every platform archive of v3.253.0–v3.255.0: thirteen entries, all
executables). This file therefore serves the attribution requirement for the
redistributed bytes. The authoritative license text is upstream's own:

- License: <https://github.com/pulumi/pulumi/blob/master/LICENSE>
- Per-version source: `https://github.com/pulumi/pulumi/tree/v<VERSION>`
  (e.g. <https://github.com/pulumi/pulumi/tree/v3.255.0>)

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle. The published binaries
statically link third-party Go modules under permissive licenses, enumerated in
the `go.mod`/`go.sum` of the tagged upstream source for each mirrored version.
