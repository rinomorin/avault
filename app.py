from flask import Flask, request, jsonify
from flask_graphql import GraphQLView
import datetime
from cvault import Mutation, Query, AuthToken, getToken
from cvault import api_config, db_connection, SECRET_KEY
from graphene import Schema
from functools import wraps
import jwt

# Initialize Flask app
app = Flask(__name__)
app.config['DEBUG'] = True
app.config['ENV'] = 'development'

# Initialize GraphQL schema with both query and mutation
schema = Schema(query=Query, mutation=Mutation)

def require_non_expired_password(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Allow login and update_password routes without any restrictions
        if request.endpoint == 'login' or request.endpoint == 'update_password':
            return f(*args, **kwargs)

        # Get the Authorization token
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({"error": "Authorization token required"}), 401

        # Decode the token to check for password_expired flag
        try:
            decoded_token = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
            if decoded_token.get('password_expired'):
                # Generate a temporary token for password reset
                temp_token = jwt.encode({
                    'username': decoded_token['username'],
                    'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=5),
                    'password_expired': True  # Ensure the temporary token retains this flag
                }, SECRET_KEY, algorithm='HS256')
                
                # Restrict access only to the update_password route if password is expired
                if request.endpoint != 'update_password':
                    return jsonify({
                        "error": "Access restricted. Update your password to continue.",
                        "temp_token": temp_token  # Provide the temporary token
                    }), 403

        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expired. Please log in again."}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Invalid token"}), 401

        return f(*args, **kwargs)
    
    return decorated_function


# Apply the middleware to all routes
@app.before_request
@require_non_expired_password
def check_password_expired():
    pass
# Login
# Login
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    # Ensure no token validation is required for login
    if username and password:
        try:
            result = schema.execute(
                '''
                mutation login($username: String!, $password: String!) {
                    login(username: $username, password: $password) {
                        authToken {
                            token
                            expiration
                        }
                    }
                }
                ''',
                variable_values={'username': username, 'password': password}
            )

            # Check if there were any errors, including password expiration
            if result.errors:
                error_message = str(result.errors[0])
                print("error_message",error_message)
                
                if "Password expired" in error_message:
                    # Generate a temporary token for password reset
                    temp_token = getToken(username, 5)  # Adjust time to 5 minutes

                    # Return the error message with the temp_token for password reset
                    return jsonify({
                        "error": "Your password has expired. Please update your password. 2",
                        "temp_token": temp_token.token,  # Provide the temporary token
                        "message": "Token expires in 5 minutes"
                    }), 403

                return jsonify({"error": error_message}), 401
            
            # Retrieve and return the auth token if authentication is successful
            auth_token = result.data['login']['authToken']['token']
            return jsonify({"token": auth_token})
        
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    else:
        return jsonify({"error": "Username and password required"}), 400


@app.route('/update_password', methods=['POST'])
def update_password():
    data = request.get_json()
    username = data.get('username')
    old_password = data.get('old_password')
    new_password = data.get('new_password')

    if username and old_password and new_password:
        try:
            result = schema.execute(
                '''
                mutation UpdatePassword($username: String!, $oldPassword: String!, $newPassword: String!) {
                    updatePassword(username: $username, oldPassword: $oldPassword, newPassword: $newPassword) {
                        message
                    }
                }
                ''',
                variable_values={'username': username, 'oldPassword': old_password, 'newPassword': new_password}
            )

            if result.errors:
                return jsonify({"error": str(result.errors[0])}), 400
            return jsonify({"message": result.data['updatePassword']['message']})
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    return jsonify({"error": "Username, old password, and new password are required"}), 400

# Token-based authentication for GraphQL requests
def token_auth_middleware(next, root, info, **args):
    auth_header = info.context.headers.get('Authorization')
    if auth_header:
        token = auth_header.split(" ")[1]  # Extract token from "Bearer <token>"
        try:
            jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            raise Exception("Token has expired")
        except jwt.InvalidTokenError:
            raise Exception("Invalid token")
    else:
        raise Exception("Authorization token is missing")
    return next(root, info, **args)

# Add GraphQL endpoint
app.add_url_rule(
    '/graphql',
    view_func=GraphQLView.as_view(
        'graphql',
        schema=schema,
        graphiql=True,
        middleware=[token_auth_middleware]  # Add token auth middleware
    )
)
## Test curl -X POST http://127.0.0.1:5000/login -H "Content-Type: application/json" -d '{"username": "admin", "password": "cvadmin_password"}'


if __name__ == "__main__":
    app.run()
