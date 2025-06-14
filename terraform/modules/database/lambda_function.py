import json
import boto3
import psycopg2
import psycopg2.extras
import logging
import secrets
import string

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to create PostgreSQL databases and users
    Expected event structure:
    {
        "action": "create_database",
        "rds_secret_arn": "arn:aws:secretsmanager:...",
        "project_name": "myproject",
        "environment_databases": ["myproject_staging", "myproject_prod"]
    }
    """
    try:
        action = event.get('action')
        if action != 'create_database':
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unsupported action: {action}'})
            }
        
        rds_secret_arn = event['rds_secret_arn']
        project_name = event['project_name']
        environment_databases = event['environment_databases']
        
        logger.info(f"Creating databases: {environment_databases}")
        
        # Get RDS master credentials
        secrets_client = boto3.client('secretsmanager')
        rds_secret = secrets_client.get_secret_value(SecretId=rds_secret_arn)
        rds_creds = json.loads(rds_secret['SecretString'])
        
        # Connect to PostgreSQL
        # Extract hostname from endpoint (remove port if included)
        host = rds_creds['endpoint'].split(':')[0]
        conn = psycopg2.connect(
            host=host,
            port=rds_creds['port'],
            database=rds_creds['dbname'],
            user=rds_creds['username'],
            password=rds_creds['password'],
            sslmode='require'
        )
        conn.autocommit = True
        
        cursor = conn.cursor()
        created_databases = {}
        
        for db_name in environment_databases:
            logger.info(f"Processing database: {db_name}")
            
            # Generate strong password for database user
            password = generate_password()
            user_name = f"{db_name}_user"
            
            # Create database if it doesn't exist
            cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
            if not cursor.fetchone():
                # Use quoted identifier to handle special characters
                cursor.execute(f'CREATE DATABASE "{db_name}"')
                logger.info(f"Created database: {db_name}")
            else:
                logger.info(f"Database {db_name} already exists")
            
            # Create user if it doesn't exist
            cursor.execute("SELECT 1 FROM pg_user WHERE usename = %s", (user_name,))
            if not cursor.fetchone():
                cursor.execute(f"CREATE USER \"{user_name}\" WITH PASSWORD %s", (password,))
                logger.info(f"Created user: {user_name}")
            else:
                # Update password for existing user
                cursor.execute(f"ALTER USER \"{user_name}\" WITH PASSWORD %s", (password,))
                logger.info(f"Updated password for user: {user_name}")
            
            # Connect to the specific database to grant privileges
            db_conn = psycopg2.connect(
                host=host,
                port=rds_creds['port'],
                database=db_name,
                user=rds_creds['username'],
                password=rds_creds['password'],
                sslmode='require'
            )
            db_conn.autocommit = True
            db_cursor = db_conn.cursor()
            
            # Grant database privileges
            db_cursor.execute(f'GRANT CONNECT, CREATE, TEMPORARY ON DATABASE "{db_name}" TO "{user_name}"')
            
            # Grant schema privileges
            db_cursor.execute(f'GRANT CREATE, USAGE ON SCHEMA public TO "{user_name}"')
            
            # Grant privileges on existing tables and sequences (if any)
            db_cursor.execute(f'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{user_name}"')
            db_cursor.execute(f'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "{user_name}"')
            
            # Grant privileges on future tables and sequences
            db_cursor.execute(f'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "{user_name}"')
            db_cursor.execute(f'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "{user_name}"')
            
            db_cursor.close()
            db_conn.close()
            
            logger.info(f"Granted privileges to {user_name} on database {db_name}")
            
            # Store credentials in Secrets Manager
            secret_name = f"{project_name}/database/{db_name}"
            database_url = f"postgresql://{user_name}:{password}@{host}:{rds_creds['port']}/{db_name}"
            
            secret_value = {
                'username': user_name,
                'password': password,
                'endpoint': host,
                'port': rds_creds['port'],
                'dbname': db_name,
                'database_url': database_url
            }
            
            try:
                # Try to create new secret
                secrets_client.create_secret(
                    Name=secret_name,
                    Description=f"Database credentials for {db_name} environment",
                    SecretString=json.dumps(secret_value),
                    Tags=[
                        {'Key': 'Name', 'Value': f"{project_name}-{db_name}-db"},
                        {'Key': 'Environment', 'Value': db_name.split('_')[-1]}, 
                        {'Key': 'Project', 'Value': project_name}
                    ]
                )
                logger.info(f"Created secret: {secret_name}")
            except secrets_client.exceptions.ResourceExistsException:
                # Update existing secret
                secrets_client.update_secret(
                    SecretId=secret_name,
                    SecretString=json.dumps(secret_value)
                )
                logger.info(f"Updated secret: {secret_name}")
            except secrets_client.exceptions.InvalidRequestException as e:
                if "already scheduled for deletion" in str(e):
                    # Restore the secret that was scheduled for deletion
                    logger.info(f"Secret {secret_name} is scheduled for deletion, restoring it")
                    secrets_client.restore_secret(SecretId=secret_name)
                    # Update the restored secret with new values
                    secrets_client.update_secret(
                        SecretId=secret_name,
                        SecretString=json.dumps(secret_value)
                    )
                    logger.info(f"Restored and updated secret: {secret_name}")
                else:
                    raise
            
            created_databases[db_name] = {
                'database_name': db_name,
                'username': user_name,
                'secret_name': secret_name,
                'endpoint': host,
                'port': rds_creds['port']
            }
        
        cursor.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Databases created successfully',
                'databases': created_databases
            })
        }
        
    except Exception as e:
        logger.error(f"Error creating databases: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def generate_password(length=32):
    """Generate a secure password"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    password = ''.join(secrets.choice(alphabet) for _ in range(length))
    return password