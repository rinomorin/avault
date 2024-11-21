# graphql.py
from graphene import ObjectType, String
from lib.log_mod import logit

logger = logit()


class User(ObjectType):
    host = String()
    port = String()
    dbname = String()
    user = String()
    password = String()
    description = String()
    key = String()