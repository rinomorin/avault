#cvault.py
from graphene import ObjectType, String, Mutation, Schema, Field
from flask import jsonify
import jwt
import datetime
from config_manager import ConfigManager
from models import CVault  # Ensure models.py is in the same directory

# Initialize CVault with your database connection (replace with actual connection)
config_manager = ConfigManager('config.xml')
SECRET_KEY = config_manager.key
db_config, api_config = config_manager.load_config()  # Correctly unpack the tuple
db_connection = config_manager.connect_to_database()

cvault = db_connection

# schema = Schema(mutation=Mutation)
class AuthToken(ObjectType):
    token = String(required=True)
    expiration = String(required=True)

# generate temp token
def getToken(username, time):
    # Generate a JWT token
    token = jwt.encode({
        'username': username,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=int(time)),  # Ensure time is an integer
        'password_expired': False  # Assume the password is not expired here
    }, SECRET_KEY, algorithm='HS256')
    
    # Set expiration time (could be adjusted as needed)
    expiration = (datetime.datetime.utcnow() + datetime.timedelta(minutes=30)).isoformat()
    
    return AuthToken(token=token, expiration=expiration)

class UpdatePassword(Mutation):
    class Arguments:
        username = String(required=True)
        old_password = String(required=False)  # Optional
        new_password = String(required=True)
        temp_token = String(required=False)  # Optional if using temp token for expired passwords

    message = String()

    # def mutate(self, info, username, old_password, new_password, temp_token=None):
    #     if temp_token:
    #         # Validate the temporary token instead of the old password
    #         try:
    #             payload = jwt.decode(temp_token, SECRET_KEY, algorithms=["HS256"])
    #             if payload["username"] != username:
    #                 raise Exception("Token does not match username")
    #         except jwt.ExpiredSignatureError:
    #             raise Exception("Temporary token has expired")
    #         except jwt.InvalidTokenError:
    #             raise Exception("Invalid token")
            
    def mutate(self, info, username, old_password, new_password):
        
        # Authenticate the old password
        auth_message = cvault.password_check(username, old_password)
        if auth_message != "Authentication successful":
            raise Exception("Old password is incorrect.")
        # Call the update password SQL function
        query = "SELECT update_password(%s, %s)"
        try:
            cvault.cursor.execute(query, (username, new_password))
            result = cvault.cursor.fetchone()
            if result:
                return UpdatePassword(message=result[0])  # Return the message from SQL function
            else:
                raise Exception("Password update failed")
        except Exception as e:
            raise Exception(f"Error during password update: {e}")

    
    
class Login(Mutation):
    class Arguments:
        username = String(required=True)
        password = String(required=True)

    auth_token = Field(AuthToken)

    def mutate(self, info, username, password):
        auth_message = cvault.authenticate(username, password)
        if auth_message == "Authentication successful":
            # Generate JWT token if authentication was successful
            token = jwt.encode({
                'username': username,
                'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=30),
                'password_expired': False  # Assume the password is not expired here
            }, SECRET_KEY, algorithm='HS256')
            
            expiration = (datetime.datetime.utcnow() + datetime.timedelta(minutes=30)).isoformat()
            return Login(auth_token=AuthToken(token=token, expiration=expiration))
        
        elif auth_message == "Password update required":
            raise Exception("Password update required. Please set a new password.")
        
        elif auth_message == "Password expired":
            # Generate a temporary token for password reset
            temp_token = getToken(username, 5)  # Adjust time to 5 minutes
            msg="Your password has expired. Please update your password.\ntemp_token: "+str(temp_token.token)+"\nToken expires in 5 minutes"
            raise Exception(msg)
        
        elif auth_message == "Account requires admin assistance":
            raise Exception("Account is locked or disabled. Please contact your administrator.")
        
        else:
            raise Exception("Invalid username or password.")





class UserType(ObjectType):
    username = String()
    first_name = String()
    last_name = String()
    email = String()
    phone = String()


class Query(ObjectType):
    get_user_info = Field(UserType, username=String(required=True))

    def resolve_get_user_info(self, info, username):
        auth_header = info.context.headers.get('Authorization')
        print("one",auth_header.split(" ")[0])
        print("two",auth_header.split(" ")[1])
        print(f"Authorization header: {auth_header}")  # Debugging line
        if auth_header:
            token = auth_header.split(" ")[1]
            try:
                decoded = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
                print("decorde",decoded['username'],"username",username)
                if decoded['username'] == username:
                    user_info = { 
                        "username": username,
                        "first_name": "Rino", 
                        "last_name": "Morin", 
                        "email": "rmorin@ca.ibm.com", 
                        "phone": "411-111-2222"
                    }  # Replace with actual query

                    return UserType(**user_info)
            except jwt.ExpiredSignatureError:
                raise Exception("Token expired")
            except jwt.InvalidTokenError:
                raise Exception("Invalid token")
        raise Exception("Authorization token required")

class CreateUser(Mutation):
    class Arguments:
        name = String(required=True)
        password = String(required=True)
        first_name = String(required=True)
        last_name = String(required=True)
        email = String(required=True)
        phone = String(required=True)

    success = String()

    def mutate(self, info, name, password, first_name, last_name, email, phone):
        try:
            # Validate and add user
            message = cvault.useradd(name, password, first_name, last_name, email, phone)
            return CreateUser(success=message)
        except Exception as e:
            raise Exception(str(e))

class DeleteUser(Mutation):
    class Arguments:
        userid = String(required=True)

    success = String()

    def mutate(self, info, userid):
        try:
            message = cvault.userdel(userid)
            return DeleteUser(success=message)
        except Exception as e:
            raise Exception(str(e))

class ModifyUser(Mutation):
    class Arguments:
        userid = String(required=True)
        action = String(required=True)
        field_name = String(required=True)
        value = String()

    success = String()

    def mutate(self, info, userid, action, field_name, value=None):
        try:
            message = cvault.usermod(userid, action, field_name, value)
            return ModifyUser(success=message)
        except Exception as e:
            raise Exception(str(e))

class GeneratePassword(Mutation):
    class Arguments:
        length = String(required=True)

    password = String()

    def mutate(self, info, length):
        try:
            password = cvault.generate_password(int(length))
            return GeneratePassword(password=password)
        except Exception as e:
            raise Exception(str(e))

class ResetPassword(Mutation):
    class Arguments:
        userid = String(required=True)
        new_password = String(required=True)

    success = String()

    def mutate(self, info, userid, new_password):
        try:
            message = cvault.userpwd(userid, new_password)
            return ResetPassword(success=message)
        except Exception as e:
            raise Exception(str(e))

class Mutation(ObjectType):
    login = Login.Field()
    create_user = CreateUser.Field()
    delete_user = DeleteUser.Field()
    modify_user = ModifyUser.Field()
    generate_password = GeneratePassword.Field()
    reset_password = ResetPassword.Field()
    update_password = UpdatePassword.Field()  # Add this line to expose the mutation

# schema = Schema(mutation=Mutation)

