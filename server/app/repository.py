import hashlib
import json
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from uuid import uuid4

from .schemas import ArtworkRequest, FeedbackRequest


class ConflictError(Exception):
    pass


class CapacityError(Exception):
    pass


class Repository:
    """Short SQLite transactions; no connection is shared across threads.

    Worker claiming and request deduplication are atomic. The service runs one
    worker process; startup recovery makes interrupted jobs visibly failed.
    """

    def __init__(self, root: Path):
        root.mkdir(parents=True, exist_ok=True)
        self.path = root / "easyfind.sqlite3"
        with self.connection() as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY);
                INSERT OR IGNORE INTO schema_version VALUES (1);
                CREATE TABLE IF NOT EXISTS jobs (
                    id TEXT PRIMARY KEY, owner TEXT NOT NULL, idem TEXT NOT NULL,
                    fingerprint TEXT NOT NULL, request TEXT NOT NULL, status TEXT NOT NULL,
                    error TEXT, created REAL NOT NULL, updated REAL NOT NULL,
                    UNIQUE(owner, idem)
                );
                CREATE INDEX IF NOT EXISTS jobs_queue ON jobs(status, created);
                CREATE INDEX IF NOT EXISTS jobs_owner_time ON jobs(owner, created);
                CREATE TABLE IF NOT EXISTS feedback (
                    id TEXT PRIMARY KEY, owner TEXT NOT NULL, request TEXT NOT NULL,
                    created REAL NOT NULL
                );
                CREATE INDEX IF NOT EXISTS feedback_owner_time ON feedback(owner, created);
            """)

    @contextmanager
    def connection(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def recover(self):
        with self.connection() as db:
            db.execute(
                "UPDATE jobs SET status='failed', error=?, updated=? WHERE status='running'",
                ("服务重启中断了生成任务，请重新提交。", time.time()),
            )

    def create_job(self, owner: str, key: str, request: ArtworkRequest, limit: int, pending: int):
        payload = json.dumps(request.model_dump(), sort_keys=True, ensure_ascii=False)
        fingerprint = hashlib.sha256(payload.encode()).hexdigest()
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            old = db.execute("SELECT * FROM jobs WHERE owner=? AND idem=?", (owner, key)).fetchone()
            if old:
                if old["fingerprint"] != fingerprint:
                    raise ConflictError
                return dict(old)
            count = db.execute(
                "SELECT COUNT(*) FROM jobs WHERE owner=? AND created>?", (owner, time.time() - 60)
            ).fetchone()[0]
            queue = db.execute(
                "SELECT COUNT(*) FROM jobs WHERE status IN ('pending','running')"
            ).fetchone()[0]
            if count >= limit or queue >= pending:
                raise CapacityError
            ident, now = str(uuid4()), time.time()
            db.execute(
                "INSERT INTO jobs VALUES (?,?,?,?,?,'pending',NULL,?,?)",
                (ident, owner, key, fingerprint, payload, now, now),
            )
            return dict(db.execute("SELECT * FROM jobs WHERE id=?", (ident,)).fetchone())

    def get_job(self, owner: str, ident: str):
        with self.connection() as db:
            row = db.execute("SELECT * FROM jobs WHERE owner=? AND id=?", (owner, ident)).fetchone()
            return dict(row) if row else None

    def claim(self):
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute(
                "SELECT * FROM jobs WHERE status='pending' ORDER BY created LIMIT 1"
            ).fetchone()
            if row:
                db.execute(
                    "UPDATE jobs SET status='running',updated=? WHERE id=?",
                    (time.time(), row["id"]),
                )
            return dict(row) if row else None

    def finish(self, ident: str, status: str, error: str | None = None) -> bool:
        with self.connection() as db:
            return (
                db.execute(
                    "UPDATE jobs SET status=?,error=?,updated=? WHERE id=? AND status='running'",
                    (status, error, time.time(), ident),
                ).rowcount
                == 1
            )

    def cancel(self, owner: str, ident: str):
        with self.connection() as db:
            db.execute(
                "UPDATE jobs SET status='cancelled',updated=? "
                "WHERE owner=? AND id=? AND status IN ('pending','running')",
                (time.time(), owner, ident),
            )

    def feedback(self, owner: str, request: FeedbackRequest, limit: int):
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            count = db.execute(
                "SELECT COUNT(*) FROM feedback WHERE owner=? AND created>?",
                (owner, time.time() - 60),
            ).fetchone()[0]
            if count >= limit:
                raise CapacityError
            ident = str(uuid4())
            db.execute(
                "INSERT INTO feedback VALUES (?,?,?,?)",
                (ident, owner, request.model_dump_json(), time.time()),
            )
            return ident
