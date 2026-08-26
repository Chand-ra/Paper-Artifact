//! CLN init message fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::InitScenario;
use fuzzln_scenarios::targets::ClnTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<InitScenario<ClnTarget>>()
}
