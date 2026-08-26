# fuzzlnbot

`fuzzlnbot` is the FuzzLN automation CLI. It orchestrates fuzzing campaigns against Lightning Network implementations using AFL++ and Nyx, reducing multi-step manual workflows to single commands.

## Install

```bash
cargo install --path fuzzlnbot
```

## Configuration

Campaign settings are stored in a TOML file. See [`sample-campaign.toml`](sample-campaign.toml) for a complete example.

| Field          | Required | Description                                                                               |
| -------------- | -------- | ----------------------------------------------------------------------------------------- |
| `target`       | yes      | Lightning implementation to fuzz (`lnd`, `cln`, `ldk`, or `eclair`).                      |
| `scenario`     | yes      | Scenario binary selected by the workload Dockerfile.                                      |
| `aflpp_path`   | yes      | Path to the AFL++ source tree.                                                            |
| `fuzzln_dir`    | yes      | Path to the fuzzln repository root.                                                        |
| `runners`      | yes      | Number of parallel AFL++ instances to launch (must be at least 1).                        |
| `seed_dir`     | no       | Directory containing seed inputs; omit to start from an empty corpus.                     |
| `output_dir`   | yes      | AFL++ output directory for findings and stats.                                            |
| `sharedir`     | yes      | Nyx shared directory path; created automatically by `fuzzlnbot start`.                     |
| `image`        | no       | Docker image tag override; defaults to `fuzzln-<target>-<scenario>`.                       |
| `tmux_session` | no       | Custom tmux session name; defaults to the campaign ID. Must not contain `:`, `.`, or `#`. |
| `afl_env`      | no       | Extra environment variables passed to AFL++ instances.                                    |
| `afl_flags`    | no       | Extra CLI flags appended to `afl-fuzz`.                                                   |

## Commands

### fuzzlnbot start

Launches a fuzzing campaign. Builds the Docker image, sets up the Nyx sharedir, spawns parallel AFL++ instances inside a tmux session (one window per runner), and attaches to the session.

```bash
fuzzlnbot start campaign.toml
```

Each runner gets a deterministic strategy distribution. The primary runner (0)
runs AFL++'s default schedule with no modifiers; secondaries carry the schedule
and mutation modifiers below. The power schedule is round-robin by index; the
remaining modifiers are spread across secondaries by a fixed hash of the runner
index, so a given runner always draws the same flags:
- Power schedule (`-p`, secondaries only): round-robin across `explore`, `fast`, `coe`, `lin`, `quad`, `exploit`, `rare`
- `-a binary`: ~70% of secondaries (wire messages are binary; hints AFL++ to use binary mutation strategies)
- `-P` (fixed mutation strategy): `explore` ~40% / `exploit` ~20% of secondaries
- `-L 0` (MOpt mode): ~10% of secondaries; skipped when a custom mutator is set (incompatible with MOpt)
- `-Z` (sequential queue selection): ~10% of secondaries
- `AFL_DISABLE_TRIM`: ~60% of secondary runners
- `AFL_FINAL_SYNC`: primary runner only
- `AFL_IMPORT_FIRST`: enabled when runner count < 16
- `AFL_TESTCACHE_SIZE`: auto-sized from available RAM

For IR scenarios (scenario names starting with `ir`), the required AFL++ custom mutator environment variables are injected automatically. User `afl_env` values override strategy defaults.

`start` begins fresh campaigns only. If `output_dir` already holds a prior run's `fuzzer_stats`, it exits with an error instead of resuming (resume is not yet supported).

After spawning, startup is verified by polling for `fuzzer_stats` files. Because AFL++ writes `fuzzer_stats` only after calibrating every seed (minutes under Nyx), a runner is reported as failed the moment its tmux window exits rather than after a fixed timeout; the poll otherwise waits up to a generous ceiling (10 min) for a runner that stays alive but never starts. On failure, the tmux session is preserved with `remain-on-exit` so error output can be inspected.

Campaign state is saved to `~/.fuzzlnbot/runs/<campaign-id>/state.json` for use by future `stop` and `status` commands.

### fuzzlnbot stop

Stops a running campaign: reaps every runner's process group — afl-fuzz and its Nyx QEMU child, which shares the group — tears down the tmux session, and records the stop time in `state.json`.

```bash
fuzzlnbot stop <campaign-id>
```

`<campaign-id>` is the directory name under `~/.fuzzlnbot/runs` (printed by `fuzzlnbot start`). 

### fuzzlnbot status

Reports the status of a campaign. Detects whether the campaign is still running (its tmux session is alive) and adapts:

```bash
fuzzlnbot status <campaign-id>
fuzzlnbot status <campaign-id> --summary
```

- `--summary`: Print a one-shot text summary to the terminal instead of attaching to the live dashboard.
- `<campaign-id>` is the directory name under `~/.fuzzlnbot/runs` (printed by `fuzzlnbot start`).

