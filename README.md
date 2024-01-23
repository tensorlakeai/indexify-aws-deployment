# Indexify-aws-deployment
## 1. Install AWS + Terraform CLI
[Install terraform cli docs](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

[Install aws cli docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

[Install eksctl docs](https://eksctl.io/installation/)
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
          "s3:*",
          "cloudformation:*"
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

## 5. Configure Kubernetes files
Once all of your resources have been created with terraform it is time to setup your kubeconfig. Make sure you have [installed kubectl](https://kubernetes.io/docs/tasks/tools/)

Update the values inside of `k8/indexify-configmap.yml` marked changeme, this includes
- database_url
- your s3 bucket name
- pgvector database_url (same as above)

Update the environment variables AWS Access Keys inside of `indexify-server.yml` and `indexify-minilm-l6-extractor.yml`.

Set your kubeconfig to the cluster
```bash
aws eks update-kubeconfig --region us-east-1 --name indexify-cluster
```

## 6. k8 Load Balancer Setup
Our k8 configuration will provision a load balancer for us, we need to do a few steps in order for this to work.

#### Create AWSLoadBalancerControllerIAMPolicy Policy
download the policy
```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
```
create the load balancer controller iam policy
```bash
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

#### Create Service Account
this command uses eksctl

create service account, update this command to use your aws account number
```bash
eksctl create iamserviceaccount \
  --cluster=indexify-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::YOURAWSACCOUNT:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

verify role was created
```bash
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --query Role.AssumeRolePolicyDocument
```

verify policy that you attached is attached to the role
```bash
aws iam list-attached-role-policies --role-name AmazonEKSLoadBalancerControllerRole --query AttachedPolicies --output text
```
output should be something like this ```arn:aws:iam::ACCOUNTNAME:policy/AWSLoadBalancerControllerIAMPolicy```

Set a variable to store the Amazon Resource Name (ARN) of the policy that you want to use. Replace my-policy with the name of the policy that you want to confirm permissions for. 

*Specify the output of the previous command

```bash
export policy_arn=PREVIOUS_COMMAND_OUTPUT
```

view default version of policy
```bash
aws iam get-policy --policy-arn $policy_arn
```

confirm k8 service account is annotated with the role
```bash
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
```


#### Create OICD provider
determine OICD issuer ID for our cluster
```bash
oidc_id=$(aws eks describe-cluster --name indexify-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

echo $oidc_id
```

determined if we already have oidc provider with cluster issuer id on our account. if output is returned skip next step

```bash
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
```

the following command will create oidc provider
```bash
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=indexify-cluster --approve
```

#### Configure Service account to assume an IAM role
Any pods that are configured to use this service account can access any aws service the role has permission to access.


<!-- #### Configure loadbalancer-controller-role
update aws-permissions/loadbalancer-controller-role.json and add identity provider id


Add to iam->roles and create loadbalancer-controller-role

Add load-balancer-controller-policy to that role

update k8/service-account.yml and update role-arn at the bottom to that of loadbalancer-controller-role -->

#### Add help repo
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
```

#### Install AWS Load Balancer
```bash
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=indexify-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### Verify installation
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

#### Apply ingress
```bash
kubectl apply -f k8/ingress.yml
```

check logs of aws load balancer controller to make sure no errors occured

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 7. Apply the rest of the k8 configuration
apply k8
```bash
kubectl apply -f k8/namespace.yml
kubectl apply -f k8/
```

