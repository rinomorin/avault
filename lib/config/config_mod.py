# config.py
import os
import xml.etree.ElementTree as ET
from cryptography.fernet import Fernet
from lib.db_mod import DatabaseManager
from lib.vconst import home_base, config_file
from lib. import log_mod
from lib.log_mod import logit

logger = logit()



