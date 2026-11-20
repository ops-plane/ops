-- used_login_codes: the SHA-256 of each redeemed `terraform login` authorization code, kept until the code
-- expires, so a code is exchanged once. Expired rows go with expired sessions (PruneSessions).
CREATE TABLE used_login_codes (
    code_hash  bytea PRIMARY KEY,
    expires_at timestamptz NOT NULL
);
