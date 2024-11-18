# db.py
import os
import psycopg2
from psycopg2 import sql
import subprocess
from cryptography.fernet import Fernet
import getpass
import xml.etree.ElementTree as ET
from lib.vconst import home_base, config_file
from lib.log_mod import logit

logger = logit()

class DatabaseManager:
    def __init__(self, config_file, dbconf):
        self.config_file = config_file
        self.dbconf = dbconf
        self.setup_info = None

    def set_home_base(self,home_base):
        self.home_base = home_base

    def set_db_setup(self,dbname):
        self.this_db = dbname

    def setup_db(self, user=None, password=None):
        """Connect to PostgreSQL database."""
        if user is None or password is None or dbname is None:
            # Get credentials if not provided
            user = input("Enter PostgreSQL username: ")
            password = getpass.getpass("Enter PostgreSQL password: ")
            dbname = "postgres"
            
            self.setup_info = { 
                "host": self.dbconf["host"],
                "dbname": dbname,
                "user": user,
                "password": password
            }

        try:
            conn = psycopg2.connect(
                host=self.dbconf["host"],
                port=self.dbconf["port"],
                dbname="postgres",
                user=user,
                password=password
            )
            logger.info(f"Connected to the database {dbname} at {self.dbconf['host']}")
            print(f"Connected to the database {dbname} at {self.dbconf['host']}")
            return conn
        except psycopg2.OperationalError as e:
            raise Exception(f"Error connecting to the database: {e}")
            return None

    def connect_to_db(self):
        dbname = self.this_db
        dbconf = self.dbconf
        host   = self.dbconf['host']
        try:
            conn = psycopg2.connect(
                host=dbconf["host"],
                port=dbconf["port"],
                dbname=dbconf['dbname'],
                user=dbconf['user'],
                password=dbconf['password']
            )
            print(f"\b\b\b OK.")
            logger.info(f"Connected to the database {dbconf['dbname']} at {dbconf['host']}")
            print(f"Connected to the database {dbconf['dbname']} at {dbconf['host']}")
            return conn
        except psycopg2.OperationalError as e:
            print(f"\b\b\b FAILED.")
            logger.info(f"Error connecting to the database 3: {e}")
            print(f"Error connecting to the database 3: {e}")
            return None

    def validate_config(self, config, db_name):
        required_keys = ["host", "port", "dbname", "user", "password", "key"]
        missing_keys = [key for key in required_keys if not config.get(key)]
        if missing_keys:
            logger.info(f"Missing keys in database configuration for {db_name}: {missing_keys}")
            raise KeyError(f"Missing keys in database configuration for {db_name}: {missing_keys}")


    def check_and_create_db(self):
        """Checks if the {self.this_db} exists, creates it if not, and runs the SQL script."""
        conn = None
        cursor = None  
        val = self.this_db
        # test conn here
        logger.info(f"check {val} communication:   ")
        print(f"check {val} communication:   ", end="", flush=True)
        try:
            # Attempt to connect to the database
            conn = self.connect_to_db()
            cursor = conn.cursor()
            logger.info(f"Database '{self.this_db}' exists.")
            print(f"Database '{self.this_db}' exists.")
            cursor.close()
            conn.close()
            return None
        except Exception as e:
            # Log the error with more detail
            logger.info(f"Error while checking database '{self.this_db}': {e}")
            print(f"Error while checking database '{self.this_db}': {e}")
            # Optional: Add any additional logic if needed (e.g., creating the database)

        # if failed
        try:
            conn = self.setup_db()
            cursor = conn.cursor()
            # Perform database checks or initialization
        except Exce.infoption as e:
            logger.info(f"Error checking database: {e}")
            raise Exception(f"Error checking database: {e}")

        if conn:
            cursor = conn.cursor()
            # Check if the {self.this_db} database exists
            cursor.execute("SELECT 1 FROM pg_catalog.pg_database WHERE datname = '{self.this_db}'")
            exists = cursor.fetchone()
            if exists:
                logger.info(f"Database '{self.this_db}' already exists.")
                print("Database '{self.this_db}' already exists.")
            else:
                logger.info(f"Database '{self.this_db}' does not exist. Creating it now...")
                logger.info(f"check_and_create {self.home_base}")
                print("Database '{self.this_db}' does not exist. Creating it now...")
                print("check_and_create",self.home_base)
                self.run_sql_script(cursor)
        cursor.close()
        conn.close()

    def modify_and_save_sql_script(self):
        """Modifies the master.sql by replacing '${inst}' with the script path."""
        home_base = self.home_base
        script_path = f"{home_base}/lib/sql/master.sql"  # Path to the original master.sql
        output_path = f"{home_base}/lib/sql/master_extend.sql"  # Path to the new master_extend.sql
        
        try:
            # Open the original master.sql to read
            with open(script_path, "r") as script_file:
                script_content = script_file.read()

            # Replace all occurrences of '${inst}' with the script_path value
            modified_content = script_content.replace("${inst}", home_base)

            # Save the modified content into a new file
            with open(output_path, "w") as output_file:
                output_file.write(modified_content)
            logger.info(f"Modified SQL script saved to {output_path}")
            print(f"Modified SQL script saved to {output_path}")
        
        except Exception as e:
            logger.info(f"Error modifying SQL script: {e}")
            print(f"Error modifying SQL script: {e}")


    def execute_psql(self,user_id, host, password, file_path):
        """Execute a psql command."""
        try:
            # Set the environment variable for the password
            env = {"PGPASSWORD": password}
            
            # Build the psql command
            command = [
                "/usr/bin/psql",
                "-U", user_id,
                "-h", host,
                "-f", file_path,
            ]
            logger.info(f"command: {command}")
            print("command",command)            
            # Run the comnmand
            result = subprocess.run(command, env=env, check=True, text=True, capture_output=True)
            logger.info("Command executed successfully:")            
            print("Command executed successfully:")
            logger.info(result.stdout)
            print(result.stdout)
        except subprocess.CalledProcessError as e:
            logger.info(f"Error executing the psql command: {e.stderr}")
            print("Error executing the psql command: ")
            print(e.stderr)
    
    def set_fernel(self,fernel):
        self.fernel = fernel

    def run_sql_script(self, cursor):
        """Runs the master.sql script to set up the database."""
        cursor.connection.rollback()  # Ensure transaction rollback if needed
        self.modify_and_save_sql_script()
        home_base = self.home_base
        script_path = f"{home_base}/lib/sql/master_extend.sql"  # Use f-string to ensure proper variable interpolation
        
        try:
            self.execute_psql(self.setup_info["user"], self.setup_info["host"], self.setup_info["password"], script_path)
            logger.info(f"SQL script executed successfully from {script_path}")
            print(f"SQL script executed successfully from {script_path}")
            if os.path.exists(script_path):
                os.remove(script_path)
        except Exception as e:
            if os.path.exists(script_path):
                os.remove(script_path)
            logger.info(f"Failed to execute SQL script: {e}"f"Failed to execute SQL script: {e}")
            print(f"Failed to execute SQL script: {e}"f"Failed to execute SQL script: {e}")
            cursor.connection.rollback()
        