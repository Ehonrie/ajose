pub mod constants;
pub mod error;
pub mod instructions;
pub mod state;

use anchor_lang::prelude::*;

pub use constants::*;
pub use instructions::*;
pub use state::*;

declare_id!("GZVETsxCKj5HqHcxjYBEDK8FdTYYbbWH88UN3nBu5iMJ");

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
    ) -> Result<()> {
        create_circle::handler(
            ctx,
            name,
            contribution_amount,
            frequency,
            seat_reservations,
            first_round_deadline,
        )
    }

    pub fn join_circle(ctx: Context<JoinCircle>, seat_index: u8) -> Result<()> {
        join_circle::handler(ctx, seat_index)
    }

    pub fn contribute(ctx: Context<Contribute>) -> Result<()> {
        contribute::handler(ctx)
    }
}
