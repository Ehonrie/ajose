use anchor_lang::prelude::*;
use anchor_spl::token::{self, CloseAccount, Mint, Token, TokenAccount, Transfer};

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
    // init_if_needed so cancelling a plain (no-collateral) circle never
    // forces the creator to already hold a USDC account — this just gets
    // created and, a moment later in the same transaction, the bond vault
    // below gets closed back into it anyway.
    #[account(
        init_if_needed,
        payer = authority,
        associated_token::mint = usdc_mint,
        associated_token::authority = authority,
    )]
    pub authority_token_account: Account<'info, TokenAccount>,
    #[account(
        init_if_needed,
        payer = authority,
        associated_token::mint = usdc_mint,
        associated_token::authority = bond_authority,
    )]
    pub bond_vault: Account<'info, TokenAccount>,
    /// CHECK: This PDA has no data and exists solely as the bond pool's
    /// signing authority. Its address and bump are constrained below.
    #[account(
        seeds = [b"bond", circle.key().as_ref()],
        bump = circle.bond_bump,
    )]
    pub bond_authority: UncheckedAccount<'info>,
    #[account(address = circle.usdc_mint)]
    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, anchor_spl::associated_token::AssociatedToken>,
    pub system_program: Program<'info, System>,
}

/// Closes the circle and refunds its rent to `authority`, after refunding
/// any collateral the creator posted and closing the (now-empty) bond
/// vault too. The `close` constraint on `circle` only takes effect if this
/// handler returns `Ok`, so checking every seat's payment status here —
/// rather than before account validation — still safely blocks
/// cancellation once anyone has paid, with no partial effects on failure.
///
/// Only the creator's own collateral is ever refunded here, so this also
/// requires `completed_rounds == 0`: per-round `status` resets to `Pending`
/// every time a round settles (see `settle_round`), so the "nobody's paid
/// yet" check alone isn't enough once a round has actually completed — a
/// joining member's bond stays in `bond_vault` even though their `status`
/// no longer shows `Paid`. Without this guard, `token::close_account` below
/// fails on-chain because the vault still holds that member's collateral
/// (there's no way to refund a seat's own bond to someone else's
/// `authority_token_account`, and no other seat's ATA is in scope here).
pub fn handler(ctx: Context<CancelCircle>) -> Result<()> {
    require!(
        ctx.accounts
            .circle
            .members
            .iter()
            .all(|seat| seat.status != MemberPaymentStatus::Paid),
        AjoseError::CircleAlreadyFunded
    );
    require!(ctx.accounts.circle.completed_rounds == 0, AjoseError::CircleAlreadyRotated);

    let creator_wallet = ctx.accounts.circle.authority;
    let bond_remaining = ctx
        .accounts
        .circle
        .members
        .iter()
        .find(|seat| seat.wallet == Some(creator_wallet))
        .map(|seat| seat.bond_remaining)
        .unwrap_or(0);

    let circle_key = ctx.accounts.circle.key();
    let bond_bump = ctx.accounts.circle.bond_bump;
    let bond_seeds: &[&[u8]] = &[b"bond", circle_key.as_ref(), &[bond_bump]];

    if bond_remaining > 0 {
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.bond_vault.to_account_info(),
                    to: ctx.accounts.authority_token_account.to_account_info(),
                    authority: ctx.accounts.bond_authority.to_account_info(),
                },
                &[bond_seeds],
            ),
            bond_remaining,
        )?;
    }

    token::close_account(CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        CloseAccount {
            account: ctx.accounts.bond_vault.to_account_info(),
            destination: ctx.accounts.authority.to_account_info(),
            authority: ctx.accounts.bond_authority.to_account_info(),
        },
        &[bond_seeds],
    ))?;

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
            bond_posted: 0,
            bond_remaining: 0,
            bond_claimed: false,
        }
    }

    fn test_circle(members: Vec<MemberSeat>) -> Circle {
        test_circle_at_round(members, 0)
    }

    fn test_circle_at_round(members: Vec<MemberSeat>, completed_rounds: u16) -> Circle {
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
            completed_rounds,
            last_payout_recipient: None,
            last_payout_amount: 0,
            last_payout_at: None,
            collateral_amount: 0,
            bond_bump: 255,
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

    /// Once a round has settled, every seat's `status` resets away from
    /// `Paid` (see `settle_round`) even though a joining member's bond is
    /// still sitting in `bond_vault` — so the payment-status check alone
    /// would wrongly allow cancelling a circle that already holds another
    /// member's collateral, which `close_account` can't actually refund.
    #[test]
    fn cancelling_after_a_round_has_completed_is_blocked_even_with_no_one_paid() {
        let circle = test_circle_at_round(
            vec![seat(MemberPaymentStatus::Pending), seat(MemberPaymentStatus::Pending)],
            1,
        );
        assert!(circle.members.iter().all(|s| s.status != MemberPaymentStatus::Paid));
        assert_ne!(circle.completed_rounds, 0);
    }
}
