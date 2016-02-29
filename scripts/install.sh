#!/bin/bash
set -e

echo "Installing Consul dependencies..."
sudo apt-get update &>/dev/null
sudo apt-get install unzip &>/dev/null

echo "Fetching Consul..."
cd /tmp
curl -s -L -o consul.zip https://releases.hashicorp.com/consul/0.6.3/consul_0.6.3_linux_amd64.zip

echo "Installing Consul..."
unzip consul.zip >/dev/null
sudo chmod +x consul
sudo mv consul /usr/local/bin/consul
sudo mkdir -p /etc/consul.d
sudo mkdir -p /mnt/consul
sudo mkdir -p /etc/service

echo "Installing Upstart service..."
sudo tee /etc/init/consul.conf > /dev/null <<"EOF"
description "Consul server"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
# This is to avoid Upstart re-spawning the process upon `consul leave`
normal exit 0 INT
# stop consul will not mark node as failed but left
kill signal INT

script
  if [ -f "/etc/service/consul" ]; then
    . /etc/service/consul
  fi

  # Make sure to use all our CPUs, because Consul can block a scheduler thread
  export GOMAXPROCS=`nproc`

  # Get the public IP
  BIND=`ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }'`

  exec /usr/local/bin/consul agent \
    -server \
    -bootstrap-expect="${CONSUL_SERVERS}" \
    -ui \
    -data-dir="/mnt/consul" \
    -config-dir="/etc/consul.d" \
    -atlas-join \
    -atlas-token="${ATLAS_TOKEN}" \
    -atlas="${ATLAS_ENVIRONMENT}" \
    -node="${NODE_NAME}" \
    -bind="${BIND}" \
    -client="${BIND}" \
    ${CONSUL_FLAGS} \
    >>/var/log/consul.log 2>&1
end script
EOF

echo "Starting Consul..."
sudo service consul start
