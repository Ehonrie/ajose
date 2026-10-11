use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("Circle names must be between 1 and 64 bytes")]
    InvalidCircleName,
    #[msg("A circle must have between 1 and 50 seats")]
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
    #[msg("Only the circle's creator can cancel it")]
    NotCircleAuthority,
    #[msg("A circle can only be cancelled before any member has contributed")]
    CircleAlreadyFunded,
    #[msg("This circle has completed its full rotation and no longer accepts contributions")]
    CircleCompleted,
    #[msg("The recipient account does not match this round's designated payout seat")]
    RecipientMismatch,
    #[msg("This round's contribution window has closed; it needs settling before the next one opens")]
    RoundClosed,
    #[msg("This round's deadline hasn't passed yet")]
    RoundNotYetDue,
    #[msg("Savings labels must be between 1 and 40 bytes")]
    InvalidSavingsLabel,
    #[msg("The unlock date must be in the future")]
    InvalidUnlockTime,
    #[msg("Deposit amount must be greater than zero")]
    InvalidDepositAmount,
    #[msg("This savings target hasn't reached its unlock date yet")]
    SavingsLocked,
    #[msg("This circle doesn't require collateral")]
    CollateralNotRequired,
    #[msg("This seat has already posted its collateral")]
    CollateralAlreadyPosted,
    #[msg("This circle hasn't completed its full rotation yet")]
    CircleNotComplete,
    #[msg("This seat's collateral has already been claimed")]
    CollateralAlreadyClaimed,
    #[msg("A circle can only be cancelled before any round has completed")]
    CircleAlreadyRotated,
}
