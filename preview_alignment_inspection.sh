#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap die SIGHUP SIGINT SIGTERM

function  die {
    osascript -e 'quit app "Preview"'
    exit
}

studyName=BrainChange

if [[ $( uname -s) == "Darwin" ]] ; then
    rootDir="/Volumes/data"
elif [[ $( uname -s) == "Linux" ]] ; then
    rootDir="/data"
    echo "*** Sorry this program is not yet set up to run on Linux. Run it on a MAC"
    exit 1
else 
    echo "Sorry can't set data directories for this computer"
    exit 1
fi


SCRIPTS_DIR=$rootDir/sanFrancisco/$studyName/scripts
DATA=$rootDir/sanFrancisco/$studyName/data
PROCESSED_DATA=$DATA/processed
RAW_DATA=$DATA/raw

task=resting

alignment_dir=alignmentTest.unif.nozp

if [[ $# -gt 0 ]] ; then
    subjects="$*"
else
    subjects=$( cd ../data/raw ; gfind ./ -maxdepth 1 -type d -a -name 'bc[0-9][0-9][0-9][abc]' -printf "%f\n" )
fi

subjectCount=$( echo $subjects | wc -w )

if [[ -f ${SCRIPTS_DIR}/${task}_alignment_parameters.sh ]] ; then
    echo "WARNING: moving pre-existing ${task}_alignment_parameters.sh to ${task}_alignment_parameters.sh.orig.$$"
    mv -f ${SCRIPTS_DIR}/${task}_alignment_parameters.sh ${SCRIPTS_DIR}/${task}_alignment_parameters.sh.orig.$$
fi

echo "Appending the following code to ${task}_alignment_parameters.sh"
cat <<EOF | tee ${SCRIPTS_DIR}/${task}_alignment_parameters.sh
     case \$subject in
EOF

## sc = subject count
(( sc=1 )) 
for subject in $subjects ; do
   
    if [[ "x$subject" == "x" ]] ; then
	break
    fi
    echo   "####################################################################################################"
    printf "### Subject: %s (%03d of %03d)\n" $subject $sc $subjectCount
    echo   "####################################################################################################"

    if [[ ! -f $PROCESSED_DATA/$subject/anat/${subject}.anat+orig.HEAD ]] || [[ ! -f $PROCESSED_DATA/$subject/${task}/${subject}.${task}+orig.HEAD ]]; then 
	echo "Can't find both T1 anatomy and EPI ${task} state file. Skipping subject"
    else
	( cd $PROCESSED_DATA/$subject/${alignment_dir} && open *overlay.jpg )
	echo "*** Sleeping for 2 seconds"
	sleep 2
	
	while true ; do
	    echo "Choose from the following list the metric that gave the best alignment, or enter s to skip subject, or q to quit immediately:"
	    echo "	S. Skip this subject"	  
	    echo "	1. LPC    (_al)"
	    echo "	2. LPC+ZZ (_al_lpc+ZZ)"
	    echo "	3. LPA    (_al_lpa)"
	    echo "	4. MI     (_al_mi)"
	    echo "	Q or q to quit"	  
	    echo -n "Enter choice: "
	    read choice
	    choice=$( echo "$choice" | tr "[:upper:]" "[:lower:]" )
	    case $choice in
		s*)
		    bestMetric="skip"
		    break
		    ;;
		1*)
		    bestMetric="lpc"
		    break
		    ;;
		2*)
		    bestMetric="lpc+ZZ"		  
		    break
		    ;;
		3*)
		    bestMetric="lpa"		  
		    break
		    ;;
		4*)
		    bestMetric="mi"		  
		    break
		    ;;
		q*)
		    die
		    break
		    ;;
		*)
		    echo "Unknown choice ($choice). Try again."
		    ;;
	    esac
	done

	if [[ $bestMetric != "skip" ]]  ; then 
	    echo "Appending the following code to ${task}_alignment_parameters.sh"
	    cat <<EOF | tee -a ${SCRIPTS_DIR}/${task}_alignment_parameters.sh
	$subject)
	    extraAlignmentArgs="-align_opts_aea  -cost ${bestMetric}"
	    ;;
EOF
	    echo "$subject,${bestMetric}" >> ${task}_alignment_parameters.csv

	    echo "*** Quitting Preview"
	    osascript -e 'quit app "Preview"'
	else
	    echo "Skipping subject"
	fi

	echo
    fi
    (( sc=sc + 1 ))
done

echo "Appending the following code to ${task}_alignment_parameters.sh"
cat <<EOF | tee -a ${SCRIPTS_DIR}/${task}_alignment_parameters.sh
    	*)
    	    extraAlignmentArgs=""
    	    ;;
    esac
EOF



echo "####################################################################################################"
echo "### All done!"
echo "####################################################################################################"

	# $subject)
	#     doZeropad $subject
	#     anatFile=\${DATA}/processed/\${subject}/\${subject}.anat.zp+orig.HEAD
	#     epiFile=\${DATA}/processed/\${subject}/\${subject}.${task}.zp+orig.HEAD
	#     extraAlignmentArgs="-align_opts_aea  -cost ${bestMetric} -giant_move"
