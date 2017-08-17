#!/bin/bash

## set -x

studyName=BrainChange

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=${MDD_ROOT:-/data/sanFrancisco/$studyName}
DATA=$ROOT/data
PROCESSED_DATA=$DATA/processed
RAW_DATA=$DATA/raw
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

if [[ $# -gt 0 ]] ; then
    subjects="$*"
else
    ## subjects="$( cat ../data/config/control.subjectList.txt ../data/config/mdd.nat.txt )"

    subjects=$( cd ../data/raw ; find ./ -maxdepth 1 -type d -a -name 'bc[0-9][0-9][0-9][abc]' -printf "%f\n" )

fi
#echo $subjects
subjectCount=$( echo $subjects | wc -w )
#exit

taskName=regcluster
## taskName=reconstruct-brainchange
taskFile=$SCRIPTS_DIR/run/${taskName}-TaskFile.$BASHPID
info_message_ln "List of tasks to be executed is stored in $taskFile"

cat /dev/null > $taskFile
## echo "$( ls $(pwd)/ttests/07-3dttest.rsfc.* )" >> ${taskFile}
## echo "$( ls $(pwd)/run/run-followup.analysis.*sh )" >> ${taskFile}

for seedfile in ../data/config/seed.list.txt ../data/config/gabbay-striatum-seeds.txt ; do
    for variable in conflict SDQ RADS ; do
	echo "$SCRIPTS_DIR/05-cluster-regressions.sh -p 0.05 -c 0.05 -n 1 -s 2 -d ../data/Group.data/ -r ../data/Group.results/followup.regressions/ -x cc -e ${variable} -l ${seedfile}" >> ${taskFile}
    done
done

# (( i=1 ))
# for subject in ${subjects} ; do

#     # if [[ ! -f $PROCESSED_DATA/$subject/resting/$subject.resting+orig.HEAD ]] || \
#     #    [[ ! -f $PROCESSED_DATA/$subject/anat/$subject.anat+orig.HEAD ]]; then 
#     # 	info_message "$( printf "Adding script(s) for subject %s (%03d of %03d) to task file\n" $subject $i $subjectCount )"
    
#     # 	echo "$SCRIPTS_DIR/00-convertDicoms.sh -s $subject" >> ${taskFile}
#     # 	## echo "$SCRIPTS_DIR/alignment_test.sh $subject" >> ${taskFile}
#     # else
#     # 	info_message "$( printf "Found reconstructed data for subject %s (%03d of %03d). Skipping.\n" $subject $i $subjectCount )"
#     # fi

#     if [[ -f $PROCESSED_DATA/$subject/resting/$subject.resting+orig.HEAD ]] || \
#        [[ -f $PROCESSED_DATA/$subject/anat/$subject.anat+orig.HEAD ]]; then 
#     	info_message_ln "$( printf "Adding script(s) for subject %s (%03d of %03d) to task file\n" $subject $i $subjectCount )"
    
#     	## echo "$SCRIPTS_DIR/alignment_test.sh $subject" >> ${taskFile}

# 	## echo "./03-singleSubjectRsfc.sh -s $subject -l ../data/config/dlpfc.seed.list.txt -d rsfc" >> ${taskFile}
# 	## echo "./03-singleSubjectRsfc.sh -s $subject -l ../data/config/seed.list.txt -d rsfc" >> ${taskFile}
# 	## echo "./03-singleSubjectRsfc.sh -s $subject -l ../data/config/gabbay-striatum-seeds.txt -d rsfc" >> ${taskFile}	

	
# 	## two lines to run the alignment inspection JPEGS in case
# 	## things go awry in the 01-runRsfcPreprocessingInParallel.sh
# 	## script (i.e., you make an edit an screw up the
# 	## snapshot_volreg command.
# 	## echo "cd ${PROCESSED_DATA}/$subject/afniRsfcPreprocessed.NL ; $SCRIPTS_DIR/snapshot_volreg.sh  ${subject}.anat_unif_al_keep+orig  ext_align_epi+orig.HEAD          ${subject}.orig.alignment" >> ${taskFile}
# 	## echo "cd ${PROCESSED_DATA}/$subject/afniRsfcPreprocessed.NL ; $SCRIPTS_DIR/snapshot_volreg.sh  anat_final.${subject}+tlrc         final_epi_vr_base+tlrc.HEAD      ${subject}.tlrc.alignment" >> ${taskFile}
	
#     else
#     	info_message_ln "$( printf "No reconstructed data for subject %s (%03d of %03d). Skipping.\n" $subject $i $subjectCount )"
#     fi
    
#     (( i=i+1 ))
# done


## jobname
#$ -N $taskName

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
sge_command="qsub -N $taskName -q all.q -j y -m n -V -wd $( pwd ) -o $LOG_DIR -t 1-$nTasks" 
echo $sge_command
( exec $sge_command <<EOF
#!/bin/sh

#$ -S /bin/sh

command=\`sed -n -e "\${SGE_TASK_ID}p" $taskFile\`

exec /bin/sh -c "\$command"
EOF
)

echo "Running qstat"
qstat
