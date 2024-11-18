# api_init.py
import os
import xml.etree.ElementTree as ET
from cryptography.fernet import Fernet
from lib.database import DatabaseManager
from lib.config import ConfigManager
from lib.vconst import home_base, config_file
from lib.log_mod import logit

logger = logit()

class API_init:
    def __init__(self, config_file=None):
        self.config_file = config_file
        self.cm = ConfigManager(config_file)
        self.home_base = None

    def run(self):
        self.cm.load_config()
        db_config = self.cm.get_database_config()  # Use the correct db_config
        self.db_config = db_config
        self.check_db(db_config[self.this_db])

    def set_home_base(self,home_base):
        self.home_base = home_base
    
    def set_db_setup(self,dbname):
        self.this_db = dbname
    
    def check_db(self, db_config):
        """Setup and/or connect to the database."""
        try:
            vaultdb = DatabaseManager(self.config_file, db_config)
            vaultdb.set_db_setup(self.this_db)
            vaultdb.set_home_base(self.home_base)
            vaultdb.check_and_create_db()
        except Exception as e:
            logger.info(f"Error during {self.this_db} check_db: {e}")
            raise Exception(f"Error during {self.this_db} check_db: {e}")

    def get_config(self, conf_type):
        if conf_type == "api_config":
            return self.cm.get_api_config()
        if conf_type == "db_config":
            return self.cm.get_database_config()

    def connect_db(self):
        """Connect to the database."""
        try:
            sdb = DatabaseManager(self.config_file, self.db_config[self.this_db])
            sdb.set_db_setup(self.this_db)
            conn = sdb.connect_to_db()
            return conn
        except Exception as e:
            logger.info(f"Error during connect_db: {e}")
            raise Exception(f"Error during connect_db: {e}")
