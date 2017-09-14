#! /bin/bash
set -e -x
## About ##
# Script used to run in CI after a production deploy. Two tags will be created: latest and new version eg. release-v2
# Flow #
# - Script should only be run after a production deploy through CI automation
# - Removing latest (if exists) in order to get current version tag (excluding latest)
# - Create new tag eg release-v2
# - Removing old tags. We only want the 10 most recent (excluding latest)
# To Set:
#   Tag_Max=
#   This is the number of tags that we will keep, the remaining will be cleaned-up
#   Default value will be 10. That will remove all tags after the 10th

TAG_MAX='10'

# install new version of git. Cirlceci has an old version
sudo su -c "echo 'deb http://ppa.launchpad.net/git-core/ppa/ubuntu trusty main' > /etc/apt/sources.list.d/git-aptrepo.list"
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E1DF1F24
sudo apt-get update && sudo apt-get install git
# Bypassing manual host checking
#mkdir -p ~/.ssh/ && echo -e "Host github.com\n\tHostName github.com\n\tUser auto-git" > ~/.ssh/config
#mkdir -p ~/.ssh/ && echo -e "Host github.com\n\tStrictHostKeyChecking no\n" > ~/.ssh/config

# Removing latest tag
if ! git rev-parse latest; then
    echo "warning: latest tag doesn't exist"
else
    echo "Latest tag exists. Removing in order to re-point latest"
    git tag -d latest && git push origin :refs/tags/latest
fi

# Gets current tag
## Additional: || true is set because if the cmd fails with 'no names found' we want it
#  to create the initial tag. Otherwise it fails with exit 1
CURRENT_TAG=$(git describe --abbrev=0 --tags 2>&1) || true
if [[ $CURRENT_TAG =~ "release" ]]; then
  echo "Current tag: $CURRENT_TAG"
elif [[ $CURRENT_TAG =~ "No names found" ]]; then
  CURRENT_TAG="release-v0"
  echo "Creating initial release tag"
else
  echo "Error: Could not fetch current tag"
  exit 1
fi

# Split tag into array to increment version number
VERSION_BITS=(${CURRENT_TAG//-/ })
PREFIX=${VERSION_BITS[0]}
BODY=${VERSION_BITS[1]::1}
CURRENT_NUM=${VERSION_BITS[1]:1}
INCR_NUM=$((CURRENT_NUM+1))

NEW_TAG="$PREFIX"-"$BODY""$INCR_NUM"

# Creates new tag
if ! git tag "$NEW_TAG"; then
    echo "error: Could not create new tag"
    exit 1
else
    echo "Updated $CURRENT_TAG to $NEW_TAG"
fi

# Gets a list of all tags sorted by committerdate (latest first)
# Starting with the $TAG_MAX tag it loops through the remaining tags and cleans them up
SORTED_TAGS=($(git tag --sort=-committerdate))

for ((i = "$TAG_MAX"; i < ${#SORTED_TAGS[@]}; i++));
do
    echo "Removing tag: ${SORTED_TAGS[i]}"
    git tag -d "${SORTED_TAGS[i]}" && git push origin :refs/tags/"${SORTED_TAGS[i]}"
done

# Creates latest tag
if ! git tag latest; then
    echo "error: Could not create latest tag"
    exit 1
else
    echo "Re-pointed latest tag to current version"
fi

# Push tags
if ! git push --tags; then
    echo "error: Could not push new tags"
    exit 1
else
    echo "Successfully pushed new tags to remote"
fi
