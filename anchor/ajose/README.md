# Ajose Anchor program

The on-chain program for Ajose's rotating savings circles. The Flutter app
remains in the repository root; this is a separate Anchor workspace.

## Development network

`Anchor.toml` is configured for devnet. `create_circle` receives and stores its
USDC mint account; subsequent token instructions enforce that stored address.
The Flutter client is responsible for offering the configured cluster's USDC
mint (USDC-Dev on devnet, mainnet USDC on mainnet-beta), so changing clusters
does not require a program redeploy.

## Current instruction: `create_circle`

```
create_circle(
  name: String,
  contribution_amount: u64,
  frequency: ContributionFrequency,
  seat_reservations: Vec<Option<Pubkey>>,
  first_round_deadline: i64,
)
```

`contribution_amount` is an integer in USDC base units: for example, 25 USDC
is `25_000_000`. `frequency` has `Weekly`, `Biweekly`, and `Monthly` variants
whose intervals are 7, 14, and 30 days. `seat_reservations` creates the fixed
payout order: an address reserves that seat and `None` creates an open seat
for the future `join_circle` instruction. Two to fifty seats are allowed.

The newly created `Circle` account is its own on-chain address, matching the
Flutter `Circle.id`. It persists the ordered member seats, the current
recipient index, current-round deadline, contribution amount, mint, and
cadence. Each `MemberSeat` stores the wallet address, payout position,
current-round payment status, and optional payment timestamp, mirroring the
Flutter `Member` model. New seats start `Pending` with no payment timestamp.

The next implementation steps are `join_circle`, SPL-token vault creation and
`contribute`, then the fully-funded `distribute_payout` flow. They must be
reviewed as one security-sensitive token-account design before any devnet
deployment.

## `join_circle`

```
join_circle(seat_index: u8)
```

The signer claims that exact open seat. The instruction checks the index,
requires an unfilled seat and at least one open seat, and prevents a wallet
from claiming multiple seats in the same circle. It sets the wallet and resets
the current-round payment fields to `Pending`/`None`; the seat's payout
position remains fixed. `SeatClaimed { circle, seat_index, wallet }` is
emitted for a future activity/notification indexer.

## `contribute`

`contribute()` takes no amount argument. It transfers the Circle's stored
`contribution_amount` from the member's USDC associated token account to the
circle vault, then marks that member `Paid` with the on-chain timestamp. The
vault is the associated token account owned by a dedicated PDA derived from
`[b"vault", circle]`; its bump is stored in `Circle` so the program can later
sign the payout transfer. A member may pay late in v1, but cannot pay twice in
the same round. The instruction emits `ContributionMade` for activity feeds.

## Commands

```
anchor build
cargo test -p ajose --lib
```

The checked-in `Cargo.lock` pins transitive packages compatible with the
Solana SBF toolchain bundled with Solana CLI 2.3.13.
