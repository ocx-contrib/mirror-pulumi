# pulumi/tests/smoke.star — stable across upstream pulumi releases.
# Asserts the contract (version shape, a real stack lifecycle against the local
# file backend, the negative control, and that a SECOND bundled binary really
# executes), never help/version prose. See ocx.mirror testing-practices.md.
#
# This bundle ships THIRTEEN executables on one PATH directory, so a smoke that
# only ran `pulumi` would leave twelve of them unproven. Two independent checks
# below reach the language hosts: `pulumi about --json` makes the CLI discover
# and *execute* `pulumi-language-yaml` to read its version over gRPC, and the
# host binary is then invoked directly for its exit polarity.
#
# EVERYTHING HERE IS OFFLINE. Measured under `docker run --network none`:
# `pulumi login --local` (file:// backend), `stack init`, `stack ls --json`,
# `about --json` all complete with no network. PULUMI_SKIP_UPDATE_CHECK keeps
# the CLI's background version probe from reaching out at all.
#
# ⚠ HOME IS SET EXPLICITLY. pulumi persists credentials and stack state under
# the user's home directory (`file://~`), and container legs run with HOME
# unset or unwritable — a tool in that class exits 1 there. PULUMI_HOME pins
# the plugin/credential dir into scratch as well, so nothing touches the
# developer's real ~/.pulumi when this is run locally.

EXE = ".exe" if ocx.target_platform.os == ocx.os.Windows else ""
PULUMI = "pulumi" + EXE
LANG_YAML = "pulumi-language-yaml" + EXE
WATCH = "pulumi-watch" + EXE

HOME_DIR = ocx.scratch_root + "/home"

ocx.mkdir("home")
ocx.mkdir("proj")

ENV = {
    "HOME": HOME_DIR,
    "USERPROFILE": HOME_DIR,
    "PULUMI_HOME": HOME_DIR + "/.pulumi",
    "PULUMI_CONFIG_PASSPHRASE": "ocx-smoke",
    "PULUMI_SKIP_UPDATE_CHECK": "true",
    "PULUMI_SKIP_CONFIRMATIONS": "true",
}

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# The digits are the contract; the `v` prefix around them is not.
r_version = ocx.run(PULUMI, "version", env = ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3: a real stack lifecycle against the local file backend ───────────
r_login = ocx.run(PULUMI, "login", "--local", env = ENV, cwd = "proj")
expect.ok(r_login)

ocx.write_file(
    "proj/Pulumi.yaml",
    "name: ocxsmoke\nruntime: yaml\ndescription: ocx mirror smoke test\n",
)

# ⚠ THE SCRATCH ROOT IS NOT GUARANTEED FRESH. Two `ocx package test` runs over
# the same bundle reuse it (measured: the second `stack init` died with
# `stack 'organization/ocxsmoke/ocxdev' already exists`), and the container legs
# for one platform test the same bundle from a shared workspace. So the stack is
# torn down first. THIS ONE RESULT IS DELIBERATELY UNASSERTED — on a genuinely
# clean scratch there is nothing to remove and `stack rm` exits non-zero, which
# is correct. The `init` below stays a strict assertion, so red is still
# reachable: it is what fails if the backend cannot create a stack at all.
ocx.run(PULUMI, "stack", "rm", "--yes", "--force", "ocxdev", env = ENV, cwd = "proj")

r_init = ocx.run(PULUMI, "stack", "init", "ocxdev", env = ENV, cwd = "proj")
expect.ok(r_init)

# THE assertion: the stack we created is the ONE stack the backend reports, in
# machine-readable form. Plain stdout is a colorized table and would break a
# substring match token by token; `--json` is byte-stable. A CLI that merely
# echoed its arguments, or that wrote nothing to the backend, fails here.
r_ls = ocx.run(PULUMI, "stack", "ls", "--json", env = ENV, cwd = "proj")
expect.ok(r_ls)
expect.eq(r_ls.stdout.count("\"name\""), 1)
expect.contains(r_ls.stdout, "\"name\": \"ocxdev\"")
expect.contains(r_ls.stdout, "\"resourceCount\": 0")

# ── Negative control — states what would go red ─────────────────────────────
# Selecting a stack that was never created must fail. Without this, a build
# whose backend accepted anything would pass every assertion above.
r_missing = ocx.run(PULUMI, "stack", "select", "nosuchstack", env = ENV, cwd = "proj")
expect.ne(r_missing.exit_code, 0)

# ── A SECOND binary, reached through the CLI's own plugin machinery ──────────
# `about --json` resolves the language host named by the project's `runtime:`
# (yaml) and asks the binary for its version — the version string below comes
# out of pulumi-language-yaml, not out of a filename. A bundle missing or
# truncating that binary cannot produce this block.
r_about = ocx.run(PULUMI, "about", "--json", env = ENV, cwd = "proj")
expect.ok(r_about)
expect.contains(r_about.stdout, "\"kind\": \"language\"")
expect.contains(r_about.stdout, "\"name\": \"yaml\"")

# ── The same binary, invoked DIRECTLY off the composed PATH ─────────────────
# Exit polarity rather than usage prose: a good flag exits 0, an unknown flag
# exits non-zero. Proves the ELF loads and its own argument parser runs.
def check_language_host():
    r_ok = ocx.run(LANG_YAML, "--help", env = ENV)
    expect.eq(r_ok.exit_code, 0)
    r_bad = ocx.run(LANG_YAML, "--ocx-no-such-flag", env = ENV)
    expect.ne(r_bad.exit_code, 0)

check_language_host()

# ── pulumi-watch — the ONLY dynamically linked binary in the bundle ─────────
# It is what forces the `+libc.glibc` platform keys, so the container legs must
# actually exec it; on a musl host this call is the one that dies at load time.
# Upstream ships no `pulumi-watch.exe` for windows/arm64 (12 entries in that
# zip, 13 everywhere else), so that one platform is skipped by construction.
def check_watch():
    if ocx.target_platform.os == ocx.os.Windows and ocx.target_platform.arch == ocx.arch.Arm64:
        return
    r_ok = ocx.run(WATCH, "--help", env = ENV)
    expect.eq(r_ok.exit_code, 0)
    r_bad = ocx.run(WATCH, "--ocx-no-such-flag", env = ENV)
    expect.ne(r_bad.exit_code, 0)

check_watch()
