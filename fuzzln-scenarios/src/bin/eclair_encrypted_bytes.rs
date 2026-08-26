use fuzzln::scenarios::fuzzln_run;
use fuzzln_scenarios::scenarios::EncryptedBytesScenario;
use fuzzln_scenarios::targets::EclairTarget;

fn main() -> std::process::ExitCode {
    fuzzln_run::<EncryptedBytesScenario<EclairTarget>>()
}
