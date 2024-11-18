# server.py
import os
from lib.restapi import app  # Ensure you're importing the actual Flask app instance
from etc.print_tree import  print_tree
from lib.services import db_services
from lib.services.db_services import vdb, dbServices


# if app.config['DEBUG']:
#     print(vdb.get_config("api_config"))
#     print(vdb.get_config("db_config"))

# Start the service
if __name__ == "__main__":
    # base_dir = os.path.dirname(os.path.abspath("app.py"))
    # print(f"Tree structure for '{base_dir}':\n")
    # print_tree(base_dir, exclude_folders=["vrel9", "tmp", ".git"])
    dbServices()
    app.run(host=app.config['HOST'], port=app.config['PORT'])