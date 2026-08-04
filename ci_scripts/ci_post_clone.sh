#!/bin/sh
# Xcode Cloud runs this after cloning, before resolving dependencies or building.
# (GitHub Actions never sees it — ci_scripts/ is an Xcode Cloud convention.)
#
# TestFlight rejects any upload whose build number it has seen before, and the
# project pins CURRENT_PROJECT_VERSION = 1 for reproducible local builds. So every
# cloud build stamps Xcode Cloud's own monotonically increasing build number over
# it — all targets at once, because an embedded extension whose version disagrees
# with its host app fails App Store validation.
set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "Not running in Xcode Cloud (CI_BUILD_NUMBER unset); leaving versions alone."
  exit 0
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;/g" \
  DrinkTracker.xcodeproj/project.pbxproj
echo "Stamped CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
