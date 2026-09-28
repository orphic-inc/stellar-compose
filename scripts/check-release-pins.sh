#!/usr/bin/env bash
# The three surfaces that name a service's release must agree (#57):
#
#   docker-compose.yml   image: ghcr.io/orphic-inc/stellar-<svc>:X
#   .gitmodules          branch = vX
#   the gitlink          the commit tag vX points to
#
# The e2e job runs the specs from the ui gitlink against the ui image, so a
# gitlink that disagrees with the image would test one release with another's
# specs and still pass. The 0.9.7 cut left `branch =` at v0.9.6, and nothing
# noticed until Renovate did.
#
# api and ui on different releases only warns. CONTRIBUTING's release step 3
# holds the api pin back when the ui has not caught up (#49), and that PR must
# stay mergeable; the e2e job still proves the pair works together.
#
# Reads the index, not HEAD, so it also checks a staged change before commit.
# Needs network access: the tag is resolved on the submodule's remote.
# Plain bash 3 (macOS /bin/bash): no associative arrays.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

fail=0
versions=""

err() {
  echo "::error::$1"
  fail=1
}

for svc in api ui; do
  image=$(sed -nE "s#^[[:space:]]*image:[[:space:]]*ghcr\.io/orphic-inc/stellar-${svc}:([^[:space:]]+).*#\1#p" docker-compose.yml)
  if [ -z "$image" ] || [ "$(printf '%s\n' "$image" | wc -l)" -ne 1 ]; then
    err "$svc: expected one image pin for stellar-$svc in docker-compose.yml, found '${image}'"
    continue
  fi
  versions="$versions $image"

  branch=$(git config -f .gitmodules --get "submodule.$svc.branch" || true)
  if [ "$branch" != "v$image" ]; then
    err "$svc: .gitmodules branch is '$branch', but the image pin is $image (expected v$image)"
  fi

  gitlink=$(git ls-files -s -- "$svc" | awk '$1 == "160000" { print $2 }')
  if [ -z "$gitlink" ]; then
    err "$svc: no submodule gitlink recorded at '$svc'"
    continue
  fi

  # actions/checkout has no SSH key here; GitHub serves the same repo over HTTPS.
  url=$(git config -f .gitmodules --get "submodule.$svc.url" | sed -E 's#^git@github\.com:#https://github.com/#')
  refs=$(git ls-remote "$url" "refs/tags/v$image" "refs/tags/v$image^{}")
  # An annotated tag lists its object and then the commit (^{}); prefer the commit.
  tagged=$(printf '%s\n' "$refs" | awk '/\^\{\}$/ { print $1 }')
  if [ -z "$tagged" ]; then
    tagged=$(printf '%s\n' "$refs" | awk 'NF { print $1 }')
  fi
  if [ -z "$tagged" ]; then
    err "$svc: tag v$image does not exist on $url"
  elif [ "$gitlink" != "$tagged" ]; then
    err "$svc: gitlink is ${gitlink:0:7}, but v$image is ${tagged:0:7}"
  else
    echo "$svc: $image — image, .gitmodules and gitlink (${gitlink:0:7}) agree"
  fi
done

# Split on purpose: one word per pinned version, which never contain spaces.
# shellcheck disable=SC2086
set -- $versions
if [ $# -eq 2 ] && [ "$1" != "$2" ]; then
  echo "::warning::the stack pins api $1 with ui $2. That is only right as a deliberate hold-back; record the pairing check (CONTRIBUTING.md, Workflow 3 step 3) in the PR. A compose version tag names a stack whose pins agree."
fi

exit "$fail"
