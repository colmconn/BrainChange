#!/bin/bash

## set -x 

trap exit SIGHUP SIGINT SIGTERM
programName=`basename $0`

studyName=BrainChange

ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data
RAW_DATA=$DATA/raw
PROCESSED_DATA=$DATA/processed
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts
SUBJECTS_DIR=$PROCESSED_DATA

GETOPT=$( which getopt )
GETOPT_OPTIONS=$( $GETOPT  -o "s:l:" --longoptions "subject:,seedlist:" -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-s|--subject)
	    subjectNumber=$2; shift 2 ;;
	-l|--seedlist)
	    seedList=$2; shift 2 ;;
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [ -z $subjectNumber ] ; then 
    echo "*** ERROR: The subject ID was not provided. Exiting"
    exit
fi

if [ ! -f $seedList ] ; then
    echo "*** ERROR: The seed list file does not exit. Exiting"
    exit
else 
    seeds=$( eval echo $( cat $seedList ) )
fi

preprocessedRsfcDir=$PROCESSED_DATA/$subjectNumber/rsfcPreprocessed

if [[ ! -d $preprocessedRsfcDir ]] ; then
    echo "*** No preprocessed RSFC data for $subjectNumber"
    exit 1
fi

echo "*** Computing RSFC for the following seeds:"
echo $seeds

[[ ! -d $PROCESSED_DATA/$subjectNumber/rsfc ]] && mkdir $PROCESSED_DATA/$subjectNumber/rsfc
cd $PROCESSED_DATA/$subjectNumber/rsfc

for seed in $seeds ; do

    seedName=${seed##*/}
    if echo $seedName | grep -q "nii" ; then 
	seedName=${seedName%%.nii*}
    else 
	seedName=${seedName%%+*}
    fi

    mkdir ${seedName}

    echo "*** Extracting timeseries for seed ${seed}"
    3dROIstats -quiet -mask_f2short -mask ${seed} ${preprocessedRsfcDir}/errts.${subjectNumber}.anaticor+tlrc.HEAD > ${seedName}/${seedName}.ts.1D

    echo "*** Computing Correlation for seed ${seedName}"
    3dfim+ -input ${preprocessedRsfcDir}/errts.${subjectNumber}.anaticor+tlrc.HEAD -ideal_file ${seedName}/${seedName}.ts.1D -out Correlation -bucket ${seedName}/${seedName}_corr
    
    echo "*** Z-transforming correlations for seed ${seedName}"
    3dcalc -datum float -a ${seedName}/${seedName}_corr+tlrc.HEAD -expr 'log((a+1)/(a-1))/2' -prefix ${seedName}/${seedName}.z-score

    3drefit -sublabel 0 $subjectNumber ${seedName}/${seedName}.z-score+tlrc.HEAD
done
