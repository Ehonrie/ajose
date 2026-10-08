use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, Mint, Token, TokenAccount, Transfer},
};

use crate::error::ErrorCode as AjoseError;
use crate::Circle;

#[event]
pub struct CollateralPosted {
    pub circle: Pubkey,
    pub wallet: Pubkey,
    pub amount: u64,
    pub posted_at: i64,
}

/// Posts a seat's collateral bond into the circle's shared `BondPool`
/// vault — a separate pool from the regular contribution vault, so a
/// forfeiture never dips into other members' saved payouts. Called by any
/// already-seated wallet (the creator bundles this right after
/// `create_circle`; a joining member bundles it right after `join_circle`)
/// — one instruction, two callers, since the posting logic is identical
/// either way.
#[derive(Accounts)]
pub struct PostCollateral<'info> {
    #[account(mut)]
    pub circle: Account<'info, Circle>,
    #[account(mut)]
    pub member: Signer<'info>,
    #[account(
        mut,
        associated_token::mint = usdc_mint,
        associated_token::authority = member,
    )]
    pub member_token_account: Account<'info, TokenAccount>,
    #[account(
        init_if_needed,
        payer = member,
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
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<PostCollateral>) -> Result<()> {
    let circle = &ctx.accounts.circle;
    require!(circle.collateral_amount > 0, AjoseError::CollateralNotRequired);

    let wallet = ctx.accounts.member.key();
    let seat_index = circle
        .members
        .iter()
        .position(|seat| seat.wallet == Some(wallet))
        .ok_or(error!(AjoseError::NotAMember))?;
    require!(
        circle.members[seat_index].bond_posted == 0,
        AjoseError::CollateralAlreadyPosted
    );

    let amount = circle.collateral_amount;

    token::transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.member_token_account.to_account_info(),
                to: ctx.accounts.bond_vault.to_account_info(),
                authority: ctx.accounts.member.to_account_info(),
            },
        ),
        amount,
    )?;

    let posted_at = Clock::get()?.unix_timestamp;
    let seat = &mut ctx.accounts.circle.members[seat_index];
    seat.bond_posted = amount;
    seat.bond_remaining = amount;

    emit!(CollateralPosted {
        circle: ctx.accounts.circle.key(),
        wallet,
        amount,
        posted_at,
    });

    Ok(())
}
