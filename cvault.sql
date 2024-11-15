-- SQL script to set up the CVault database schema
-- Create roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cvadmin') THEN
        CREATE ROLE cvadmin LOGIN PASSWORD 'cvadmin_password';
    END IF;
END
$$;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cvservice') THEN
        CREATE ROLE cvservice LOGIN PASSWORD 'cvservice_password';
    END IF;
END
$$;

-- clear database
DROP DATABASE cvaultdb;
-- Create the database if it doesn't already exist
CREATE DATABASE cvaultdb;

-- Connect to the database
\c cvaultdb;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- Create config table
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    service_policy_id SERIAL,  -- Auto-incrementing column without a default value
    vault_id SERIAL,            -- Auto-incrementing column without a default value
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);

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

-- Create acl table
CREATE TABLE acl (
    acl_id SERIAL PRIMARY KEY UNIQUE,
    acl_group VARCHAR,
    acl_permission VARCHAR,
    change_trigger_update_history TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_acl_group_perm UNIQUE (acl_group, acl_permission) 
);

CREATE TABLE users (
    uuid UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Use UUID instead of SERIAL
    username VARCHAR UNIQUE,
    first_name VARCHAR,
    last_name VARCHAR,
    password TEXT NOT NULL, -- Encrypted password
    email VARCHAR,
    phone VARCHAR,
    created TIMESTAMP DEFAULT NOW(),
    expired TIMESTAMP,
    status VARCHAR CHECK (status IN ('new', 'active', 'disable', 'lock', 'expired')),
    reval_by VARCHAR,
    reval_date TIMESTAMP,
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);

-- Create password table
CREATE TABLE password_history (
    userid UUID REFERENCES users(uuid) ON DELETE CASCADE,
    password TEXT NOT NULL,  -- Store the hashed password
    last_change TIMESTAMP DEFAULT NOW(),
    fail_login_count INT DEFAULT 0,
    PRIMARY KEY (userid, last_change)  -- Composite primary key
);
-- Create groups table
CREATE TABLE groups (
    name VARCHAR UNIQUE,
    members TEXT[], -- Array of usernames
    owner VARCHAR NOT NULL,
    reval_by VARCHAR,
    reval_date TIMESTAMP,
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);

-- Create objects table
CREATE TABLE objects (
    object_id SERIAL PRIMARY KEY UNIQUE,
    object_name VARCHAR,
    object_owner VARCHAR,
    object_acl_groups TEXT[], -- Array of groups with access
    object_acl VARCHAR,
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);

-- Create history table
CREATE TABLE history (
    timestamp TIMESTAMP DEFAULT NOW(),
    action VARCHAR,
    field_updated VARCHAR,
    value TEXT, -- Hide value if it's a password
    updated_by VARCHAR,
    status VARCHAR
);

-- Create vault_history table
CREATE TABLE vault_history (
    timestamp TIMESTAMP DEFAULT NOW(),
    action VARCHAR,
    field_updated VARCHAR,
    updated_by VARCHAR,
    value TEXT, -- Hide value if it's a password
    status VARCHAR,
    change_trigger_update_vault_history TIMESTAMP DEFAULT NOW()
);

-- Create secret_object table
CREATE TABLE secret_object (
    uniq_id SERIAL PRIMARY KEY,
    username VARCHAR NOT NULL,
    hostname VARCHAR NOT NULL,
    secret TEXT,
    ssh_key TEXT DEFAULT NULL,
    ssh_pwd TEXT DEFAULT NULL,
    check_out BOOLEAN DEFAULT FALSE,
    check_out_stamp TIMESTAMP,
    status VARCHAR,
    auto_check_time INTERVAL, -- Removed DEFAULT subquery here
    owner VARCHAR,
    groups TEXT[], -- Array of group names
    group_acl VARCHAR CHECK (group_acl IN ('read', 'list', 'update', 'remove', 'none')),
    change_trigger_update_vault_history TIMESTAMP DEFAULT NOW()
);

