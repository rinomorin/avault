from flask import Flask, request, jsonify
from flask_graphql import GraphQLView
from sqlalchemy import create_engine, Column, Integer, String, DateTime, func, Interval
from sqlalchemy.orm import sessionmaker, declarative_base
from passlib.context import CryptContext
import os

# Initialize Flask app
app = Flask(__name__)

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://cvadmin:your_cvadmin_password@localhost/cvault")
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)
Base = declarative_base()

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Define the Vault model
class Vault(Base):
    __tablename__ = 'vault'
    id = Column(Integer, primary_key=True)
    username = Column(String, nullable=False)
    password = Column(String, nullable=False)
    hostname = Column(String, nullable=False)
    ssh_key = Column(String, nullable=False)
    ssh_password = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    last_checkout = Column(DateTime)
    last_checkin = Column(DateTime)
    checkout_time_limit = Column(Interval)

# Create the database tables
Base.metadata.create_all(engine)

# Helper functions
def execute_query(query, *args):
    session = Session()
    try:
        result = session.execute(query, args)
        session.commit()
        return result
    except Exception as e:
        session.rollback()
        return str(e)
    finally:
        session.close()

# Add a new vault entry
@app.route('/add_entry', methods=['POST'])
def add_entry():
    data = request.json
    username = data['username']
    password = data['password']
    hostname = data['hostname']
    ssh_key = data['ssh_key']
    ssh_password = data['ssh_password']
    checkout_time_limit = data['checkout_time_limit']

    query = "SELECT add_entry(:username, :password, :hostname, :ssh_key, :ssh_password, :checkout_time_limit)"
    result = execute_query(query, username, password, hostname, ssh_key, ssh_password, checkout_time_limit)

    return jsonify({"message": "Entry added successfully!"}), 201

# Delete an entry
@app.route('/delete_entry/<int:entry_id>', methods=['DELETE'])
def delete_entry(entry_id):
    query = "SELECT delete_entry(:entry_id)"
    result = execute_query(query, entry_id)
    return jsonify({"message": "Entry deleted successfully!"}), 200

# Update an entry
@app.route('/update_entry/<int:entry_id>', methods=['PUT'])
def update_entry(entry_id):
    data = request.json
    username = data['username']
    password = data['password']
   
