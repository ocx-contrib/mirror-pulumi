---
title: pulumi
description: Infrastructure as Code in TypeScript, Python, Go, C#, Java or YAML — define cloud resources in a real programming language and preview, deploy and destroy them
keywords: pulumi,infrastructure-as-code,iac,cloud,aws,azure,gcp,kubernetes,devops,terraform-alternative,cli,go
---

# pulumi

[Pulumi](https://github.com/pulumi/pulumi) is an infrastructure-as-code engine.
Instead of a bespoke configuration language, you describe cloud resources as
objects in a general-purpose language — TypeScript/JavaScript, Python, Go, C#,
Java — or in declarative YAML, and the engine diffs your program's desired
state against recorded state and applies the difference. It talks to AWS,
Azure, Google Cloud, Kubernetes and several hundred other providers through
downloadable resource plugins, and keeps state either in Pulumi Cloud or in a
self-managed backend (a local directory, S3, Azure Blob, GCS).

## What's included

This bundle is the full upstream CLI distribution — **thirteen executables**,
all placed on `PATH` together, because the CLI launches the others as
subprocesses:

- **pulumi** — the CLI. `pulumi up`, `preview`, `destroy`, `stack`, `config`,
  `state`, `plugin`, `login`.
- **pulumi-language-go**, **-nodejs**, **-python**, **-dotnet**, **-java**,
  **-yaml**, **-bun**, **-pcl** — the language hosts. `pulumi` starts the one
  named by your project's `runtime:` and runs your program through it. They are
  not optional extras; a project cannot execute without its host.
- **pulumi-language-python-exec** — the Python launcher shim (a Python script).
- **pulumi-resource-pulumi-nodejs**, **-python** — the dynamic-provider hosts
  used by resources whose implementation lives inside your own program.
- **pulumi-watch** — the file-change watcher behind `pulumi watch`.
  *(Not shipped by upstream for windows/arm64.)*

**Runtimes are NOT bundled.** The language hosts are launchers: running a
TypeScript program needs `node` on `PATH`, a Python program needs `python`, and
so on. `runtime: yaml` needs nothing extra, which is why it is what this
package's smoke test exercises. Resource providers (`@pulumi/aws`, …) are
downloaded on demand into `PULUMI_HOME` at first use.

## Usage

```sh
# self-managed state in a local directory — no account required
pulumi login --local
```

```sh
# create a stack and preview it
pulumi stack init dev
pulumi preview
```

```sh
# apply, then inspect
pulumi up
pulumi stack ls --json
```

`PULUMI_HOME` (default `~/.pulumi`) holds credentials, downloaded plugins and —
under `pulumi login --local` — the state files themselves. Set
`PULUMI_CONFIG_PASSPHRASE` for a self-managed backend's secret provider.

## Links

- [Pulumi on GitHub](https://github.com/pulumi/pulumi)
- [pulumi.com](https://www.pulumi.com)
- [Documentation](https://www.pulumi.com/docs/)
- [CLI reference](https://www.pulumi.com/docs/cli/)
- [Registry (providers)](https://www.pulumi.com/registry/)
