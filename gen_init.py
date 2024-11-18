import os

def create_init_py_with_content(directory, content=""):
    """Creates an __init__.py file with custom content."""
    init_file = os.path.join(directory, "__init__.py")
    if not os.path.exists(init_file):
        with open(init_file, "w") as f:
            f.write(content)
        print(f"Created {init_file} with content.")
    else:
        print(f"__init__.py already exists in {directory}")

def create_init_files_in_subdirectories(base_dir, content=""):
    """Create __init__.py files in all subdirectories, excluding 'tmp' and '.git'."""
    for root, dirs, files in os.walk(base_dir):
        # Exclude 'tmp' and '.git' directories
        dirs[:] = [d for d in dirs if d not in ("tmp", ".git", "vrel9")]

        # Skip files in root, create __init__.py only in directories
        if os.path.isdir(root):
            create_init_py_with_content(root, content)

if __name__ == "__main__":
    directory = input("Enter the directory path to create __init__.py in subdirectories: ").strip()
    default_content = "# Initialization code or imports\n"
    
    if os.path.isdir(directory):
        create_init_files_in_subdirectories(directory, default_content)
    else:
        print(f"The specified path is not a directory: {directory}")
