# config.py
import os
import os
import xml.etree.ElementTree as ET
from cryptography.fernet import Fernet
# from lib.db import DatabaseManager
from lib import home_base, config_file , logit

logger = logit()


class ConfigManager:
    def __init__(self, config_file):
        self.config_file = config_file
        self.tree = None
        self.root = None
        self.fernet = None

        # Ensure the config file exists
        if not os.path.exists(self.config_file):
            raise FileNotFoundError(f"Config file not found: {self.config_file}")
        self.load_config()

    def load_config(self):
        """Loads and parses the XML configuration file."""
        self.tree = ET.parse(self.config_file)
        self.root = self.tree.getroot()

    def set_dbname(self,dbname):
        self.this_db = dbname


    def get_config(self):
        """Retrieves database configuration for {self.this_db} and secretdb."""
        dbConfigs = {}  # Use a dictionary to store configurations for different databases

        # Iterate over each database type
        for this_db in ["vaultdb", "secretdb"]:
            db_config = self.root.find(f"database/{this_db}")
            self.thisdb = this_db
            self.set_fernet()
            if db_config is None:
                logger.info("No <database> section found for {this_db} in config")
                raise ValueError(f"No <database> section found for {this_db} in config")

            config = {
                "host": db_config.findtext("host"),
                "port": db_config.findtext("port"),
                "dbname": db_config.findtext("dbname"),
                "user": db_config.findtext("user"),
                "password": self.decrypt_password(db_config.findtext("password")),
                "description": db_config.findtext("description"),
                "key": db_config.findtext("key"),
            }
            # Encrypt the password if not encrypted
            if not self.is_encrypted(db_config.findtext("password")):
                password = self.encrypt_password(this_db,config["password"])
                self.update_password(db_config, password)
                # config["password"] = self.decrypt_password(this_db,config["password"])
            dbConfigs[this_db] = config  # Store the config under its db name

        return dbConfigs

    def get_api_config(self):
        """Retrieves API configuration."""
        api_config = self.root.find("api")
        if api_config is None:
            logger.info("No <api> section found in config.xml")
            raise ValueError("No <api> section found in config.xml")

        return {
            "hostname": api_config.findtext("hostname"),
            "port": api_config.findtext("port"),
            "initial_token": api_config.findtext("initial_token"),
            "token_expire_minutes": api_config.findtext("token_expire_minutes"),
        }

    def is_encrypted(self, value):
        """Checks if the password appears to be encrypted."""
        if value.startswith('gAAAAA'):
            return True

        try:
            self.fernet.decrypt(value.encode())
            # Fernet(value.encode())
            return True
        except Exception:
            return False

    def set_home_base(self,home_base):
        self.home_base = home_base

    def set_fernet(self):
        # Dynamically build the XPath to fetch the correct key for the database
        dbname = self.thisdb
        key = self.root.findtext(f"database/{dbname}/key")
        if not key:
            raise ValueError(f"Encryption key not found for database '{dbname}' in config.xml")
        self.fernet = Fernet(key.encode())
        return Fernet(key.encode())

    def encrypt_password(self, dbname, password):
        """Encrypts the given password."""
        fernet = self.fernet
        return fernet.encrypt(password.encode()).decode()

    def decrypt_password(self, password=None):
        """Decrypts the given password."""
        if password is None:
            raise ValueError("Password cannot be None.")
        
        if password.startswith("gAAAAA"):
            encout = self.fernet.decrypt(password.encode()).decode()
        
        if encout.startswith("b'") and encout.endswith("'"):
            encout = encout[2:-1]
        
        return encout

    def update_password(self, db_config, encrypted_password):
        """Updates the encrypted password in the XML file."""
        db_config.find("password").text = encrypted_password
        self.save_config()

    def save_config(self):
        """Writes changes back to the XML file."""
        self.tree.write(self.config_file, encoding="utf-8", xml_declaration=True)

