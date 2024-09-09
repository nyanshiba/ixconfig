#!/bin/bash

# set your SSH hostname of the DNS server
server=igo
serverip=10.0.3.5

md5sum running-config.cfg
rsync -rtv running-config.cfg $server:/var/lib/tftpboot
ssh $server systemctl is-active tftp.socket
echo "copy $serverip:running-config.cfg startup-config" | clip.exe
echo "Paste the clipboard contents, then reload IX."
