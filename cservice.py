import requests
import psycopg2
from psycopg2 import sql

class CVaultAPI:
    def __init__(self, api_url, db_config):
        self.api_url = api_url
        self.bearer_token = None
        self.connection = self.connect_db(db_config)

    def connect_db(self, db_config):
        """
        Establish a connection to the PostgreSQL database.

        Parameters:
            db_config (dict): Database configuration parameters.

        Returns:
            connection: PostgreSQL database connection object.
        """
        try:
            connection = psycopg2.connect(**db_config)
            return connection
        except Exception as e:
            print(f"Database connection error: {e}")
            return None

    def login(self, user_id, password):
        """
        Login to the CVault API and obtain a bearer token.

        Parameters:
            user_id (str): The user ID for login.
            password (str): The password for login.

        Returns:
            str: The bearer token if login is successful, None otherwise.
        """
        login_url = f"{self.api_url}/login"
        credentials = {
            'userid': user_id,
            'password': password
        }

        try:
            response = requests.post(login_url, json=credentials)
            response.raise_for_status()
            self.bearer_token = response.json().get('token')
            return self.bearer_token
        except requests.exceptions.HTTPError as err:
            print(f"Login failed: {err}")
            return None

    def verify_token(self):
        """
        Verify the bearer token by making an authenticated request to the API.

        Returns:
            bool: True if the token is valid, False otherwise.
        """
        verify_url = f"{self.api_url}/verify"
        headers = {
            'Authorization': f'Bearer {self.bearer_token}'
        }

        try:
            response = requests.get(verify_url, headers=headers)
            response.raise_for_status()
            return True
        except requests.exceptions.HTTPError as err:
            print(f"Token verification failed: {err}")
            return False

    def get_user_info(self, user_id):
        """
        Retrieve user information from the PostgreSQL database.

        Parameters:
            user_id (str): The user ID to retrieve information for.

        Returns:
            dict: User information if found, None otherwise.
        """
        with self.connection.cursor() as cursor:
            query = sql.SQL("SELECT * FROM users WHERE userid = %s")
            cursor.execute(query, (user_id,))
            user_info = cursor.fetchone()
            return user_info

    def close_db(self):
        """Close the database connection."""
        if self.connection:
            self.connection.close()


# Example Usage
if __name__ == "__main__":
    db_config = {
        'dbname': 'your_database_name',
        'user': 'your_db_user',
        'password': 'your_db_password',
        'host': 'localhost',
        'port': '5432'
    }

    api = CVaultAPI(api_url="https://your-cvault-api-url.com", db_config=db_config)

    # Login and obtain the bearer token
    token = api.login(user_id="your_user_id", password="your_password")
    if token:
        print("Bearer Token:", token)

        # Verify the bearer token
        is_valid = api.verify_token()
        print("Is token valid?", is_valid)

        # Get user info from the database
        user_info = api.get_user_info("your_user_id")
        print("User Info:", user_info)

    # Close the database connection
    api.close_db()
