#!/bin/bash

# bail on error
set -e

DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )

# Note: dart_analyzer needs to be run from the root directory for proper path
# canonicalization.
pushd $DIR/..
echo Compile RSP files
find -name *.rsp.dart | xargs rm -rf
dart bin/rspc.dart */*/*.rsp.html

echo Analyzing library for warnings or type errors
dart_analyzer --fatal-warnings --fatal-type-errors lib/*.dart \
  || echo -e "Ignoring analyzer errors"

echo Analyzing test cases
dart_analyzer --fatal-warnings --fatal-type-errors */*/*/main.dart \
  || echo -e "Ignoring analyzer errors"
rm -rf out/*
popd

#dart --enable-type-checks --enable-asserts test/run_all.dart $@
#no unit test yet
