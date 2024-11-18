import logging
import os
from lib.vconst import home_base

def logit():

    log_file= os.path.join(home_base, "logs", "vault.log")
    if log_file:
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    # Configure the logger
    logging.basicConfig(
        filename=log_file,  # Specify your log file path
        level=logging.DEBUG,  # Set the minimum log level
        format='%(asctime)s - %(levelname)s - %(message)s',  # Log format
    )

    return logging.getLogger()
