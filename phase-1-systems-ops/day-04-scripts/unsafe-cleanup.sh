#!/bin/bash

# "cleanup" script — deletes old logs from a directory and archives them
# DELIBERATELY UNSAFE — do not run as-is

LOGDIR=$1
ARCHIVE=/tmp/archive

echo Cleaning up logs in $LOGDIR

rm -rf $LOGDIR/*.tmp

for f in `ls $LOGDIR`; do
  if [ $f == *.log ]; then
    cp $f $ARCHIVE/$f
    echo archived $f
  fi
done

tar czf $ARCHIVE/logs.tar.gz $LOGDIR/*.log

echo Done. Files archived: `ls $ARCHIVE | wc -l`
