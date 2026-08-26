#!/bin/bash
# docker/build_docker.sh
#
# Builds one Docker image per bug per scenario. Needed for the survival
# campaigns, the coverage one handles docker image creation on its own.
#
# Run from the FuzzLN repo root: bash fuzzln-evaluation/docker/build_docker.sh
#
# Pass a bug name as the first argument to build only that bug's images
# instead of all 20, e.g.: bash fuzzln-evaluation/docker/build_docker.sh send_tlvs
# Bug names are unique across targets, so the name alone is enough to resolve
# which bugs/<target>/<bug> directory to build.

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FUZZLN_DIR="$(cd "$EVAL_DIR/.." && pwd)"
DOCKER_DIR="$EVAL_DIR/docker"
VULNS_DIR="$EVAL_DIR/bugs"

# Scenarios to build. Add more if needed for ablation.
SCENARIOS=("encrypted_bytes" "ir")

# Apply stdio-inherit patch so target stderr is visible during local reproduction.
# git apply is idempotent here: the || true silences the expected failure
# on subsequent runs when the patch is already applied.
git -C "$FUZZLN_DIR" apply "$EVAL_DIR/docker/stdio-inherit.patch" 2>/dev/null || true

BUG_FILTER="${1:-}"

if [ -n "$BUG_FILTER" ]; then
    # shellcheck disable=SC2206
    META_FILES=("$VULNS_DIR"/*/"$BUG_FILTER"/metadata.json)
    if [ ! -e "${META_FILES[0]}" ]; then
        echo "ERROR: no bug named '$BUG_FILTER' found under $VULNS_DIR/*/$BUG_FILTER/metadata.json" >&2
        exit 1
    fi
    if [ "${#META_FILES[@]}" -gt 1 ]; then
        echo "ERROR: bug name '$BUG_FILTER' is ambiguous (matched ${#META_FILES[@]} directories)" >&2
        exit 1
    fi
else
    META_FILES=("$VULNS_DIR"/*/*/metadata.json)
fi

for meta_file in "${META_FILES[@]}"; do
    target=$(python3 -c "import json,sys; print(json.load(open('$meta_file'))['target'])")
    bug=$(python3 -c "import json,sys; print(json.load(open('$meta_file'))['bug'])")
    commit=$(python3 -c "import json,sys; print(json.load(open('$meta_file'))['buggy_commit'])")
    patch=""
    if [ -s "$VULNS_DIR/$target/$bug/flag.patch" ]; then
        patch="${target}/${bug}/flag.patch"
    fi

    for scenario in "${SCENARIOS[@]}"; do
        image="fuzzln-eval-${target}-${bug,,}-${scenario}"

        if docker image inspect "$image" > /dev/null 2>&1; then
            echo "[skip] $image already exists"
            continue
        fi

        echo "[build] $image"
        
        # Branch build args depending on whether target is LDK or not
        if [ "$target" = "ldk" ]; then
            docker build \
                -t "$image" \
                -f "$DOCKER_DIR/${target}.Dockerfile" \
                --build-arg "SCENARIO=$scenario" \
                --build-arg "FUZZLN_PATCH=${target}/${bug}/fuzzln.patch" \
                --build-arg "FLAG_PATCH=$patch" \
                "$FUZZLN_DIR"
        else
            docker build \
                -t "$image" \
                -f "$DOCKER_DIR/${target}.Dockerfile" \
                --build-arg "SCENARIO=$scenario" \
                --build-arg "COMMIT_HASH=$commit" \
                --build-arg "FLAG_PATCH=$patch" \
                "$FUZZLN_DIR"
        fi
    done
done

echo "All images built."

# Build the custom mutator
echo "Building custom mutator..."
cargo build --release -p fuzzln-ir-mutator

# Enable KVM-backdoor for Nyx
echo "Enabling VMware backdoor..."
sudo "$FUZZLN_DIR/scripts/enable-vmware-backdoor.sh"

