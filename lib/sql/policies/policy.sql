
-- Create policy table
CREATE TABLE policy (
    service_policy_id SERIAL PRIMARY KEY UNIQUE,
    policy_name VARCHAR NOT NULL UNIQUE,
    status BOOLEAN DEFAULT FALSE,  -- Fixed "false" spelling
    reval_cycle VARCHAR CHECK (reval_cycle IN ('daily', 'weekly', 'monthly', 'bi-monthly', 'quarterly', 'bi-yearly', 'yearly')),
    max_len INT DEFAULT 63,
    min_len INT DEFAULT 15,
    upper_char INT DEFAULT 1,
    lower_char INT DEFAULT 1,
    numeric_char INT DEFAULT 1,
    special_char INT DEFAULT 1,
    special_char_string VARCHAR DEFAULT 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~#^_=+',
    password_history_count INT DEFAULT 12,
    password_override BOOLEAN DEFAULT FALSE,
    token_expire INTERVAL DEFAULT '20 minutes',
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION insert_policy(
    p_policy_name VARCHAR,
    p_status BOOLEAN DEFAULT FALSE,
    p_reval_cycle VARCHAR DEFAULT 'monthly',
    p_max_len INT DEFAULT 15,
    p_min_len INT DEFAULT 7,
    p_upper_char INT DEFAULT 1,
    p_lower_char INT DEFAULT 1,
    p_numeric_char INT DEFAULT 1,
    p_special_char INT DEFAULT 1,
    p_special_char_string VARCHAR DEFAULT 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~#^_=+',
    p_password_history_count INT DEFAULT 12,
    p_password_override BOOLEAN DEFAULT FALSE,
    p_token_expire INTERVAL DEFAULT '20 minutes',
    p_change_trigger_update_history TIMESTAMP DEFAULT NOW()
) RETURNS VOID AS $$
BEGIN
    INSERT INTO policy (
        policy_name,
        status,
        reval_cycle,
        max_len,
        min_len,
        upper_char,
        lower_char,
        numeric_char,
        special_char,
        special_char_string,
        password_history_count,
        password_override,
        token_expire,
        change_trigger_update_history
    ) VALUES (
        p_policy_name,
        p_status,
        p_reval_cycle,
        p_max_len,
        p_min_len,
        p_upper_char,
        p_lower_char,
        p_numeric_char,
        p_special_char,
        p_special_char_string,
        p_password_history_count,
        p_password_override,
        p_token_expire,
        p_change_trigger_update_history
    );
END;
$$ LANGUAGE plpgsql;

-- Function to toggle policy status on or off based on policy ID
CREATE OR REPLACE FUNCTION set_policy_status(p_id INT, p_status BOOLEAN) RETURNS VOID AS $$
DECLARE
    active_count INT;
BEGIN
    -- Check how many policies are currently active
    SELECT COUNT(*) INTO active_count FROM policy WHERE status = TRUE;

    IF p_status THEN
        -- If activating a policy, deactivate all others
        UPDATE policy
        SET status = FALSE
        WHERE service_policy_id <> p_id;

        -- Activate the specified policy
        UPDATE policy
        SET status = TRUE
        WHERE service_policy_id = p_id;
    ELSE
        -- Deactivate the specified policy
        UPDATE policy
        SET status = FALSE
        WHERE service_policy_id = p_id;
    END IF;

    -- After updates, check if there are no active policies
    SELECT COUNT(*) INTO active_count FROM policy WHERE status = TRUE;

    -- If no policies are active, set policy ID 1 to active
    IF active_count = 0 THEN
        UPDATE policy
        SET status = TRUE
        WHERE service_policy_id = 1;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Function to update policy fields, only changing fields with new values provided
CREATE OR REPLACE FUNCTION update_policy(
    p_id INT,
    p_policy_name VARCHAR DEFAULT NULL,
    p_reval_cycle VARCHAR DEFAULT NULL,
    p_max_len INT DEFAULT NULL,
    p_min_len INT DEFAULT NULL,
    p_upper_char INT DEFAULT NULL,
    p_lower_char INT DEFAULT NULL,
    p_numeric_char INT DEFAULT NULL,
    p_special_char INT DEFAULT NULL,
    p_special_char_string VARCHAR DEFAULT NULL,
    p_password_history_count INT DEFAULT NULL,
    p_password_override BOOLEAN DEFAULT NULL,
    p_token_expire INTERVAL DEFAULT NULL,
    p_status BOOLEAN DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE policy
    SET
        policy_name = COALESCE(p_policy_name, policy_name),
        reval_cycle = COALESCE(p_reval_cycle, reval_cycle),
        max_len = COALESCE(p_max_len, max_len),
        min_len = COALESCE(p_min_len, min_len),
        upper_char = COALESCE(p_upper_char, upper_char),
        lower_char = COALESCE(p_lower_char, lower_char),
        numeric_char = COALESCE(p_numeric_char, numeric_char),
        special_char = COALESCE(p_special_char, special_char),
        special_char_string = COALESCE(p_special_char_string, special_char_string),
        password_history_count = COALESCE(p_password_history_count, password_history_count),
        password_override = COALESCE(p_password_override, password_override),
        token_expire = COALESCE(p_token_expire, token_expire),
        status = COALESCE(p_status, status)
    WHERE service_policy_id = p_id;
END;
$$ LANGUAGE plpgsql;

SELECT insert_policy( p_policy_name := 'Default', p_reval_cycle := 'quarterly',p_max_len := 15);
SELECT set_policy_status(1, True);
