import ast
import os

# Function to read and parse app.py
def parse_app(app_path):
    """Reads the app.py file and parses it into an AST."""
    with open(app_path, "r") as f:
        tree = ast.parse(f.read(), filename=app_path)
    return tree

# Function to extract function definitions and their calls
def extract_functions_and_calls(tree):
    """Extracts function definitions and calls from the AST."""
    functions = {}
    function_stack = []  # Stack to keep track of current function scope
    imports = set()  # Set to store unique imports

    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            functions[node.name] = {"dependencies": [], "imports": []}
            function_stack.append(node.name)  # Push function onto the stack
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                # Track function calls inside other functions
                if function_stack:
                    current_function = function_stack[-1]  # Top of the stack is the current function
                    functions[current_function]["dependencies"].append(node.func.id)
        elif isinstance(node, ast.Import):
            for alias in node.names:
                imports.add(alias.name)  # Add the import to the set
        elif isinstance(node, ast.ImportFrom):
            for alias in node.names:
                imports.add(f"{node.module}.{alias.name}")  # Add the import with its module name
    
    return functions, imports

# Function to generate a function flowchart
def generate_function_flowchart(app_path):
    """Generates a function flowchart by analyzing function calls."""
    tree = parse_app(app_path)
    functions, imports = extract_functions_and_calls(tree)
    
    return functions, imports

# Function to print the flowchart
def print_flowchart(functions, imports):
    """Prints the function flowchart with dependencies and imports."""
    print(f"Imports: {', '.join(sorted(imports))}")
    print("\nFunction Flowchart:")
    
    for func, data in functions.items():
        print(f"\nFunction: {func}")
        if data["dependencies"]:
            print(f"  -> Calls: {', '.join(data['dependencies'])}")
        else:
            print(f"  -> No dependencies")
        if data["imports"]:
            print(f"  -> Local Imports: {', '.join(sorted(data['imports']))}")
        else:
            print(f"  -> No local imports")

# Example usage
if __name__ == "__main__":
    app_path = "/opt/Games/code/avault/server.py"  # Path to your app.py

    functions, imports = generate_function_flowchart(app_path)
    print_flowchart(functions, imports)
