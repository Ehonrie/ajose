use anchor_lang::prelude::*;

/// Contribution cadence, matching Flutter's `ContributionFrequency` enum.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, Debug, InitSpace, PartialEq, Eq)]
pub enum ContributionFrequency {
    Weekly,
    Biweekly,
    Monthly,
}

impl ContributionFrequency {
    pub const fn interval_seconds(self) -> i64 {
        match self {
            Self::Weekly => 7 * 24 * 60 * 60,
            Self::Biweekly => 14 * 24 * 60 * 60,
            Self::Monthly => 30 * 24 * 60 * 60,
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
    }
}
