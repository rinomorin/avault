# Define the User object type
from graphene import ObjectType, String


class User(ObjectType):
    host = String()
    port = String()
    dbname = String()
    user = String()
    password = String()
    description = String()
    key = String()