# Step 2: Set Up a Startup Script via Terraform to Pre-install Docker
# 2.1 Create a Shell Script to Install Docker

#!/bin/bash

# install_docker.sh

sudo apt-get update -y
sudo apt-get install -y docker.io
sudo usermod -aG docker ${USER}
sudo systemctl enable docker
sudo systemctl start docker