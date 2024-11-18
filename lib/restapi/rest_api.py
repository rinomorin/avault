from flask import Flask, request, jsonify
from flask_graphql import GraphQLView
import graphene
from lib.vconst import debug, config_file
from lib.config import ConfigManager, API_init

vapi = API_init(config_file)
api_conf = vapi.get_config("api_config")
print(api_conf)
# S{'hostname': '0.0.0.0', 'port': '5000', 'initial_token': 'initial_token_secret', 'token_expire_minutes': '20'}
print(api_conf.get("hostname", "127.0.0.1"))

# Initialize Flask app
app = Flask(__name__)
app.config['DEBUG'] = debug
app.config['ENV'] = 'development'
app.config['HOST'] = api_conf.get("hostname", "127.0.0.1")  # Default to '127.0.0.1' if not found
app.config['PORT'] = int(api_conf.get("port", 5000))  # Default to 5000 if not found
# app.config['CERT'] = os.getenv("SSL_CERT", "cert.pem")  # Path to SSL certificate
# app.config['KEY'] = os.getenv("SSL_KEY", "key.pem")  # Path to SSL key

# Sample in-memory user data store for this example
users = {}

# GraphQL Mutation to create a user
class CreateUser(graphene.Mutation):
    class Arguments:
        username = graphene.String(required=True)
        email = graphene.String(required=True)

    success = graphene.Boolean()
    user_id = graphene.String()

    def mutate(self, info, username, email):
        # Generate a new user ID (this can be replaced by an actual database call)
        user_id = f"user_{len(users) + 1}"
        
        # Store user data
        users[user_id] = {"username": username, "email": email}

        return CreateUser(success=True, user_id=user_id)


# Define GraphQL Query class (example query to fetch user details)
class Query(graphene.ObjectType):
    user = graphene.Field(lambda: User, user_id=graphene.String())

    def resolve_user(self, info, user_id):
        if user_id in users:
            user = users[user_id]
            return User(username=user["username"], email=user["email"], user_id=user_id)
        return None


# Define GraphQL User type
class User(graphene.ObjectType):
    username = graphene.String()
    email = graphene.String()
    user_id = graphene.String()


# Define GraphQL Mutation class to handle all mutations (e.g., createUser)
class Mutation(graphene.ObjectType):
    create_user = CreateUser.Field()


# Add GraphQL view to Flask app with GraphiQL interface enabled
app.add_url_rule('/graphql', view_func=GraphQLView.as_view('graphql', 
                                                           schema=graphene.Schema(query=Query, mutation=Mutation),
                                                           graphiql=True))


@app.route('/')
def index():
    return "Welcome to the GraphQL API!"

