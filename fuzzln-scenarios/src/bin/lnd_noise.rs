//! LND noise handshake fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::NoiseScenario;
use fuzzln_scenarios::targets::LndTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<NoiseScenario<LndTarget>>()
}
