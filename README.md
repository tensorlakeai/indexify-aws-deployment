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

## 3. Setup IAM Policy + Role
- Create a new policy named `TerraformPolicy` with the following.
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "Statement1",
        "Effect": "Allow",
        "Action": [
          "ec2:*",
          "rds:*",
          "iam:*",
          "logs:*",
          "kms:*",
          "eks:*",
          "s3:*"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  }
  ```
  *Note this policy is just an example, you may want to change this policy based on your needs.
- Add `TerraformPolicy` to `indexify-user` permissions.


## 4. Initialize terraform and apply resources
First you want to change values marked changeme inside of terraform/variables.tf. This is for your database password and s3 bucket name
```bash
cd terraform
terraform init
terraform apply
```

## 5. Deploy kubernetes
Once all of your resources have been created with terraform setup your kubeconfig. Make sure you have [installed kubectl](https://kubernetes.io/docs/tasks/tools/)

Update kubeconfig
```bash
aws eks update-kubeconfig --region us-east-1 --name indexify-cluster
```

apply k8
```bash
kubectl apply -f k8/namespace.yml
kubectl apply -f k8/

