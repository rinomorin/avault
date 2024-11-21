import xml.etree.ElementTree as ET
import psycopg2
from lib import home_base, config_file, debug
from lib.config import ConfigManager
from lib.db.modules.connection import DB_CONN
from lib.log_mod import logit
from lib.db.avaultdb import AvaultDB

logger = logit()
av = AvaultDB(DB_CONN, config_file)
# av.load_config()
# api_conf = av.get_api_config()

# Define the User object type
# Class to manage user data retrieval
class UserInfo:
    def __init__(self):
         self.db = av
    @staticmethod
    def get_user_data(username):
        if username == "vadmin":
            return {
                "host": "127.0.0.1",
                "port": "5432",
                "dbname": "vaultdb",
                "user": "vadmin",
                "password": "vadmin_password",
                "description": "Vault DB system (vadmin_password)",
                "key": "dmz1nEn6Xw9vHDUOJmXp1bpn5V7eoPGIfCdQ_S4PfL4="
            }
        return None
    
    @staticmethod
    def add_user(username):
        # For simplicity, just return some mock data for the added user
        if username == "mytest":
            return {
                "host": "127.0.0.1",
                "port": "5432",
                "dbname": "vaultdb",
                "user": username,
                "password": "mytest_password",
                "description": "Test user (mytest_password)",
                "key": "newKeyForMyTestUser"
            }
        return None
