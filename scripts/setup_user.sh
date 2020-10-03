#!/bin/bash

# add user mobian
adduser --disabled-password --gecos "" mobian

# add mobian to groups
usermod -a -G sudo,render,plugdev,video mobian

# set default pass to 1234, change it
echo "mobian:1234" | chpasswd

