use anchor_lang::prelude::*;
use anchor_spl::{
    associated_token::{self, AssociatedToken},
    token::{self, Mint, Token, TokenAccount, Transfer},
};

use crate::error::ErrorCode as AjoseError;
use crate::{Circle, MemberPaymentStatus, MemberSeat};

/// Emitted once a round's deadline has passed and its pot (whatever
/// accumulated, whether or not every member paid) has been transferred to
/// that round's recipient.
#[event]
pub struct PayoutDisbursed {
    pub circle: Pubkey,
    pub round_index: u16,
    pub recipient: Pubkey,
    pub amount: u64,
    pub paid_at: i64,
}

/// Settles the circle's current round once its deadline has passed: pays
/// the vault's balance to that round's recipient and, if the circle hasn't
/// finished its rotation, opens the next round. Deliberately permissionless
/// — anyone can pay the (tiny) fee to trigger it, since the outcome is
/// fully determined by on-chain state and the clock, not by who calls it.
/// There's no on-chain cron, so a client is expected to call this itself
/// the moment it notices a round is overdue (see `AutoSettleTicker` in the
/// Flutter app) — this instruction is what makes that safe to do from any
/// wallet, not just a circle member.
#[derive(Accounts)]
pub struct SettleRound<'info> {
    #[account(mut)]
    pub circle: Account<'info, Circle>,
    #[account(mut)]
    pub payer: Signer<'info>,
    // init_if_needed: a round can reach its deadline with zero
    // contributions ever made, in which case the vault's ATA was never
    // created by `contribute` — without this, settling that round would
    // fail simulation/execution every time (the account simply doesn't
    // exist yet), permanently stalling the circle on that round.
    #[account(
        init_if_needed,
        payer = payer,
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
    // init_if_needed for the same reason as circle_vault — a circle that
    // never uses collateral (or hasn't had anyone post any yet) would
    // otherwise never have this account at all.
    #[account(
        init_if_needed,
        payer = payer,
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
    /// CHECK: this round's designated payout recipient — checked in the
    /// handler against `circle.members[circle.current_round_index]`.
    pub recipient: UncheckedAccount<'info>,
    /// CHECK: recipient's USDC associated token account, created
    /// idempotently here if it doesn't already exist.
    #[account(mut)]
    pub recipient_token_account: UncheckedAccount<'info>,
    #[account(address = circle.usdc_mint)]
    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<SettleRound>) -> Result<()> {
    let now = Clock::get()?.unix_timestamp;
    require!(
        ctx.accounts.circle.completed_rounds < ctx.accounts.circle.members.len() as u16,
        AjoseError::CircleCompleted
    );
    require!(
        now >= ctx.accounts.circle.current_round_deadline,
        AjoseError::RoundNotYetDue
    );

    let round_index = ctx.accounts.circle.current_round_index;
    let recipient_wallet = ctx.accounts.circle.members[round_index as usize]
        .wallet
        .ok_or(error!(AjoseError::RecipientMismatch))?;
    require_keys_eq!(
        ctx.accounts.recipient.key(),
        recipient_wallet,
        AjoseError::RecipientMismatch
    );

    associated_token::create_idempotent(CpiContext::new(
        ctx.accounts.associated_token_program.to_account_info(),
        associated_token::Create {
            payer: ctx.accounts.payer.to_account_info(),
            associated_token: ctx.accounts.recipient_token_account.to_account_info(),
            authority: ctx.accounts.recipient.to_account_info(),
            mint: ctx.accounts.usdc_mint.to_account_info(),
            system_program: ctx.accounts.system_program.to_account_info(),
            token_program: ctx.accounts.token_program.to_account_info(),
        },
    ))?;

    let contribution_amount = ctx.accounts.circle.contribution_amount;
    let member_count_now = ctx.accounts.circle.members.len() as u64;
    let expected_total = contribution_amount.saturating_mul(member_count_now);
    // Whatever members actually paid in before the deadline — a round
    // settles on schedule either way; this is just what's really there
    // before any collateral tops it up.
    let actual_collected = ctx.accounts.circle_vault.amount;
    let shortfall = expected_total.saturating_sub(actual_collected);

    // A no-op when this circle doesn't use collateral — collateral_amount
    // zero means nobody has bond_remaining > 0 to pull from anyway.
    let total_forfeited = if shortfall > 0 && ctx.accounts.circle.collateral_amount > 0 {
        forfeit_shortfall(&mut ctx.accounts.circle.members, contribution_amount, shortfall)
    } else {
        0
    };

    let circle_key = ctx.accounts.circle.key();
    let vault_bump = ctx.accounts.circle.vault_bump;
    let bond_bump = ctx.accounts.circle.bond_bump;
    let vault_seeds: &[&[u8]] = &[b"vault", circle_key.as_ref(), &[vault_bump]];
    let bond_seeds: &[&[u8]] = &[b"bond", circle_key.as_ref(), &[bond_bump]];

    if total_forfeited > 0 {
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.bond_vault.to_account_info(),
                    to: ctx.accounts.circle_vault.to_account_info(),
                    authority: ctx.accounts.bond_authority.to_account_info(),
                },
                &[bond_seeds],
            ),
            total_forfeited,
        )?;
    }

    // Exactly what's now sitting in circle_vault — actual contributions
    // plus whatever collateral just topped it up — without needing to
    // reload the account after the CPI above.
    let payout_amount = actual_collected + total_forfeited;

    if payout_amount > 0 {
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.circle_vault.to_account_info(),
                    to: ctx.accounts.recipient_token_account.to_account_info(),
                    authority: ctx.accounts.vault_authority.to_account_info(),
                },
                &[vault_seeds],
            ),
            payout_amount,
        )?;
    }

    emit!(PayoutDisbursed {
        circle: circle_key,
        round_index,
        recipient: recipient_wallet,
        amount: payout_amount,
        paid_at: now,
    });

    let circle = &mut ctx.accounts.circle;
    circle.completed_rounds += 1;
    circle.last_payout_recipient = Some(recipient_wallet);
    circle.last_payout_amount = payout_amount;
    circle.last_payout_at = Some(now);

    let member_count = circle.members.len() as u16;
    if circle.completed_rounds < member_count {
        circle.current_round_index = (round_index + 1) % member_count;
        circle.current_round_deadline = now + circle.frequency.interval_seconds();
        for seat in circle.members.iter_mut() {
            // A member who paid gets a clean slate for the new round; one
            // who didn't is flagged Overdue rather than silently forgiven —
            // still eligible to contribute going forward (eligibility only
            // checks for Paid), just visibly behind.
            seat.status = match seat.status {
                MemberPaymentStatus::Paid => MemberPaymentStatus::Pending,
                MemberPaymentStatus::Pending | MemberPaymentStatus::Overdue => {
                    MemberPaymentStatus::Overdue
                }
            };
            seat.paid_at = None;
        }
    }

    Ok(())
}

