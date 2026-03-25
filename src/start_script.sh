#!/bin/bash

# 1. Wait for the network to be ready
echo "Waiting for internet..."
until curl -s --head https://github.com > /dev/null; do
  sleep 2
done

git clone https://github.com/v72450993-create/comfyui-wan.git

mv comfyui-wan/src/start.sh /
bash /start.sh