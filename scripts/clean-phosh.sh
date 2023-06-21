#!/bin/bash

# Remove totem and clean up
DEBIAN_FRONTEND=noninteractive apt-get remove -y totem
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

exit 0
