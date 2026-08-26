//! LND fuzzing scenario binary.

use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::EncryptedBytesScenario;
use fuzzln_scenarios::targets::LndTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<EncryptedBytesScenario<LndTarget>>()
}
