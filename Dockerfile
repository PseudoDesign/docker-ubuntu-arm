# Use the Ubuntu Xenial runtime as the parent image
FROM ubuntu:xenial

WORKDIR /app

# Copy packages.txt into the container
ADD packages.txt /app

# Update the package listing and install the packages in packages.txt
RUN apt-get update
RUN apt-get install -y dos2unix
RUN dos2unix packages.txt
RUN apt-get install -y $(grep -vE "^\s*#" packages.txt  | tr "\n" " ")

# Create the appuser user
RUN useradd appuser
RUN mkdir -p /home/appuser
RUN cp /etc/skel/.bashrc /home/appuser/.

# Install sudo and give appuser access
RUN apt-get install -y sudo && rm -rf /var/lib/apt/lists/*
RUN usermod -aG sudo appuser
RUN echo "appuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy the appuser directory to /home/appuser and change ownership
ADD appuser/. /home/appuser
RUN chown appuser:appuser /home/appuser -R

WORKDIR /home/appuser
