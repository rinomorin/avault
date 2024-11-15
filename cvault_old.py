import os
import random
import string
from datetime import datetime, timedelta
from cryptography.fernet import Fernet
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base, Secret, User
import secrets

class Vault:
    def __init__(self, db_url='sqlite:///secrets.db'):
        self.engine = create_engine(db_url)
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.key = Fernet.generate_key()
        self.cipher = Fernet(self.key)

        self.min_len = int(os.getenv("MINLEN", 16))
        self.max_len = int(os.getenv("MAXLEN", 63))
        self.upper = int(os.getenv("UPPER", 1))
        self.lower = int(os.getenv("LOWER", 1))
        self.number = int(os.getenv("NUMBER", 1))
        self.special = int(os.getenv("SPECIAL", 1))
        self.special_chars = os.getenv("SPECIAL_CHAR", "~@#%^-_=+")
        self.JWT_SECRET = os.getenv("JWT_SECRET") 

    def generate_password(self, length=16):
        if length < self.min_len or length > self.max_len:
            raise ValueError(f"Password length must be between {self.min_len} and {self.max_len}")

        # Ensure the password meets the specified criteria
        password_chars = []
        if self.upper > 0:
            password_chars.append(random.choice(string.ascii_uppercase))
        if self.lower > 0:
            password_chars.append(random.choice(string.ascii_lowercase))
        if self.number > 0:
            password_chars.append(random.choice(string.digits))
        if self.special > 0:
            password_chars.append(random.choice(self.special_chars))

        # Fill the remaining length with a mix of all allowed characters
        all_chars = string.ascii_letters + string.digits + self.special_chars
        while len(password_chars) < length:
            password_chars.append(random.choice(all_chars))

        random.shuffle(password_chars)  # Shuffle to ensure randomness
        return ''.join(password_chars)

    def validate_password(self, password):
        if len(password) < self.min_len or len(password) > self.max_len:
            return False

        if self.upper > 0 and sum(1 for c in password if c.isupper()) < self.upper:
            return False
        if self.lower > 0 and sum(1 for c in password if c.islower()) < self.lower:
            return False
        if self.number > 0 and sum(1 for c in password if c.isdigit()) < self.number:
            return False
        if self.special > 0 and sum(1 for c in password if c in self.special_chars) < self.special:
            return False

        return True
    
    # Generate a secure API token
    def generate_api_token(self, length=32):
        return secrets.token_hex(length // 2)  # Generates a secure token
    
    def add_user(self, username, hostname, ssh_key, key_password):
        session = self.Session()
        try:
            encrypted_key_password = self.cipher.encrypt(key_password.encode()).decode()
            user = User(username=username, hostname=hostname, ssh_key=ssh_key, key_password=encrypted_key_password)
            session.add(user)
            session.commit()
        except Exception as e:
            session.rollback()  # Rollback on error
            print(f"Error adding user: {e}")
        finally:
            session.close()

    # def add_secret(self, name, value, username, checkout_time_limit=None):
    def add_secret(self, hostname, password, username, key_password, checkout_time_limit=None):
        session = self.Session()
        try:            
            encrypted_password = self.cipher.encrypt(password.encode()).decode()
            encrypted_key_password = self.cipher.encrypt(key_password.encode()).decode()
            user = session.query(User).filter_by(username=username).first()
            if user is None:
                print(f"User '{username}' not found.")
                return
            secret = Secret(user_id=user.id, password=encrypted_password, hostname=hostname,
                        key_password=self.cipher.encrypt(key_password.encode()).decode(), 
                        token=self.generate_api_token(),  # Assuming you have a token generation method
                        checkout_time_limit=checkout_time_limit)
            session.add(secret)
            session.commit()
        except Exception as e:
            session.rollback()  # Rollback on error
            print(f"Error adding secret: {e}")
        finally:
            session.close()

    def get_secret(self, name):
        session = self.Session()
        try:
            secret = session.query(Secret).filter_by(name=name).order_by(Secret.version.desc()).first()
            if secret:
                decrypted_value = self.cipher.decrypt(secret.value.encode()).decode()
                return {
                    'name': secret.name,
                    'value': decrypted_value,
                    'version': secret.version,
                    'last_checked_out': secret.last_checked_out,
                    'checked_out': secret.checked_out
                }
            return None
        except Exception as e:
            print(f"Error retrieving secret '{name}': {e}")
            return None
        finally:
            session.close()

    def update_secret(self, name, value):
        session = self.Session()
        try:
            secret = session.query(Secret).filter_by(name=name).order_by(Secret.version.desc()).first()
            if secret:
                encrypted_value = self.cipher.encrypt(value.encode()).decode()
                secret.value = encrypted_value
                secret.version += 1
                secret.last_password_check = datetime.utcnow()
                session.commit()
            else:
                print(f"Secret '{name}' not found for update.")
        except Exception as e:
            session.rollback()  # Rollback on error
            print(f"Error updating secret '{name}': {e}")
        finally:
            session.close()

    def checkout_secret(self, name):
        session = self.Session()
        try:
            secret = session.query(Secret).filter_by(name=name).first()
            if secret and not secret.checked_out:
                secret.checked_out = 1
                secret.last_checked_out = datetime.utcnow()
                session.commit()
            else:
                print(f"Secret '{name}' not found or already checked out.")
        except Exception as e:
            session.rollback()  # Rollback on error
            print(f"Error checking out secret '{name}': {e}")
        finally:
            session.close()

    def checkin_secret(self, name):
        session = self.Session()
        try:
            secret = session.query(Secret).filter_by(name=name).first()
            if secret and secret.checked_out:
                secret.checked_out = 0
                session.commit()
            else:
                print(f"Secret '{name}' not found or not checked out.")
        except Exception as e:
            session.rollback()  # Rollback on error
            print(f"Error checking in secret '{name}': {e}")
        finally:
            session.close()

    def rotate_secret(self, name):
        session = self.Session()
        try:
            secret = session.query(Secret).filter_by(name=name).first()
            if secret:
                new_password = self.generate_password()
                self.update_secret(name, new_password)
            else:
                print(f"Secret '{name}' not found for rotation.")
        except Exception as e:
            print(f"Error rotating secret '{name}': {e}")
        finally:
            session.close()

    def auto_checkin(self):
        session = self.Session()
        try:
            current_time = datetime.utcnow()
            secrets = session.query(Secret).all()
            for secret in secrets:
                if secret.checked_out:
                    if secret.checkout_time_limit:
                        if current_time - secret.last_checked_out >= timedelta(seconds=secret.checkout_time_limit):
                            secret.checked_out = 0  # Auto check-in
            session.commit()
        except Exception as e:
            session.rollback()  # Rollback on error
            print(f"Error during auto check-in: {e}")
        finally:
            session.close()
