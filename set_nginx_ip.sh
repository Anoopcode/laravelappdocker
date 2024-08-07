#!/bin/bash

# Fetch the public IP of the EC2 instance
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

# Update the Nginx configuration with the public IP
sed -i "s/server_name localhost;/server_name $PUBLIC_IP;/" /etc/nginx/conf.d/default.conf
