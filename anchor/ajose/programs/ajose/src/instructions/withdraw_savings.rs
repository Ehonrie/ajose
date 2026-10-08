use anchor_lang::prelude::*;
use anchor_spl::token::{self, CloseAccount, Mint, Token, TokenAccount, Transfer};

use crate::error::ErrorCode as AjoseError;
use crate::SavingsTarget;

#[event]
pub struct SavingsWithdrawn {
    pub savings_target: Pubkey,
    pub owner: Pubkey,
    pub amount: u64,
    pub withdrawn_at: i64,
}

/// Withdraws a savings target's full balance and closes it out — both the
/// vault token account and the `SavingsTarget` account itself, refunding
/// their rent to `owner` along with the savings. Only valid once
/// `unlock_at` has passed; there's no partial or early withdrawal.
#[derive(Accounts)]
pub struct WithdrawSavings<'info> {
    #[account(mut, has_one = owner, close = owner)]
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
        mut,
        associated_token::mint = usdc_mint,
        associated_token::authority = vault_authority,
    )]
    pub savings_vault: Account<'info, TokenAccount>,
    /// CHECK: This PDA has no data and exists solely as the vault's signing
    /// authority. Its address and bump are constrained below.
    #[account(
        mut,
        seeds = [b"savings_vault", savings_target.key().as_ref()],
        bump = savings_target.vault_bump,
    )]
    pub vault_authority: UncheckedAccount<'info>,
    #[account(address = savings_target.usdc_mint)]
    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<WithdrawSavings>) -> Result<()> {
    let now = Clock::get()?.unix_timestamp;
    require!(
        now >= ctx.accounts.savings_target.unlock_at,
        AjoseError::SavingsLocked
    );

    let amount = ctx.accounts.savings_vault.amount;
    let savings_target_key = ctx.accounts.savings_target.key();
    let vault_bump = ctx.accounts.savings_target.vault_bump;
    let vault_seeds: &[&[u8]] = &[b"savings_vault", savings_target_key.as_ref(), &[vault_bump]];

    if amount > 0 {
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.savings_vault.to_account_info(),
                    to: ctx.accounts.owner_token_account.to_account_info(),
                    authority: ctx.accounts.vault_authority.to_account_info(),
                },
                &[vault_seeds],
            ),
            amount,
        )?;
    }

    token::close_account(CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        CloseAccount {
            account: ctx.accounts.savings_vault.to_account_info(),
            destination: ctx.accounts.owner.to_account_info(),
            authority: ctx.accounts.vault_authority.to_account_info(),
        },
        &[vault_seeds],
    ))?;

    emit!(SavingsWithdrawn {
        savings_target: savings_target_key,
        owner: ctx.accounts.owner.key(),
        amount,
        withdrawn_at: now,
    });

    Ok(())
}