-- Trigger function to set default value for auto_check_time
CREATE OR REPLACE FUNCTION set_auto_check_time()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.auto_check_time IS NULL THEN
        NEW.auto_check_time := (SELECT token_expire FROM policy WHERE status = true LIMIT 1);  -- Ensure a value is returned
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to call the function before insert
CREATE TRIGGER trg_set_auto_check_time
BEFORE INSERT ON secret_object
FOR EACH ROW
EXECUTE FUNCTION set_auto_check_time();


-- setup 
INSERT INTO config (key, value) VALUES ('global_encryption_key', 'dmz1nEn6Xw9vHDUOJmXp1bpn5V7eoPGIfCdQ_S4PfL4=');


-- Procedures
CREATE OR REPLACE FUNCTION lock_user(p_username VARCHAR) RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET status = 'lock'
    WHERE username = p_username;
    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'User % locked successfully', p_username;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION update_password_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert the old password into the password history
    INSERT INTO password_history (userid, password, last_change)
    VALUES (NEW.uuid, NEW.password, NOW());

    RETURN NEW;  -- Return the new user record
END;
$$ LANGUAGE plpgsql;


-- Check in secret object by id
CREATE OR REPLACE FUNCTION check_in_id(id INT, force BOOLEAN DEFAULT FALSE) RETURNS VOID AS $$
BEGIN
    -- Logic to check in an object
    -- Check if admin for forced check-in
    RAISE NOTICE 'Checked in ID %', id;
END;
$$ LANGUAGE plpgsql;

-- Add a new secret
CREATE OR REPLACE FUNCTION add_secret(username VARCHAR, hostname VARCHAR, password TEXT, ssh_key TEXT, ssh_password TEXT) RETURNS VOID AS $$
BEGIN
    -- Logic to add a new secret
    RAISE NOTICE 'Added secret for % on %', username, hostname;
END;
$$ LANGUAGE plpgsql;

-- View a secret
CREATE OR REPLACE FUNCTION view_secret(id INT) RETURNS VOID AS $$
BEGIN
    -- Logic to view a secret
    RAISE NOTICE 'Viewed secret ID %', id;
END;
$$ LANGUAGE plpgsql;

-- Update a secret
CREATE OR REPLACE FUNCTION update_secret(id INT, field VARCHAR, value TEXT) RETURNS VOID AS $$
BEGIN
    -- Logic to update a secret
    RAISE NOTICE 'Updated secret ID % field %', id, field;
END;
$$ LANGUAGE plpgsql;

-- Delete a secret
CREATE OR REPLACE FUNCTION delete_secret(id INT) RETURNS VOID AS $$
BEGIN
    -- Logic to delete a secret
    RAISE NOTICE 'Deleted secret ID %', id;
END;
$$ LANGUAGE plpgsql;

-- Generate a password
CREATE OR REPLACE FUNCTION generate_password() RETURNS TEXT AS $$
BEGIN
    -- Logic to generate a secure password
    RETURN 'new_secure_password'; -- Placeholder for actual generation logic
END;
$$ LANGUAGE plpgsql;



-- Add a new user with hashed password
CREATE OR REPLACE FUNCTION useradd(
    username VARCHAR,        
    password TEXT,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    phone VARCHAR
) RETURNS VOID AS $$
DECLARE
    hashed_password TEXT;
BEGIN
    -- Hash the password using bcrypt
    hashed_password := crypt(password, gen_salt('bf'));    
    
    -- Insert the new user into the users table
    INSERT INTO users (username, password, first_name, last_name, email, phone)
    VALUES (username, hashed_password, first_name, last_name, email, phone);
    
    -- Check if the "users" group exists
    IF EXISTS (SELECT 1 FROM groups WHERE name = 'users') THEN
        -- Add the new user to the "users" group
        UPDATE groups
        SET members = array_append(members, username)
        WHERE name = 'users';
    ELSE
        -- Optionally raise a notice if the group does not exist
        RAISE NOTICE 'Group "users" does not exist, user % was not added to any group', username;
    END IF;
    
    RAISE NOTICE 'Added user %', username;
