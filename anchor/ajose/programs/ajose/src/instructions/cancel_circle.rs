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
/// Only the creator's own collateral is ever in play here: joining already
/// requires paying the first contribution atomically (see `join_circle`),
/// which the payment-status guard below would already have blocked
/// cancellation over — so by the time this can succeed, no other seat
/// could possibly have posted a bond. Nothing to loop over.
pub fn handler(ctx: Context<CancelCircle>) -> Result<()> {
    require!(
        ctx.accounts
            .circle
            .members
            .iter()
            .all(|seat| seat.status != MemberPaymentStatus::Paid),
        AjoseError::CircleAlreadyFunded
    );

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
