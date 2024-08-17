#bin/sh

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account --region $AWS_REGION)

# Build the database setup function
./mvnw clean package -f infrastructure/db-setup/pom.xml

# Build the unicorn application
./mvnw clean package -f software/unicorn-store-spring/pom.xml
./mvnw clean package -f software/alternatives/unicorn-store-micronaut/pom.xml
./mvnw clean package -f software/alternatives/unicorn-store-quarkus/pom.xml

# Deploy the infrastructure
cd ~/environment/aws-lambda-java-workshop/labs/unicorn-store/infrastructure/cdk

cdk bootstrap
cdk deploy UnicornStoreInfrastructure --require-approval never --outputs-file target/output.json

# Execute the DB Setup function to create the table
aws lambda invoke --function-name $(cat target/output.json | jq -r '.UnicornStoreInfrastructure.DbSetupArn') /dev/stdout | cat;

cd ~/environment/aws-lambda-java-workshop/labs/unicorn-store
./setup-vpc-peering.sh