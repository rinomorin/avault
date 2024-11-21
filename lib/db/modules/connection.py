
import os
import psycopg2
from psycopg2 import sql
import subprocess
import getpass
from lib.vconst import home_base, config_file
from lib.log_mod import logit

logger = logit()

class DB_CONN:
    def __init__(self, config_file=None):
        # self.config_file = config_file
        # self.cm = ConfigManager(config_file)
        self.home_base = home_base
        # self.conf_xml=None
        # self.load_config()
        # self.init_db()

    def get_postgres(self, user=None, password=None, dbconf=None):
        print(dbconf)
        """Connect to PostgreSQL database."""
        if user is None or password is None or dbname is None:
            # Get credentials if not provided
            user = input("Enter PostgreSQL username: ")
            password = getpass.getpass("Enter PostgreSQL password: ")
            dbconf["dbname"] = "postgres"
            dbconf["user"] = user
            dbconf["password"] = password
            return dbconf

    def connect_to_db(self, dbconf):
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


    def run_sql_script(self, cursor, dbconf):
        """Runs the master.sql script to set up the database."""
        print(home_base)
        cursor.connection.rollback()  # Ensure transaction rollback if needed
        self.modify_and_save_sql_script()
        # home_base = self.home_base
        script_path = f"{home_base}/lib/sql/master_extend.sql"  # Use f-string to ensure proper variable interpolation
        
        try:
            self.execute_psql(dbconf["user"], dbconf["host"], dbconf["password"], script_path)
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

    def modify_and_save_sql_script(self):
        """Modifies the master.sql by replacing '${inst}' with the script path."""
        home_base = self.home_base
        script_path = f"{home_base}/lib/sql/master.sql"  # Path to the original master.sql
        output_path = f"{home_base}/lib/sql/master_extend.sql"  # Path to the new master_extend.sql
        print(script_path)
        print(output_path)
        
        try:
            # Open the original master.sql to read
            with open(script_path, "r") as script_file:
                script_content = script_file.read()

            # Replace all occurrences of '${inst}' with the script_path value
            modified_content = script_content.replace("${inst}", str(home_base))

            # Save the modified content into a new file
            with open(output_path, "w") as output_file:
                output_file.write(modified_content)
            logger.info("Modified SQL script saved to {output_path}")
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