END;
$$ LANGUAGE plpgsql;


-- Modify user information
CREATE OR REPLACE FUNCTION usermod(user_id UUID, field_name TEXT, value TEXT) RETURNS BOOLEAN AS $$
DECLARE
    user_record RECORD;
BEGIN
    -- Fetch user record
    SELECT *
    INTO user_record
    FROM users
    WHERE uuid = user_id;

    -- Check if user is an admin
    IF EXISTS (SELECT 1 FROM acl WHERE acl_group = 'admin' AND acl_permission = 'allow' AND userid = user_id) THEN
        -- Admins can modify all fields
        UPDATE users
        SET (field_name) = (value)
        WHERE uuid = user_id;
    ELSE
        -- For non-admins, only allow specific fields to be modified
        IF field_name = 'password' THEN
            -- Call userpwd function to update the password, checking password restrictions
            PERFORM userpwd(user_id, value);
        ELSE
            -- Handle other fields accordingly
            UPDATE users
            SET (field_name) = (value)
            WHERE uuid = user_id;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- Change user password
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



-- Delete a user
CREATE OR REPLACE FUNCTION userdel(userid INT) RETURNS VOID AS $$
DECLARE
    user_name VARCHAR;  -- Renamed variable to avoid ambiguity
BEGIN
    -- Get the username of the user to be deleted
    SELECT username INTO user_name FROM users WHERE uuid = userid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with ID % does not exist', userid;
    END IF;

    -- Remove the user from the users table
    DELETE FROM users WHERE uuid = userid;

    -- Remove the username from all groups
    UPDATE groups 
    SET members = array_remove(members, user_name) 
    WHERE user_name = ANY(members);

    RAISE NOTICE 'Deleted user % with ID %', user_name, userid;
END;
$$ LANGUAGE plpgsql;


-- Add a new group
-- Create or replace the groupadd function
CREATE OR REPLACE FUNCTION groupadd(groupname VARCHAR, owner VARCHAR, acl_permissions TEXT[]) RETURNS VOID AS $$
DECLARE
    perm TEXT;  -- Variable for looping through permissions
BEGIN
    -- Check if the group already exists in groups
    IF EXISTS (SELECT 1 FROM groups WHERE name = groupname) THEN
        RAISE NOTICE 'Group % already exists, updating permissions.', groupname;
        -- Call updategroup to refresh permissions
        PERFORM updategroup(groupname, acl_permissions);
        RETURN;
    END IF;

    -- Logic to add a new group
    INSERT INTO groups (name, owner) VALUES (groupname, owner);

    -- Add entries in the acl table for each permission
    FOREACH perm IN ARRAY acl_permissions
    LOOP
        INSERT INTO acl (acl_group, acl_permission) 
        VALUES (groupname, perm)
        ON CONFLICT (acl_group, acl_permission) DO NOTHING;  -- Ignore if the permission already exists
    END LOOP;

    RAISE NOTICE 'Added group % with owner %', groupname, owner;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION updategroup(groupname VARCHAR, acl_permissions TEXT[]) RETURNS VOID AS $$
DECLARE
    perm TEXT;  -- Declare the variable for looping through permissions
BEGIN
    -- Check if the group exists
    IF NOT EXISTS (SELECT 1 FROM groups WHERE name = groupname) THEN
        RAISE EXCEPTION 'Group % does not exist', groupname;
    END IF;

    -- Delete existing permissions for the group
    DELETE FROM acl WHERE acl_group = groupname;

    -- Add new permissions
    FOREACH perm IN ARRAY acl_permissions
    LOOP
        INSERT INTO acl (acl_group, acl_permission) 
        VALUES (groupname, perm)
        ON CONFLICT (acl_group, acl_permission) DO NOTHING;  -- Ignore if the permission already exists
    END LOOP;

    RAISE NOTICE 'Updated group % with new permissions', groupname;
END;
$$ LANGUAGE plpgsql;


