use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, Mint, Token, TokenAccount, Transfer},
};

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

/// Claims an open seat and pays that seat's first contribution in the same
/// transaction — joining and free-riding (holding a seat, never paying in,
/// still collecting a payout turn once it comes around) aren't separable
/// actions here. Later rounds still go through the plain `contribute`.
#[derive(Accounts)]
pub struct JoinCircle<'info> {
    #[account(mut)]
    pub circle: Account<'info, Circle>,
    #[account(mut)]
    pub joining_wallet: Signer<'info>,
    #[account(
        mut,
        associated_token::mint = usdc_mint,
        associated_token::authority = joining_wallet,
    )]
    pub joining_wallet_token_account: Account<'info, TokenAccount>,
    #[account(
        init_if_needed,
        payer = joining_wallet,
        associated_token::mint = usdc_mint,
        associated_token::authority = vault_authority,
    )]
    pub circle_vault: Account<'info, TokenAccount>,
    /// CHECK: This PDA has no data and exists solely as the vault's signing
    /// authority. Its address and bump are constrained below.
    #[account(
        seeds = [b"vault", circle.key().as_ref()],
        bump = circle.vault_bump,
    )]
    pub vault_authority: UncheckedAccount<'info>,
    #[account(address = circle.usdc_mint)]
    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<JoinCircle>, seat_index: u8) -> Result<()> {
    let circle = &ctx.accounts.circle;
    require!(
        circle.completed_rounds < circle.members.len() as u16,
        AjoseError::CircleCompleted
    );
    let now = Clock::get()?.unix_timestamp;
    require!(now < circle.current_round_deadline, AjoseError::RoundClosed);

    let wallet = ctx.accounts.joining_wallet.key();
    claim_seat(&mut ctx.accounts.circle, seat_index, wallet)?;

    let amount = ctx.accounts.circle.contribution_amount;
    token::transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.joining_wallet_token_account.to_account_info(),
                to: ctx.accounts.circle_vault.to_account_info(),
                authority: ctx.accounts.joining_wallet.to_account_info(),
            },
        ),
        amount,
    )?;

    let paid_at = Clock::get()?.unix_timestamp;
    let seat = &mut ctx.accounts.circle.members[seat_index as usize];
    seat.status = MemberPaymentStatus::Paid;
    seat.paid_at = Some(paid_at);

    emit!(SeatClaimed {
        circle: ctx.accounts.circle.key(),
        seat_index,
        wallet,
    });

    Ok(())
}

/// Applies the seat-claim rules separately from the account context so they
/// can be unit tested without a validator. Leaves the seat Pending/unpaid —
/// [handler] immediately upgrades it to Paid once the transfer above lands,
/// so this intermediate state is never actually observable on-chain.
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
            bond_posted: 0,
            bond_remaining: 0,
            bond_claimed: false,
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
            completed_rounds: 0,
            last_payout_recipient: None,
            last_payout_amount: 0,
            last_payout_at: None,
            collateral_amount: 0,
            bond_bump: 255,
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
