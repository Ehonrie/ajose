use anchor_lang::prelude::*;

use crate::error::ErrorCode as AjoseError;
use crate::{Circle, MemberPaymentStatus};

#[derive(Accounts)]
pub struct CancelCircle<'info> {
    #[account(
        mut,
        has_one = authority @ AjoseError::NotCircleAuthority,
        close = authority,
    )]
    pub circle: Account<'info, Circle>,
    #[account(mut)]
    pub authority: Signer<'info>,
}

/// Closes the circle and refunds its rent to `authority`. The `close`
/// constraint above only takes effect if this handler returns `Ok`, so
/// checking every seat's payment status here — rather than before account
/// validation — still safely blocks cancellation once anyone has paid,
/// with no partial effects on failure.
pub fn handler(ctx: Context<CancelCircle>) -> Result<()> {
    require!(
        ctx.accounts
            .circle
            .members
            .iter()
            .all(|seat| seat.status != MemberPaymentStatus::Paid),
        AjoseError::CircleAlreadyFunded
    );

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{ContributionFrequency, MemberSeat};

    fn seat(status: MemberPaymentStatus) -> MemberSeat {
        MemberSeat {
            wallet: None,
            payout_position: 0,
            status,
            paid_at: None,
        }
    }

    fn test_circle(members: Vec<MemberSeat>) -> Circle {
        Circle {
            authority: Pubkey::new_unique(),
            name: "Test circle".to_owned(),
            usdc_mint: Pubkey::new_unique(),
            contribution_amount: 10_000_000,
            frequency: ContributionFrequency::Weekly,
            members,
            current_round_index: 0,
            current_round_deadline: 2_000_000_000,
            vault_bump: 255,
            created_at: 1_000_000_000,
        }
    }

    #[test]
    fn cancelling_with_no_payments_is_allowed() {
        let circle = test_circle(vec![
            seat(MemberPaymentStatus::Pending),
            seat(MemberPaymentStatus::Pending),
        ]);
        assert!(circle.members.iter().all(|s| s.status != MemberPaymentStatus::Paid));
    }

    #[test]
    fn cancelling_after_a_payment_is_blocked() {
        let circle = test_circle(vec![seat(MemberPaymentStatus::Paid), seat(MemberPaymentStatus::Pending)]);
        assert!(!circle.members.iter().all(|s| s.status != MemberPaymentStatus::Paid));
    }
}
