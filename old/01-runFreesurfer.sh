#!/bin/bash

# set -x 
trap exit SIGHUP SIGINT SIGTERM

studyName=BrainChange

ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data
PROCESSED_DATA=$DATA/processed

if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    subjects=$( cd $PROCESSED_DATA ; ls -1d b* )
fi

taskFile=$PROCESSED_DATA/01-runFreesurfer-taskFile.$BASHPID
cat /dev/null > $taskFile


for subject in $subjects ; do
    ## echo "recon-all -s ${subject} -all" >> ${taskFile}
    ## echo "recon-all -all -s ${subject} -no-isrunning -qcache -hippo-subfields" >> ${taskFile}

    echo "recon-all -s ${subject} -autorecon1" >> ${taskFile}

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

nTasks=$( cat $taskFile | wc -l )

sge_command="qsub -N runFreesurfer -q all.q -j y -m n -V -wd $PROCESSED_DATA -t 1-$nTasks" 
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
