#!/bin/bash

# bail on error
set -e

# TODO(sigmund): replace with a real test runner
DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )

# Note: dart_analyzer needs to be run from the root directory for proper path
# canonicalization.
pushd $DIR/..
echo Analyzing library for warnings or type errors
dart_analyzer --fatal-warnings --fatal-type-errors lib/*.dart \
  || echo -e "Ignoring analyzer errors ([36mdartbug.com/8132[0m)"
rm -rf out/*
popd

#dart --enable-type-checks --enable-asserts test/run_all.dart $@
#no unit test yet
