use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, Mint, Token, TokenAccount, Transfer},
};

use crate::error::ErrorCode as AjoseError;
use crate::SavingsTarget;

#[event]
pub struct SavingsDeposited {
    pub savings_target: Pubkey,
    pub owner: Pubkey,
    pub amount: u64,
    pub deposited_at: i64,
}

/// Deposits USDC into a savings target's vault. Allowed anytime — unlike a
/// withdrawal, a deposit never needs to wait on `unlock_at`.
#[derive(Accounts)]
pub struct DepositSavings<'info> {
    #[account(has_one = owner)]
    pub savings_target: Account<'info, SavingsTarget>,
    #[account(mut)]
    pub owner: Signer<'info>,
    #[account(
        mut,
        associated_token::mint = usdc_mint,
        associated_token::authority = owner,
    )]
    pub owner_token_account: Account<'info, TokenAccount>,
    #[account(
        init_if_needed,
        payer = owner,
        associated_token::mint = usdc_mint,
        associated_token::authority = vault_authority,
    )]
    pub savings_vault: Account<'info, TokenAccount>,
    /// CHECK: This PDA has no data and exists solely as the vault's signing
    /// authority. Its address and bump are constrained below.
    #[account(
        seeds = [b"savings_vault", savings_target.key().as_ref()],
        bump = savings_target.vault_bump,
    )]
    pub vault_authority: UncheckedAccount<'info>,
    #[account(address = savings_target.usdc_mint)]
    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<DepositSavings>, amount: u64) -> Result<()> {
    require!(amount > 0, AjoseError::InvalidDepositAmount);

    token::transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.owner_token_account.to_account_info(),
                to: ctx.accounts.savings_vault.to_account_info(),
                authority: ctx.accounts.owner.to_account_info(),
            },
        ),
        amount,
    )?;

    emit!(SavingsDeposited {
        savings_target: ctx.accounts.savings_target.key(),
        owner: ctx.accounts.owner.key(),
        amount,
        deposited_at: Clock::get()?.unix_timestamp,
    });

    Ok(())
}
