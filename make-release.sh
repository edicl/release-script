#!/bin/sh

set -e

program=`basename $PWD`
if [ -f .pre-release.sh ]
then
    sh .pre-release.sh
fi

if [ -f CHANGELOG ]
then
    version=`grep -m 1 Version CHANGELOG | sed -e 's/.* //'`
    
    if sed -ne 2p CHANGELOG | grep -vq '^20..-..-..$'
    then
        echo "expected date in second line of CHANGELOG, can't continue"
        exit 1
    fi
else
    version=`perl -ne 'print "$1\n" if (/:version\s*"(.*?)"/)' ${program}.asd`
fi

if [ "$version" = "" ]
then
    echo could not determine version number 1>&2
    exit 1
fi

echo "making $program release $version"
if git tag -l | fgrep -qx v$version
then
    echo release $version already tagged
    exit 1
fi

if [ "`git status -s`" != "" ]
then
    echo working directory is dirty
    git status -s
    exit 1
fi

git commit --allow-empty -m "release $version"
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
