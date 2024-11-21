# server.py
import os
from lib import logit
from lib.restapi.rest_api import Loading, app
from lib.db.dbsetup import Setup
from lib import home_base, config_file, debug

logger = logit()
logger.info("starting")

ap=Setup(config_file)
ap.load_config()
api_conf = ap.get_api_config()

# Start the service
if __name__ == "__main__":
    app.run(host=api_conf['hostname'], port=api_conf['port'])
