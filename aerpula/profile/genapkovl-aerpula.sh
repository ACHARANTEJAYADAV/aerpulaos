#!/bin/sh -e
HOSTNAME="$1"
[ -n "$HOSTNAME" ] || { echo "usage: $0 hostname" >&2; exit 1; }
SRC="${AERPULA_SRC:-/work}"

cleanup() { rm -rf "$tmp"; }
makefile() {
	OWNER="$1"; PERMS="$2"; FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}
rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

DEF="$(ls "$SRC"/assets/wallpapers/default.* 2>/dev/null | head -n1)"
[ -n "$DEF" ] || { echo "ERROR: add assets/wallpapers/default.jpg (or .png)" >&2; exit 1; }
DEF="$(basename "$DEF")"

mkdir -p "$tmp"/etc/init.d "$tmp"/etc/network "$tmp"/etc/apk \
	"$tmp"/etc/xdg/pcmanfm-qt/lxqt "$tmp"/etc/sddm.conf.d \
	"$tmp"/etc/doas.d "$tmp"/etc/NetworkManager \
	"$tmp"/usr/share/backgrounds/aerpula

# --- Wallpapers ---
cp "$SRC"/assets/wallpapers/* "$tmp"/usr/share/backgrounds/aerpula/

makefile root:root 0644 "$tmp"/etc/xdg/pcmanfm-qt/lxqt/settings.conf <<EOF
[Desktop]
Wallpaper=/usr/share/backgrounds/aerpula/$DEF
WallpaperMode=zoom
EOF

# --- Branding ---
makefile root:root 0644 "$tmp"/etc/hostname <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "$tmp"/etc/os-release <<'EOF'
NAME="AERPULA"
PRETTY_NAME="AERPULA Linux"
ID=aerpula
ID_LIKE=alpine
VERSION_ID=1.0
EOF

makefile root:root 0644 "$tmp"/etc/issue <<'EOF'
AERPULA Linux \n \l

EOF

makefile root:root 0644 "$tmp"/etc/motd <<'EOF'
Welcome to AERPULA.
EOF

# --- Network ---
makefile root:root 0644 "$tmp"/etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback
EOF

makefile root:root 0644 "$tmp"/etc/NetworkManager/NetworkManager.conf <<'EOF'
[main]
dhcp=internal
EOF

# --- Autologin + doas ---
makefile root:root 0644 "$tmp"/etc/sddm.conf.d/10-aerpula.conf <<'EOF'
[Autologin]
User=aerpula
Session=lxqt.desktop
EOF

makefile root:root 0644 "$tmp"/etc/doas.d/aerpula.conf <<'EOF'
permit persist :wheel
EOF

# --- Live user creation (runs before the display manager) ---
makefile root:root 0755 "$tmp"/etc/init.d/aerpula-live <<'EOF'
#!/sbin/openrc-run
description="Create AERPULA live user"
depend() {
	need localmount
	before sddm elogind
}
start() {
	ebegin "Creating AERPULA live user"
	if ! id aerpula >/dev/null 2>&1; then
		adduser -D -s /bin/bash aerpula
		echo "aerpula:aerpula" | chpasswd
		echo "root:aerpula" | chpasswd
		for g in wheel audio video input netdev plugdev users; do
			addgroup aerpula "$g" 2>/dev/null || true
		done
	fi
	eend 0
}
EOF

# --- Packages installed at boot from the ISO ---
{ echo alpine-base; grep -vE '^[[:space:]]*(#|$)' "$SRC/profile/packages.txt"; } \
	| sort -u > "$tmp"/etc/apk/world

# --- Services ---
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add udev sysinit
rc_add udev-trigger sysinit
rc_add udev-settle sysinit
rc_add modloop sysinit

rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add networking boot

rc_add udev-postmount default
rc_add dbus default
rc_add elogind default
rc_add networkmanager default
rc_add aerpula-live default
rc_add sddm default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc usr | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
