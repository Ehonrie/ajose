use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("Circle names must be between 1 and 64 bytes")]
    InvalidCircleName,
    #[msg("A circle must have between 2 and 50 seats")]
    InvalidSeatCount,
    #[msg("Contribution amount must be greater than zero")]
    InvalidContributionAmount,
    #[msg("The first round deadline must be in the future")]
    InvalidRoundDeadline,
    #[msg("A wallet may only reserve one seat in a circle")]
    DuplicateMember,
    #[msg("The requested seat index does not exist in this circle")]
    SeatIndexOutOfBounds,
    #[msg("The requested seat has already been claimed")]
    SeatAlreadyClaimed,
    #[msg("All seats in this circle have already been claimed")]
    CircleFull,
    #[msg("This wallet already occupies a seat in the circle")]
    WalletAlreadyMember,
    #[msg("Only a circle member can contribute")]
    NotAMember,
    #[msg("This member has already contributed for the current round")]
    AlreadyPaid,
}
