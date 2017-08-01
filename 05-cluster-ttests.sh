#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM

programName=`basename $0`

GETOPT=$( which getopt )
ROOT=${MDD_ROOT:-/data/sanFrancisco/BrainChange/}
DATA=$ROOT/data
MDD_STANDARD=$ROOT/standard
MDD_TISSUEPRIORS=$ROOT/tissuepriors
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

logDir=${DATA}/log
GETOPT_OPTIONS=$( $GETOPT  -o "l:on:p:c:s:d:r:x:" \
			   --longoptions "seedlist:,overwrite,nn:,pvalue:,cpvalue:,sided,data:,results:,prefix_clustsim:" \
			   -n ${programName} -- "$@" )
exitStatus=$?
if [[ $exitStatus != 0 ]] ; then 
    error_message_ln "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi


# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-p|--pvalue)
	    pValue=$2;
	    shift 2 ;;
	-c|--cpvalue)
	    cPvalue=$2;
	    shift 2 ;;
	-n|--nn)
	    NN=$2; 
	    shift 2 ;;
	-s|--sided )
	    ss=$2
	    if [[ $ss == "1" ]] ; then 
		side="1"
	    elif [[ $ss == "2" ]] ; then 
		side="2"
	    elif [[ $ss == "bi" ]] ; then 
		side="bi"
	    else
		warn_message_ln "Unknown argument provided to -s or --sided. Valid values are 1, 2, and bi. Defaulting to 1-sided"
		side="1"		
	    fi
	    shift 2 ;;	
	-o|--overwrite ) 
	    overwrite=1; 
	    shift ;;
	-d|--data)
	    GROUP_DATA=$2;
	    shift 2 ;;
	-r|--results)
	    GROUP_RESULTS=$2;
	    shift 2 ;;
	-l|--seedlist)
	    seedList=$2; shift 2 ;;
	-x|--prefix_clustsim)
	    csimprefix="$2";
	    shift 2 ;;
	
	--) 
	    shift ; break ;;

	*) 
	    error_message_ln "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

function extractTStatpars {
    local bucket="$1"
    local subbrikId="$2"

    a=$(3dAttribute BRICK_STATSYM $bucket"[$subbrikId]" )
    b=${a##*(}
    c=${b%%)*}

    echo $( echo $c | tr "," " " )
}

function pickLatestBucketFile {
    ## restingstate.acci8L.3mm.b.and.c.timepoints.3dttest.bucket.20170724-1050PDT+tlrc.HEAD
    ## restingstats.acci8L.3mm.b.and.c.timepoints.3dttest.bucket.*+tlrc.HEAD
    local infix=$1
    local latest=$( ls -1t ${GROUP_RESULTS}/restingstate.${infix}.3dttest.bucket.*+tlrc.HEAD | head -1 ) 

    if [ "x$latest" == "x" ] || [ ! -f $latest ] ; then
        exit
    fi
    echo $latest
}


if [ "x$NN" == "x" ] ; then 
    ## nearest neighbour 1=touching at faces, 2=faces and edges 3=faces,
    ## edges and corners, just like in the afni clusterize window

    warn_message_ln "No argument provided to -n or --nn. Defaulting to 1 (touching faces)."
    NN=1
fi

case $NN in
    1)
	rmm=1.01
	;;
    2)
	rmm=1.44
	;;
    3)
	rmm=1.75
	;;

    *) 
	error_message_ln "Unknown value ($NN) for NN. Exiting."
	exit 2 ;;
esac

if [[ "x$pValue" == "x" ]] ; then
    ## voxelwise pvalue
    pValue=0.05
    info_message_ln "Set voxelwise pvalue to $pValue (default)"
else
    info_message_ln "Set voxelwise pvalue to $pValue"
fi

if [[ "x$cPvalue" == "x" ]] ; then
    # clusterwise pvalue
    cPvalue=0.050
    info_message_ln "Set whole brain pvalue to $cPvalue (default)"	    
else
    useFirstColumn=1
    info_message_ln "Set whole brain pvalue to $cPvalue"    
fi

if [[ "x$side" == "x" ]] ; then
    warn_message_ln "No value provided for side. Defaulting to 1sided"
    side="1"
else
    info_message_ln "Running a $side test"
fi

if [[ "x$GROUP_DATA" == "x" ]] ; then
    error_message_ln "No value provided for GROUP_DATA (-d or --data). Cannot continue."
    exit
fi

if [[ "x$GROUP_RESULTS" == "x" ]] ; then
    error_message_ln "No value provided for GROUP_RESULTS (-r or --results). Cannot continue."
    exit
fi

GROUP_DATA=$( readlink -f $GROUP_DATA )
if [[ ! -d "$GROUP_DATA" ]] ; then
    error_message_ln "No such directory: $GROUP_DATA"
    error_message_ln "Cannot continue."
    exit 1
fi

GROUP_RESULTS=$( readlink -f $GROUP_RESULTS )
if [[ ! -d "$GROUP_RESULTS" ]] ; then
    error_message_ln "No such directory: $GROUP_RESULTS"
    error_message_ln "Cannot continue."
    exit 1
fi

info_message_ln "Will use data          files in $GROUP_DATA"
info_message_ln "Will use group results files in $GROUP_RESULTS"


