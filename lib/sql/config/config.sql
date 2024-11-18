-- config.sql
-- Connect to the database
\c vaultdb;
-- Create config table
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    service_policy_id SERIAL,  -- Auto-incrementing column without a default value
    vault_id SERIAL,            -- Auto-incrementing column without a default value
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);
-- setup global encryption key
INSERT INTO config (key, value) VALUES ('global_encryption_key', 'dmz1nEn6Xw9vHDUOJmXp1bpn5V7eoPGIfCdQ_S4PfL4=');
