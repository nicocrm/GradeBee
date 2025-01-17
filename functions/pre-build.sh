#!/bin/sh
# Prepare build of the function by open runtimes by moving the function code to
# the current directory and adjusting the import path in pubspec.yaml

set -e
FUNCTION=$1

mv $FUNCTION/* .
sed -i 's#\.\./#./#' pubspec.yaml
sed -i 's#^name: .*#name: open_runtimes_dart_function#' pubspec.yaml
dart pub get