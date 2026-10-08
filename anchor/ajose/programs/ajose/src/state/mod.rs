use anchor_lang::prelude::*;

/// Contribution cadence, matching Flutter's `ContributionFrequency` enum.
/// `TestFast` is appended last, not inserted, so the existing variants'
/// Borsh ordinals (and every already-created Circle account's stored byte)
/// stay unchanged.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, Debug, InitSpace, PartialEq, Eq)]
pub enum ContributionFrequency {
    Weekly,
    Biweekly,
    Monthly,
    /// A 10-minute round, for exercising a circle's full lifecycle without
    /// waiting on a real cadence. Not meant to be offered outside testing.
    TestFast,
}

impl ContributionFrequency {
    pub const fn interval_seconds(self) -> i64 {
        match self {
            Self::Weekly => 7 * 24 * 60 * 60,
            Self::Biweekly => 14 * 24 * 60 * 60,
            Self::Monthly => 30 * 24 * 60 * 60,
            Self::TestFast => 10 * 60,
        }
    }
}

/// Payment state for a seat in the active round. `Overdue` is set by a later
/// settlement/status instruction when the deadline has passed.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, Debug, InitSpace, PartialEq, Eq)]
pub enum MemberPaymentStatus {
    Paid,
    Pending,
    Overdue,
}

/// One turn in a circle. An empty `wallet` represents an inviteable seat.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub struct MemberSeat {
    pub wallet: Option<Pubkey>,
    pub payout_position: u16,
    pub status: MemberPaymentStatus,
    pub paid_at: Option<i64>,
    /// What this seat originally posted to `BondPool` via `post_collateral`
    /// — zero if the circle doesn't require collateral, or this seat hasn't
    /// posted yet.
    pub bond_posted: u64,
    /// `bond_posted` minus whatever's since been forfeited to cover this
    /// member's own missed contributions — one contribution's worth per
    /// miss, not the whole bond at once. What `claim_collateral` actually
    /// pays out.
    pub bond_remaining: u64,
    /// Set once this seat's `claim_collateral` has paid out
    /// `bond_remaining`, so it can't be claimed twice.
    pub bond_claimed: bool,
}

/// Persistent state for one rotating savings circle.
#[account]
pub struct Circle {
    pub authority: Pubkey,
    pub name: String,
    pub usdc_mint: Pubkey,
    /// USDC base units (six decimals for the configured mint), never a float.
    pub contribution_amount: u64,
    pub frequency: ContributionFrequency,
    pub members: Vec<MemberSeat>,
    /// Zero-based index into `members` for the current payout recipient.
    pub current_round_index: u16,
    pub current_round_deadline: i64,
    /// Bump for the vault-authority PDA: [b"vault", circle.key()].
    pub vault_bump: u8,
    pub created_at: i64,
    /// How many of this circle's rounds have paid out so far. A circle has
    /// completed its one full rotation (and `contribute` stops accepting
    /// further calls) once this reaches `members.len()`.
    pub completed_rounds: u16,
    /// Snapshot of the most recent payout, so the UI has something durable
    /// to show (a receipt, a "payout disbursed" notice) without replaying
    /// program logs. Overwritten each time a round completes.
    pub last_payout_recipient: Option<Pubkey>,
    pub last_payout_amount: u64,
    pub last_payout_at: Option<i64>,
    /// Required bond to hold a seat, in USDC base units. Zero means this
    /// circle doesn't require collateral at all — entirely optional, set
    /// once at creation and never changed after.
    pub collateral_amount: u64,
    /// Bump for the bond-pool vault-authority PDA: [b"bond", circle.key()].
    /// Present even when `collateral_amount` is zero, so `settle_round`'s
    /// account shape stays the same for every circle regardless of whether
    /// it uses collateral.
    pub bond_bump: u8,
}

impl Circle {
    pub fn space(name_length: usize, seat_count: usize) -> usize {
        8 + 32
            + 4
            + name_length
            + 32
            + 8
            + ContributionFrequency::INIT_SPACE
            + 4
            + seat_count * MemberSeat::INIT_SPACE
            + 2
            + 8
            + 1
            + 8
            + 2
            + (1 + 32)
            + 8
            + (1 + 8)
            + 8
            + 1
    }
}

/// A personal, time-locked USDC savings vault — unrelated to circles.
/// Deposits are accepted anytime; a withdrawal is only valid once
/// `unlock_at` has passed, and empties + closes the vault in one go.
#[account]
pub struct SavingsTarget {
    pub owner: Pubkey,
    pub label: String,
    pub usdc_mint: Pubkey,
    /// A goal to visualize progress toward, in USDC base units. Zero means
    /// no specific goal — just a locked jar with a free-form balance.
    pub target_amount: u64,
    pub unlock_at: i64,
    /// Bump for the vault-authority PDA: [b"savings_vault", savings_target.key()].
    pub vault_bump: u8,
    pub created_at: i64,
}

impl SavingsTarget {
    pub fn space(label_length: usize) -> usize {
        8 + 32
            + 4
            + label_length
            + 32
            + 8
            + 8
            + 1
            + 8
    }
}

#[cfg(test)]
mod tests {
    use super::ContributionFrequency;

    #[test]
    fn cadence_matches_flutter_model() {
        assert_eq!(ContributionFrequency::Weekly.interval_seconds(), 604_800);
        assert_eq!(
            ContributionFrequency::Biweekly.interval_seconds(),
            1_209_600
        );
        assert_eq!(ContributionFrequency::Monthly.interval_seconds(), 2_592_000);
        assert_eq!(ContributionFrequency::TestFast.interval_seconds(), 600);
    }
}
