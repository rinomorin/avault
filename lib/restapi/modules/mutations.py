from graphene import ObjectType, String, Field, Mutation
from lib.restapi.modules.graphql import User  # Assuming this is where the User class is defined
from lib.restapi.modules.avault import UserInfo
from lib.log_mod import logit

logger = logit()


# Define the Mutation class to handle user creation
class SetUser(Mutation):
    class Arguments:
        username = String(required=True)

    # Output fields for the mutation
    user = Field(User)

    # Resolver for the mutation
    def mutate(self, info, username):
        user_data = UserInfo.add_user(username)
        if user_data:
            user = User(**user_data)  # Create a User instance
            return SetUser(user=user)  # Return an instance of SetUser containing the user
        else:
            raise Exception(f"Failed to add user '{username}'")

# The main Mutation class which includes all mutations
class Mutation(ObjectType):
    add_user = SetUser.Field()  # Register the add_user mutation
