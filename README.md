# Indexify-aws-deployment
## 1. Install AWS + Terraform CLI
[Install terraform cli docs](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

[Install aws cli docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)


## 2. Create AWS Credentials
- In the console navigate to IAM.
- Create a new user, for our example we will name this user indexify-user (this can be named anything), where we will create aws credentials on behalf of.
- Go to indexify-user `Security Credentials` tab and create access key for CLI
- configure aws cli with your credentials with 
  ```bash
  aws configure
  ```

## 3. Initialize terraform
```bash
cd terraform
terraform init
```