-- Add a member to a group
CREATE OR REPLACE FUNCTION groupaddMember(groupname VARCHAR, newmember VARCHAR) RETURNS VOID AS $$
BEGIN
    -- Check if the member is already in the group's members array
    IF array_position((SELECT members FROM groups WHERE name = groupname), newmember) IS NULL THEN
        -- Add the new member to the group's members array
        UPDATE groups
        SET members = array_append(members, newmember)
        WHERE name = groupname;

        RAISE NOTICE 'Added member % to group %', newmember, groupname;
    ELSE
        RAISE NOTICE 'Member % is already in group %', newmember, groupname;
    END IF;
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

CREATE OR REPLACE FUNCTION expire_user_password(p_username VARCHAR) RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET expired = CURRENT_DATE
    WHERE username = p_username;
    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'Password for user % expired successfully', p_username;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION disable_user(p_username VARCHAR) RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET status = 'disable'
    WHERE username = p_username;    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'User % disabled successfully', p_username;
END;
$$ LANGUAGE plpgsql;

-- Delete a member from a group
CREATE OR REPLACE FUNCTION groupdelMember(groupname VARCHAR, memberToRemove VARCHAR) RETURNS VOID AS $$
BEGIN
    -- Remove the member from the group's members array
    UPDATE groups
    SET members = array_remove(members, memberToRemove)
    WHERE name = groupname;

    RAISE NOTICE 'Deleted member % from group %', memberToRemove, groupname;
END;
$$ LANGUAGE plpgsql;

-- Check revaluation
CREATE OR REPLACE FUNCTION checkreval() RETURNS VOID AS $$
BEGIN
    -- Logic to check revaluation
    RAISE NOTICE 'Checked revaluation';
END;
$$ LANGUAGE plpgsql;

-- User revaluation
CREATE OR REPLACE FUNCTION userreval(username VARCHAR, reviewdate TIMESTAMP, reviewedby VARCHAR) RETURNS VOID AS $$
BEGIN
    -- Logic for user revaluation
    RAISE NOTICE 'Revaluated user % on %', username, reviewdate;
END;
$$ LANGUAGE plpgsql;

-- Group revaluation
CREATE OR REPLACE FUNCTION groupreval(groupname VARCHAR, reviewdate TIMESTAMP, reviewedby VARCHAR) RETURNS VOID AS $$
BEGIN
    -- Logic for group revaluation
    RAISE NOTICE 'Revaluated group % on %', groupname, reviewdate;
END;
$$ LANGUAGE plpgsql;

-- Auto check-in for scheduled tasks
CREATE OR REPLACE FUNCTION auto_check_in(id INT) RETURNS VOID AS $$
BEGIN
    -- Logic for automatic check-in
    RAISE NOTICE 'Auto-checked in ID %', id;
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


SELECT groupadd('users', 'system', ARRAY['None']);
SELECT groupadd('system', 'system_owner', ARRAY['Read', 'Write', 'Modify', 'Delete', 'Update']);
SELECT groupadd('admins', 'admin_owner', ARRAY['FULL Access']);
SELECT useradd('admin', 'cvadmin_password', 'System', 'ID', 'jdoe@example.com', '123-456-7890');
SELECT groupaddMember('admins', 'admin');
SELECT useradd('cvsystem', 'cvsystem_password', 'System', 'ID', 'jdoe@example.com', '123-456-7890');
SELECT groupaddMember('system', 'cvsystem');
SELECT insert_policy( p_policy_name := 'Default', p_reval_cycle := 'quarterly',p_max_len := 15);
SELECT set_policy_status(1, True);


-- final touches 
-- Grant all privileges to cvadmin
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cvadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cvadmin;

-- Grant select, insert, update, delete on tables to cvservice
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO cvservice;

-- If you have specific stored procedures, you can grant execute privileges as well
-- Example: GRANT EXECUTE ON FUNCTION your_procedure_name TO cvservice;

-- Grant privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO cvadmin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO cvservice;

-- Grant privileges for future functions and procedures
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO cvservice;
-- Note: No need for procedures since PostgreSQL does not support ALTER DEFAULT PRIVILEGES for them

-- End of SQL script
