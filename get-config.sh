#!/bin/bash

# set your SSH hostname of the DNS server
server=igo
serverip=10.0.3.5

ssh $server systemctl is-active tftp.socket
echo 'write memory' | clip.exe
echo "copy startup-config $serverip:startup-config.cfg" | clip.exe
read -p "Paste the clipboard contents and press Enter."
rsync -rtv $server:/var/lib/tftpboot/startup-config.cfg .
md5sum startup-config.cfg
