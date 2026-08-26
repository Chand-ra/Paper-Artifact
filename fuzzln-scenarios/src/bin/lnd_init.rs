//! LND init message fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::InitScenario;
use fuzzln_scenarios::targets::LndTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<InitScenario<LndTarget>>()
}
