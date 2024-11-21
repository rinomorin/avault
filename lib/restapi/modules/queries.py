from graphene import ObjectType, String, Field
from lib.restapi.modules.graphql import User
from lib.restapi.modules.avault import UserInfo
from lib.log_mod import logit

logger = logit()

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
