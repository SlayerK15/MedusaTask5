#!/bin/bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose git
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker
cd /home/ubuntu
git clone https://github.com/SlayerK15/EC2Deploy.git
cd EC2Deploy
sudo docker-compose up -d --build