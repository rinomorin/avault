-- Create groups table
CREATE TABLE groups (
    name VARCHAR UNIQUE,
    members TEXT[], -- Array of usernames
    owner VARCHAR NOT NULL,
    reval_by VARCHAR,
    reval_date TIMESTAMP,
    change_trigger_update_history TIMESTAMP DEFAULT NOW()
);

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

-- Group revaluation
CREATE OR REPLACE FUNCTION groupreval(groupname VARCHAR, reviewdate TIMESTAMP, reviewedby VARCHAR) RETURNS VOID AS $$
BEGIN
    -- Logic for group revaluation
    RAISE NOTICE 'Revaluated group % on %', groupname, reviewdate;
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


SELECT groupadd('users', 'system', ARRAY['None']);
SELECT groupadd('system', 'system_owner', ARRAY['Read', 'Write', 'Modify', 'Delete', 'Update']);
SELECT groupadd('admins', 'admin_owner', ARRAY['FULL Access']);