### fuzzlnbot config

Validates a campaign configuration file, reports the resolved settings, and checks that referenced paths exist on disk.

```bash
fuzzlnbot config campaign.toml
fuzzlnbot config campaign.toml --json
```

- `--json`: Emit machine-readable JSON output. Both success and error paths produce valid JSON.

### fuzzlnbot build

Builds FuzzLN workload Docker images. Accepts a campaign config file or standalone CLI flags. When both are provided, CLI flags override config values.

```bash
fuzzlnbot build --target lnd --scenario encrypted_bytes
fuzzlnbot build campaign.toml
fuzzlnbot build campaign.toml --target cln
fuzzlnbot build campaign.toml --coverage --no-cache
```

- `--target`: Target implementation to build. Required when no config file is provided.
- `--scenario`: Scenario binary for the workload Dockerfile. Required when no config file is provided.
- `--fuzzln-dir`: Path to the fuzzln repository root; defaults to `.` when no config file is provided.
- `--coverage`: Build a coverage-instrumented image.
- `--image`: Docker image tag; overrides the config value and the default naming convention.
- `--no-cache`: Perform a clean rebuild without using cached Docker layers.

Image tags follow the FuzzLN convention: `fuzzln-<target>-<scenario>` or `fuzzln-<target>-<scenario>-coverage`.

### fuzzlnbot doctor

Validates host prerequisites before running FuzzLN campaigns. Accepts a campaign config file or standalone CLI flags. When both are provided, CLI flags override config values.

```bash
fuzzlnbot doctor --aflpp-path ~/AFLplusplus
fuzzlnbot doctor campaign.toml
fuzzlnbot doctor campaign.toml --json
fuzzlnbot doctor campaign.toml --aflpp-path ~/other-aflpp
```

- `--aflpp-path`: Path to AFL++ source tree. Required when no config file is provided.
- `--fuzzln-dir`: Path to the fuzzln repository root; overrides the config value.
- `--json`: Emit machine-readable JSON output.

Checks performed:

- `x86_64` architecture
- CPU virtualization enabled (`vmx` or `svm`)
- `/dev/kvm` is present and openable
- Docker daemon is reachable (`docker version`)
- AFL++ built with Nyx support (`libnyx.so` under `--aflpp-path`)
- VMware backdoor is enabled
- AFL++ tools (`afl-fuzz`, `afl-cmin`, `afl-tmin`, `afl-whatsup`) are executable
- Required host tools (`bash`, `python`, `python3`, `tmux`)
- Required FuzzLN scripts are present and executable
- Required workload Dockerfiles are present

JSON output example:

```json
{
  "checks": [
    { "name": "x86_64 architecture", "passed": true },
    { "name": "Docker daemon reachable", "passed": false, "reason": "docker version: exit status: 1" }
  ],
  "overall": false
}
```

### fuzzlnbot print-ir

Decodes a serialized IR program and prints it to standard output. IR programs are opaque postcard-encoded `Program`s, the same form the fuzzing loop serializes them in; point it at one to see what it actually does.

```bash
fuzzlnbot print-ir <path>
fuzzlnbot print-ir output/default/crashes/id:000000,sig:06,...
```

`<path>` is a path to a postcard-encoded IR program.

The program is printed using the IR's `Display` format, the same textual form the `fuzzln-ir` mutator emits in its trim logs. An empty program prints `(empty program)`.

### fuzzlnbot corpus merge

Collects all queue files from one or more campaign runner directories, deduplicates by content, and writes unique files to an output directory. Accepts multiple campaign IDs to merge corpora across independent runs.

```bash
fuzzlnbot corpus merge <campaign-id> -o <output-dir>
fuzzlnbot corpus merge <campaign-id-1> <campaign-id-2> ... -o <output-dir>
```

- `<campaign-id>`: directory name(s) under `~/.fuzzlnbot/runs`
- `-o, --output <output-dir>`: output directory for the merged corpus (required)

### fuzzlnbot corpus minimize

Removes corpus inputs that do not contribute new coverage, using `afl-cmin` in Nyx mode (`-X`). Reads `sharedir` and `aflpp_path` from the campaign's `state.json`; no live campaign required.

```bash
fuzzlnbot corpus minimize <campaign-id>
fuzzlnbot corpus minimize <campaign-id> [-i <dir>]... [-o <output-dir>] [--aflpp-path <path>]
```

- `<campaign-id>`: directory name under `~/.fuzzlnbot/runs`
- `-i, --input <dir>`: One input directory to minimize. If multiple `-i` flags are present, all specified directories are merged before minimizing. If omitted, the campaign's runner queues are merged and minimized.
- `-o, --output <output-dir>`: output directory; defaults to `~/.fuzzlnbot/runs/<id>/corpus-min/`
- `--aflpp-path <path>`: AFL++ source tree, overriding the `aflpp_path` stored in `state.json` (useful when the checkout has moved)
