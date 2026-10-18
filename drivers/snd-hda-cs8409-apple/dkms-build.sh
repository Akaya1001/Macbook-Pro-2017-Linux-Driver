#!/bin/bash
# Build snd-hda-codec-cs8409.ko with Apple (MacBookPro 13,x/14,x, iMac 18/19) support
# from davidjo/snd_hda_macbookpro for ONE Ubuntu kernel, out of tree.
#
#   usage: dkms-build.sh <kernelver> [kernel_build_dir]      (DKMS: MAKE[0])
#          dkms-build.sh --clean
#
# The module includes private HDA headers (sound/hda/common/*.h, codecs/generic.h)
# that linux-headers does not ship, and it accesses struct hda_gen_spec directly.
# Those headers MUST come from exactly the Ubuntu source of the target kernel ABI:
# Ubuntu 7.0.x has 'share_spdif_kctl' in struct hda_multi_out that kernel.org v7.0
# lacks -> 8-byte shift of hda_gen_spec.autocfg -> GPF in probe (davidjo #205).
# So the source is looked up strictly by "<x.y.z>-<ABI>." and never guessed:
#   1. vendored   ./ksrc/<x.y.z>-<ABI>.*            (7.0.0-38.38 ships in this package)
#   2. cache      $CACHE_DIR/<x.y.z>-<ABI>.*
#   3. installed  linux-source-<x.y.z> / linux-hwe-*-source-<x.y.z> at that version
#   4. download   apt-get download of that package/version (apt-verified), if allowed
# Then davidjo's files are dropped in, the patches in ./patches are applied with
# fuzz 0 (any drift fails loudly instead of mis-applying), and kbuild builds it.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"
log() { echo "[cs8409-apple] $*"; }
die() { echo "[cs8409-apple] ERROR: $*" >&2; exit 1; }

if [[ ${1:-} == --clean ]]; then rm -rf "$HERE/build" "$HERE/ksrc-work"; exit 0; fi

KVER=${1:?usage: dkms-build.sh <kernelver> [kernel_build_dir]}
KBUILD=${2:-/lib/modules/$KVER/build}
# shellcheck source=build.conf
. "$HERE/build.conf"
CACHE_DIR=${CS8409_CACHE_DIR:-$CACHE_DIR}
ALLOW_APT_DOWNLOAD=${CS8409_ALLOW_APT_DOWNLOAD:-$ALLOW_APT_DOWNLOAD}

[[ $KVER =~ ^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)-(.+)$ ]] ||
    die "'$KVER' is not an Ubuntu <x.y.z>-<ABI>-<flavour> kernel; no matching source can be determined"
BASE=${BASH_REMATCH[1]}
ABI=${BASH_REMATCH[2]}
WANT="$BASE-$ABI."                       # e.g. 7.0.0-38.  (matches source version 7.0.0-38.38)
[[ -f $KBUILD/.config && -f $KBUILD/Module.symvers ]] || die "kernel build dir $KBUILD incomplete (install linux-headers-$KVER)"
grep -Eq '^CONFIG_SND_HDA_CODEC_CS8409=[ym]' "$KBUILD/.config" || die "CONFIG_SND_HDA_CODEC_CS8409 not enabled in $KVER"

SUBSET=(
    sound/hda/common/hda_local.h
    sound/hda/common/hda_auto_parser.h
    sound/hda/common/hda_jack.h
    sound/hda/common/hda_beep.h
    sound/hda/codecs/generic.h
    sound/hda/codecs/side-codecs/hda_component.h
    sound/hda/codecs/cirrus/cs8409.c
    sound/hda/codecs/cirrus/cs8409.h
    sound/hda/codecs/cirrus/cs8409-tables.c
    include/sound/hda_codec.h
    include/sound/hdaudio.h
)
SRC=$HERE/ksrc-work
rm -rf "$SRC" "$HERE/build"
mkdir -p "$SRC"

