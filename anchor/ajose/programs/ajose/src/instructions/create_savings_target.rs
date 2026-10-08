use anchor_lang::prelude::*;
use anchor_spl::token::Mint;

use crate::error::ErrorCode as AjoseError;
use crate::{SavingsTarget, MAX_SAVINGS_LABEL_LENGTH};

#[event]
pub struct SavingsTargetCreated {
    pub savings_target: Pubkey,
    pub owner: Pubkey,
    pub label: String,
    pub unlock_at: i64,
    pub target_amount: u64,
}

#[derive(Accounts)]
#[instruction(label: String)]
pub struct CreateSavingsTarget<'info> {
    #[account(
        init,
        payer = owner,
        space = SavingsTarget::space(label.as_bytes().len()),
    )]
    pub savings_target: Account<'info, SavingsTarget>,
    #[account(mut)]
    pub owner: Signer<'info>,
    /// The token mint this savings target holds — the client policy selects
    /// the cluster's USDC mint, same as a circle's own `usdc_mint`.
    pub usdc_mint: Account<'info, Mint>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<CreateSavingsTarget>,
    label: String,
    unlock_at: i64,
    target_amount: u64,
) -> Result<()> {
    require!(
        !label.is_empty() && label.as_bytes().len() <= MAX_SAVINGS_LABEL_LENGTH,
        AjoseError::InvalidSavingsLabel
    );
    let now = Clock::get()?.unix_timestamp;
    require!(unlock_at > now, AjoseError::InvalidUnlockTime);

    let savings_target = &mut ctx.accounts.savings_target;
    savings_target.owner = ctx.accounts.owner.key();
    savings_target.label = label.clone();
    savings_target.usdc_mint = ctx.accounts.usdc_mint.key();
    savings_target.target_amount = target_amount;
    savings_target.unlock_at = unlock_at;
    savings_target.vault_bump = Pubkey::find_program_address(
        &[b"savings_vault", savings_target.key().as_ref()],
        ctx.program_id,
    )
    .1;
    savings_target.created_at = now;

    emit!(SavingsTargetCreated {
        savings_target: savings_target.key(),
        owner: savings_target.owner,
        label,
        unlock_at,
        target_amount,
    });

    Ok(())
}
