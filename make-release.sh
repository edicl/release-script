#!/bin/sh

set -e

if [ "`git status -s`" != "" ]
then
    echo working directory is dirty
    git status -s
    exit 1
fi

if [ "$EDICL_GITHUB_TOKEN" = "" ]
then
    echo EDICL_GITHUB_TOKEN environment variable not set, cannot continue
    echo You can generate a token using https://github.com/settings/applications#personal-access-tokens
    exit 1
fi

if [ "$EDITOR" = "" ]
then
    EDITOR=vi
fi

program=`basename $PWD`
current_version=`perl -ne 'print "$1\n" if (/:version\s*"(.*?)"/)' ${program}.asd`

if [ "$current_version" = "" ]
then
    echo could not determine version number 1>&2
    exit 1
fi

default_next_version=`echo $current_version | perl -pe 's/(\d+)$/int($1) + 1/e'`

echo "Version number [$default_next_version]: \c"
read next_version
if [ "$next_version" = "" ]
then
    next_version=$default_next_version
fi

(
    echo Version $next_version
    date +%Y-%m-%d
    git log --format='%s (%an)' v$current_version.. | cat
    echo
    cat CHANGELOG
) > CHANGELOG.new
mv CHANGELOG.new CHANGELOG

$EDITOR CHANGELOG

version=$next_version

perl -pi -e "s/$current_version/$version/ if (/:version/)" ${program}.asd

if [ -f .pre-release.sh ]
then
    sh .pre-release.sh
fi

echo "Press return to release $program v$version: \c"
read line

git commit -am "release $version"

echo "making $program release $version"
if git tag -l | fgrep -qx v$version
then
    echo release $version already tagged
    exit 1
fi

git push --all

curl -d @- -H 'Content-Type: application/json' -u $EDICL_GITHUB_TOKEN:x-oauth-basic https://api.github.com/repos/edicl/$program/releases <<EOD
{
  "tag_name": "v$version",
  "target_commitish": "master",
  "name": "v$version",
  "body": "Release $version",
  "draft": false,
  "prerelease": false
}
EOD

if [ -f .post-release.sh ]
then
    sh .post-release.sh
fi
