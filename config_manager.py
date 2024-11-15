import xml.etree.ElementTree as ET
from cryptography.fernet import Fernet
from models import CVault  # Ensure models.py is in the same directory
# import psycopg2

class ConfigManager:
    def __init__(self, xml_file):
        self.xml_file = xml_file
        self.key = self.load_key()
        self.fernet = Fernet(self.key)

        # Load and update the password if needed
        self.update_password_in_xml()

    def load_key(self):
        tree = ET.parse(self.xml_file)
        root = tree.getroot()

        # Check if the key is present in the <database> element
        key_element = root.find('./database/key')
        if key_element is not None:
            return key_element.text.encode()  # Return the existing key
        else:
            return self.generate_key()

    def generate_key(self):
        key = Fernet.generate_key()
        self.add_key_to_xml(key.decode())
        return key

    def add_key_to_xml(self, key):
        tree = ET.parse(self.xml_file)
        root = tree.getroot()
        
        # Find the <database> element and add the key under it
        database_element = root.find('./database')
        key_element = ET.Element('key')
        key_element.text = key
        
        database_element.append(key_element)
        tree.write(self.xml_file)

    def load_config(self):
        tree = ET.parse(self.xml_file)
        root = tree.getroot()
        
        db_config = {
            "host": root.find('./database/host').text,
            "port": root.find('./database/port').text,
            "dbname": root.find('./database/dbname').text,
            "user": root.find('./database/user').text,
            "password": self.decrypt_password(root.find('./database/password').text)
        }
        
        api_config = {
            "hostname": root.find('./api/hostname').text,
            "port": root.find('./api/port').text,
            "initial_token": root.find('./api/initial_token').text,
            "token_expire_minutes": root.find('./api/token_expire_minutes').text
        }
        self.db_config=db_config
        self.api_config = api_config
        return db_config, api_config

    def decrypt_password(self, encrypted_password):
        decrypted = self.fernet.decrypt(encrypted_password.encode()).decode()
        return decrypted

    def encrypt_password(self, password):
        return self.fernet.encrypt(password.encode()).decode()

    def update_password_in_xml(self):
        tree = ET.parse(self.xml_file)
        root = tree.getroot()
        
        password_element = root.find('./database/password')
        current_password = password_element.text

        # Check if the password is already encrypted
        try:
            self.fernet.decrypt(current_password.encode())
        except:
            # If decryption fails, encrypt the password and update it
            print("Encrypting password...")
            new_encrypted_password = self.encrypt_password(current_password)
            password_element.text = new_encrypted_password
            tree.write(self.xml_file)
            print("Password updated in XML.")

    def verify_password(self, input_password):
        db_config, _ = self.load_config()  # Unpack to get db_config
        stored_password = db_config["password"]  # Get the stored password from db_config
        return input_password == stored_password

    def connect_to_database(self):
        try:
            connection = CVault(self.db_config["dbname"], self.db_config["user"], 
                                self.db_config["password"], self.db_config["host"], 
                                self.db_config["port"])
            print("Database connection established.")
            return connection
        except Exception as e:
            print(f"Error connecting to database: {e}")
            return None


    def connect_to_database(self):
        db_config, _ = self.load_config()  # Load database config
        try:
            connection = CVault(db_config["dbname"],db_config["user"],db_config["password"],db_config["host"],db_config["port"],)
            # connection = psycopg2.connect(
            #     host=db_config["host"],
            #     port=db_config["port"],
            #     dbname=db_config["dbname"],
            #     user=db_config["user"],
            #     password=db_config["password"]
            # )
            print("Database connection established.")
            return connection
        except Exception as e:
            print(f"Error connecting to database: {e}")
            return None



