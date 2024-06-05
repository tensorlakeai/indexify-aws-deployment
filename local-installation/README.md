# Indexify Setup Guide

This guide will walk you through setting up a local development environment for Indexify using Docker, Kubernetes, and LocalStack. Follow each step carefully to ensure a successful setup. (Don't forget to check the important documents at the end in case you want some extra information about the setup).

# Table of content:

- [Indexify Setup Guide](#indexify-setup-guide)
- [Table of content:](#table-of-content)
  - [About Indexify](#about-indexify)
  - [Prerequisites](#prerequisites)
  - [Installation Steps](#installation-steps)
    - [Step 1: Clone the Repository](#step-1-clone-the-repository)
    - [Step 2: Start Docker Desktop](#step-2-start-docker-desktop)
    - [Step 3: Create LocalStack Environment](#step-3-create-localstack-environment)
    - [Step 4: Configure AWS Credentials for LocalStack](#step-4-configure-aws-credentials-for-localstack)
    - [Step 5: Create Indexify Namespace](#step-5-create-indexify-namespace)
    - [Step 6: Create a Local PostgreSQL Installation](#step-6-create-a-local-postgresql-installation)
    - [Step 7: Setup Nginx Locally](#step-7-setup-nginx-locally)
    - [Step 8: Create Local Indexify, Coordinator, and Extractor Installation](#step-8-create-local-indexify-coordinator-and-extractor-installation)
    - [Step 9: Start Basic Testing](#step-9-start-basic-testing)
  - [Helm Installation](#helm-installation)
    - [Helm step 1: Install prerequisites](#helm-step-1-install-prerequisites)
    - [Helm step 2: Indexify Helm chart installation](#helm-step-2-indexify-helm-chart-installation)
  - [Important Documents](#important-documents)

## About Indexify

[Indexify](https://github.com/tensorlakeai) is a reactive compute engine for extracting unstructured data and building Indexes. If you are building RAG/LLM Applications or Agents which depend on LLMs consuming data extracted from documents or video/audio, Indexify can help you to build pipelines which keeps your indexes updated in real time as data changes. For more information and getting started, visit the [Tensorlake indexify home page](https://docs.getindexify.ai/).

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) installed and running
- Kubernetes enabled in Docker Desktop (instructions [here](https://docs.docker.com/desktop/kubernetes/))
- [AWS CLI](https://aws.amazon.com/cli/) installed
- [LocalStack](https://docs.localstack.cloud/getting-started/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed
- [Python](https://www.python.org/downloads/) installed

## Installation Steps

This is the complete installation using kubernetes, helm and localstack, please do it in case you want to know the complete process and setup for indexify. In case you just want to go and run, please follow the new [Helm installation guide](#helm-installation)

### Step 1: Clone the Repository

First, clone this repository to your local machine:

```sh
git clone https://github.com/tensorlakeai/indexify-aws-deployment
cd local-installation
```

### Step 2: Start Docker Desktop

Ensure Docker Desktop is running. You should be logged in and able to run Kubernetes and Docker commands. Follow these steps to check and confirm Docker Desktop is running:

**Open Docker Desktop:**

- **On Windows**, click on the Docker icon in the Start menu.
- **On macOS**, open Docker from the Applications folder.

**Enable Kubernetes:**

1. Open Docker Desktop and go to the Settings or Preferences menu.
2. Navigate to the "Kubernetes" tab.
3. Check the box to enable Kubernetes and apply the changes. Docker will take a few minutes to start the Kubernetes cluster.

**Confirm Docker and Kubernetes:**

1. Open a terminal or command prompt.
2. Run the following commands to ensure Docker and Kubernetes are functioning correctly:

    ```sh
    docker --version
    kubectl version --client
    ```

You should see the versions of Docker (at least version `24.0.0`) and kubectl (at least `1.30`) output to the terminal. If you encounter any issues, refer to the [Docker Desktop getting started](https://www.docker.com/blog/getting-started-with-docker-desktop/) guide for troubleshooting.

### Step 3: Create LocalStack Environment

**Start LocalStack:**

```sh
localstack start
```

**Get the LocalStack IP address. This will be needed later for the Indexify installation:**

```sh
docker inspect localstack-main | jq -r '.[0].NetworkSettings.Networks | to_entries | .[].value.IPAddress'
```

**Output (This may change, so please ensure to save it):**

```sh
172.17.0.2
```

### Step 4: Configure AWS Credentials for LocalStack

**Create a new user for Indexify inside your localstack aws installation:**

```sh
awslocal iam create-user --user-name indexify-user
```

**Output:**

```json
{
  "User": {
      "Path": "/",
      "UserName": "indexify-user",
      "UserId": "ipux92qsoiivugnuc1pm",
      "Arn": "arn:aws:iam::000000000000:user/indexify-user",
      "CreateDate": "2024-05-30T19:57:35.224000+00:00"
  }
}
```

**Create access keys for the new created user `indexify-user`:**

```sh
awslocal iam create-access-key --user-name indexify-user
```

**Output:**

```json
{
  "AccessKey": {
      "UserName": "indexify-user",
      "AccessKeyId": "LKIAQAAAAAAAKY5FY2RO",
      "Status": "Active",
      "SecretAccessKey": "OhmKB4fcCvMfh2yqSvmGjD4eXwfkmw7tYHQxh+uZ",
      "CreateDate": "2024-05-30T19:57:45+00:00"
  }
}
```

**Export the `indexify-user` keys to use the same user locally:**

```sh
export AWS_ACCESS_KEY_ID=LKIAQAAAAAAAKY5FY2RO
export AWS_SECRET_ACCESS_KEY=OhmKB4fcCvMfh2yqSvmGjD4eXwfkmw7tYHQxh+uZ
awslocal sts get-caller-identity
```

**Output:**

```json
{
  "UserId": "ipux92qsoiivugnuc1pm",
  "Account": "000000000000",
  "Arn": "arn:aws:iam::000000000000:user/indexify-user"
}
```

**Create an S3 bucket:**

```sh
awslocal s3api create-bucket --bucket sample-bucket
```

**Output:**

```json
{
  "Location": "/sample-bucket"
}
```

### Step 5: Create Indexify Namespace

**Apply the namespace configuration:**

```sh
kubectl apply -f namespace.yml
```

**Output:**

```sh
namespace/indexify created
```

### Step 6: Create a Local PostgreSQL Installation

**Apply the PostgreSQL configuration:**

```sh
kubectl apply -f postgres-k8/
```

**Output:**

```sh
configmap/postgres-secret created
deployment.apps/postgres created
service/postgres created
```

**Ensure your pod is running as expected:**

```sh
kubectl get pods --namespace=indexify
```

**Output:**

```sh
NAME                        READY   STATUS    RESTARTS   AGE
postgres-567d8f9954-xbzvn   1/1     Running   0          2m14s
```

**Confirm that your Postgres DB is working:**

```sh
kubectl exec -it postgres-567d8f9954-xbzvn --namespace=indexify -- psql -h localhost -U ps_user --password -p 5432 ps_db
```

It will then ask for your password, which you can get from the file `postgres-k8/postgres-configmap.yml`.
**After the successful authentication, you will get into the Postgres shell:**

```sh
Password:
psql (14.10 (Debian 14.10-1.pgdg120+1))
Type "help" for help.
ps_db=#
```

**Next, verify the PostgreSQL connection using the following command:**

```sh
ps_db=# \conninfo
```

**Output**

```sh
You are connected to database "ps_db" as user "ps_user" on host "localhost" (address "::1") at port "5432".
```

**After that, you can exit the instance using:**

```sh
exit
```

### Step 7: Setup Nginx Locally

**Install Nginx using Helm:**

```sh
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace indexify
```

**Modify your `/etc/hosts` file to point indexify.local to your localhost:**

```sh
vi /etc/hosts
```

**Or in case you have installed Visual Studio Code you can run:**

```sh
code /etc/hosts
```

**Add the following line at the end of the file:**

```sh
127.0.0.1 indexify.local
```

### Step 8: Create Local Indexify, Coordinator, and Extractor Installation

**Update the AWS_VALUES in `indexify-coordinator.yml` and `indexify-minilm-l6-extractor.yml` to use your keys and the IP address of your LocalStack installation:**

```yaml
- name: AWS_ACCESS_KEY_ID
  value: LKIAQAAAAAAAKY5FY2RO
- name: AWS_SECRET_ACCESS_KEY
  value: OhmKB4fcCvMfh2yqSvmGjD4eXwfkmw7tYHQxh+uZ
- name: AWS_ENDPOINT
  value: http://172.17.0.2:4566
```

**Apply the Kubernetes configuration:**

```sh
kubectl apply -f k8-local
```

**Output:**

```sh
configmap/indexify-configmap created
service/coordinator-service created
deployment.apps/coordinator created
service/minilm-l6-extractor-service created
deployment.apps/minilm-l6-extractor created
service/indexify-service created
deployment.apps/indexify created
ingress.networking.k8s.io/ingress-indexify created
```

**Verify your installation to ensure your pods are up and running:**

```sh
kubectl get pods --namespace=indexify
```

### Step 9: Start Basic Testing

**Create a Python virtual environment:**

```sh
python -m venv .venv                                                                                                              ─╯
source .venv/bin/activate
```

**Install Jupyter:**

```sh
pip install jupyter
```

(Optional) Use the Visual Studio plugin for Jupyter: [VSCode Jupyter Plugin](https://www.youtube.com/watch?v=xS5ZXOC4e6A)

**Install Indexify:**

```sh
pip install indexify
```

**Open the file `indexify-testing.ipynb` in Visual Studio and run the code blocks one by one.**

By following these steps, you should have a fully functional local development environment for Indexify. If you encounter any issues, refer to the documentation or seek help from the community channels:

- [Discord channel](https://discord.gg/mrXrq3DmV8)
- [X](https://twitter.com/tensorlake)

## Helm Installation

This is an fast, easy installation using helm, so in case you want to go more in deep about the tools installation please refer to the complete [Installation Steps](#installation-steps) guide above.

### Helm step 1: Install prerequisites

**Please follow the first 5 steps described above:**

- [Step 1: Clone the Repository](#step-1-clone-the-repository)
- [Step 2: Start Docker Desktop](#step-2-start-docker-desktop)
- [Step 3: Create LocalStack Environment](#step-3-create-localstack-environment)
- [Step 4: Configure AWS Credentials for LocalStack](#step-4-configure-aws-credentials-for-localstack)
- [Step 5: Create Indexify Namespace](#step-5-create-indexify-namespace)

### Helm step 2: Indexify Helm chart installation

**Go inside `local-installation/indexify-helm-chart/` directory**

```sh
cd local-installation/indexify-helm-chart/
```

**Change all the `Changme` values inside `values.yml` file based on your LocalStack AWS values (step 4) and LocalStack IP address(step 3):**

```json
  aws:
    accessKeyId: "changeme with your AWS values"
    secretAccessKey: "changeme with your AWS values"
    endpoint: "http://<changeme>:4566"
```

**Update dependencies and run Helm installation command**:

```sh
helm dependency update
helm install indexify-app . --namespace indexify
```

**Output**:

```sh
NAME: indexify-app
LAST DEPLOYED: Tue Jun  4 11:46:31 2024
NAMESPACE: indexify
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace indexify -l "app.kubernetes.io/name=indexify-app,app.kubernetes.io/instance=indexify-app" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace indexify $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace indexify port-forward $POD_NAME 8080:$CONTAINER_PORT
```

After installation you can now just go and [run the basic testing described in step 9](#step-9-start-basic-testing).
If you encounter any issues, refer to the documentation or seek help from the community channels:

- [Discord channel](https://discord.gg/mrXrq3DmV8)
- [X](https://twitter.com/tensorlake)

## Important Documents

For extra documentation and info, refer to the following links:

- [LocalStack IAM Getting Started](https://docs.localstack.cloud/user-guide/aws/iam/#getting-started)
- [LocalStack Network Troubleshooting](https://docs.localstack.cloud/references/network-troubleshooting/endpoint-url/)
- [Setting Up a PostgreSQL Environment in Docker: A Step-by-Step Guide](https://medium.com/@nathaliafriederichs/setting-up-a-postgresql-environment-in-docker-a-step-by-step-guide-55cbcb1061ba)
- [How to Deploy PostgreSQL to Kubernetes Cluster](https://www.digitalocean.com/community/tutorials/how-to-deploy-postgres-to-kubernetes-cluster)
- [Issue with Installing Packages with pip: Cargo, the Rust Package Manager, is Not Installed](https://stackoverflow.com/questions/71696582/issue-with-installing-packages-with-pip-cargo-the-rust-package-manager-is-no)
- [OpenAI API Keys](https://platform.openai.com/api-keys)
- [How to create a python virutal environment](https://python.land/virtual-environments/virtualenv)
- [Recommended K8 CLI to use](https://k9scli.io/topics/install/)
- [Indexify extraction graphs](https://docs.getindexify.ai/apis/extraction_graphs/)
