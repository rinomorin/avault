import os
import argparse
from pathlib import Path

# Get the current file's directory
current_directory = Path(__file__).resolve().parent

# Default home base path (one level up from current file)
home_base = current_directory.parents[0]

# Default config file path
default_config_file = os.path.join(home_base, "etc", "config.xml")
default_debug = False  # Default value for debug


# Set up argument parsing to override config file path and debug value
def parse_args():
    parser = argparse.ArgumentParser(description="Override config file path and debug setting.")
    
    # Argument for the config file path
    parser.add_argument(
        "-f", "--config", type=str, help="Path to the config.xml file", default=default_config_file
    )
    
    # Argument for enabling debug mode
    parser.add_argument(
        "-d", "--debug", action="store_true", help="Enable debug mode", default=default_debug
    )
    
    return parser.parse_args()

# Parse the command-line arguments
args = parse_args()

# Use the config file and debug value provided by the user, or the default ones
config_file = args.config if args.config else default_config_file
debug = args.debug  # Will be True if --debug is passed, False otherwise

print(f"Using config file: {config_file}")

print(f"Debug mode: {debug}")
