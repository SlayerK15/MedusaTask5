# Automated Deployment of EC2 Instance Using Terraform and GitHub Actions

This repository contains code and configurations for automating the deployment of an AWS EC2 instance running Ubuntu 22.04, using Terraform for infrastructure provisioning and GitHub Actions for continuous deployment. The deployed EC2 instance will have Docker and Docker Compose installed, and will run a backend server accessible on port 9000.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
  - [1. Add AWS Credentials to GitHub Secrets](#1-add-aws-credentials-to-github-secrets)
  - [2. Create the Terraform Configuration File (`main.tf`)](#2-create-the-terraform-configuration-file-maintf)
  - [3. Create the Installation Script (`install.sh`)](#3-create-the-installation-script-installsh)
  - [4. Create the GitHub Actions Workflow (`deploy.yml`)](#4-create-the-github-actions-workflow-deployyml)
  - [5. Commit and Push Changes](#5-commit-and-push-changes)
- [Verification](#verification)
- [Important Notes](#important-notes)


## Prerequisites

- **AWS Account**: An active AWS account with permissions to create EC2 instances and manage related resources.
- **AWS Access Keys**: AWS Access Key ID and Secret Access Key.
- **GitHub Repository**: A GitHub repository to host your code and configuration files.
- **SSH Key Pair**: An existing AWS key pair for SSH access to EC2 instances.
- **Security Group Configuration**: A security group in AWS that allows inbound traffic on port 9000 and SSH (port 22).

## Setup Instructions

### 1. Add AWS Credentials to GitHub Secrets

1. Navigate to your GitHub repository.
2. Go to **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
3. Add the following secrets:

   - `AWS_ACCESS_KEY_ID`: Your AWS Access Key ID.
   - `AWS_SECRET_ACCESS_KEY`: Your AWS Secret Access Key.
   - `EC2_SSH_KEY`: The private key corresponding to your AWS key pair (used for SSH access).

### 2. Create the Terraform Configuration File (`main.tf`)

Create a file named `main.tf` in the root directory of your repository with the following content:

```hcl
provider "aws" {
  region = "ap-south-1" // Specify your AWS region
}

variable "ec2_private_key" {
  type      = string
  sensitive = true
}

resource "aws_instance" "medusa_ec2" {
  ami                    = "ami-0c2af51e265bd5e0e" // AMI ID for Ubuntu 22.04
  instance_type          = "t2.small"
  key_name               = "YourKeyPairName" // Replace with your AWS key pair name
  vpc_security_group_ids = ["sg-xxxxxxxx"] // Replace with your security group ID

  tags = {
    Name = "MedusaEC2"
  }

  provisioner "file" {
    source      = "install.sh"
    destination = "/home/ubuntu/install.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_private_key
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install.sh",
      "/home/ubuntu/install.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_private_key
      host        = self.public_ip
    }
  }
}

output "ec2_public_ip" {
  value = aws_instance.medusa_ec2.public_ip
}
```

**Explanation:**

- **Provider Block**: Specifies AWS as the provider and sets the region.
- **Variable Declaration**: Defines a sensitive variable `ec2_private_key` to store the SSH private key.
- **Resource `aws_instance`**:
  - `ami`: Uses the AMI ID for Ubuntu 22.04. Ensure this AMI ID is valid in your chosen region.
  - `instance_type`: Sets the instance type to `t2.small` to provide sufficient resources.
  - `key_name`: Specifies the AWS key pair name for SSH access. Replace `"YourKeyPairName"` with your actual key pair name.
  - `vpc_security_group_ids`: Includes the security group ID that allows inbound traffic on the required ports.
- **Provisioners**:
  - `file`: Uploads the `install.sh` script to the EC2 instance.
  - `remote-exec`: Executes the `install.sh` script on the EC2 instance.
- **Output**: Exposes the public IP address of the EC2 instance after deployment.

### 3. Create the Installation Script (`install.sh`)

Create a file named `install.sh` with the following content:

```bash
#!/bin/bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose git
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker
cd /home/ubuntu
git clone https://github.com/YourUsername/YourRepository.git
cd YourRepository
sudo docker-compose up -d --build
```

**Explanation:**

- **Update System Packages**: Runs `apt-get update` to refresh the package list.
- **Install Dependencies**: Installs Docker, Docker Compose, and Git.
- **Configure Docker**:
  - Adds the `ubuntu` user to the `docker` group to allow non-root Docker usage.
  - Enables and starts the Docker service.
- **Deploy Application**:
  - Clones your application repository from GitHub. Replace `https://github.com/YourUsername/YourRepository.git` with your repository URL.
  - Navigates to the repository directory and builds and runs the Docker containers defined in `docker-compose.yml`.

### 4. Create the GitHub Actions Workflow (`deploy.yml`)

Create a directory `.github/workflows/` in your repository and add a file named `deploy.yml` with the following content:

```yaml
name: Deploy to EC2 with Terraform

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          TF_VAR_ec2_private_key: ${{ secrets.EC2_SSH_KEY }}
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          TF_VAR_ec2_private_key: ${{ secrets.EC2_SSH_KEY }}
        run: terraform apply -auto-approve tfplan

      - name: Get EC2 Public IP
        id: get_ip
        run: echo "ec2_public_ip=$(terraform output -raw ec2_public_ip)" >> $GITHUB_OUTPUT

      - name: Wait for EC2 to be Ready
        run: sleep 60

      - name: Add SSH Key
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.EC2_SSH_KEY }}

      - name: Test SSH Connection
        run: ssh -o StrictHostKeyChecking=no ubuntu@${{ steps.get_ip.outputs.ec2_public_ip }} 'echo "SSH Connection Successful"'
```

**Explanation:**

- **Trigger**: The workflow runs on every push to the `main` branch.
- **Jobs**:
  - **Checkout Code**: Retrieves the repository's code.
  - **Set up Terraform**: Prepares the environment for Terraform commands.
  - **Terraform Init**: Initializes Terraform.
  - **Terraform Plan**: Creates an execution plan.
  - **Terraform Apply**: Applies the infrastructure changes.
  - **Get EC2 Public IP**: Retrieves the public IP of the deployed EC2 instance.
  - **Wait for EC2 to be Ready**: Pauses the workflow to allow the instance to initialize.
  - **Add SSH Key**: Adds the SSH private key to the SSH agent for subsequent connections.
  - **Test SSH Connection**: Verifies SSH connectivity to the EC2 instance.
- **Environment Variables**:
  - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`: Used by Terraform to authenticate with AWS.
  - `TF_VAR_ec2_private_key`: Passes the EC2 SSH private key to Terraform as a variable.

### 5. Commit and Push Changes

Add all the created files to your Git repository:

```bash
git add main.tf install.sh .github/workflows/deploy.yml
git commit -m "Automated EC2 deployment with Terraform and GitHub Actions"
git push origin main
```

## Verification

After pushing the changes:

- **Monitor the Workflow**: Go to the **Actions** tab in your GitHub repository to observe the workflow execution.
- **Retrieve the Public IP Address**:
  - The workflow outputs the EC2 instance's public IP.
  - Alternatively, obtain the IP from the AWS Management Console.
- **Access the Backend Server**:
  - Ensure that the security group associated with the EC2 instance allows inbound traffic on port 9000.
  - Open a web browser and navigate to `http://<EC2_PUBLIC_IP>:9000` to access the backend server.

## Important Notes

1. **Amazon Machine Image (AMI) ID**:

   - The AMI ID `ami-0c2af51e265bd5e0e` corresponds to Ubuntu 22.04 in the `ap-south-1` region.
   - Verify the AMI ID for your specific region by consulting the AWS documentation or using the AWS CLI.

2. **AWS Access Keys**:

   - Access keys provide programmatic access to AWS resources.
   - Create or use existing access keys from the AWS Management Console under **Security Credentials**.

3. **GitHub Secrets**:

   - Store sensitive information like AWS credentials and SSH keys in GitHub Secrets.
   - Access these secrets securely within GitHub Actions workflows.

4. **Provisioning Scripts**:

   - The `install.sh` script automates the installation of necessary software on the EC2 instance.
   - Ensure the script has executable permissions and follows best practices for shell scripting.

5. **Workflow Configuration**:

   - The `deploy.yml` file defines the CI/CD pipeline using GitHub Actions.
   - Ensure that the workflow steps are correctly defined and that dependencies are installed.

6. **Security Considerations**:

   - Do not expose sensitive information in logs or code repositories.
   - Restrict access to the EC2 instance by properly configuring security groups.
   - Regularly rotate AWS access keys and monitor for unauthorized access.


**Disclaimer**: This repository assumes that all necessary permissions and prerequisites are met. The user is responsible for any costs incurred by the use of AWS resources.
