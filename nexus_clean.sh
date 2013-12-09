#!/bin/sh

NR_ARGS=4

if [ $# -ne "$NR_ARGS" ]    # script invoked with wrong command-line args?
then
  echo "Usage: `basename $0` <path> <library> <group_id> <keep_versions>"
  echo "        cleanup of whole repository: group_id=first_group_id, e.g. com"
  echo "        cleanup of just a part of the repository: group_id=more_detailed_group_id, e.g. com.only.supplier"
  echo "Example: `basename $0` /path/to/my/nexus/storage my-releases de 5"
  exit 2                    # exit and explain usage.
fi  

BASE=$1
LIBRARY=$2
# replace dots in maven group id with file separator /
GROUP_ID=`echo $3 | sed 's#\.#/#g'`

KEEP_VERSIONS=$4

if [ ! -d $BASE/$LIBRARY/$GROUP_ID ] ; then
  echo "can not access directory: $BASE/$LIBRARY/$GROUP_ID"
  exit 2
fi 

cd $BASE/$LIBRARY

# determination of artifact names and corresponding dirs, which hold every archived artifact version
# assumption: every artifact directory contains a pom file
DIRS=`find $GROUP_ID -name "*.pom" -print | \
	sort -n | sed 's#/[.a-zA-Z0-9-]*\.pom$#/#'`
# DIRS contains every version directory, but we need only the paths of the artifacts, because there may be several versions of the same artifact, the following iteration has to be cleaned up before we continue
for i in $DIRS ; do
    # check if found directory is really a directory
    cd $i; cd ..
    ARTIFACT_DIRS="$ARTIFACT_DIRS `pwd`" 
    # remove duplicates with sort -u
    ARTIFACT_DIRS=`echo $ARTIFACT_DIRS | tr " " "\n" | sort -u`
    cd $BASE/$LIBRARY
done

# walk through the artifact dirs and delete all except the last n versions ($KEEP_VERSIONS)
for artifactDir in $ARTIFACT_DIRS; do
    cd $artifactDir
    # how many subdirectories/releases are in the artifact dir?
    # numeric sort of var1.var2.var3.var4 -t= (var separator) = '.'
    DIR=`find -maxdepth 1 -type d -print | sed 's#\./##' | \
	sort -n -t\. -k1,1 -k2,2 -k3,3 -k4,4 | \
	tail -n +2`
    DIR_COUNT=`echo $DIR |  tr " " "\n" | wc -l`
    # echo "$artifactDir contains $DIR_COUNT versions"
    # how many versions have to be deleted?
    DELETE_NUMBER=`expr $DIR_COUNT - $KEEP_VERSIONS`
    if [ $DELETE_NUMBER -gt 0 ]; then
	DIRS_TO_DELETE=`echo $DIR |  tr " " "\n" | \
	    head -n $DELETE_NUMBER`
        for versionToDelete in $DIRS_TO_DELETE; do
	    rm -rf $artifactDir/$versionToDelete
	    echo "rm -rf $artifactDir/$versionToDelete"
	done
    fi
    cd $BASE/$LIBRARY
done


