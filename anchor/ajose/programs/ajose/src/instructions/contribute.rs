use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::AssociatedToken,
    token::{self, Mint, Token, TokenAccount, Transfer},
};

use crate::error::ErrorCode as AjoseError;
use crate::{Circle, MemberPaymentStatus, MemberSeat};

#[event]
pub struct ContributionMade {
    pub circle: Pubkey,
    pub seat_index: u8,
    pub wallet: Pubkey,
    pub amount: u64,
    pub paid_at: i64,
}

#[derive(Accounts)]
pub struct Contribute<'info> {
    #[account(mut)]
    pub circle: Account<'info, Circle>,
    #[account(mut)]
    pub contributor: Signer<'info>,
    #[account(
        mut,
        associated_token::mint = usdc_mint,
        associated_token::authority = contributor,
    )]
    pub contributor_token_account: Account<'info, TokenAccount>,
    #[account(
        init_if_needed,
        payer = contributor,
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

pub fn handler(ctx: Context<Contribute>) -> Result<()> {
    let wallet = ctx.accounts.contributor.key();
    let seat_index = eligible_member_index(&ctx.accounts.circle.members, wallet)?;
    let amount = ctx.accounts.circle.contribution_amount;

    token::transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.contributor_token_account.to_account_info(),
                to: ctx.accounts.circle_vault.to_account_info(),
                authority: ctx.accounts.contributor.to_account_info(),
            },
        ),
        amount,
    )?;

    let paid_at = Clock::get()?.unix_timestamp;
    let seat = &mut ctx.accounts.circle.members[seat_index];
    seat.status = MemberPaymentStatus::Paid;
    seat.paid_at = Some(paid_at);

    emit!(ContributionMade {
        circle: ctx.accounts.circle.key(),
        seat_index: seat_index as u8,
        wallet,
        amount,
        paid_at,
    });

    Ok(())
}

/// Returns the contributing member's fixed seat index, while enforcing that
/// the current round has not already been paid by that wallet.
pub fn eligible_member_index(members: &[MemberSeat], wallet: Pubkey) -> Result<usize> {
    let index = members
        .iter()
        .position(|seat| seat.wallet == Some(wallet))
        .ok_or(error!(AjoseError::NotAMember))?;
    require!(
        members[index].status != MemberPaymentStatus::Paid,
        AjoseError::AlreadyPaid
    );
    Ok(index)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn member(wallet: Option<Pubkey>, status: MemberPaymentStatus) -> MemberSeat {
        MemberSeat {
            wallet,
            payout_position: 0,
            status,
            paid_at: None,
        }
    }

    #[test]
    fn member_is_eligible_once_then_marked_paid() {
        let wallet = Pubkey::new_unique();
        let mut members = vec![member(Some(wallet), MemberPaymentStatus::Pending)];
        let index = eligible_member_index(&members, wallet).unwrap();

        members[index].status = MemberPaymentStatus::Paid;
        members[index].paid_at = Some(123);

        assert_eq!(members[index].status, MemberPaymentStatus::Paid);
        assert_eq!(members[index].paid_at, Some(123));
        assert!(eligible_member_index(&members, wallet).is_err());
    }

    #[test]
    fn non_member_is_not_eligible() {
        let members = vec![member(
            Some(Pubkey::new_unique()),
            MemberPaymentStatus::Pending,
        )];

        let error = eligible_member_index(&members, Pubkey::new_unique()).unwrap_err();

        assert!(error.to_string().contains("Only a circle member"));
    }

    #[test]
    fn already_paid_member_is_not_eligible() {
        let wallet = Pubkey::new_unique();
        let members = vec![member(Some(wallet), MemberPaymentStatus::Paid)];

        let error = eligible_member_index(&members, wallet).unwrap_err();

        assert!(error.to_string().contains("already contributed"));
    }
}
