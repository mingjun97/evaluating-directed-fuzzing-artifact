#!/bin/bash
git clone https://github.com/sgzeng/aflgo.git AFLGo++
cd AFLGo++
apt-get -y update
apt-get -y install python3 python3-dev python3-pip libboost-all-dev ninja-build --no-install-recommends
pip3 install --upgrade pip
pip3 install networkx==2.5 pydot pydotplus
./build.sh