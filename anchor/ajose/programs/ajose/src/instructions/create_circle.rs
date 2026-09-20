use std::collections::BTreeSet;

use anchor_lang::prelude::*;
use anchor_spl::token::Mint;

use crate::error::ErrorCode as AjoseError;
use crate::{
    Circle, ContributionFrequency, MemberPaymentStatus, MemberSeat, MAX_CIRCLE_NAME_LENGTH,
    MAX_SEATS, MIN_SEATS,
};

#[derive(Accounts)]
#[instruction(name: String, _contribution_amount: u64, _frequency: ContributionFrequency, seat_reservations: Vec<Option<Pubkey>>)]
pub struct CreateCircle<'info> {
    #[account(
        init,
        payer = authority,
        space = Circle::space(name.as_bytes().len(), seat_reservations.len()),
    )]
    pub circle: Account<'info, Circle>,
    #[account(mut)]
    pub authority: Signer<'info>,
    /// The token mint used by this Circle for all contributions, bonds, and
    /// payouts. The client policy selects the cluster's USDC mint.
    pub usdc_mint: Account<'info, Mint>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<CreateCircle>,
    name: String,
    contribution_amount: u64,
    frequency: ContributionFrequency,
    seat_reservations: Vec<Option<Pubkey>>,
    first_round_deadline: i64,
) -> Result<()> {
    require!(
        !name.is_empty() && name.as_bytes().len() <= MAX_CIRCLE_NAME_LENGTH,
        AjoseError::InvalidCircleName
    );
    require!(
        (MIN_SEATS..=MAX_SEATS).contains(&seat_reservations.len()),
        AjoseError::InvalidSeatCount
    );
    require!(
        contribution_amount > 0,
        AjoseError::InvalidContributionAmount
    );

    let now = Clock::get()?.unix_timestamp;
    require!(first_round_deadline > now, AjoseError::InvalidRoundDeadline);

    let mut reserved_wallets = BTreeSet::new();
    for wallet in seat_reservations.iter().flatten() {
        require!(
            reserved_wallets.insert(*wallet),
            AjoseError::DuplicateMember
        );
    }

    let circle = &mut ctx.accounts.circle;
    circle.authority = ctx.accounts.authority.key();
    circle.name = name;
    circle.usdc_mint = ctx.accounts.usdc_mint.key();
    circle.contribution_amount = contribution_amount;
    circle.frequency = frequency;
    circle.members = seat_reservations
        .into_iter()
        .enumerate()
        .map(|(index, wallet)| MemberSeat {
            wallet,
            payout_position: index as u16,
            status: MemberPaymentStatus::Pending,
            paid_at: None,
        })
        .collect();
    circle.current_round_index = 0;
    circle.current_round_deadline = first_round_deadline;
    circle.vault_bump =
        Pubkey::find_program_address(&[b"vault", circle.key().as_ref()], ctx.program_id).1;
    circle.created_at = now;

    Ok(())
}
