//! LND IR fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::{IrScenario, PostInitSetup};
use fuzzln_scenarios::targets::LndTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<IrScenario<LndTarget, PostInitSetup>>()
}
