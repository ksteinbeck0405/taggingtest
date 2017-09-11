#! /bin/bash
set -e -x

echo -n "Are you sure you want to merge from develop to master and push to the indigo-ag fork?"
read ANSWER
if echo "$ANSWER" | grep -iq "^y" ;then
    echo "Continuing merge to master"
else
    echo "Canceling merge"
    exit 1
fi

MERGE_DIR='/tmp/indigo-repo-merge'

#gets github repo name of current project
REPO=$(git config --list | grep remote.origin.url | sed 's%^.*/\([^/]*\)\.git$%\1%g')

#cleanup merge dir if exists
rm -Rf "${MERGE_DIR}"

#make mergedir
mkdir -p "${MERGE_DIR}"

#clone indigo develop
cd "${MERGE_DIR}"
git clone git@github.com:ksteinbeck0405/"${REPO}".git
cd "${REPO}"

#check if changes exist in master and not develop
if [[ !  -z  $(git log origin/develop..origin/master)  ]]; then
    echo "Master has commits that develop does not."
    echo "Canceling the merge. Please investigate"
    exit 1
else
    echo "Develop is even with master changes"
    echo "Continuing"
fi

#fetch origin
if ! git fetch origin; then
    echo "error: Could not fetch from origin"
    exit 1
fi

#checkout develop
if ! git checkout develop; then
    echo "error: could not checkout develop"
    exit 1
fi

#checkout master
if ! git checkout master; then
    echo "error: could not checkout master"
fi

#fast forward merge to master
if ! git merge --ff develop; then
    echo "error: could not merged rebased branch"
fi

#push merge
if ! git push origin master; then
    echo "error: could not push merge to master"
fi

#compare differences
echo "Comparing master and develop branches"
if [[ !  -z  $(git log origin/master..origin/develop)  ]]; then
    echo "Master and develop have different commits."
    echo "Merge was successful but the branches are out of sync. Please investigate"
    exit 1
else
    echo "Master is even with develop commits"
    echo "Merge was successful"
fi

#cleanup merge dirs
rm -Rf "${MERGE_DIR}"
exit