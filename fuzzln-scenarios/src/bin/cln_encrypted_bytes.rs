//! CLN (Core Lightning) fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::EncryptedBytesScenario;
use fuzzln_scenarios::targets::ClnTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<EncryptedBytesScenario<ClnTarget>>()
}