subset_ok() {   # $1 dir: complete and checksums intact
    local f
    for f in "${SUBSET[@]}"; do [[ -f $1/$f ]] || return 1; done
    [[ -f $1/SHA256SUMS ]] && (cd "$1" && sha256sum --quiet -c SHA256SUMS >/dev/null 2>&1)
}
untar_subset() {   # $1 tarball path or '-' (stdin, bzip2) -> $SRC
    local pats=() f
    for f in "${SUBSET[@]}"; do pats+=("*/$f"); done
    tar -xjf "$1" -C "$SRC" --strip-components=1 --wildcards "${pats[@]}"
    for f in "${SUBSET[@]}"; do [[ -f $SRC/$f ]] || die "kernel source tarball lacks $f"; done
}
seal_and_cache() {   # $1 source version, $2 origin text
    (cd "$SRC" && find sound include -type f | sort | xargs sha256sum > SHA256SUMS)
    printf '%s\n' "$2" > "$SRC/ORIGIN"
    if mkdir -p "$CACHE_DIR" 2>/dev/null && [[ -w $CACHE_DIR ]]; then
        rm -rf "${CACHE_DIR:?}/$1.tmp" && cp -a "$SRC" "$CACHE_DIR/$1.tmp" &&
            rm -rf "${CACHE_DIR:?}/$1" && mv "$CACHE_DIR/$1.tmp" "$CACHE_DIR/$1" &&
            log "cached source subset in $CACHE_DIR/$1"
    fi
}

SRCVER="" ORIGIN=""
# 1 + 2: vendored subset or cache
for d in "$HERE"/ksrc/"$WANT"* "$CACHE_DIR"/"$WANT"*; do
    [[ -d $d && $d != *.tmp ]] || continue
    if subset_ok "$d"; then
        cp -a "$d/." "$SRC/"
        SRCVER=$(basename "$d"); ORIGIN="subset $d"
        break
    fi
    log "ignoring incomplete/corrupt source subset $d"
done
# 3: installed linux-source package at exactly this ABI
if [[ -z $SRCVER ]]; then
    while read -r pkg ver st; do
        [[ $st == ii && $ver == "$WANT"* ]] || continue
        tb=$(dpkg -L "$pkg" | grep -E '\.tar\.bz2$' | while read -r f; do [[ -f $f && ! -L $f ]] && echo "$f"; done | head -n1 || true)
        [[ -n $tb ]] || continue
        log "extracting sound/hda subset from $tb ($pkg $ver)"
        untar_subset "$tb"
        SRCVER=$ver; ORIGIN="installed package $pkg $ver ($tb)"
        seal_and_cache "$SRCVER" "$ORIGIN"
        break
    done < <(dpkg-query -W -f '${Package} ${Version} ${db:Status-Abbrev}\n' \
                 "linux-source-$BASE" "linux-hwe-*-source-$BASE" 2>/dev/null || true)
