use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

use crate::error::ErrorCode as AjoseError;
use crate::Circle;

#[event]
pub struct CollateralClaimed {
    pub circle: Pubkey,
    pub wallet: Pubkey,
    pub amount: u64,
    pub claimed_at: i64,
}

/// Returns a seat's remaining collateral once the circle has finished its
/// full rotation. Every seat's payout turn is guaranteed to have come up
/// exactly once by the time `completed_rounds` reaches `members.len()` —
/// the round-robin schedule settles every position on the way there — so
/// "you've received your own payout" and "the circle is done" collapse
/// into this one check rather than needing separate tracking.
#[derive(Accounts)]
pub struct ClaimCollateral<'info> {
    #[account(mut)]
    pub circle: Account<'info, Circle>,
    pub member: Signer<'info>,
    #[account(
        mut,
        associated_token::mint = usdc_mint,
        associated_token::authority = member,
    )]
    pub member_token_account: Account<'info, TokenAccount>,
    #[account(
        mut,
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
}

pub fn handler(ctx: Context<ClaimCollateral>) -> Result<()> {
    let circle = &ctx.accounts.circle;
    require!(
        circle.completed_rounds >= circle.members.len() as u16,
        AjoseError::CircleNotComplete
    );

    let wallet = ctx.accounts.member.key();
    let seat_index = circle
        .members
        .iter()
        .position(|seat| seat.wallet == Some(wallet))
        .ok_or(error!(AjoseError::NotAMember))?;
    require!(
        !circle.members[seat_index].bond_claimed,
        AjoseError::CollateralAlreadyClaimed
    );

    let amount = circle.members[seat_index].bond_remaining;

    if amount > 0 {
        let circle_key = ctx.accounts.circle.key();
        let bond_bump = ctx.accounts.circle.bond_bump;
        let bond_seeds: &[&[u8]] = &[b"bond", circle_key.as_ref(), &[bond_bump]];

        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.bond_vault.to_account_info(),
                    to: ctx.accounts.member_token_account.to_account_info(),
                    authority: ctx.accounts.bond_authority.to_account_info(),
                },
                &[bond_seeds],
            ),
            amount,
        )?;
    }

    let claimed_at = Clock::get()?.unix_timestamp;
    let seat = &mut ctx.accounts.circle.members[seat_index];
    seat.bond_claimed = true;

    emit!(CollateralClaimed {
        circle: ctx.accounts.circle.key(),
        wallet,
        amount,
        claimed_at,
    });

    Ok(())
}
