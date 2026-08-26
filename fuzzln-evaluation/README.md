# FuzzLN Evaluation

This directory contains the ground-truth bug benchmark, campaign orchestration scripts,
and analysis scripts used to produce the paper's evaluation results. It is a standalone
subtree of the [FuzzLN](../README.md) repo: the fuzzing framework itself lives one level
up, this directory only adds what's needed to *evaluate* it.

## Paper result → script mapping

| Paper result | RQ | Reproduced by |
|---|---|---|
| Table 2 (time-to-exposure / TTE results) | RQ1 | [`orchestrator/survival-orchestrator.py`](orchestrator/survival-orchestrator.py) to run trials, then [`analysis/survival_analysis.py`](analysis/survival_analysis.py) to analyze them |
| Table 3 (coverage results) | RQ3/RQ4 | [`orchestrator/coverage-orchestator.py`](orchestrator/coverage-orchestator.py) to run trials, then [`analysis/coverage_analysis.py`](analysis/coverage_analysis.py) to analyze them |
| Table 4 (mutator ablation) | RQ5 | same coverage pipeline, with the ablation configs — see [Reproducing Tables 3 & 4](#reproducing-tables-3--4-coverage--rq3-rq4-rq5) below |

## Directory structure

```
fuzzln-evaluation/
├── bugs/                      # Ground-truth benchmark: 20 candidate bugs, 5 per target
│   ├── README.md              # 20-candidate vs. 17-reported accounting; see below
│   ├── cln/<bug>/              flag.patch + metadata.json (+ poc_ir and/or poc_encrypted_bytes for triggered bugs)
│   ├── eclair/<bug>/
│   ├── ldk/<bug>/
│   └── lnd/<bug>/
├── docker/
│   ├── build_docker.sh        # Builds per-bug, per-scenario images for the survival campaigns
│   ├── {cln,eclair,ldk,lnd}.Dockerfile
│   └── stdio-inherit.patch    # Makes target stderr visible during local repro
├── seeds/
│   ├── encrypted_bytes/<target>/   # Raw-bytes baseline seed corpus, per target
│   └── ir/<target>/                # Structured IR seed corpus, per target
├── orchestrator/
│   ├── survival-orchestrator.py    # TTE campaign runner -> Table 2
│   └── coverage-orchestator.py     # Coverage campaign runner -> Tables 3 & 4
├── analysis/
│   ├── survival_analysis.py   # Kaplan-Meier, log-rank, Holm-Bonferroni -> Table 2
│   ├── coverage_analysis.py   # Mann-Whitney, Vargha-Delaney, ablation -> Tables 3 & 4
│   ├── utils.py                # Shared path constants and data-loading/validation helpers
│   ├── requirements.txt
│   ├── survival-output/       # Generated: report + KM plots + ribbon figure
│   └── coverage-output/       # Generated: report + boxplots + time-series + ablation figures
├── survival-results/
│   └── trials.csv             # One row per TTE trial: target, bug, config, trial, tte_seconds, censored
└── coverage-results/
    └── <target>/<config>/trial-NN/afl-out/default/   # fuzzer_stats + plot_data per trial
```

`survival-results/` and `coverage-results/` as checked into this repo already contain the
raw trial data behind the paper's tables, so the analysis scripts can be run immediately
without re-running any campaigns (see [Quick sanity check](#quick-sanity-check-no-campaign-required)
below).

## Bugs: 20 candidates, 17 reported

`bugs/` holds 20 candidate bugs (5 per target). A post-campaign audit excluded 3 of them
from the paper's final 17-bug benchmark; the exclusions are marked in place with an
`EXCLUDED.md` in each affected bug's directory. See [bugs/README.md](bugs/README.md) for
the full list and reasons. (The checked-in `survival-results/trials.csv` already reflects
this: it has rows for exactly the 17 included bugs, none of the 3 excluded ones.)

## Prerequisites

Same as the root [FuzzLN README](../README.md#prerequisites), plus:

- Python 3 with `pip install -r analysis/requirements.txt` for the analysis scripts
- `rich` (`pip install rich`) for the orchestrators' live dashboards
- [`fuzzlnbot`](../fuzzlnbot) on `PATH` (`cargo install --path fuzzlnbot`) — the
  orchestrators shell out to `fuzzlnbot doctor` for host validation
- Docker, to build the per-bug images (`docker/build_docker.sh`)

Both orchestrators are bare-metal-oriented: `fuzzlnbot doctor` (invoked automatically by
each orchestrator before it starts) checks for `/dev/kvm` access, CPU virtualization
flags, the KVM VMware backdoor, and a Nyx-enabled AFL++ build — none of which are
guaranteed inside a VM or container. The paper's campaigns were run bare-metal (see the
[root README's Evaluation Environment section](../README.md#evaluation-environment)).

## Reproducing Table 2 (TTE / RQ1)

1. Build the per-bug Docker images (one per bug × scenario):

   ```bash
   bash fuzzln-evaluation/docker/build_docker.sh
   ```

2. Run the survival campaign. `--configs` maps a label to a scenario
   (`encrypted_bytes` = raw-bytes baseline, `ir` = structured IR); the paper uses one
   label per arm, 20 trials per bug per arm, and a 24h (86400s) per-trial timeout:

   ```bash
   python3 fuzzln-evaluation/orchestrator/survival-orchestrator.py \
     --out-dir /path/to/survival-out \
     --configs baseline:encrypted_bytes,experimental:ir \
     --fuzzln-dir /path/to/fuzzln-checkout \
     --afl-dir /path/to/AFLplusplus \
     --cores 0,1,2,3 \
     --trials 20 \
     --timeout 86400
   ```

   Add `--targets cln,lnd` to restrict to specific targets, or `--bugs send_tlvs,...` to
   restrict to specific bugs (both filters are optional; default is all targets/bugs
   under `bugs/`).

3. Copy (or point) the resulting `trials.csv` into `survival-results/`, then run the
   analysis:

   ```bash
   python3 fuzzln-evaluation/analysis/survival_analysis.py
   ```

   This reads `survival-results/trials.csv` and writes
   `analysis/survival-output/survival_evaluation_report.md` (Table 2's per-bug medians,
   IQRs, and Holm-Bonferroni-adjusted log-rank p-values) plus per-bug Kaplan-Meier plots
   and the paper's "USENIX Ribbon" figure.

## Reproducing Tables 3 & 4 (coverage / RQ3, RQ4, RQ5)

1. Run the coverage campaigns. Unlike the survival orchestrator, this one builds its own
   Docker images and the IR mutator, so no separate build step is needed. `--scenario` is
   a single value shared by every `--configs` label in one invocation, so the raw-bytes
   baseline and the IR-based configs (full stack + 4 ablations) each need their own
   invocation — you can't mix scenarios within one run. The checked-in `coverage-results/`
   data has 20 trials per target per config with a 24h timeout (the orchestrator's own
   `--trials` default is 30 — pass `--trials 20` to match what's checked in, or override
   to whatever scale you need):

   ```bash
   # Baseline: raw-bytes scenario
   python3 fuzzln-evaluation/orchestrator/coverage-orchestator.py \
     --out-dir /path/to/coverage-out \
     --configs encrypted_bytes:/path/to/fuzzln-checkout \
     --scenario encrypted_bytes \
     --targets cln,eclair,ldk,lnd \
     --afl-dir /path/to/AFLplusplus \
     --cores 0,1,2,3 \
     --trials 20 \
     --timeout 86400

   # Full IR mutator stack: build target/release/libfuzzln_ir_mutator.so with every
   # mutator enabled in the checkout below, then run the ir scenario
   python3 fuzzln-evaluation/orchestrator/coverage-orchestator.py \
     --out-dir /path/to/coverage-out \
     --configs ir-full-stack:/path/to/fuzzln-checkout-full-stack \
     --scenario ir \
     --targets cln,eclair,ldk,lnd \
     --afl-dir /path/to/AFLplusplus \
     --cores 0,1,2,3 \
     --trials 20 \
     --timeout 86400
   ```

   Each `--configs` label points at a `fuzzln` checkout with the mutator variant under
   test already built at `target/release/libfuzzln_ir_mutator.so`. For Table 4's ablation,
   repeat the `ir`-scenario invocation once per mutator, each time with that one mutator
   disabled in the checkout and a distinct label (`ir-splice`, `ir-gen-insert`,
   `ir-delete`, `ir-reorder` — see the script's module docstring for the ablation
   workflow, and `ABLATION_CONFIGS` in [`analysis/utils.py`](analysis/utils.py) for how
   these labels map to mutators).

2. Each invocation's `--out-dir` already lays out `<target>/<label>/trial-NN/afl-out/default/`
   using the labels above, matching `coverage-results/<target>/<config>/trial-NN/afl-out/default/`
   directly. Merge/copy the runs into `coverage-results/` (or edit the hardcoded
   `COVERAGE_RESULTS_DIR` constant in [`analysis/utils.py`](analysis/utils.py) to point at
   your own `--out-dir` instead), then run:

   ```bash
   python3 fuzzln-evaluation/analysis/coverage_analysis.py
   ```

   This writes `analysis/coverage-output/coverage_evaluation_report.md`: section 1
   (summary statistics: median/AUC coverage, Mann-Whitney + Vargha-Delaney Â12, union
   coverage) is Table 3; section 4 (mutator ablation) is Table 4.

## Quick sanity check (no campaign required)

Because `survival-results/` and `coverage-results/` are checked into this repo with the
data behind the paper's tables already in place, a reviewer can regenerate both reports
immediately without running any fuzzing campaign:

```bash
pip install -r fuzzln-evaluation/analysis/requirements.txt
python3 fuzzln-evaluation/analysis/survival_analysis.py
python3 fuzzln-evaluation/analysis/coverage_analysis.py
```

This reruns the statistics/plotting only (seconds, not hours) and regenerates
`analysis/survival-output/` and `analysis/coverage-output/` in place — a good first check
that the analysis pipeline and its dependencies are set up correctly.

To sanity-check the *campaign* side (the orchestrators + Docker + AFL++ + Nyx) without a
full 24h/20-trial run, both orchestrators accept `--timeout` (seconds) and `--trials` /
`--trial-ids` to cut a run down to a handful of short trials, and `--bugs` /
`--targets` to restrict to one bug. For example, one 2-minute trial against a single CLN
bug:

```bash
bash fuzzln-evaluation/docker/build_docker.sh send_tlvs   # build only that bug's images

python3 fuzzln-evaluation/orchestrator/survival-orchestrator.py \
  --out-dir /path/to/survival-out \
  --configs baseline:encrypted_bytes,experimental:ir \
  --fuzzln-dir /path/to/fuzzln-checkout \
  --afl-dir /path/to/AFLplusplus \
  --cores 0 \
  --bugs send_tlvs \
  --trials 1 \
  --timeout 120
```

The coverage orchestrator does not expose a single-bug filter (it filters by `--targets`
only, since coverage is measured per target rather than per bug), but the same
`--trials`/`--trial-ids`/`--timeout` reduction applies there too. Neither orchestrator
supports a "dry run" mode beyond this — reducing scale via these flags is the only
supported way to get a fast turnaround.

## Runtime & resource requirements

Per the paper: 24h per trial, 20 trials per config for both the survival and coverage
campaigns (the coverage orchestrator's own `--trials` default is 30; pass `--trials 20`
to match the checked-in data), bare-metal recommended (see
[Prerequisites](#prerequisites) above — the orchestrators' own host validation checks for
this). A full reproduction of either campaign is a multi-day, multi-core undertaking; use
the [quick sanity check](#quick-sanity-check-no-campaign-required) above to validate the
pipeline before committing to a full run.
