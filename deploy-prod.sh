#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# hebbsheffer-pages is the source for three deploys (GitHub Pages, beta
# staging, www prod) that each need a different robots.txt. The committed
# copy stays "Disallow: /" (correct for GitHub Pages and staging); this
# script swaps in the "allow" version only for the prod deploy, then
# restores the committed copy so it never lingers in the working tree.
trap 'git checkout -- robots.txt' EXIT

cp robots-prod.txt robots.txt
firebase deploy --only hosting:hebbsheffer-ca-prod
