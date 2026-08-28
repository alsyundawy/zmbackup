PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 15000;
PRAGMA synchronous = NORMAL;

CREATE TABLE IF NOT EXISTS backup_session (
    sessionID VARCHAR PRIMARY KEY,
    initial_date TIMESTAMP NOT NULL,
    conclusion_date TIMESTAMP,
    size VARCHAR,
    type VARCHAR NOT NULL,
    status VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS backup_account (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionID VARCHAR NOT NULL,
    account_size VARCHAR,
    email VARCHAR NOT NULL,
    initial_date TIMESTAMP NOT NULL,
    conclusion_date TIMESTAMP,
    status VARCHAR DEFAULT 'PENDING',
    sha256_hash VARCHAR,
    retry_count INTEGER DEFAULT 0,
    FOREIGN KEY (sessionID) REFERENCES backup_session(sessionID) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_account_session ON backup_account(sessionID);
CREATE INDEX IF NOT EXISTS idx_account_status ON backup_account(status);
CREATE INDEX IF NOT EXISTS idx_account_email ON backup_account(email);