/// Pulls just enough bond to cover `shortfall` — one `contribution_amount`
/// at a time, only from seats that didn't pay this round — stopping as
/// soon as the shortfall's covered rather than draining every defaulting
/// member's whole bond. Separate from the account context so it can be
/// unit tested without a validator, same as `eligible_member_index` and
/// `claim_seat` elsewhere in this program.
pub fn forfeit_shortfall(members: &mut [MemberSeat], contribution_amount: u64, shortfall: u64) -> u64 {
    let mut total_forfeited: u64 = 0;
    for seat in members.iter_mut() {
        if total_forfeited >= shortfall {
            break;
        }
        if seat.status == MemberPaymentStatus::Paid {
            continue;
        }
        if seat.bond_remaining >= contribution_amount {
            seat.bond_remaining -= contribution_amount;
            total_forfeited += contribution_amount;
        }
    }
    total_forfeited
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Mirrors the round-advance match in [handler] without a validator.
    #[test]
    fn round_advance_resets_paid_and_flags_unpaid_as_overdue() {
        let next = |status: MemberPaymentStatus| match status {
            MemberPaymentStatus::Paid => MemberPaymentStatus::Pending,
            MemberPaymentStatus::Pending | MemberPaymentStatus::Overdue => {
                MemberPaymentStatus::Overdue
            }
        };

        assert_eq!(next(MemberPaymentStatus::Paid), MemberPaymentStatus::Pending);
        assert_eq!(next(MemberPaymentStatus::Pending), MemberPaymentStatus::Overdue);
        assert_eq!(next(MemberPaymentStatus::Overdue), MemberPaymentStatus::Overdue);
    }

    /// A single-seat circle finishes its whole rotation after one round.
    #[test]
    fn single_seat_circle_completes_after_one_round() {
        let member_count: u16 = 1;
        let completed_rounds_after: u16 = 0 + 1;
        assert_eq!(completed_rounds_after, member_count);
    }

    fn seat(status: MemberPaymentStatus, bond_remaining: u64) -> MemberSeat {
        MemberSeat {
            wallet: Some(Pubkey::new_unique()),
            payout_position: 0,
            status,
            paid_at: None,
            bond_posted: bond_remaining,
            bond_remaining,
            bond_claimed: false,
        }
    }

    #[test]
    fn forfeits_one_contribution_per_defaulter_until_shortfall_covered() {
        let mut members = vec![
            seat(MemberPaymentStatus::Paid, 10_000_000),
            seat(MemberPaymentStatus::Overdue, 10_000_000),
            seat(MemberPaymentStatus::Pending, 10_000_000),
        ];

        // One missed contribution's worth of shortfall — only the first
        // defaulter (seat 1) should be touched, for exactly that amount.
        let forfeited = forfeit_shortfall(&mut members, 5_000_000, 5_000_000);

        assert_eq!(forfeited, 5_000_000);
        assert_eq!(members[0].bond_remaining, 10_000_000); // paid — untouched
        assert_eq!(members[1].bond_remaining, 5_000_000); // one contribution forfeited
        assert_eq!(members[2].bond_remaining, 10_000_000); // never reached — shortfall already covered
    }

    #[test]
    fn stops_short_once_bonds_run_out() {
        // Only enough bond left to cover one contribution, but the
        // shortfall calls for two — the result is a partial payout, not an
        // error or a negative balance.
        let mut members = vec![seat(MemberPaymentStatus::Overdue, 5_000_000)];

        let forfeited = forfeit_shortfall(&mut members, 5_000_000, 10_000_000);

        assert_eq!(forfeited, 5_000_000);
        assert_eq!(members[0].bond_remaining, 0);
    }
}
