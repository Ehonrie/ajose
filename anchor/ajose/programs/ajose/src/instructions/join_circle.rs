use anchor_lang::prelude::*;

use crate::error::ErrorCode as AjoseError;
use crate::{Circle, MemberPaymentStatus};

/// Indexed by off-chain clients to refresh a circle/activity feed after a
/// wallet claims an inviteable seat.
#[event]
pub struct SeatClaimed {
    pub circle: Pubkey,
    pub seat_index: u8,
    pub wallet: Pubkey,
}

#[derive(Accounts)]
pub struct JoinCircle<'info> {
    #[account(mut)]
    pub circle: Account<'info, Circle>,
    pub joining_wallet: Signer<'info>,
}

pub fn handler(ctx: Context<JoinCircle>, seat_index: u8) -> Result<()> {
    let wallet = ctx.accounts.joining_wallet.key();
    claim_seat(&mut ctx.accounts.circle, seat_index, wallet)?;

    emit!(SeatClaimed {
        circle: ctx.accounts.circle.key(),
        seat_index,
        wallet,
    });

    Ok(())
}

/// Applies the seat-claim rules separately from the account context so they
/// can be unit tested without a validator.
pub fn claim_seat(circle: &mut Circle, seat_index: u8, wallet: Pubkey) -> Result<()> {
    let index = seat_index as usize;
    require!(
        index < circle.members.len(),
        AjoseError::SeatIndexOutOfBounds
    );
    require!(
        circle.members.iter().any(|seat| seat.wallet.is_none()),
        AjoseError::CircleFull
    );
    require!(
        !circle
            .members
            .iter()
            .any(|seat| seat.wallet == Some(wallet)),
        AjoseError::WalletAlreadyMember
    );

    let seat = &mut circle.members[index];
    require!(seat.wallet.is_none(), AjoseError::SeatAlreadyClaimed);

    seat.wallet = Some(wallet);
    seat.status = MemberPaymentStatus::Pending;
    seat.paid_at = None;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{ContributionFrequency, MemberSeat};

    fn seat(wallet: Option<Pubkey>, payout_position: u16) -> MemberSeat {
        MemberSeat {
            wallet,
            payout_position,
            status: MemberPaymentStatus::Pending,
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
    fn claiming_an_open_seat_sets_wallet_and_resets_payment_state() {
        let wallet = Pubkey::new_unique();
        let mut circle = test_circle(vec![seat(Some(Pubkey::new_unique()), 0), seat(None, 1)]);
        circle.members[1].status = MemberPaymentStatus::Paid;
        circle.members[1].paid_at = Some(123);

        claim_seat(&mut circle, 1, wallet).unwrap();

        assert_eq!(circle.members[1].wallet, Some(wallet));
        assert_eq!(circle.members[1].payout_position, 1);
        assert_eq!(circle.members[1].status, MemberPaymentStatus::Pending);
        assert_eq!(circle.members[1].paid_at, None);
    }

    #[test]
    fn claiming_an_filled_seat_fails() {
        let mut circle = test_circle(vec![seat(Some(Pubkey::new_unique()), 0), seat(None, 1)]);

        let error = claim_seat(&mut circle, 0, Pubkey::new_unique()).unwrap_err();

        assert!(error.to_string().contains("already been claimed"));
    }

    #[test]
    fn claiming_an_out_of_bounds_seat_fails() {
        let mut circle = test_circle(vec![seat(None, 0), seat(None, 1)]);

        let error = claim_seat(&mut circle, 2, Pubkey::new_unique()).unwrap_err();

        assert!(error.to_string().contains("does not exist"));
    }

    #[test]
    fn existing_member_cannot_claim_another_open_seat() {
        let wallet = Pubkey::new_unique();
        let mut circle = test_circle(vec![seat(Some(wallet), 0), seat(None, 1)]);

        let error = claim_seat(&mut circle, 1, wallet).unwrap_err();

        assert!(error.to_string().contains("already occupies"));
    }
}
