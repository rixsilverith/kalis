#!/usr/bin/bash

rm -f kalis.conf
rm -f kalis.sh

curl -O https://raw.githubusercontent.com/rixsilverith/kalis/master/kalis.conf
curl -O https://raw.githubusercontent.com/rixsilverith/kalis/master/kalis.sh

chmod +x kalis.sh
