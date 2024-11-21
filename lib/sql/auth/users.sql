
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

-- Procedures
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

CREATE OR REPLACE FUNCTION lock_user(p_username VARCHAR) RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET status = 'lock'
    WHERE username = p_username;
    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'User % locked successfully', p_username;
END;
$$ LANGUAGE plpgsql;
-- Add a new user with hashed password
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

CREATE OR REPLACE FUNCTION disable_user(p_username VARCHAR) RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET status = 'disable'
    WHERE username = p_username;    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'User % disabled successfully', p_username;
END;
$$ LANGUAGE plpgsql;

-- User revaluation
CREATE OR REPLACE FUNCTION userreval(username VARCHAR, reviewdate TIMESTAMP, reviewedby VARCHAR) RETURNS VOID AS $$
BEGIN
    -- Logic for user revaluation
    RAISE NOTICE 'Revaluated user % on %', username, reviewdate;
END;
$$ LANGUAGE plpgsql;



SELECT useradd('admin', 'cvadmin_password', 'System', 'ID', 'jdoe@example.com', '123-456-7890');
SELECT useradd('cvsystem', 'cvsystem_password', 'System', 'ID', 'jdoe@example.com', '123-456-7890');
SELECT groupaddMember('admins', 'admin');
SELECT groupaddMember('system', 'cvsystem');

