#!/bin/bash

set -euo pipefail

apt update && apt install -y \
  curl \
  jq \
  texlive-font-utils \
  zip
