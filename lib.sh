detect_partition() {
	if [[ -n "$1" ]] ; then
		local detected_partition
		detected_partition=$(fdisk -l "$1" | grep -P -A 100 "Device.+Boot.+Start.+End.+Sectors.+Size.+Id.+Type")
		local partition_line
		partition_line=$(echo "$detected_partition" | head -n2 | tail -n1)
		[[ -z "$partition_line" ]] && return 1
		partition_start=$(echo "$partition_line" | awk '{print $2}')
		[[ -z "$partition_start" ]] && return 2
		partition_size=$(echo "$partition_line" | awk '{print $4}')
		[[ -z "$partition_size" ]] && return 3
		echo "${partition_start} ${partition_size}"
	else
		return 4
	fi
}

JETHOME_TOOLS_ROOT="${JETHOME_TOOLS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
JETHOME_TOOLS_CACHE="${JETHOME_TOOLS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/jethome-tools}"

# Releases: https://github.com/jethome-iot/buildroot-recovery-build/releases
RECOVERY_VERSION="${RECOVERY_VERSION:-v0.3.0}"
RECOVERY_SHA256_J100="${RECOVERY_SHA256_J100:-f6da60486a8d1e9a976776fb7d8d8c754a09e676f77816b93ef139df05f58537}"
RECOVERY_SHA256_J310="${RECOVERY_SHA256_J310:-9d215a746bf2cd4339c5ef097d5925536ce7352f58cac2d3a4da7b3333386e15}"
RECOVERY_URL_BASE="${RECOVERY_URL_BASE:-https://github.com/jethome-iot/buildroot-recovery-build/releases/download}"

recovery_fit_info() {
	local fit="$1" desc ts
	desc=$(dd if="$fit" bs=4k count=1 status=none | strings -n 6 | head -1)
	ts=$(od -An -tu4 -j76 -N4 --endian=big "$fit" 2>/dev/null | tr -d ' ')
	if [[ "$ts" =~ ^[0-9]+$ ]]; then
		printf '%s (built %s)\n' "$desc" "$(date -u -d "@$ts" '+%Y-%m-%d %H:%M:%S UTC')"
	else
		printf '%s\n' "$desc"
	fi
}

ensure_recovery_fit() {
	local board="$1"
	local local_fit="$JETHOME_TOOLS_ROOT/bins/$board/recovery.fit"
	local asset url cached tmp got sha

	if [[ -n "$RECOVERY_FIT" ]]; then
		[[ -e "$RECOVERY_FIT" ]] || { echo "RECOVERY_FIT=$RECOVERY_FIT does not exist" >&2; return 1; }
		echo "Using recovery.fit from RECOVERY_FIT: $(recovery_fit_info "$RECOVERY_FIT")" >&2
		printf '%s\n' "$RECOVERY_FIT"
		return 0
	fi

	case "$board" in
		j100) asset="recovery-j100-$RECOVERY_VERSION.fit"; sha="$RECOVERY_SHA256_J100" ;;
		j310) asset="recovery-j310-$RECOVERY_VERSION.fit"; sha="$RECOVERY_SHA256_J310" ;;
		*)
			if [[ -e "$local_fit" ]]; then
				echo "Using unverified bins/$board/recovery.fit: $(recovery_fit_info "$local_fit")" >&2
				printf '%s\n' "$local_fit"
				return 0
			fi
			echo "no published recovery for '$board'; put one at bins/$board/recovery.fit or set RECOVERY_FIT" >&2
			return 1
			;;
	esac
	url="$RECOVERY_URL_BASE/$RECOVERY_VERSION/$asset"
	cached="$JETHOME_TOOLS_CACHE/recovery/$asset"

	if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
		echo "no usable checksum pinned for '$board'" >&2
		return 1
	fi

	if [[ -e "$cached" ]]; then
		if echo "$sha  $cached" | sha256sum -c --status; then
			echo "Using cached $asset: $(recovery_fit_info "$cached")" >&2
			printf '%s\n' "$cached"
			return 0
		fi
		echo "Cached $asset fails its checksum, removing" >&2
		rm -f "$cached"
	fi

	mkdir -p "$JETHOME_TOOLS_CACHE/recovery" || return 1
	tmp="$cached.tmp.$$"

	echo "Downloading $asset from $url" >&2
	if ! curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "$tmp" "$url" >&2; then
		rm -f "$tmp"
		echo "Download of $asset failed" >&2
		return 1
	fi

	got=$(sha256sum "$tmp" | awk '{print $1}')
	if [[ "$got" != "$sha" ]]; then
		rm -f "$tmp"
		echo "Checksum mismatch for $asset: got $got, expected $sha" >&2
		return 1
	fi

	mv -f "$tmp" "$cached"
	echo "Fetched $asset: $(recovery_fit_info "$cached")" >&2
	printf '%s\n' "$cached"
}

extract_partition() {
	if [[ -n "$1" || -n "$2" || -n "$3" || -n "$4" ]] ; then
		local input_file="$1"
		local skip="$2"
		local count="$3"
		local output_file="$4"
		# 1b = 512 bytes
		dd bs=1b skip="$skip" count="$count" if="$input_file" of="$output_file" > /dev/null 2>&1 || return 1
	else
		return 2
	fi
}

