from graphene import ObjectType, String, Field, Mutation
from lib.restapi.modules.avault import User  # Assuming this is where the User class is defined

# Define the static method for adding a user
class UserDefine:
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

# Define the Mutation class to handle user creation
class SetUser(Mutation):
    class Arguments:
        username = String(required=True)

    # Output fields for the mutation
    user = Field(User)

    # Resolver for the mutation
    def mutate(self, info, username):
        user_data = UserDefine.add_user(username)
        if user_data:
            user = User(**user_data)  # Create a User instance
            return SetUser(user=user)  # Return an instance of SetUser containing the user
        else:
            raise Exception(f"Failed to add user '{username}'")

# The main Mutation class which includes all mutations
class Mutation(ObjectType):
    add_user = SetUser.Field()  # Register the add_user mutation
