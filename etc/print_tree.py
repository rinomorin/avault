
import os
from lib.vconst import home_base, config_file

test = home_base

def print_tree(directory, exclude_folders=None, prefix=""):
    """Recursively prints the tree structure of a directory, excluding specific folders."""
    if exclude_folders is None:
        exclude_folders = []

    try:
        entries = sorted(os.listdir(directory))
    except FileNotFoundError:
        print(f"Error: Directory '{directory}' not found.")
        return
    except PermissionError:
        print(f"Error: Permission denied for directory '{directory}'.")
        return

    for index, entry in enumerate(entries):
        path = os.path.join(directory, entry)
        # Skip if the folder is in the exclude list
        if any(exclude_folder in path for exclude_folder in exclude_folders):
            continue

        connector = "└── " if index == len(entries) - 1 else "├── "
        print(f"{prefix}{connector}{entry}")

        if os.path.isdir(path):
            # Recurse into the subdirectory, adjusting the prefix
            new_prefix = f"{prefix}    " if index == len(entries) - 1 else f"{prefix}│   "
            print_tree(path, exclude_folders, new_prefix)