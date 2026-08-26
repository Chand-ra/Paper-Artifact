//! LDK IR fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::{IrScenario, PostInitSetup};
use fuzzln_scenarios::targets::LdkTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<IrScenario<LdkTarget, PostInitSetup>>()
}
