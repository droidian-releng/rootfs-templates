#!/bin/bash

# initialize flatpak
if [ -f "/usr/bin/flatpak" ]; then
   flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
   flatpak remote-modify --enable flathub
fi

# Workaround until droidian-update-service is in the archive
if ! grep -q next /etc/apt/apt.conf.d/90-droidian-snapshot; then
  rm -f /etc/apt/apt.conf.d/90-droidian-snapshot
fi

exit 0
