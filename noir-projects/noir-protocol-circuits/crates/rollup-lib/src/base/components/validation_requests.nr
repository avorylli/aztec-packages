use types::abis::validation_requests::RollupValidationRequests;

pub fn validate_max_block_number(
    validation_requests: RollupValidationRequests,
    current_block_number: u32,
) {
    if validation_requests.max_block_number.is_some() {
        assert(
            current_block_number <= validation_requests.max_block_number.unwrap_unchecked(),
            "kernel max_block_number is smaller than block number",
        );
    }
}
