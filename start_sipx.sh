#!/bin/bash
su - ms    -c  "indown"
su - media -c  "mediastop"
su - acd   -c  "acdstop"
su - cti   -c  "ctistop"
su - smp   -c  "smpstop"
su - acdweb   -c  "acdwebstop"
#
sleep 5
#啟用 messipx-server 服務
su - rmi -c "./cc-server.sh start> /dev/null 2>&1"

#啟用 ./rmi 服務
sleep 5
su - rmi -c  "./rmi > /dev/null 2>&1 &"
