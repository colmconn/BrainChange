#!/bin/bash

set -x 

# if ctrl-c is typed exit immediatly
trap kill_afni_then_exit SIGHUP SIGINT SIGTERM

function  kill_afni_then_exit {
    plugout_drive $NPB \
	-com "QUIT" \
	-quit > /dev/null
    exit
}

studyName=BrainChange

if [[ $( uname -s) == "Darwin" ]] ; then
    rootDir="/Volumes/data"
elif [[ $( uname -s) == "Linux" ]] ; then
    rootDir="/data"
else 
    echo "Sorry can't set data directories for this computer"
    exit 1
fi

SCRIPTS_DIR=$rootDir/sanFrancisco/$studyName/scripts
DATA=$rootDir/sanFrancisco/$studyName/data/processed

export AFNI_NOSPLASH=YES
#export AFNI_LAYOUT_FILE=elvis
#subjects="311_A"

if [[ $# -gt 0 ]] ; then
    subjects="$*"
else

    ## subjects="$( cat ../data/config/control.subjectList.txt ../data/config/mdd.nat.txt )"
    ## subjects=$( cd /data/sanDiego ; ls -d [0-9][0-9][0-9]_{A,B,C,D,E} [0-9][0-9][0-9]_{A,B,C,D,E}2 2> /dev/null | grep -v 999 )
    subjects=$( cd ../data/processed ; ls -d b* )
fi

subjectCount=$( echo $subjects | wc -w )

# PIF=AlignmentInspection     #A string identifying programs launched by this script
#                             #Get a free line and tag programs from this script
# NPB="-npb `afni -available_npb_quiet` -pif $PIF -echo_edu" 

# @Quiet_Talkers -pif $PIF > /dev/null 2>&1   #Quiet previously launched programs

# afni $NPB -niml -yesplugouts $adir/afni  >& /dev/null &

# plugout_drive  $NPB     

export AFNI_LAYOUT_FILE=noDefaultLayout

if [[ -f ${SCRIPTS_DIR}/resting_alignment_parameters.sh ]] ; then
    echo "WARNING: moving pre-existing resting_alignment_parameters.sh to resting_alignment_parameters.sh.orig.$BASHPID"
    mv -f ${SCRIPTS_DIR}/resting_alignment_parameters.sh ${SCRIPTS_DIR}/resting_alignment_parameters.sh.orig.$$
fi

echo "Appending the following code to resting_alignment_parameters.sh"
cat <<EOF | tee ${SCRIPTS_DIR}/resting_alignment_parameters.sh
    case \$subject in
EOF

## sc = subject count
(( sc=1 )) 
for subject in $subjects ; do
#while true ; do
#    echo -n "Enter subject ID: "
#    read subject
    
    if [[ "x$subject" == "x" ]] ; then
	break
    fi
    echo   "####################################################################################################"
    printf "### Subject: %s (%03d of %03d)\n" $subject $sc $subjectCount
    echo   "####################################################################################################"

    if [[ ! -f $DATA/$subject/anat/${subject}.anat+orig.HEAD ]] || [[ ! -f $DATA/$subject/resting/${subject}.resting+orig.HEAD ]]; then 
	echo "Can't find both T1 anatomy and EPI resting state file. Skipping subject"
    else
	cd $DATA/$subject/alignmentTest.unif.nozp
	
	afni -noplugins -niml -YESplugouts \
	     -dset \
	     $subject.anat_unif+orig.HEAD  \
	     $subject.anat_unif{_al,_al_lpc+ZZ,_al_lpa,_al_mi}+orig.HEAD \
	     vr_base+orig \
	     &

	snooze=8
	echo "Sleeping $snooze seconds"
	sleep $snooze
	## -com "SWITCH_UNDERLAY $subject.anat.zp+orig.HEAD" \

	
	plugout_drive  \
		      -com "SWITCH_OVERLAY  vr_base+orig.HEAD" \
		      -com "SET_THRESHNEW 0" \
		      -com 'OPEN_WINDOW A.axialimage geom=400x400+416+430 \
                     opacity=7'                         \
		      -com 'OPEN_WINDOW A.coronalimage geom=274x413+10+830 \
                     opacity=7'                         \
		      -com 'OPEN_WINDOW A.sagittalimage geom=400x400+10+430     \
                     opacity=7'                         \
		      -quit > /dev/null
	echo
	for metric in _al _al_lpc+ZZ _al_lpa _al_mi ; do
	    echo    "Switching anatomy underlay to $subject.anat_unif${metric}+orig.HEAD"

	    plugout_drive  \
			  -com "SWITCH_UNDERLAY $subject.anat_unif${metric}+orig.HEAD" \
			  -quit > /dev/null

	    echo -n "Press enter to continue to the next metric of enter s to skip remaining metrics: "
	    read choice
	    choice=$( echo "$choice" | tr "[:upper:]" "[:lower:]" )
	    case $choice in
		s*)
		    break
		    ;;
		*)
		    ;;
	    esac
	done

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
		    kill_afni_then_exit
		    break
		    ;;
		*)
		    echo "Unknown choice ($choice). Try again."
		    ;;
	    esac
	done

	if [[ $bestMetric != "skip" ]]  ; then 
	    echo "Appending the following code to resting_alignment_parameters.sh"
	    cat <<EOF | tee -a ${SCRIPTS_DIR}/resting_alignment_parameters.sh
	$subject)
	    anatFile=\${DATA}/processed/\${subject}/\${subject}.anat+orig.HEAD
	    epiFile=\${DATA}/processed/\${subject}/\${subject}.resting+orig.HEAD
	    extraAlignmentArgs="-align_opts_aea  -cost ${bestMetric}"
	    ;;
EOF
	else
	    echo "Skipping subject"
	fi
	plugout_drive \
		      -com "QUIT" \
		      -quit > /dev/null
	killall -9 $( pgrep -f AlignmentInspection ) 
	echo
    fi
    (( sc=sc + 1 ))
done

echo "Appending the following code to resting_alignment_parameters.sh"
cat <<EOF | tee -a ${SCRIPTS_DIR}/resting_alignment_parameters.sh
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
	#     epiFile=\${DATA}/processed/\${subject}/\${subject}.resting.zp+orig.HEAD
	#     extraAlignmentArgs="-align_opts_aea  -cost ${bestMetric} -giant_move"