fi
# 4: apt-get download of exactly that version (apt verifies it against the signed archive metadata)
if [[ -z $SRCVER && $ALLOW_APT_DOWNLOAD == yes ]]; then
    for pkg in $(apt-cache pkgnames 2>/dev/null | grep -E "^linux(-hwe-[0-9.]+)?-source-${BASE//./\\.}\$" || true); do
        ver=$(apt-cache madison "$pkg" 2>/dev/null | awk -F' *\\| *' -v w="$WANT" 'index($2, w) == 1 && !v { v = $2 } END { print v }' || true)
        [[ -n $ver ]] || continue
        dl=$(mktemp -d "${TMPDIR:-/tmp}/cs8409-src.XXXXXX")
        chmod 755 "$dl"
        log "downloading $pkg=$ver (once per kernel ABI, ~190 MB)"
        if (cd "$dl" && apt-get -q download "$pkg=$ver"); then
            deb=$(ls "$dl"/*.deb)
            member=$(dpkg-deb -c "$deb" | awk '$1 ~ /^-/ && $6 ~ /^\.\/usr\/src\/.*\.tar\.bz2$/ && !m { m = $6 } END { print m }' || true)
            [[ -n $member ]] || die "no source tarball inside $deb"
            dpkg-deb --fsys-tarfile "$deb" | tar -xOf - "$member" | untar_subset -
            SRCVER=$ver; ORIGIN="apt-get download $pkg=$ver ($(sha256sum "$deb" | cut -d' ' -f1))"
            seal_and_cache "$SRCVER" "$ORIGIN"
        fi
        rm -rf "$dl"
        [[ -n $SRCVER ]] && break
    done
fi
[[ -n $SRCVER ]] || die "no Ubuntu kernel source for ABI $WANT* found. Install it and rebuild:
    sudo apt install linux-source-$BASE   # must be version ${WANT}*
    sudo dkms install snd-hda-cs8409-apple/<version> -k $KVER"

# Cross-check: public headers of that source must equal the target kernel's headers.
for f in include/sound/hda_codec.h include/sound/hdaudio.h; do
    cmp -s "$SRC/$f" "$KBUILD/$f" || die "$f of source $SRCVER differs from $KBUILD/$f - wrong source for $KVER"
done
log "kernel $KVER, HDA source $SRCVER [$ORIGIN]"

# Assemble the out-of-tree hda tree exactly like davidjo's install.cirrus.driver.sh (>= 6.17 layout).
H=$HERE/build/hda
mkdir -p "$H/common" "$H/codecs/cirrus" "$H/codecs/side-codecs"
cp "$SRC"/sound/hda/common/*.h "$H/common/"
cp "$SRC/sound/hda/codecs/generic.h" "$H/codecs/"
cp "$SRC/sound/hda/codecs/side-codecs/hda_component.h" "$H/codecs/side-codecs/"
cp "$SRC"/sound/hda/codecs/cirrus/cs8409* "$H/codecs/cirrus/"
cp "$HERE/upstream/makefiles/Makefile"        "$H/Makefile"
cp "$HERE/upstream/makefiles/Makefile_common" "$H/common/Makefile"
cp "$HERE/upstream/makefiles/Makefile_codecs" "$H/codecs/Makefile"
cp "$HERE/upstream/makefiles/Makefile_cirrus" "$H/codecs/cirrus/Makefile"
for f in cirrus_apple.h patch_cirrus_boot84.h patch_cirrus_new84.h patch_cirrus_real84.h \
         patch_cirrus_hda_generic_copy.h patch_cirrus_real84_i2c.h; do
    cp "$HERE/upstream/patch_cirrus/$f" "$H/codecs/cirrus/"
done
for p in "$HERE"/patches/*.patch; do
    log "applying $(basename "$p")"
    patch -d "$H" -p1 -F0 -N --no-backup-if-mismatch -s < "$p" ||
        die "$(basename "$p") does not apply cleanly to $SRCVER - needs porting for this kernel"
done

CFLAGS="$APPLE_CFLAGS"
grep -q '^CONFIG_SND_HDA_RECONFIG=y' "$KBUILD/.config" && CFLAGS="$CFLAGS -DCONFIG_SND_HDA_RECONFIG=1"
CCARG=()
cc=$(sed -n 's/^CONFIG_CC_VERSION_TEXT="\([^ ]*\) .*/\1/p' "$KBUILD/.config")
[[ -n $cc ]] && command -v "$cc" >/dev/null && CCARG=(CC="$cc")

log "make -C $KBUILD ${CCARG[*]} M=$H CFLAGS_MODULE=\"$CFLAGS\" modules"
make -C "$KBUILD" "${CCARG[@]}" M="$H" CFLAGS_MODULE="$CFLAGS" -j"$(nproc)" modules

KO=$H/codecs/cirrus/snd-hda-codec-cs8409.ko
[[ -f $KO ]] || die "module not built"
vm=$(modinfo -F vermagic "$KO")
[[ ${vm%% *} == "$KVER" ]] || die "vermagic '$vm' does not match $KVER"
modinfo -F alias "$KO" | grep -qx 'hdaudio:v10138409r\*a01\*' || die "hdaudio:v10138409 alias missing"
grep -aq 'Primary patch_cs8409 NOT FOUND trying APPLE' "$KO" || die "Apple fallback code missing from module"
{
    echo "kernel=$KVER"
    echo "hda_source=$SRCVER"
    echo "hda_source_origin=$ORIGIN"
    echo "upstream=$(head -n1 "$HERE/upstream/UPSTREAM_COMMIT")"
    echo "patches=$(cd "$HERE/patches" && ls ./*.patch | xargs -n1 basename | tr '\n' ' ')"
    echo "cflags=$CFLAGS"
    echo "vermagic=$vm"
    echo "sha256=$(sha256sum "$KO" | cut -d' ' -f1)"
} | tee "$HERE/build/BUILDINFO"
log "OK: $KO"
