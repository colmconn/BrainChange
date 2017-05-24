#!/bin/bash

## set -x 

trap exit SIGHUP SIGINT SIGTERM

studyName=BrainChange

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=${MDD_ROOT:-/data/sanFrancisco/$studyName}

DATA=$ROOT/data
RAW_DATA=$DATA/raw
PROCESSED_DATA=$DATA/processed

SCRIPTS_DIR=${ROOT}/scripts

GETOPT_OPTIONS=$( $GETOPT  -o "s:" --longoptions "subject::" -n ${programName} -- "$@" )
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
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [ -z $subjectNumber ] ; then 
    echo "*** ERROR: The subject ID was not provided."
    exit
fi

function reconstruct {
    output="$1"
    subject=$2
    dicomTask="$3"
    task="$4"
    
    subjectDicomContainerDir=$( ls -1d $RAW_DATA/$subject/E* | head -1 )
    if [[ ${#subjectDicomContainerDir} -gt 0 ]] && [[ -d $subjectDicomContainerDir ]] ; then 
	if [[ ! -f $subjectDicomContainerDir/dcm_info.txt ]] ; then 
	    (cd $subjectDicomContainerDir; $SCRIPTS_DIR/dcm_check.sh )
	fi
	
	series=( $( cat $subjectDicomContainerDir/dcm_info.txt   | grep -P "$dicomTask" | tail -1 | awk '{print $1}' ) )
	dcmfiles=( $( cat $subjectDicomContainerDir/dcm_info.txt | grep -P "$dicomTask" | tail -1 | awk '{print $2}' ) )
	(( run=1 ))
	(( ii=0 ))
	for sdir in ${series[$ii]} ; do
	    if [[ ${#sdir} -gt 0 ]] && [[ -d  $subjectDicomContainerDir/$sdir ]] ; then 

		echo "*** Task: \"${task}\" --> DICOM Task: \"${dicomTask}\" --> DICOM series directory: \"${sdir}\""
		dcmFile=${dcmfiles[$ii]}
		session=$PROCESSED_DATA/${subject}/$task
		if [[ ! -d $session ]] ; then 
		    echo "*** $session does not exist. Creating it now"
		    mkdir -p $session
		fi
		
		# if [[ "$dicomTask" == "resting state" ]] ; then
		#     ntask="$task$run"
		# else
		#     ntask="$task"		    
		# fi

		ntask=$task
		
		prefix="$subject.$ntask"
		echo "*** Now creating AFNI HEAD/BRIK of the ${dicomTask} task for $subject"
		echo "*** Prefix will be $prefix"
		if [[ $output == "afni" ]] || [[ $output == "both" ]] ; then 
		   ( cd $subjectDicomContainerDir;  \
		     Dimon -infile_pattern $sdir/'*.DCM' -dicom_org -gert_filename make.$ntask \
			   -save_file_list "${subject}.${ntask}.dicom.list" \
			   -gert_to3d_prefix "${subject}.${ntask}" -gert_outdir ${session} \
			   -GERT_Reco  -gert_create_dataset -quit )
		fi
		if [[ $output == "mgz" ]] || [[ $output == "both" ]] ; then   
		    ( mkdir -p $session/../mri/orig/ ; 
		      cd $subjectDicomContainerDir;  \
		      mri_convert -it dicom -ot mgz -i $dcmFile -o $session/../mri/orig/001.mgz ) 
		fi
		
	    else
		echo "*** The s-directory $sdir does not exist. Cannot reconstruct $task task data for subject ${subject}. Skipping."
	    fi
	    (( run=run+1 ))
	    (( ii=ii+1 ))
	done
    else 
	echo "*** Cannot find $subjectDicomContainerDir"
	echo "*** Skipping"
    fi
}

noDataDir=""
existingDataDirs=""

i=$((${#subjectNumber}-1))
timepoint="${subjectNumber:$i:1}"

echo "####################################################################################################"
echo "### Timepoint $timepoint: $subjectNumber"


if [[ ! -d $PROCESSED_DATA/${subjectNumber} ]] ; then
    echo "*** Making the subject's directory in the study data folder: $PROCESSED_DATA/${subjectNumber}"
    mkdir $PROCESSED_DATA/${subjectNumber}
fi


echo "****************************************************************************************************"
echo "*** T1 Anatomy reconstruction"

dicomTask="Sag T1 IRSPGR"
task="anat"
if [[ ! -f $PROCESSED_DATA/${subjectNumber}/$task/${subjectNumber}.${task}+orig.HEAD ]] ; then 
    ## reconstruct "mgz" "$subjectNumber"  "$dicomTask" "$task"
    reconstruct "afni" "$subjectNumber"  "$dicomTask" "$task"
else
    echo "*** Found $PROCESSED_DATA/${subjectNumber}/$task/${subjectNumber}.${task}+orig.HEAD. Skipping reconstruction."
fi


echo "****************************************************************************************************"
echo "*** Resting state reconstruction"

## dicomTask="fMRI"
dicomTask='(rs )?fMRI(?! Hariri).*'
task="resting"
if [[ ! -f $PROCESSED_DATA/${subjectNumber}/$task/${subjectNumber}.${task}+orig.HEAD ]] ; then 
    reconstruct "afni" "$subjectNumber"  "$dicomTask" "$task"
else
    echo "*** Found $PROCESSED_DATA/${subjectNumber}/$task/${subjectNumber}.${task}+orig.HEAD. Skipping reconstruction."
fi

echo "****************************************************************************************************"
echo "*** Hariri reconstruction"

dicomTask="Hariri"
task="hariri"
if [[ ! -f $PROCESSED_DATA/${subjectNumber}/$task/${subjectNumber}.${task}+orig.HEAD ]] ; then 
    reconstruct "afni" "$subjectNumber"  "$dicomTask" "$task"
else
    echo "*** Found $PROCESSED_DATA/${subjectNumber}/$task/${subjectNumber}.${task}+orig.HEAD. Skipping reconstruction."
fi

# echo "****************************************************************************************************"
# echo "*** T2 Anatomy reconstruction"

# dicomTask="Ax T2 FSE"
# task="t2anat"
# if [[ ! -f $dataRoot/${subjectNumber}BRIKS/${subjectNumber}.${task}+orig.HEAD ]] ; then 
#     reconstruct "$subjectNumber"  "$dicomTask" "$task"
# fi

# mv -f $PROCESSED_DATA/${subjectNumber}/$task/*$task* $PROCESSED_DATA/${subjectNumber}/anat
# rm -rf $PROCESSED_DATA/${subjectNumber}/$task
