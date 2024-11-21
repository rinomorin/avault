from graphene import ObjectType, String, Field
from lib.restapi.modules.avault import User

# # Define the User object type
# class User(ObjectType):
#     host = String()
#     port = String()
#     dbname = String()
#     user = String()
#     password = String()
#     description = String()
#     key = String()

# Class to manage user data retrieval
class UserInfo:
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

# Define the Query class
class Query(ObjectType):
    hello = String(name=String(default_value="World"))
    get_user = Field(User, username=String(required=True))  # Add the username argument

    # Resolver for the hello query
    def resolve_hello(self, info, name):
        return f"Hello, {name}!"

    # Resolver for the get_user query
    def resolve_get_user(self, info, username):
        user_data = UserInfo.get_user_data(username)
        if user_data:
            return User(**user_data)
        else:
            raise Exception(f"User '{username}' not found")
