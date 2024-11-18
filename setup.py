from setuptools import setup, find_packages

# Read requirements from the requirements.txt file
with open("etc/requirements.txt", "r") as req_file:
    requirements = req_file.read().splitlines()

setup(
    name="avault",
    version="0.1.0",
    description="A modular vault application.",
    author="Your Name",
    author_email="your_email@example.com",
    packages=find_packages(),
    include_package_data=True,
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "avault-server=server:main",  # Example entry point
        ],
    },
)
