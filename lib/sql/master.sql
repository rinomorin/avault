-- master.sql

-- Include all files from defaults
\i ${inst}/lib/sql/defaults/preload.sql

-- Include all files from config
\i ${inst}/lib/sql/config/config.sql

-- Optionally, include any files from other directories
-- \i ${inst}/lib/sql/policies/*.sql
