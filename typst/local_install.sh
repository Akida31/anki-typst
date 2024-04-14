#!/bin/bash

VERSION=0.1.0
PACKAGE_PATH=~/.cache/typst/packages/local/anki/$VERSION/
CUR_CWD=$(pwd)

mkdir -p $PACKAGE_PATH
echo $PACKAGE_PATH
cd $PACKAGE_PATH || exit

git init
git remote add origin "$CUR_CWD"
git pull origin main
