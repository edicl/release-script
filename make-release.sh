#!/bin/sh

set -e

if [ "`git status -s`" != "" ]
then
    echo working directory is dirty
    git status -s
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

git tag v$version
git push --tags
git push --all
git archive --format=tar --prefix=${program}-${version}/ v$version | gzip > ${program}-${version}.tar.gz
scp ${program}-${version}.tar.gz netzhansa.com:/usr/local/www/site/netzhansa.com/
mv ${program}-${version}.tar.gz ${program}.tar.gz
scp ${program}.tar.gz netzhansa.com:/usr/local/www/site/netzhansa.com/
rm ${program}.tar.gz

if [ -f .post-release.sh ]
then
    sh .post-release.sh
fi
