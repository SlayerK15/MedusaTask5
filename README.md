### Deployment of Medusa Backend to AWS EC2 Using GitHub Actions

This document outlines the process of deploying a Medusa backend application to an AWS EC2 instance using GitHub Actions to automate the deployment process. The application is set to run on port 9000.

---

### Step-by-Step Process

#### 1. **Creating the EC2 Instance and Key Pair**
- **EC2 Setup**: Create a new EC2 instance with the following configurations:
  - **Instance type**: `t2.small`
  - **Operating system**: Ubuntu 22.04
  - **Security group**: Allow inbound traffic on port 9000 for the Medusa backend application.
- **Key Pair**: Generate a new key pair to securely access the EC2 instance via SSH.

#### 2. **Accessing the EC2 Instance**
Use the following command to access the EC2 instance via SSH:

```bash
ssh -i <key-pair-file> ubuntu@<EC2-public-IP>
```

Once inside the EC2 instance, install the necessary tools with the following commands:

```bash
sudo apt update
sudo apt install docker docker-compose git -y
```

#### 3. **Generating SSH Keys for GitHub Actions**
- **SSH Key Generation**: Generate an SSH key pair to establish a secure connection between GitHub Actions and the EC2 instance:

```bash
ssh-keygen -t rsa -b 4096 -C "GithubActions"
```

- **Public key**: Add this key to the EC2 instance under `~/.ssh/authorized_keys`.
- **Private key**: Store this in the GitHub repository as a secret under the name `EC2_SSH_KEY`.
- **EC2 Public IP**: Store the EC2 instance's public IP as a secret in GitHub, under the name `EC2_IP`.

#### 4. **Creating the GitHub Repository**
- Create a new repository called `EC2Deploy` to manage the deployment process.
- Clone the previous Task-3 project to your local machine, and within the `.github/workflows/` directory, create a new workflow file named `deploy.yml` to handle the deployment.

#### 5. **Writing the GitHub Actions Workflow**

```yaml
name: Deploy to EC2

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

      - name: Install SSH Client
        run: sudo apt-get install -y sshpass

      - name: Add SSH Key
        uses: webfactory/ssh-agent@v0.7.0
        with:
          ssh-private-key: ${{ secrets.EC2_SSH_KEY }}

      - name: Deploy to EC2
        run: |
          ssh -o StrictHostKeyChecking=no ubuntu@${{ secrets.EC2_IP }} '
          cd /home/ubuntu/EC2Deploy || git clone https://github.com/SlayerK15/EC2Deploy.git /home/ubuntu/EC2Deploy
          cd /home/ubuntu/EC2Deploy
          git pull
          docker-compose down
          docker-compose up -d --build
          '
```

#### Explanation of Workflow Steps:
1. **Checkout Code**: This step checks out the code from the GitHub repository to the runner machine.
2. **Install SSH Client**: Installs `sshpass` to facilitate SSH communication with the EC2 instance.
3. **Add SSH Key**: Adds the private SSH key stored in GitHub secrets for secure SSH access using the `webfactory/ssh-agent` action.
4. **Deploy to EC2**: SSHs into the EC2 instance, navigates to the project directory, pulls the latest changes from the repository, and restarts the Docker containers with `docker-compose`.

#### 6. **Pushing Code and Triggering Deployment**
- After writing the workflow, commit and push the changes to the main branch. This triggers the GitHub Actions workflow and automates the deployment to the EC2 instance.
- The Medusa backend application will be successfully deployed and run on port 9000.

#### 7. **Verifying the Deployment**
- Access the EC2 instance via SSH and run the following command to check if the Docker containers are running:

```bash
docker ps
```

- You can also check the images with:

```bash
docker images
```

These commands will confirm that the Medusa backend is running on the EC2 instance.

---

By following this process, the deployment of the Medusa backend to AWS EC2 using GitHub Actions is automated and can be easily repeated with future updates.