if [ ! -f $seedList ] ; then
    info_message_ln "ERROR: The seed list file does not exit. Exiting"
    exit
else 
    seeds=$( eval echo $( cat $seedList ) )
    nseeds=$( cat $seedList | wc -l )
fi

info_message_ln "Clustering t-tests for RSFC analysis for the following seeds:"
info_message_ln "$seeds"

cd $GROUP_RESULTS

csvFile=parameters.csv

if [[ $overwrite -eq 1 ]] || [[ ! -f $csvFile ]] ; then 
    echo "seedname,contrastBrikId,statBrikId,threshold,rmm,nVoxels,pValue,cPvalue,nClusters,tTestFile" > $csvFile
fi

labelPrefix="c-b"
task=rsfc

(( seedCount=1 ))
for seed in $seeds ; do
    seedName=${seed##*/}
    if echo $seedName | grep -q "nii" ; then 
	seedName=${seedName%%.nii*}
    else 
	seedName=${seedName%%+*}
    fi

    infix=${seedName}.b.and.c.timepoints

    info_message_ln "#################################################################################################"
    countMsg=$( printf '%02d of %02d' $seedCount $nseeds )
    info_message_ln "Clustering RSFC t-tests for $seedName. ${countMsg}." 
    info_message_ln "#################################################################################################"
    
    dataTableFilename=$GROUP_DATA/dataTable.ttest.rsfc.${infix}.txt
    info_message_ln "### GLT data table file is: $dataTableFilename"
    
    tTestFile=$( pickLatestBucketFile ${infix} )
    info_message_ln "### T-test file is: $tTestFile"    
        
    statBrikId=$( 3dinfo -label2index "${labelPrefix}_Zscr" $tTestFile 2> /dev/null )
    contrastBrikId=$( 3dinfo -label2index "${labelPrefix}_mean" $tTestFile 2> /dev/null )    

    nVoxels=$( $SCRIPTS_DIR/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side --csimfile=$GROUP_RESULTS/${csimprefix}.restingstate.${infix}.CSim.NN${NN}_${side}sided.1D )
    if [[ "x$nVoxels" == "x" ]] ; then
	error_message_ln "Couldn't get the correct number of voxels to go with pvalue=$pValue and corrected pvalue=$cPvalue"
	error_message_ln "You may need to pad these values with zeros to ensure you match the correct row and column in $cstempPrefix.NN${NN}_${side}.1D"
	exit
    fi

    threshold=$( cdf -p2t fizt $pValue | sed 's/t = //' )
    info_message_ln "### labelPrefix = $labelPrefix"
    info_message_ln "### contrastBrikId = $contrastBrikId"
    info_message_ln "### statBrikId = $statBrikId"
    info_message_ln "### threshold = $threshold"
    info_message_ln "### rmm = $rmm"
    info_message_ln "### nVoxels = $nVoxels"
    ## echo "### df = $df"
    info_message_ln "### voxelwise pValue = $pValue"
    info_message_ln "### corrected  pValue = $cPvalue"

    infix=${seedName}

    3dmerge -session . -prefix clorder.$infix			\
	    -1erode 50 -1dilate					\
	    -2thresh -$threshold $threshold			\
	    -1clust_order $rmm $nVoxels				\
	    -dxyz=1						\
	    -1dindex $contrastBrikId -1tindex $statBrikId	\
	    -nozero						\
	    $tTestFile

    if [[ -f clorder.$infix+tlrc.HEAD ]] ; then 
	3dclust -1Dformat -nosum -dxyz=1 $rmm $nVoxels clorder.$infix+tlrc.HEAD > clust.$infix.txt

	3dcalc -a clorder.${infix}+tlrc.HEAD -b ${tTestFile}\[$statBrikId\] -expr "step(a)*b" -prefix clust.$infix
	
	nClusters=$( 3dBrickStat -max clorder.$infix+tlrc.HEAD 2> /dev/null | tr -d ' ' )

	columnNumber=$( head -1 $dataTableFilename | tr -s '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
	if [[ -z $columnNumber ]] ; then
	    error_message_ln "Couldn't find a column named InputFile in $dataTableFilename"
	    error_message_ln "Cannot continue"
	    exit 1
	fi
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $dataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.txt

	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${tTestFile}\[$contrastBrikId\]      > roiStats.$infix.averageContrastValue.txt
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${tTestFile}\[$statBrikId\]          > roiStats.$infix.averageZscore.txt

	3drefit -cmap INT_CMAP clorder.$infix+tlrc.HEAD
	
    else
	nClusters=0
	warn_message_ln "WARNING No clusters found!"
    fi
    echo "${seedName},$contrastBrikId,$statBrikId,$threshold,$rmm,$nVoxels,$pValue,$cPvalue,$nClusters,$tTestFile" >> $csvFile
    (( seedCount=seedCount+1 ))
done

cd $scriptsDir
##echo "Making cluster location tables using Maximum intensity"
##./cluster2Table.pl --space=mni --force -mi $GROUP_RESULTS

info_message_ln "Making cluster location tables using Center of Mass"
${SCRIPTS_DIR}/cluster2Table.pl --space=mni --force $GROUP_RESULTS
