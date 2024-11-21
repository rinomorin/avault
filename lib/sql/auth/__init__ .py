# ./lib/sql/defaults/_init_.py
# Initialization for the sql.defaults subpackage

GROUPS_SQL = "lib/sql/auth/groups.sql"
PASSWORD_SQL = "lib/sql/auth/password.sql"
USERS_SQL = "lib/sql/auth/users.sql"

__all__ = ["GROUPS_SQL","PASSWORD_SQL","USERS_SQL"]
