-- Create roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vadmin') THEN
        CREATE ROLE vadmin LOGIN PASSWORD 'vadmin_password';
    END IF;
END
$$;
DROP DATABASE vaultdb;
-- Create the database if it doesn't already exist
CREATE DATABASE vaultdb;

-- Connect to the database
\c vaultdb;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create history table
CREATE TABLE history (
    timestamp TIMESTAMP DEFAULT NOW(),
    action VARCHAR,
    field_updated VARCHAR,
    value TEXT, -- Hide value if it's a password
    updated_by VARCHAR,
    status VARCHAR
);

-- Grant all privileges to vadmin
-- Grant all privileges on vaultdb to postgres user
GRANT ALL PRIVILEGES ON DATABASE vaultdb TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vadmin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vadmin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO vadmin;

-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vservice') THEN
--         CREATE ROLE vservice LOGIN PASSWORD 'vservice_password';service_policy_id
--     END IF;
-- END
-- $$;

-- -- Grant select, insert, update, delete on tables to cvservice
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO vservice;

-- -- Grant privileges for future tables
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vservice;

-- -- Grant privileges for future functions and procedures
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO vservice;
