# rest api
from flask import Flask, request, jsonify
from flask_graphql import GraphQLView
from graphene import Schema
from lib.restapi.modules.dbsetup import Setup
from lib import home_base, config_file, debug  
from lib.restapi.modules.queries import Query
from lib.restapi.modules.mutations import Mutation

ap=Setup(config_file)
ap.load_config()
api_conf = ap.get_api_config()

class Loading():
    def __init__(self, config_file):
        self.config_file = config_file
        self.api_conf = api_conf
        return self.api_conf
        
    def junk(self):
        return "loading....."+str(s)


# Initialize Flask app
app = Flask(__name__)
app.config['DEBUG'] = debug
app.config['ENV'] = 'development'
app.config['HOST'] = api_conf.get("hostname", "127.0.0.1")  # Default to '127.0.0.1' if not found
app.config['PORT'] = int(api_conf.get("port", 5000))  # Default to 5000 if not found
# app.config['CERT'] = os.getenv("SSL_CERT", "cert.pem")  # Path to SSL certificate
# app.config['KEY'] = os.getenv("SSL_KEY", "key.pem")  # Path to SSL key

@app.route('/')
def index():
    return None

# Optionally add a route for adding user
@app.route('/add_user', methods=['POST'])
def add_user():
    # Logic to add user (this could be done via GraphQL mutation, but for REST endpoint)
    return jsonify({"message": "User added successfully"})

# @app.route('/update_password', methods=['POST'])
# def update_password():
#     return adb.update_password()


schema = Schema(query=Query, mutation=Mutation)

# Add GraphQL route
app.add_url_rule(
    '/graphql',
    view_func=GraphQLView.as_view(
        'graphql',
        schema=schema,
        graphiql=True  # Enable GraphiQL interface
    )
)

