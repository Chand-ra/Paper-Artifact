//! Eclair IR fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::{IrScenario, PostInitSetup};
use fuzzln_scenarios::targets::EclairTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<IrScenario<EclairTarget, PostInitSetup>>()
}
