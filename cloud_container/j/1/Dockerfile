# Use the official Ubuntu base image
FROM ubuntu:latest

# Set environment variable to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install latest updates
RUN apt-get update && apt-get upgrade -y

# Install NGINX
RUN apt-get install -y nginx

# Expose port 80 for NGINX
EXPOSE 80

# Start NGINX in the foreground (to keep the container running)
CMD ["nginx", "-g", "daemon off;"]
