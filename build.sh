#!/bin/bash

set -euo pipefail

SCRIPT_FILE=${BASH_SOURCE[0]}
[ -n "$SCRIPT_FILE" ] || SCRIPT_FILE=${(%):-%N} # zsh
CURDIR=$(dirname "$(realpath "$SCRIPT_FILE")")

SRC_DIR=$CURDIR/src
DIST_DIR=$CURDIR/dist
WORK_DIR=$CURDIR/work
OUT_FILE=inter.zip
if [[ "${DIST_DIR:0:2}" == "./" ]]; then
  DIST_DIR=${DIST_DIR:2}
  WORK_DIR=${WORK_DIR:2}
fi

cd "$CURDIR"

function fetch() {
  URL=$1
  DSTFILE=$2
  echo "Fetching $URL"
  curl '-#' --create-dirs -o "$DSTFILE" -L "$URL"
}

# Clean
rm -rf "$DIST_DIR" "$WORK_DIR" "$OUT_FILE"

# Fetch source fonts
GH_REPO=rsms/inter
RELEASE_URL=$(curl -s -L "https://api.github.com/repos/$GH_REPO/releases/latest" \
  | jq -r '.assets[0].browser_download_url')
RELEASE_DEST="$WORK_DIR"/inter.zip

fetch "$RELEASE_URL" "$RELEASE_DEST"
unzip -q -j "$RELEASE_DEST" \*.otf -d "$WORK_DIR"
rm "$RELEASE_DEST"

# Create LaTeX font families
TEXMF="$DIST_DIR/texmf"
autoinst \
  -logfile="$WORK_DIR/autoinst.log" \
  -vendor=public -typeface=inter \
  -sanserif \
  -target="$TEXMF" "$WORK_DIR"/*.otf

# Adapt directory structure for CTAN package
mkdir "$DIST_DIR"/{doc,enc,latex,map,opentype,tfm,type1,vf}
ln -s -r "$TEXMF/fonts/enc/dvips/inter"/* "$DIST_DIR/enc"
ln -s -r "$TEXMF/fonts/map/dvips/inter"/* "$DIST_DIR/map"
ln -s -r "$TEXMF/fonts/tfm/public/inter"/* "$DIST_DIR/tfm"
ln -s -r "$TEXMF/fonts/type1/public/inter"/* "$DIST_DIR/type1"
ln -s -r "$TEXMF/fonts/vf/public/inter"/* "$DIST_DIR/vf"

# Replace autoinst style file by our own
rm "$TEXMF/tex/latex/inter/Inter.sty"
cp "$SRC_DIR/inter.sty" "$TEXMF/tex/latex/inter"
ln -s -r "$TEXMF/tex/latex/inter"/* "$DIST_DIR/latex"

OTF_DEST="$TEXMF/fonts/opentype/public/inter/"
mkdir -p "$OTF_DEST"
cp -r "$WORK_DIR"/*.otf "$OTF_DEST"
ln -s -r "$OTF_DEST"/* "$DIST_DIR/opentype"

# Copy sources (documentation, licenses, etc.)
mkdir -p "$DIST_DIR/texmf/doc/fonts/inter"
cp -r "$SRC_DIR/doc"/* "$TEXMF/doc/fonts/inter"
ln -s -r "$TEXMF/doc/fonts/inter"/* "$DIST_DIR/doc"

cp "$SRC_DIR/README" "$TEXMF/doc/fonts/inter"
cp "$SRC_DIR/README" "$DIST_DIR"

# Create ZIP files for distribution
pushd "$DIST_DIR/texmf" >/dev/null
zip -q -r inter.tds.zip .
popd >/dev/null

REL_DIST_PATH=$(realpath --relative-to="$CURDIR" "$DIST_DIR")
zip -q -r "$OUT_FILE" "$REL_DIST_PATH" -x "$REL_DIST_PATH/texmf/*"
