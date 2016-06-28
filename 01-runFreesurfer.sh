#!/bin/bash

## set -x 

trap exit SIGHUP SIGINT SIGTERM

studyName=BrainChange

ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data
RAW_DATA=$DATA/raw
PROCESSED_DATA=$DATA/processed
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

####################################################################################################
### Functions
####################################################################################################

function getFirstDicom {
    subject=$1
    dicomTask="$2"
    
    subjectDicomContainerDir=$( ls -1d $RAW_DATA/$subject/E* | tail -1 )
    if [[ ${#subjectDicomContainerDir} -gt 0 ]] && [[ -d $subjectDicomContainerDir ]] ; then 
	if [[ ! -f $subjectDicomContainerDir/dcm_info.txt ]] ; then 
	    (cd $subjectDicomContainerDir; $SCRIPTS_DIR/dcm_check.sh )
	fi
	if [[ ! -f $subjectDicomContainerDir/dcm_info.txt ]] ; then
	    echo "*** The $subjectDicomContainerDir/dcm_info.txt was not created by dcm_check.sh. Cannot continue"
	    exit 1
	fi
	dcmfile=$( cat $subjectDicomContainerDir/dcm_info.txt | grep -iE "$dicomTask" | tail -1 | awk '{print $2}' )
	if [[ -z $dcmfile ]] ; then
	    echo
	else
	    echo "$subjectDicomContainerDir/$dcmfile"
	fi
    else
	echo 
    fi
}

####################################################################################################


if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    subjects=$( cd $RAW_DATA ; ls -1d b* )
fi


taskFile=$SCRIPTS_DIR/run/01-runFreesurfer-taskFile.$BASHPID
rm -f $SCRIPTS_DIR/run/01-runFreesurfer-taskFile*
cat /dev/null > $taskFile

for subject in $subjects ; do
    dicomTask="Sag T1 IRSPGR"
    t1FirstDicom=$( getFirstDicom $subject "$dicomTask" )
    dicomTask="Ax T2 FSE|SAG CUBE T2"
    t2FirstDicom=$( getFirstDicom $subject "$dicomTask" )

    if [[ -z $t1FirstDicom ]] || [[ -z $t2FirstDicom ]] ; then
	echo "*** Got no directory for either the T1 anatomy ($t1anat) or the T2 ($t2anat)"
	echo "*** Skipping sibject $subject"
	continue
    fi
    echo "*** Adding $subject to list of subjects to be processed by freesurfer"
    
    ## echo "recon-all -s ${subject} -all" >> ${taskFile}
    ## echo "recon-all -all -s ${subject} -no-isrunning -qcache -hippo-subfields" >> ${taskFile}

    subjectProcessedDir=$PROCESSED_DATA/${subject}/
    
    echo "recon-all -subject $subject -i $t1FirstDicom -T2 $t2FirstDicom -T2pial -all" >> ${taskFile}
    
    ## echo "recon-all -s ${subject} -autorecon1"## >> ${taskFile}

    #echo "recon-all -skullstrip -clean-bm -gcut -subjid ${subject}" >> ${taskFile}
done


## jobname
#$ -N allSubjectsToMgz

## queue
#$ -q all.q

## binary?
#$ -b y

## rerunnable?
#$ -r y

## merge stdout and stderr?
#$ -j y

## send no mail
#$ -m n

## execute from the current working directory
#$ -cwd

## use a shell to run the command
#$ -shell yes 
## set the shell
#$ -S /bin/bash

## preserve environment
#$ -V 

[[ ! -d $LOG_DIR ]] && mkdir $LOG_DIR

nTasks=$( cat $taskFile | wc -l )
sge_command="qsub -N runFreesurfer -q all.q -j y -m n -V -wd $PROCESSED_DATA -o $LOG_DIR -t 1-$nTasks"

#echo $sge_command
echo -n "Queuing job... "
( exec $sge_command <<EOF
#!/bin/sh

#$ -S /bin/sh

FREESURFER_HOME=/data/software/freesurfer/
SUBJECTS_DIR=/data/sanFrancisco/BrainChange/data/processed
export FS_FREESURFERENV_NO_OUTPUT FREESURFER_HOME SUBJECTS_DIR
source $FREESURFER_HOME/SetUpFreeSurfer.sh

command=\`sed -n -e "\${SGE_TASK_ID}p" $taskFile\`

exec /bin/sh -c "\$command"
EOF
)

echo "Running qstat"
qstat
