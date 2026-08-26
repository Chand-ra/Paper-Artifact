# Ground-truth bug benchmark

This directory originally curated **20 candidate bugs** (5 per target: CLN, Eclair, LDK,
LND) against the criteria in the paper's Historical Bug Curation paragraph (Evaluation
Architecture section of the Methodology).

A post-campaign audit excluded **3** of these, leaving the **17** bugs reported as the
paper's final benchmark (5 CLN, 5 Eclair, 4 LND, 3 LDK):

| Target / bug                | Reason excluded                     |
|------------------------------|--------------------------------------|
| `ldk/balance_underflow`      | not a real defect                    |
| `ldk/bogus_min_msat`         | misplaced flag                       |
| `lnd/push_overflow`          | not a real defect                    |

All 20 are retained in this repo for transparency. The 3 excluded bugs are individually
marked with an `EXCLUDED.md` file in their own directory (e.g.
[ldk/balance_underflow/EXCLUDED.md](ldk/balance_underflow/EXCLUDED.md)); their
`flag.patch`, `metadata.json`, and any PoC files are unchanged.

## Per-target bug list

### CLN (5/5 included)

- `dns_overflow`
- `early_cupdate`
- `malformed_cannounce`
- `openchannel_assert`
- `send_tlvs`

### Eclair (5/5 included)

- `decode_drop`
- `htlc_propagation`
- `pubkey_exception`
- `shutdown_retransmit`
- `unknown_message`

### LND (4/5 included)

- `cupdate_no_htlc`
- `gossiper_deadlock`
- `malformed_tlv`
- `zero_timestamp`
- ~~`push_overflow`~~ — **excluded**, not a real defect ([EXCLUDED.md](lnd/push_overflow/EXCLUDED.md))

### LDK (3/5 included)

- `annsig_panic`
- `channel_ready`
- `reachable_unwrap`
- ~~`balance_underflow`~~ — **excluded**, not a real defect ([EXCLUDED.md](ldk/balance_underflow/EXCLUDED.md))
- ~~`bogus_min_msat`~~ — **excluded**, misplaced flag ([EXCLUDED.md](ldk/bogus_min_msat/EXCLUDED.md))
