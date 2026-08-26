#!/bin/sh

# This script is executed inside the VM by the Nyx fuzzer

set -eu

# Run the LDK fuzzing harness
export FUZZLN_NYX=1
export PATH=$PATH:/usr/local/bin

# Override the default crash handler with the Nyx version, which reports
# crashes via Nyx hypercalls instead of writing to a file.
export FUZZLN_CRASH_HANDLER=/nyx-crash-handler.so

/ldk-scenario > /init.log 2>&1
