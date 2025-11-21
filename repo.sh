#!/bin/bash

dnf_var="/etc/dnf/vars"

. /etc/os-release

#$ID
echo $VERSION_ID > $dnf_var/releasever
uname -m > $dnf_var/basearch
#判斷OS版本
MAJOR="${VERSION_ID%%.*}"   # 例如 8 或 9
MINOR="${VERSION_ID##*.}"   # 例如 10
LATEST_MINOR=( [8]=10 [9]=6 )
if [[ -n "${LATEST_MINOR[$MAJOR]:-}" && "$MINOR" -lt "${LATEST_MINOR[$MAJOR]}" ]]; then
    # 舊版本 → vault
    echo "vault/rocky" > $dnf_var/contentdir
else
    # 最新 → pub
    echo "pub/rocky" > $dnf_var/contentdir
fi

echo "192.168.173.107 se-repo.ai3">> /etc/hosts

cat > /etc/yum.repos.d/ai3.repo <<'EOF'
[baseos]
name=Rocky Linux $releasever - BaseOS
baseurl=http://se-repo.ai3/rocky/$contentdir/$releasever/BaseOS/$basearch/os/
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/BaseOS/$basearch/os/
gpgcheck=1
enabled=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial

[appstream]
name=Rocky Linux $releasever - AppStream
baseurl=http://se-repo.ai3/rocky/$contentdir/$releasever/AppStream/$basearch/os/
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/AppStream/$basearch/os/
gpgcheck=1
enabled=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
EOF