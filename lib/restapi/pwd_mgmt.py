from graphene import ObjectType, String, Mutation, Schema, Field

class UpdatePassword(Mutation):
    class Arguments:
        username = String(required=True)
        old_password = String(required=False)  # Optional
        new_password = String(required=True)
        temp_token = String(required=False)  # Optional if using temp token for expired passwords

    message = String()
            
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
