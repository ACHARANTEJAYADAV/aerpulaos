#!/bin/sh
set -eu
. /etc/os-release
VER="v${VERSION_ID%.*}"
BRANCH="${VER#v}-stable"
echo ">>> Building AERPULA on Alpine $VER"

apk add --no-cache alpine-sdk alpine-conf apk-tools busybox fakeroot \
	syslinux xorriso squashfs-tools mtools dosfstools grub-efi git

# Fail early on misspelled/missing package names
apk update
missing=""
for p in $(grep -vE '^[[:space:]]*(#|$)' /work/profile/packages.txt); do
	apk search -e "$p" | grep -q . || missing="$missing $p"
done
if [ -n "$missing" ]; then
	echo "ERROR: packages not found in $VER:$missing" >&2
	echo "Fix profile/packages.txt (try: apk search <name>)" >&2
	exit 1
fi

adduser -D builder 2>/dev/null || true
addgroup builder abuild 2>/dev/null || true
su builder -c 'abuild-keygen -a -n'
cp /home/builder/.abuild/*.pub /etc/apk/keys/

su builder -c "git clone --depth=1 --branch $BRANCH https://github.com/alpinelinux/aports.git /home/builder/aports"
install -m 644 /work/profile/mkimg.aerpula.sh /home/builder/aports/scripts/
install -m 755 /work/profile/genapkovl-aerpula.sh /home/builder/aports/scripts/
mkdir -p /home/builder/out
chown -R builder /home/builder

su builder -c "cd /home/builder/aports/scripts && \
  AERPULA_SRC=/work sh mkimage.sh \
    --tag $VER \
    --outdir /home/builder/out \
    --workdir /home/builder/work \
    --arch x86_64 \
    --repository https://dl-cdn.alpinelinux.org/alpine/$VER/main \
    --repository https://dl-cdn.alpinelinux.org/alpine/$VER/community \
    --profile aerpula"

ISO="$(ls /home/builder/out/*.iso | head -n1)"
cp "$ISO" /work/out/AERPULA-x86_64.iso
chown -R "${HOST_UID:-0}:${HOST_GID:-0}" /work/out
echo ">>> Done: out/AERPULA-x86_64.iso"
