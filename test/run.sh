#!/bin/bash

# bail on error
set -e

DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )

# Note: dartanalyzer needs to be run from the root directory for proper path
# canonicalization.
pushd $DIR/..
echo Compile RSP files
find -name *.rsp.dart | xargs rm -rf
dart bin/rspc.dart */*/*.rsp.html

echo Analyzing library for warnings or type errors
dartanalyzer --fatal-warnings --fatal-type-errors lib/*.dart \
  || echo -e "Ignoring analyzer errors"

for fn in `grep -l 'main[(][)]' */*/*/*.dart|grep -v packages/`; do
	echo Analyzing $fn
	dartanalyzer --fatal-warnings --fatal-type-errors lib/*.dart \
	  || echo -e "Ignoring analyzer errors"
done

rm -rf out/*
popd

#dart --enable-type-checks --enable-asserts test/run_all.dart $@
#no unit test yet
