pub mod constants;
pub mod error;
pub mod instructions;
pub mod state;

use anchor_lang::prelude::*;

pub use constants::*;
pub use instructions::*;
pub use state::*;

declare_id!("3wu1WDSheyZL2Ti6XXEMi59KqqSYBdSvTKMTFQhsJQ8o");

#[program]
pub mod ajose {
    use super::*;

    pub fn create_circle(
        ctx: Context<CreateCircle>,
        name: String,
        contribution_amount: u64,
        frequency: ContributionFrequency,
        seat_reservations: Vec<Option<Pubkey>>,
        first_round_deadline: i64,
        collateral_amount: u64,
    ) -> Result<()> {
        create_circle::handler(
            ctx,
            name,
            contribution_amount,
            frequency,
            seat_reservations,
            first_round_deadline,
            collateral_amount,
        )
    }

    pub fn join_circle(ctx: Context<JoinCircle>, seat_index: u8) -> Result<()> {
        join_circle::handler(ctx, seat_index)
    }

    pub fn contribute(ctx: Context<Contribute>) -> Result<()> {
        contribute::handler(ctx)
    }

    pub fn cancel_circle(ctx: Context<CancelCircle>) -> Result<()> {
        cancel_circle::handler(ctx)
    }

    pub fn settle_round(ctx: Context<SettleRound>) -> Result<()> {
        settle_round::handler(ctx)
    }

    pub fn create_savings_target(
        ctx: Context<CreateSavingsTarget>,
        label: String,
        unlock_at: i64,
        target_amount: u64,
    ) -> Result<()> {
        create_savings_target::handler(ctx, label, unlock_at, target_amount)
    }

    pub fn deposit_savings(ctx: Context<DepositSavings>, amount: u64) -> Result<()> {
        deposit_savings::handler(ctx, amount)
    }

    pub fn withdraw_savings(ctx: Context<WithdrawSavings>) -> Result<()> {
        withdraw_savings::handler(ctx)
    }

    pub fn post_collateral(ctx: Context<PostCollateral>) -> Result<()> {
        post_collateral::handler(ctx)
    }

    pub fn claim_collateral(ctx: Context<ClaimCollateral>) -> Result<()> {
        claim_collateral::handler(ctx)
    }
}
