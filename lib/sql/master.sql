-- master.sql

-- Include all files from defaults
\i ${inst}/lib/sql/defaults/preload.sql

-- Include all files from config
\i ${inst}/lib/sql/config/config.sql

-- Include all files from policy
\i ${inst}/lib/sql/policies/policy.sql

-- Include all files from auth
\i ${inst}/lib/sql/auth/groups.sql
\i ${inst}/lib/sql/auth/users.sql
\i ${inst}/lib/sql/auth/password.sql


-- Optionally, include any files from other directories
-- \i ${inst}/lib/sql/policies/*.sql
