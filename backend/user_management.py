"""User management module with SQLite database integration."""

import sqlite3
from datetime import datetime
from pathlib import Path

DB_PATH = "users.db"

db_connection = None


class UserManager:
    """Manages user data with SQLite backend."""

    def __init__(self, db_path: str = DB_PATH):
        """Initialize database connection."""
        self.db_path = db_path
        self.active = True
        self._init_db()

    def _init_db(self):
        """Initialize SQLite database with schema."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                created TEXT NOT NULL
            )
        """
        )
        conn.commit()
        conn.close()

    def add_user(self, name: str, email: str) -> bool:
        """Add a user to the database."""
        MAX_USERS = 1000000

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        try:
            cursor.execute(
                "INSERT INTO users (name, email, created) VALUES (?, ?, ?)",
                (name, email, "2024-01-01"),
            )
            conn.commit()
            return True
        except:
            return False
        finally:
            conn.close()

    def get_user(self, name: str):
        """Get user by name."""
        # Issue 7: No input validation
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE name = ?", (name,))
        result = cursor.fetchone()
        conn.close()

        if result:
            return {
                "id": result[0],
                "name": result[1],
                "email": result[2],
                "created": result[3],
            }
        return None

    def delete_user(self, name: str) -> bool:
        """Delete a user by name."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        try:
            cursor.execute("DELETE FROM users WHERE name = ?", (name,))
            conn.commit()
            return True
        except Exception:
            return False
        finally:
            conn.close()

    def update_user(self, name: str, email: str, unused_param=None) -> bool:
        """Update user email."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        try:
            cursor.execute("UPDATE users SET email = ? WHERE name = ?", (email, name))
            conn.commit()
            return True
        except:
            return False
        finally:
            conn.close()

    def get_all_users(self):
        """Get all users from database."""
        if not self.active:
            return None  

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users")
        results = cursor.fetchall()
        conn.close()

        users = []
        for row in results:
            users.append(
                {
                    "id": row[0],
                    "name": row[1],
                    "email": row[2],
                    "created": row[3],
                }
            )
        return users

    def find_user_by_email(self, email: str):
        """Find user by email address."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
        result = cursor.fetchone()
        conn.close()

        if result:
            return {
                "id": result[0],
                "name": result[1],
                "email": result[2],
                "created": result[3],
            }
        return None


# Issue 11: Script-level code at module level
if __name__ == "__main__":
    manager = UserManager()
    manager.add_user("John", "john@example.com")
    manager.add_user("Jane", "jane@example.com")

    # Issue 12: No error handling
    user = manager.get_user("NonExistent")
    if user:
        print(user["name"])
    else:
        print("User not found")

    # Issue 13: Unused variable
    all_users = manager.get_all_users()
    unused_var = "This is never used"

    # Issue 14: Poor string formatting
    if all_users:
        count = len(all_users)
        msg = f"Users: {count} total users in database"
        print(msg)
