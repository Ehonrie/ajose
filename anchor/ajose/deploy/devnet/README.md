# Devnet deploy artifacts

Prebuilt output for the `ajose` Anchor program, built 2026-09-30 with `cargo-build-sbf`
(platform-tools v1.48) against the pinned `Cargo.lock` in this repo.

- `ajose.so` — compiled BPF program binary.
- `ajose-keypair.json` — program keypair. Its pubkey (`6F6jhojAyf5ksvSpERBUwFKnBXSR5DUdcCxThDdSZgta`)
  matches `declare_id!` in `programs/ajose/src/lib.rs` and `Anchor.toml`. Needed to deploy to
  this exact program address. Devnet-only — never reuse for a mainnet program.

Deploy with the Solana CLI (no Rust/Anchor toolchain needed):

```
solana program deploy deploy/devnet/ajose.so \
  --program-id deploy/devnet/ajose-keypair.json \
  --url https://api.devnet.solana.com \
  --keypair <path-to-a-funded-devnet-wallet>.json
```
