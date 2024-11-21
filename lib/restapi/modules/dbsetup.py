import xml.etree.ElementTree as ET
import psycopg2
from lib import home_base, config_file, debug
from lib.config import ConfigManager
from lib.db.modules.connection import DB_CONN

class Setup:
    def __init__(self, config_file=None):
        self.config_file = config_file
        self.cm = ConfigManager(config_file)
        self.home_base = None
        self.tree = None
        self.root = None
        self.fernet = None
        self.conf_xml=None
        self.load_config()
        self.init_db()

        # # Ensure the config file exists
        # if not os.path.exists(self.config_file):
        #     raise FileNotFoundError(f"Config file not found: {self.config_file}")
        # self.load_config()

    def load_config(self):
        """Loads and parses the XML configuration file."""
        self.tree = ET.parse(self.config_file)
        self.root = self.tree.getroot()


    def get_database_names(self):
        """Parses the XML file and returns a list of database names."""
        try:
            tree = ET.parse(self.config_file)
            root = tree.getroot()

            dbnames = []
            database_element = root.find('database')
            
            if database_element is not None:
                for db in database_element:
                    dbname = db.find('dbname')
                    if dbname is not None:
                        dbnames.append(dbname.text)
            else:
                print("No <database> section found in the XML.")
            
            return dbnames
        except Exception as e:
            print(f"Error parsing the XML file: {e}")
            return []

    # Load and parse the XML file
    # xml_file = "config.xml"  # Replace with the path to your XML file
    # db_names = .get_database_names(xml_file)

    def load_config(self):
        cm = self.cm
        self.conf_xml = cm.get_config()

    def get_api_config(self):
        """Retrieves API configuration."""
        self.tree = ET.parse(self.config_file)
        self.root = self.tree.getroot()
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


    def try_connection(self,dbconf):
        db = DB_CONN()
        try:
            print("dbconf",dbconf)
            conn=db.connect_to_db(dbconf)
            if conn:
                return conn
            else:
                print("initial connection failed to"+str(dbconf["dbname"]))
                # self.run_sql_script(cursor)
            dbconf= db.get_postgres(None, None, dbconf)
            print(dbconf)
            conn=db.connect_to_db(dbconf)
            if conn:
                print("initializing "+str(dbconf["dbname"]))
                cursor = conn.cursor()
                db.run_sql_script(cursor, dbconf)
                return conn
            print("dbconf",dbconf)
            return conn
        except psycopg2.OperationalError as e:
            print(f"\b\b\b FAILED.")
            logger.info(f"Error connecting to the database 3: {e}")
            print(f"Error connecting to the database 3: {e}")
            return None

    def init_db(self):
        cm = self.cm
        dbnames = self.get_database_names()
        db_list = {}
        for dbname in dbnames:
            if dbname == "secretdb":
                continue
            if dbname in db_list:
                print(f"Duplicate entry ignored: {dbname}")
                continue
            cm.set_dbname(dbname)
            a_list=cm.get_config()
            db_list[dbname]=a_list[dbname]
            self.try_connection(a_list[dbname])
            dbname=None
        

    


# vapi = API_init(config_file)
# api_conf = vapi.get_config("api_config")
# print(api_conf)
# # S{'hostname': '0.0.0.0', 'port': '5000', 'initial_token': 'initial_token_secret', 'token_expire_minutes': '20'}
# print(api_conf.get("hostname", "127.0.0.1"))
