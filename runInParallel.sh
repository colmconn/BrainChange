#!/bin/bash

## set -x

studyName=BrainChange
ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

taskFile=$SCRIPTS_DIR/run/convertDicoms-TaskFile.$BASHPID

cat /dev/null > $taskFile

for subject in									\
    bc001a bc002a bc003a bc004b bc005c bc007b bc009a bc013b bc014c		\
    bc018a bc019a bc020a bc021b bc023b bc024b bc025b bc026b bc030a bc033b	\
    bc034c bc035c bc037b bc038c bc040b bc001b bc002b bc003b bc004c bc006b	\
    bc007c bc012b bc013c bc016b bc018b bc019b bc020b bc021c bc023c bc024c	\
    bc025c bc027a bc030b bc033c bc035a bc036b bc037c bc039b bc040c bc001c	\
    bc002c bc003c bc005b bc006c bc008a bc012c bc014b bc016c bc018c bc019c	\
    bc021a bc023a bc024a bc025a bc026a bc029a bc033a bc034a bc035b bc036c	\
    bc038b bc039c ; do
    
    ## echo "$SCRIPTS_DIR/00-convertDicoms.sh -s $subject" >> ${taskFile}

    echo "./03-singleSubjectRsfc.sh -s $subject -l ../data/config/dlpfc.seed.list.txt" >> ${taskFile}
done

## jobname
#$ -N convertDicoms

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
sge_command="qsub -N convertDicoms -q all.q -j y -m n -V -wd $( pwd ) -o $LOG_DIR -t 1-$nTasks" 
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
