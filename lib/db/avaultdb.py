import xml.etree.ElementTree as ET
import psycopg2
from lib import home_base, config_file, debug
from lib.config import ConfigManager
from lib.db.modules.connection import DB_CONN
from lib.log_mod import logit

logger = logit()


class AvaultDB:
    def __init__(self, conn, config_file=None):
        self.config_file = config_file
        self.conn = conn
        self.cm = ConfigManager(config_file)
        self.home_base = None
        self.tree = None
        self.root = None
        self.fernet = None
        self.conf_xml=None
        # self.load_config()

    def load_config(self):
        """Loads and parses the XML configuration file."""
        self.tree = ET.parse(self.config_file)
        self.root = self.tree.getroot()

    


