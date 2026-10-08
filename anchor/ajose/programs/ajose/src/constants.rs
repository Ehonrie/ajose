pub const MAX_CIRCLE_NAME_LENGTH: usize = 64;
// 1 rather than 2: a solo circle is degenerate as a *rotation* (the only
// member immediately becomes their own recipient every round), but it's
// useful for exercising create→contribute→payout mechanics without a
// second wallet on hand.
pub const MIN_SEATS: usize = 1;
pub const MAX_SEATS: usize = 50;

pub const MAX_SAVINGS_LABEL_LENGTH: usize = 40;
