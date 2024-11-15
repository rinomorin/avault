import random
import string
import re
import psycopg2
from psycopg2 import sql

# usage: from models import CVault
class CVault:
    def __init__(self, db_name, user, password, host='localhost', port='5432'):
        self.connection = None
        self.cursor = None
        self.connect(db_name, user, password, host, port)

    def connect(self, db_name, user, password, host, port):
        try:
            self.connection = psycopg2.connect(
                dbname=db_name,
                user=user,
                password=password,
                host=host,
                port=port
            )
            self.cursor = self.connection.cursor()
            print("Database connection successful.")
        except Exception as e:
            print(f"Error connecting to the database: {e}")

    def authenticate(self, username, password):
        query = "SELECT authenticate_user(%s, %s)"
        try:
            self.cursor.execute(query, (username, password))
            result = self.cursor.fetchone()
            print(result)
            if result:
                print(result[0])
                return result[0]  # Returns the message from the stored procedure
            else:
                return "Authentication failed"
        except Exception as e:
            print(f"Error during authentication: {e}")
            return "Error during authentication"

    def password_check(self, username, password):
        query = "SELECT password_check(%s, %s)"
        try:
            self.cursor.execute(query, (username, password))
            result = self.cursor.fetchone()
            print(result)
            if result:
                print(result[0])
                return result[0]  # Returns the message from the stored procedure
            else:
                return "Authentication failed"
        except Exception as e:
            print(f"Error during authentication: {e}")
            return "Error during authentication"
        
    def close(self):
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            print("Database connection closed.")

    def execute_query(self, query, params=None):
        self.cursor.execute(query, params)
        return self.cursor.fetchall()

    def commit(self):
        self.connection.commit()
    
    def validate_password(self, password):
        """Validate the given password based on certain rules."""
        if len(password) < 8:
            raise ValueError("Password must be at least 8 characters long.")
        if not re.search(r"[A-Z]", password):
            raise ValueError("Password must contain at least one uppercase letter.")
        if not re.search(r"[a-z]", password):
            raise ValueError("Password must contain at least one lowercase letter.")
        if not re.search(r"[0-9]", password):
            raise ValueError("Password must contain at least one digit.")
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
            raise ValueError("Password must contain at least one special character.")
        return True

    def generate_password(self, length=12):
        """Generate a secure random password."""
        if length < 8:
            raise ValueError("Password length must be at least 8 characters.")
        
        characters = string.ascii_letters + string.digits + string.punctuation
        password = ''.join(random.choice(characters) for _ in range(length))
        
        # Ensure the generated password is valid
        self.validate_password(password)
        return password

    def useradd(self, name, password, first_name, last_name, email, phone):
        """Add a new user, ensuring permissions are validated."""
        try:
            self.validate_password(password)
            # Simulate permission check for ACL admins
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can add users.")
            # Insert user logic goes here (not directly shown)
            return f"User {name} added successfully."
        except Exception as e:
            return str(e)

    def usermod(self, userid, action, field_name, value=None):
        """Modify user information."""
        try:
            # Simulate permission check
            if not self.lookup_acl_admins_or_owner(userid):
                raise PermissionError("Only ACL admins or owners can modify users.")
            # Update logic goes here (not directly shown)
            return f"User {userid} modified successfully."
        except Exception as e:
            return str(e)

    def userpwd(self, userid, password, value=None):
        """Change a user's password."""
        try:
            self.validate_password(password)
            # Simulate permission check
            if not self.lookup_acl_admins_or_owner(userid):
                raise PermissionError("Only ACL admins or owners can change passwords.")
            # Update password logic goes here (not directly shown)
            return f"Password for user {userid} changed successfully."
        except Exception as e:
            return str(e)

    def userdel(self, userid):
        """Delete a user."""
        try:
            # Simulate permission check
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can delete users.")
            # Delete logic goes here (not directly shown)
            return f"User {userid} deleted successfully."
        except Exception as e:
            return str(e)

    def groupadd(self, groupname, acl_permission):
        """Add a new group."""
        try:
            # Simulate permission check
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can add groups.")
            # Group addition logic goes here (not directly shown)
            return f"Group {groupname} added successfully."
        except Exception as e:
            return str(e)

    def groupaddMember(self, groupname, newmember):
        """Add a member to a group."""
        try:
            # Simulate permission check
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can add members to groups.")
            # Logic to add member goes here (not directly shown)
            return f"Member {newmember} added to group {groupname}."
        except Exception as e:
            return str(e)

    def groupdelMember(self, groupname, newmember):
        """Remove a member from a group."""
        try:
            # Simulate permission check
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can remove members from groups.")
            # Logic to remove member goes here (not directly shown)
            return f"Member {newmember} removed from group {groupname}."
        except Exception as e:
            return str(e)

    def checkreval(self):
        """Check review status for users."""
        try:
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can check reval status.")
            # Logic to check reval status goes here (not directly shown)
            return "Reval check completed."
        except Exception as e:
            return str(e)

    def userreval(self, username, reviewdate, reviewedby):
        """Re-evaluate a user's status."""
        try:
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can re-evaluate users.")
            # Logic to re-evaluate user goes here (not directly shown)
            return f"User {username} re-evaluated successfully."
        except Exception as e:
            return str(e)

    def groupreval(self):
        """Re-evaluate groups."""
        try:
            if not self.lookup_acl_admins():
                raise PermissionError("Only ACL admins can re-evaluate groups.")
            # Logic to re-evaluate groups goes here (not directly shown)
            return "Group re-evaluation completed."
        except Exception as e:
            return str(e)

    def lookup_acl_admins(self):
        """Check if the user has ACL admin rights."""
        # Placeholder for actual ACL check logic
        return True  # Replace with actual check

    def lookup_acl_admins_or_owner(self, userid):
        """Check if the user is either an ACL admin or the owner."""
        # Placeholder for actual ACL check logic
        return True  # Replace with actual check
