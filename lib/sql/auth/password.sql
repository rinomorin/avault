CREATE OR REPLACE FUNCTION update_password_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert the old password into the password history
    INSERT INTO password_history (userid, password, last_change)
    VALUES (NEW.uuid, NEW.password, NOW());

    RETURN NEW;  -- Return the new user record
END;
$$ LANGUAGE plpgsql;

-- Generate a password
CREATE OR REPLACE FUNCTION generate_password() RETURNS TEXT AS $$
BEGIN
    -- Logic to generate a secure password
    RETURN 'new_secure_password'; -- Placeholder for actual generation logic
END;
$$ LANGUAGE plpgsql;

-- Create password table
CREATE TABLE password_history (
    userid UUID REFERENCES users(uuid) ON DELETE CASCADE,
    password TEXT NOT NULL,  -- Store the hashed password
    last_change TIMESTAMP DEFAULT NOW(),
    fail_login_count INT DEFAULT 0,
    PRIMARY KEY (userid, last_change)  -- Composite primary key
);

CREATE OR REPLACE FUNCTION update_password_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert the old password into the password history
    INSERT INTO password_history (userid, password, last_change)
    VALUES (NEW.uuid, NEW.password, NOW());

    RETURN NEW;  -- Return the new user record
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION userpwd(
    requestor_id UUID,
    target_user_id UUID,
    new_password TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    policy_record RECORD;
    target_user_record RECORD;
    is_admin BOOLEAN;
    hashed_password TEXT;
BEGIN
    -- Fetch the active policy settings from the policy table
    SELECT *
    INTO policy_record
    FROM policy
    WHERE status = TRUE;  -- Assuming there's an "active" column that indicates the current policy

    -- Check if a policy was found
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active policy found.';
    END IF;

    -- Fetch target user record and check if the requestor is an admin or the owner of the user ID
    SELECT u.*, 
           EXISTS (SELECT 1 FROM acl WHERE acl_group = 'admin' AND acl_permission = 'allow' AND u.uuid = requestor_id) AS is_admin
    INTO target_user_record
    FROM users u
    WHERE u.uuid = target_user_id;

    -- Check if the requestor is an admin or the owner of the target user
    is_admin := target_user_record.is_admin;
    IF NOT is_admin AND target_user_record.uuid != requestor_id THEN
        RAISE EXCEPTION 'Permission denied: You must be an admin or the owner to reset this password.';
    END IF;


    -- Hash the new password using bcrypt
    hashed_password := crypt(new_password, gen_salt('bf'));

    -- Update the user's password to the new hashed password
    UPDATE users
    SET password = hashed_password
    WHERE uuid = target_user_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Enhanced Validate Password Function with Admin Override
CREATE OR REPLACE FUNCTION validate_password(user_id UUID, password TEXT) RETURNS BOOLEAN AS $$
DECLARE
    policy_record RECORD;
    user_record RECORD;
    upper_count INT;
    lower_count INT;
    numeric_count INT;
    special_count INT;
    is_admin BOOLEAN;
BEGIN
    -- Fetch policy settings from the policy table
    SELECT *
    INTO policy_record
    FROM policy
    WHERE status = TRUE; -- Assuming we're only dealing with the default policy

    -- Fetch user record and check if the user is part of the admin group
    SELECT u.*, 
           EXISTS (SELECT 1 FROM acl WHERE acl_group = 'admin' AND acl_permission = 'allow' AND userid = user_id) AS is_admin
    INTO user_record
    FROM users u
    WHERE uuid = user_id;

    is_admin := user_record.is_admin;

    -- Check length constraints
    IF LENGTH(password) < policy_record.min_len OR LENGTH(password) > policy_record.max_len THEN
        RAISE EXCEPTION 'Password must be between % and % characters long', policy_record.min_len, policy_record.max_len;
    END IF;

    -- Count character types
    SELECT COUNT(*)
    INTO upper_count
    FROM unnest(string_to_array(password, '')) AS char
    WHERE char ~ '[A-Z]'; -- Count uppercase letters

    SELECT COUNT(*)
    INTO lower_count
    FROM unnest(string_to_array(password, '')) AS char
    WHERE char ~ '[a-z]'; -- Count lowercase letters

    SELECT COUNT(*)
    INTO numeric_count
    FROM unnest(string_to_array(password, '')) AS char
    WHERE char ~ '[0-9]'; -- Count numeric characters

    SELECT COUNT(*)
    INTO special_count
    FROM unnest(string_to_array(password, '')) AS char
    WHERE char IN (SELECT unnest(string_to_array(policy_record.special_char_string, ''))); -- Count special characters

    -- Check character type constraints
    IF upper_count < policy_record.upper_char THEN
        RAISE EXCEPTION 'Password must contain at least % uppercase character(s)', policy_record.upper_char;
    END IF;

    IF lower_count < policy_record.lower_char THEN
        RAISE EXCEPTION 'Password must contain at least % lowercase character(s)', policy_record.lower_char;
    END IF;

    IF numeric_count < policy_record.numeric_char THEN
        RAISE EXCEPTION 'Password must contain at least % numeric character(s)', policy_record.numeric_char;
    END IF;

    IF special_count < policy_record.special_char THEN
        RAISE EXCEPTION 'Password must contain at least % special character(s)', policy_record.special_char;
    END IF;

    -- Check password history if applicable and if user is not an admin
    IF NOT policy_record.password_override AND NOT is_admin THEN
        -- Here, you would add logic to check against the password history table.
        -- For example:
        IF password IN (SELECT password FROM password WHERE userid = user_id LIMIT policy_record.password_history_count) THEN
            RAISE EXCEPTION 'Password must not be one of the last % passwords used', policy_record.password_history_count;
        END IF;
    END IF;

    -- If all checks pass, return true
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION expire_user_password(p_username VARCHAR) RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET expired = CURRENT_DATE
    WHERE username = p_username;
    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'Password for user % expired successfully', p_username;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authenticate_user(p_username VARCHAR, p_password VARCHAR) RETURNS TEXT AS $$
DECLARE
    v_password_hash VARCHAR;
    v_password_expiry_date DATE;
    v_status VARCHAR;
BEGIN
    -- Get the user details
    SELECT password, expired, status
    INTO v_password_hash, v_password_expiry_date, v_status
    FROM users
    WHERE username = p_username;

    -- Check if the user account status requires admin intervention (case-insensitive check)
    IF trim(lower(v_status)) = 'disable' OR trim(lower(v_status)) = 'lock' THEN
        RETURN 'Account requires admin assistance';
    END IF;

     -- Check if the user account status requires admin intervention (case-insensitive check)
    -- IF trim(lower(v_status)) = 'expired' THEN
    --     RETURN 'Account expired, please reset password.';
    -- END IF;

    -- Check if the user is new and needs to update their password
    IF v_status = 'new' THEN
        RETURN 'Password update required';
    END IF;

    -- Check if the password is expired
    IF v_password_expiry_date < CURRENT_DATE THEN
        RETURN 'Password expired';
    END IF;

    -- Check if the provided password matches the stored hash
    IF v_password_hash IS NOT NULL AND v_password_hash = crypt(p_password, v_password_hash) THEN
        RETURN 'Authentication successful';  -- Authentication is successful
    ELSE
        RETURN 'Authentication failed';  -- Password mismatch or authentication failure
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION token_duration() RETURNS INT AS $$
DECLARE
    token_value INTERVAL;   -- Declare the variable to hold the token expiration interval
    token_expire INT;       -- Declare an integer to hold the final token expiration duration in minutes
BEGIN
    -- Retrieve the token expiration interval from the policy table where status is TRUE
    SELECT policy.token_expire INTO token_value
    FROM policy
    WHERE status = TRUE
    LIMIT 1;  -- Assuming you want the token duration for the first active policy

    -- Check if token_value is not null and extract minutes from the interval
    IF token_value IS NOT NULL THEN
        -- Extract minutes from the interval and convert to integer
        token_expire := EXTRACT(EPOCH FROM token_value) / 60;
    ELSE
        token_expire := NULL;  -- Or set to a default value, e.g., 0
    END IF;

    RETURN token_expire;  -- Return the token duration in minutes
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_password(p_username VARCHAR, p_new_password VARCHAR) RETURNS TEXT AS $$
DECLARE
    v_status VARCHAR;
    v_user_id UUID;
BEGIN
    -- Get the user's UUID and status
    SELECT uuid, status INTO v_user_id, v_status
    FROM users
    WHERE username = p_username;

    -- Check if the user exists
    IF v_user_id IS NULL THEN
        RETURN 'User not found';
    END IF;

    -- Validate the new password according to policy
    PERFORM validate_password(v_user_id, p_new_password);
    
    -- Update the password if validation succeeds
    UPDATE users
    SET password = crypt(p_new_password, gen_salt('bf')),  -- Encrypt the new password
        expired = NULL,  -- Reset expired flag if applicable
        change_trigger_update_history = NOW(),  -- Update the last change timestamp
        status = 'active'  -- Unlock or set status to active
    WHERE uuid = v_user_id;

    RETURN 'Password updated successfully';
EXCEPTION
    WHEN OTHERS THEN
        -- Catch any validation errors and return the message
        RETURN SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Check revaluation
CREATE OR REPLACE FUNCTION checkreval() RETURNS VOID AS $$
BEGIN
    -- Logic to check revaluation
    RAISE NOTICE 'Checked revaluation';
END;
$$ LANGUAGE plpgsql;
