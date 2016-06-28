#!/bin/bash

## set -x

studyName=BrainChange
ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

cd $DATA/processed

subjects=$( ls -d b* )

echo "subjectId,anatExists,restExists"
for ss in $subjects ; do

    if [[ -f $ss/anat/${ss}.anat+orig.HEAD ]] ; then
	anatExists="TRUE"
    else
	anatExists="FALSE"
    fi
    
    if [[ -f $ss/resting/${ss}.resting+orig.HEAD ]] ; then
	restExists="TRUE"
    else
	restExists="FALSE"
    fi
    echo "$ss,$anatExists,$restExists"
    
done
