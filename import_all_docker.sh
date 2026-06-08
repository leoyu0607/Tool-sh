#!/bin/bash
for f in *.tar; do echo "==> $f"; docker load -i "$f"; done