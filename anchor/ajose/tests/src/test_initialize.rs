#[test]
fn program_id_is_stable() {
    assert_eq!(
        ajose::id().to_string(),
        "GZVETsxCKj5HqHcxjYBEDK8FdTYYbbWH88UN3nBu5iMJ"
    );
}
