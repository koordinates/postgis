#!/bin/bash
set -eu

if [ -n "${KX_BUILD_DEBUG-}" ]; then
  echo "Enabling script debugging..."
  set -x
fi

export TIMEFORMAT='🕑 %1lR'
export DEBEMAIL=support@koordinates.com
export DEBFULLNAME="Koordinates CI Builder"

echo "Updating changelog..."

if which ggrep ; then
  # so we can run this locally on MacOS
  # (run `brew install grep` to install this)
  GREP=ggrep
else
  GREP=grep
fi

# add version number vars
source ./Version.config

DEB_BASE_VERSION="${POSTGIS_MAJOR_VERSION}.${POSTGIS_MINOR_VERSION}.${POSTGIS_MICRO_VERSION}"
DEB_VERSION="${DEB_BASE_VERSION}+kx-ci${BUILDKITE_BUILD_NUMBER}-$(git show -s --date=format:%Y%m%d --format=git%cd.%h)"
echo "Debian Package Version: ${DEB_VERSION}"

if [ -n "${BUILDKITE_AGENT_ACCESS_TOKEN-}" ] ; then 
  buildkite-agent meta-data set deb-base-version "$DEB_BASE_VERSION"
  buildkite-agent meta-data set deb-version "$DEB_VERSION"

  echo -e ":debian: Package Version: \`${DEB_VERSION}\`" \
      | buildkite-agent annotate --style info --context deb-version
fi

time docker run \
  -v "$(pwd):/src" \
  -w "/src" \
  -e DEBEMAIL \
  -e DEBFULLNAME \
  "${ECR}/ci-tools:master.latest" \
    dch --distribution jammy --newversion "${DEB_VERSION}" "Koordinates CI build of ${BUILDKITE_COMMIT}: branch=${BUILDKITE_BRANCH} tag=${BUILDKITE_TAG-}"

BUILD_CONTAINER="build-${BUILDKITE_JOB_ID}"

echo "--- Building debian package ..."
# Uses a docker volume for ccache
time docker run \
  --name "${BUILD_CONTAINER}" \
  -v "$(pwd):/kx/source" \
  -v "ccache:/ccache" \
  -e CCACHE_DIR=/ccache \
  -w "/kx/source" \
  "${ECR}/jammybuild:master.latest" \
    /kx/buildscripts/build_binary_package.sh -uc -us

echo "--- Signing debian archives ..."
# docker doesn't run a shell, so the glob has to be expanded here. sign-debs used
# to do it for us by way of dpkg-sig; it now calls debsigs, which doesn't glob.
DEB_PATHS=()
for deb in build-jammy/*.deb; do
  # an unmatched glob stays literal, so skip anything that isn't a real file
  [ -f "${deb}" ] || continue
  DEB_PATHS+=("/src/${deb}")
done
if [ "${#DEB_PATHS[@]}" -eq 0 ]; then
  echo "No .deb files in build-jammy/ to sign" >&2
  exit 1
fi

time docker run \
  -v "$(pwd):/src" \
  -e "GPG_KEY=${APT_GPG_KEY}" \
  -w "/src" \
  "${ECR}/ci-tools:master.latest" \
    sign-debs "${DEB_PATHS[@]}"
