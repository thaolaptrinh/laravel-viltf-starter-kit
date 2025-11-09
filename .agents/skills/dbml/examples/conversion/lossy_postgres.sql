-- Demonstrates SILENT LOSSES on import. See lossy_imported.dbml + losses.md.
-- What survives: the accounts table (as plain columns).
-- What is DROPPED (no error): the VIEW, the SEQUENCE, the FUNCTION.
-- What is LOST on a surviving column: the GENERATED expression (email_lower keeps its type, loses lower(email)).

CREATE TABLE accounts (
  id serial PRIMARY KEY,
  email varchar(255) UNIQUE NOT NULL,
  email_lower text GENERATED ALWAYS AS (lower(email)) STORED,
  created_at timestamp DEFAULT now()
);

CREATE VIEW active_accounts AS SELECT * FROM accounts;

CREATE SEQUENCE accounts_seq START 1;

CREATE OR REPLACE FUNCTION audit() RETURNS trigger AS $$
BEGIN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
