--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: add_secret(character varying, character varying, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_secret(username character varying, hostname character varying, password text, ssh_key text, ssh_password text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to add a new secret
    RAISE NOTICE 'Added secret for % on %', username, hostname;
END;
$$;


ALTER FUNCTION public.add_secret(username character varying, hostname character varying, password text, ssh_key text, ssh_password text) OWNER TO postgres;

--
-- Name: authenticate_user(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.authenticate_user(p_username character varying, p_password character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
    IF trim(lower(v_status)) = 'expired' THEN
        RETURN 'Account expired, please reset password.';
    END IF;

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
$$;


ALTER FUNCTION public.authenticate_user(p_username character varying, p_password character varying) OWNER TO postgres;

--
-- Name: auto_check_in(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_check_in(id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic for automatic check-in
    RAISE NOTICE 'Auto-checked in ID %', id;
END;
$$;


ALTER FUNCTION public.auto_check_in(id integer) OWNER TO postgres;

--
-- Name: check_in_id(integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_in_id(id integer, force boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to check in an object
    -- Check if admin for forced check-in
    RAISE NOTICE 'Checked in ID %', id;
END;
$$;


ALTER FUNCTION public.check_in_id(id integer, force boolean) OWNER TO postgres;

--
-- Name: checkreval(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.checkreval() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to check revaluation
    RAISE NOTICE 'Checked revaluation';
END;
$$;


ALTER FUNCTION public.checkreval() OWNER TO postgres;

--
-- Name: delete_secret(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_secret(id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to delete a secret
    RAISE NOTICE 'Deleted secret ID %', id;
END;
$$;


ALTER FUNCTION public.delete_secret(id integer) OWNER TO postgres;

--
-- Name: disable_user(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.disable_user(p_username character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE users
    SET status = 'disable'
    WHERE username = p_username;    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'User % disabled successfully', p_username;
END;
$$;


ALTER FUNCTION public.disable_user(p_username character varying) OWNER TO postgres;

--
-- Name: expire_user_password(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.expire_user_password(p_username character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE users
    SET expired = CURRENT_DATE
    WHERE username = p_username;
    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'Password for user % expired successfully', p_username;
END;
$$;


ALTER FUNCTION public.expire_user_password(p_username character varying) OWNER TO postgres;

--
-- Name: generate_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_password() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to generate a secure password
    RETURN 'new_secure_password'; -- Placeholder for actual generation logic
END;
$$;


ALTER FUNCTION public.generate_password() OWNER TO postgres;

--
-- Name: groupadd(character varying, character varying, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.groupadd(groupname character varying, owner character varying, acl_permissions text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.groupadd(groupname character varying, owner character varying, acl_permissions text[]) OWNER TO postgres;

--
-- Name: groupaddmember(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.groupaddmember(groupname character varying, newmember character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.groupaddmember(groupname character varying, newmember character varying) OWNER TO postgres;

--
-- Name: groupdelmember(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.groupdelmember(groupname character varying, membertoremove character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Remove the member from the group's members array
    UPDATE groups
    SET members = array_remove(members, memberToRemove)
    WHERE name = groupname;

    RAISE NOTICE 'Deleted member % from group %', memberToRemove, groupname;
END;
$$;


ALTER FUNCTION public.groupdelmember(groupname character varying, membertoremove character varying) OWNER TO postgres;

--
-- Name: groupreval(character varying, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.groupreval(groupname character varying, reviewdate timestamp without time zone, reviewedby character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic for group revaluation
    RAISE NOTICE 'Revaluated group % on %', groupname, reviewdate;
END;
$$;


ALTER FUNCTION public.groupreval(groupname character varying, reviewdate timestamp without time zone, reviewedby character varying) OWNER TO postgres;

--
-- Name: insert_policy(character varying, boolean, character varying, integer, integer, integer, integer, integer, integer, character varying, integer, boolean, interval, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_policy(p_policy_name character varying, p_status boolean DEFAULT false, p_reval_cycle character varying DEFAULT 'monthly'::character varying, p_max_len integer DEFAULT 15, p_min_len integer DEFAULT 7, p_upper_char integer DEFAULT 1, p_lower_char integer DEFAULT 1, p_numeric_char integer DEFAULT 1, p_special_char integer DEFAULT 1, p_special_char_string character varying DEFAULT 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~#^_=+'::character varying, p_password_history_count integer DEFAULT 12, p_password_override boolean DEFAULT false, p_token_expire interval DEFAULT '00:20:00'::interval, p_change_trigger_update_history timestamp without time zone DEFAULT now()) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.insert_policy(p_policy_name character varying, p_status boolean, p_reval_cycle character varying, p_max_len integer, p_min_len integer, p_upper_char integer, p_lower_char integer, p_numeric_char integer, p_special_char integer, p_special_char_string character varying, p_password_history_count integer, p_password_override boolean, p_token_expire interval, p_change_trigger_update_history timestamp without time zone) OWNER TO postgres;

--
-- Name: lock_user(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lock_user(p_username character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE users
    SET status = 'lock'
    WHERE username = p_username;
    
    -- Optionally, you can raise a notice or log the event
    RAISE NOTICE 'User % locked successfully', p_username;
END;
$$;


ALTER FUNCTION public.lock_user(p_username character varying) OWNER TO postgres;

--
-- Name: set_auto_check_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_auto_check_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.auto_check_time IS NULL THEN
        NEW.auto_check_time := (SELECT token_expire FROM policy WHERE status = true LIMIT 1);  -- Ensure a value is returned
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_auto_check_time() OWNER TO postgres;

--
-- Name: set_policy_status(integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_policy_status(p_id integer, p_status boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.set_policy_status(p_id integer, p_status boolean) OWNER TO postgres;

--
-- Name: token_duration(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.token_duration() RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.token_duration() OWNER TO postgres;

--
-- Name: update_password_history(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_password_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert the old password into the password history
    INSERT INTO password_history (userid, password, last_change)
    VALUES (NEW.uuid, NEW.password, NOW());

    RETURN NEW;  -- Return the new user record
END;
$$;


ALTER FUNCTION public.update_password_history() OWNER TO postgres;

--
-- Name: update_policy(integer, character varying, character varying, integer, integer, integer, integer, integer, integer, character varying, integer, boolean, interval, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_policy(p_id integer, p_policy_name character varying DEFAULT NULL::character varying, p_reval_cycle character varying DEFAULT NULL::character varying, p_max_len integer DEFAULT NULL::integer, p_min_len integer DEFAULT NULL::integer, p_upper_char integer DEFAULT NULL::integer, p_lower_char integer DEFAULT NULL::integer, p_numeric_char integer DEFAULT NULL::integer, p_special_char integer DEFAULT NULL::integer, p_special_char_string character varying DEFAULT NULL::character varying, p_password_history_count integer DEFAULT NULL::integer, p_password_override boolean DEFAULT NULL::boolean, p_token_expire interval DEFAULT NULL::interval, p_status boolean DEFAULT NULL::boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_policy(p_id integer, p_policy_name character varying, p_reval_cycle character varying, p_max_len integer, p_min_len integer, p_upper_char integer, p_lower_char integer, p_numeric_char integer, p_special_char integer, p_special_char_string character varying, p_password_history_count integer, p_password_override boolean, p_token_expire interval, p_status boolean) OWNER TO postgres;

--
-- Name: update_secret(integer, character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_secret(id integer, field character varying, value text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to update a secret
    RAISE NOTICE 'Updated secret ID % field %', id, field;
END;
$$;


ALTER FUNCTION public.update_secret(id integer, field character varying, value text) OWNER TO postgres;

--
-- Name: updategroup(character varying, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updategroup(groupname character varying, acl_permissions text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.updategroup(groupname character varying, acl_permissions text[]) OWNER TO postgres;

--
-- Name: useradd(character varying, text, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.useradd(username character varying, password text, first_name character varying, last_name character varying, email character varying, phone character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.useradd(username character varying, password text, first_name character varying, last_name character varying, email character varying, phone character varying) OWNER TO postgres;

--
-- Name: userdel(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.userdel(userid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.userdel(userid integer) OWNER TO postgres;

--
-- Name: usermod(uuid, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.usermod(user_id uuid, field_name text, value text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.usermod(user_id uuid, field_name text, value text) OWNER TO postgres;

--
-- Name: userpwd(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.userpwd(requestor_id uuid, target_user_id uuid, new_password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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

    -- Validate the new password
    IF NOT validate_password(new_password, policy_record) THEN
        RAISE EXCEPTION 'Password does not meet policy requirements.';
    END IF;

    -- Check the last `password_history_count` passwords for uniqueness
    IF EXISTS (
        SELECT 1 
        FROM password_history 
        WHERE userid = target_user_id
          AND password = crypt(new_password, password)  -- Compare hashed password
        ORDER BY last_change DESC  -- Corrected the ORDER BY clause
        LIMIT policy_record.password_history_count
    ) THEN
        RAISE EXCEPTION 'Password must not match any of the last % passwords used', policy_record.password_history_count;
    END IF;

    -- Hash the new password using bcrypt
    hashed_password := crypt(new_password, gen_salt('bf'));

    -- Update the user's password to the new hashed password
    UPDATE users
    SET password = hashed_password
    WHERE uuid = target_user_id;

    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.userpwd(requestor_id uuid, target_user_id uuid, new_password text) OWNER TO postgres;

--
-- Name: userreval(character varying, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.userreval(username character varying, reviewdate timestamp without time zone, reviewedby character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic for user revaluation
    RAISE NOTICE 'Revaluated user % on %', username, reviewdate;
END;
$$;


ALTER FUNCTION public.userreval(username character varying, reviewdate timestamp without time zone, reviewedby character varying) OWNER TO postgres;

--
-- Name: validate_password(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_password(password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Validate the password based on policy
    RETURN TRUE; -- Placeholder for actual validation
END;
$$;


ALTER FUNCTION public.validate_password(password text) OWNER TO postgres;

--
-- Name: validate_password(text, record); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_password(password text, policy_record record) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- Check minimum length
    IF LENGTH(password) < policy_record.min_len THEN
        RAISE NOTICE 'Password must be at least % characters long.', policy_record.min_len;
        RETURN FALSE;  -- Return FALSE if the password is too short
    END IF;

    -- Check maximum length (if needed)
    IF LENGTH(password) > policy_record.max_len THEN
        RAISE NOTICE 'Password must be no more than % characters long.', policy_record.max_len;
        RETURN FALSE;  -- Return FALSE if the password is too long
    END IF;

    -- Check for required uppercase letters
    IF LENGTH(REGEXP_REPLACE(password, '[^A-Z]', '', 'g')) < policy_record.upper_char THEN
        RAISE NOTICE 'Password must contain at least % uppercase letters.', policy_record.upper_char;
        RETURN FALSE;
    END IF;

    -- Check for required lowercase letters
    IF LENGTH(REGEXP_REPLACE(password, '[^a-z]', '', 'g')) < policy_record.lower_char THEN
        RAISE NOTICE 'Password must contain at least % lowercase letters.', policy_record.lower_char;
        RETURN FALSE;
    END IF;

    -- Check for required numeric characters
    IF LENGTH(REGEXP_REPLACE(password, '[^0-9]', '', 'g')) < policy_record.numeric_char THEN
        RAISE NOTICE 'Password must contain at least % numeric characters.', policy_record.numeric_char;
        RETURN FALSE;
    END IF;

    -- Check for required special characters
    IF LENGTH(REGEXP_REPLACE(password, '[^' || policy_record.special_char_string || ']', '', 'g')) < policy_record.special_char THEN
        RAISE NOTICE 'Password must contain at least % special characters.', policy_record.special_char;
        RETURN FALSE;
    END IF;

    -- Check for at least one special character (adjust as needed)
    IF NOT password ~ '[!@#$%^&*(),.?":{}|<>]' THEN
        RAISE NOTICE 'Password must contain at least one special character.';
        RETURN FALSE;
    END IF;

    -- If all checks pass
    RETURN TRUE;  -- All validation checks passed
END;
$_$;


ALTER FUNCTION public.validate_password(password text, policy_record record) OWNER TO postgres;

--
-- Name: validate_password(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_password(user_id uuid, password text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
    WHERE service_policy_id = 1; -- Assuming we're only dealing with the default policy

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
$$;


ALTER FUNCTION public.validate_password(user_id uuid, password text) OWNER TO postgres;

--
-- Name: view_secret(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.view_secret(id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Logic to view a secret
    RAISE NOTICE 'Viewed secret ID %', id;
END;
$$;


ALTER FUNCTION public.view_secret(id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acl; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acl (
    acl_id integer NOT NULL,
    acl_group character varying,
    acl_permission character varying,
    change_trigger_update_history timestamp without time zone DEFAULT now()
);


ALTER TABLE public.acl OWNER TO postgres;

--
-- Name: acl_acl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.acl_acl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.acl_acl_id_seq OWNER TO postgres;

--
-- Name: acl_acl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.acl_acl_id_seq OWNED BY public.acl.acl_id;


--
-- Name: config; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.config (
    key text NOT NULL,
    value text NOT NULL,
    service_policy_id integer NOT NULL,
    vault_id integer NOT NULL,
    change_trigger_update_history timestamp without time zone DEFAULT now()
);


ALTER TABLE public.config OWNER TO postgres;

--
-- Name: config_service_policy_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.config_service_policy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.config_service_policy_id_seq OWNER TO postgres;

--
-- Name: config_service_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.config_service_policy_id_seq OWNED BY public.config.service_policy_id;


--
-- Name: config_vault_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.config_vault_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.config_vault_id_seq OWNER TO postgres;

--
-- Name: config_vault_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.config_vault_id_seq OWNED BY public.config.vault_id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groups (
    name character varying,
    members text[],
    owner character varying NOT NULL,
    reval_by character varying,
    reval_date timestamp without time zone,
    change_trigger_update_history timestamp without time zone DEFAULT now()
);


ALTER TABLE public.groups OWNER TO postgres;

--
-- Name: history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.history (
    "timestamp" timestamp without time zone DEFAULT now(),
    action character varying,
    field_updated character varying,
    value text,
    updated_by character varying,
    status character varying
);


ALTER TABLE public.history OWNER TO postgres;

--
-- Name: objects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.objects (
    object_id integer NOT NULL,
    object_name character varying,
    object_owner character varying,
    object_acl_groups text[],
    object_acl character varying,
    change_trigger_update_history timestamp without time zone DEFAULT now()
);


ALTER TABLE public.objects OWNER TO postgres;

--
-- Name: objects_object_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.objects_object_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.objects_object_id_seq OWNER TO postgres;

--
-- Name: objects_object_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.objects_object_id_seq OWNED BY public.objects.object_id;


--
-- Name: password_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.password_history (
    userid uuid NOT NULL,
    password text NOT NULL,
    last_change timestamp without time zone DEFAULT now() NOT NULL,
    fail_login_count integer DEFAULT 0
);


ALTER TABLE public.password_history OWNER TO postgres;

--
-- Name: policy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.policy (
    service_policy_id integer NOT NULL,
    policy_name character varying NOT NULL,
    status boolean DEFAULT false,
    reval_cycle character varying,
    max_len integer DEFAULT 63,
    min_len integer DEFAULT 15,
    upper_char integer DEFAULT 1,
    lower_char integer DEFAULT 1,
    numeric_char integer DEFAULT 1,
    special_char integer DEFAULT 1,
    special_char_string character varying DEFAULT 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~#^_=+'::character varying,
    password_history_count integer DEFAULT 12,
    password_override boolean DEFAULT false,
    token_expire interval DEFAULT '00:20:00'::interval,
    change_trigger_update_history timestamp without time zone DEFAULT now(),
    CONSTRAINT policy_reval_cycle_check CHECK (((reval_cycle)::text = ANY ((ARRAY['daily'::character varying, 'weekly'::character varying, 'monthly'::character varying, 'bi-monthly'::character varying, 'quarterly'::character varying, 'bi-yearly'::character varying, 'yearly'::character varying])::text[])))
);


ALTER TABLE public.policy OWNER TO postgres;

--
-- Name: policy_service_policy_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.policy_service_policy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.policy_service_policy_id_seq OWNER TO postgres;

--
-- Name: policy_service_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.policy_service_policy_id_seq OWNED BY public.policy.service_policy_id;


--
-- Name: secret_object; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.secret_object (
    uniq_id integer NOT NULL,
    username character varying NOT NULL,
    hostname character varying NOT NULL,
    secret text,
    ssh_key text,
    ssh_pwd text,
    check_out boolean DEFAULT false,
    check_out_stamp timestamp without time zone,
    status character varying,
    auto_check_time interval,
    owner character varying,
    groups text[],
    group_acl character varying,
    change_trigger_update_vault_history timestamp without time zone DEFAULT now(),
    CONSTRAINT secret_object_group_acl_check CHECK (((group_acl)::text = ANY ((ARRAY['read'::character varying, 'list'::character varying, 'update'::character varying, 'remove'::character varying, 'none'::character varying])::text[])))
);


ALTER TABLE public.secret_object OWNER TO postgres;

--
-- Name: secret_object_uniq_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.secret_object_uniq_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.secret_object_uniq_id_seq OWNER TO postgres;

--
-- Name: secret_object_uniq_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.secret_object_uniq_id_seq OWNED BY public.secret_object.uniq_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    uuid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    username character varying,
    first_name character varying,
    last_name character varying,
    password text NOT NULL,
    email character varying,
    phone character varying,
    created timestamp without time zone DEFAULT now(),
    expired timestamp without time zone,
    status character varying,
    reval_by character varying,
    reval_date timestamp without time zone,
    change_trigger_update_history timestamp without time zone DEFAULT now(),
    CONSTRAINT users_status_check CHECK (((status)::text = ANY ((ARRAY['new'::character varying, 'active'::character varying, 'disable'::character varying, 'lock'::character varying, 'expired'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: vault_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vault_history (
    "timestamp" timestamp without time zone DEFAULT now(),
    action character varying,
    field_updated character varying,
    updated_by character varying,
    value text,
    status character varying,
    change_trigger_update_vault_history timestamp without time zone DEFAULT now()
);


ALTER TABLE public.vault_history OWNER TO postgres;

--
-- Name: acl acl_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acl ALTER COLUMN acl_id SET DEFAULT nextval('public.acl_acl_id_seq'::regclass);


--
-- Name: config service_policy_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.config ALTER COLUMN service_policy_id SET DEFAULT nextval('public.config_service_policy_id_seq'::regclass);


--
-- Name: config vault_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.config ALTER COLUMN vault_id SET DEFAULT nextval('public.config_vault_id_seq'::regclass);


--
-- Name: objects object_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.objects ALTER COLUMN object_id SET DEFAULT nextval('public.objects_object_id_seq'::regclass);


--
-- Name: policy service_policy_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.policy ALTER COLUMN service_policy_id SET DEFAULT nextval('public.policy_service_policy_id_seq'::regclass);


--
-- Name: secret_object uniq_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.secret_object ALTER COLUMN uniq_id SET DEFAULT nextval('public.secret_object_uniq_id_seq'::regclass);


--
-- Data for Name: acl; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.acl (acl_id, acl_group, acl_permission, change_trigger_update_history) FROM stdin;
1	users	None	2024-11-12 12:02:01.760355
2	system	Read	2024-11-12 12:02:01.7626
3	system	Write	2024-11-12 12:02:01.7626
4	system	Modify	2024-11-12 12:02:01.7626
5	system	Delete	2024-11-12 12:02:01.7626
6	system	Update	2024-11-12 12:02:01.7626
7	admins	FULL Access	2024-11-12 12:02:01.763576
\.


--
-- Data for Name: config; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.config (key, value, service_policy_id, vault_id, change_trigger_update_history) FROM stdin;
global_encryption_key	dmz1nEn6Xw9vHDUOJmXp1bpn5V7eoPGIfCdQ_S4PfL4=	1	1	2024-11-12 12:02:01.731901
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groups (name, members, owner, reval_by, reval_date, change_trigger_update_history) FROM stdin;
admins	{admin}	admin_owner	\N	\N	2024-11-12 12:02:01.763576
users	{admin,cvsystem}	system	\N	\N	2024-11-12 12:02:01.760355
system	{cvsystem}	system_owner	\N	\N	2024-11-12 12:02:01.7626
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.history ("timestamp", action, field_updated, value, updated_by, status) FROM stdin;
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.objects (object_id, object_name, object_owner, object_acl_groups, object_acl, change_trigger_update_history) FROM stdin;
\.


--
-- Data for Name: password_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.password_history (userid, password, last_change, fail_login_count) FROM stdin;
\.


--
-- Data for Name: policy; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.policy (service_policy_id, policy_name, status, reval_cycle, max_len, min_len, upper_char, lower_char, numeric_char, special_char, special_char_string, password_history_count, password_override, token_expire, change_trigger_update_history) FROM stdin;
1	Default	t	quarterly	15	7	1	1	1	1	abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.~#^_=+	12	f	00:20:00	2024-11-12 12:02:01.776952
\.


--
-- Data for Name: secret_object; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.secret_object (uniq_id, username, hostname, secret, ssh_key, ssh_pwd, check_out, check_out_stamp, status, auto_check_time, owner, groups, group_acl, change_trigger_update_vault_history) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (uuid, username, first_name, last_name, password, email, phone, created, expired, status, reval_by, reval_date, change_trigger_update_history) FROM stdin;
dcae8833-7b64-4255-98e8-48ac18cbbc97	cvsystem	System	ID	$2a$06$QVDi5cB/W3gH4x.vShUGROydORFQQUaWNotvRg/T4YY.cfC5g49Pi	jdoe@example.com	123-456-7890	2024-11-12 12:02:01.771561	\N	\N	\N	\N	2024-11-12 12:02:01.771561
739f9f65-8d62-494a-ba64-d48ac3bee428	admin	System	ID	$2a$06$GGU2RCqioBzHWY5za5/iVuGEmJHfgh4eFa/K2gtrBxApp9h7UREXi	jdoe@example.com	123-456-7890	2024-11-12 12:02:01.76446	2024-11-12 00:00:00	active	\N	\N	2024-11-12 12:02:01.76446
\.


--
-- Data for Name: vault_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vault_history ("timestamp", action, field_updated, updated_by, value, status, change_trigger_update_vault_history) FROM stdin;
\.


--
-- Name: acl_acl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.acl_acl_id_seq', 7, true);


--
-- Name: config_service_policy_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.config_service_policy_id_seq', 1, true);


--
-- Name: config_vault_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.config_vault_id_seq', 1, true);


--
-- Name: objects_object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.objects_object_id_seq', 1, false);


--
-- Name: policy_service_policy_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.policy_service_policy_id_seq', 1, true);


--
-- Name: secret_object_uniq_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.secret_object_uniq_id_seq', 1, false);


--
-- Name: acl acl_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acl
    ADD CONSTRAINT acl_pkey PRIMARY KEY (acl_id);


--
-- Name: config config_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.config
    ADD CONSTRAINT config_pkey PRIMARY KEY (key);


--
-- Name: groups groups_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_name_key UNIQUE (name);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (object_id);


--
-- Name: password_history password_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.password_history
    ADD CONSTRAINT password_history_pkey PRIMARY KEY (userid, last_change);


--
-- Name: policy policy_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_pkey PRIMARY KEY (service_policy_id);


--
-- Name: policy policy_policy_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.policy
    ADD CONSTRAINT policy_policy_name_key UNIQUE (policy_name);


--
-- Name: secret_object secret_object_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.secret_object
    ADD CONSTRAINT secret_object_pkey PRIMARY KEY (uniq_id);


--
-- Name: acl unique_acl_group_perm; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acl
    ADD CONSTRAINT unique_acl_group_perm UNIQUE (acl_group, acl_permission);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (uuid);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: secret_object trg_set_auto_check_time; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_set_auto_check_time BEFORE INSERT ON public.secret_object FOR EACH ROW EXECUTE FUNCTION public.set_auto_check_time();


--
-- Name: password_history password_history_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.password_history
    ADD CONSTRAINT password_history_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(uuid) ON DELETE CASCADE;


--
-- Name: FUNCTION authenticate_user(p_username character varying, p_password character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.authenticate_user(p_username character varying, p_password character varying) TO cvservice;


--
-- Name: FUNCTION disable_user(p_username character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.disable_user(p_username character varying) TO cvservice;


--
-- Name: FUNCTION expire_user_password(p_username character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.expire_user_password(p_username character varying) TO cvservice;


--
-- Name: FUNCTION lock_user(p_username character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.lock_user(p_username character varying) TO cvservice;


--
-- Name: TABLE acl; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.acl TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.acl TO cvservice;


--
-- Name: SEQUENCE acl_acl_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.acl_acl_id_seq TO cvadmin;


--
-- Name: TABLE config; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.config TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.config TO cvservice;


--
-- Name: SEQUENCE config_service_policy_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.config_service_policy_id_seq TO cvadmin;


--
-- Name: SEQUENCE config_vault_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.config_vault_id_seq TO cvadmin;


--
-- Name: TABLE groups; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.groups TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.groups TO cvservice;


--
-- Name: TABLE history; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.history TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.history TO cvservice;


--
-- Name: TABLE objects; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.objects TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.objects TO cvservice;


--
-- Name: SEQUENCE objects_object_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.objects_object_id_seq TO cvadmin;


--
-- Name: TABLE password_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.password_history TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.password_history TO cvservice;


--
-- Name: TABLE policy; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.policy TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.policy TO cvservice;


--
-- Name: SEQUENCE policy_service_policy_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.policy_service_policy_id_seq TO cvadmin;


--
-- Name: TABLE secret_object; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.secret_object TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.secret_object TO cvservice;


--
-- Name: SEQUENCE secret_object_uniq_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.secret_object_uniq_id_seq TO cvadmin;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.users TO cvservice;


--
-- Name: TABLE vault_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vault_history TO cvadmin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.vault_history TO cvservice;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO cvservice;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO cvadmin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO cvservice;


--
-- PostgreSQL database dump complete
--

