#!/bin/sh
NAME=`dirname $1`
find $NAME -maxdepth 1 | grep -v source | grep -vG \\.git | grep -vG $NAME$ | xargs rm -rf {}
