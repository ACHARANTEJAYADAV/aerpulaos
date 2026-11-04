profile_aerpula() {
	profile_standard
	profile_abbrev="aerpula"
	title="AERPULA"
	desc="AERPULA Linux - LXQt live system"
	arch="x86_64"
	hostname="aerpula"
	kernel_flavors="lts"
	kernel_addons=""
	apkovl="genapkovl-aerpula.sh"

	apks="$apks $(grep -vE '^[[:space:]]*(#|$)' "$AERPULA_SRC/profile/packages.txt" | tr '\n' ' ')"

	local _k
	for _k in $kernel_flavors; do
		apks="$apks linux-$_k"
	done
}
