#!/bin/bash

### ncmeter listens on port 23456, so it has to be opened on the listener machine

sudo apt-get update && apt-get upgrade -y
sudo cp /usr/share/doc/netcat-openbsd/examples/contrib/ncmeter /tmp
sudo chmod +x /tmp/ncmeter
cd /tmp
sudo ./ncmeter