#!/bin/bash

# bail on error
set -e

DIR=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )

# Note: dart analyze needs to be run from the root directory to analyze the whole package.
pushd $DIR/..
echo Compile RSP files
find . -name *.rsp.dart | xargs rm -rf
tool/rspc -f

echo Analyzing for warnings or type errors
dart analyze --fatal-warnings

echo Running tests
dart test "$@"
popd
