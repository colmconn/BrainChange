#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap exit SIGHUP SIGINT SIGTERM

programName=`basename $0`

studyName=BrainChange

GETOPT=$( which getopt )
ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data/processed
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT  -o "l:on:p:c:s:d:r:x:e:" \
			   --longoptions "seedlist:,overwrite,nn:,pvalue:,cpvalue:,sided,data:,results:,prefix_clustsim:,regvar:" \
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
		echo "Unknown argument provided to -s or --sided. Valid values are 1, 2, and bi. Defaulting to 1-sided"
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
	-x|--prefix_clustsim)
	    csimprefix="$2";
	    shift 2 ;;
	-e|--regvar)
	    regressionVariable="$2";
	    shift 2 ;;
	-l|--seedlist)
	    seedList=$2; shift 2 ;;
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done


function pickLatestBucketFile {
    
    local prefix=$1
    local latest=$( ls -1t ${prefix}*+tlrc.HEAD | head -1 ) 

    if [ "x$latest" == "x" ] || [ ! -f $latest ] ; then
	exit
    fi
    echo $latest
}

function extractCoefBrikId {
    local rvName=$1
    local bucketFilename=$2
    
    label=$( 3dinfo -label $bucketFilename | tr "|" "\n" | grep "${rvName}.Value"  2> /dev/null )
    id=$( 3dinfo -label2index $label $bucketFilename 2> /dev/null )
    
    echo $id
}

function extractTStatpars {
    local rvName=$1
    local bucketFilename=$2

    a=$(3dAttribute BRICK_STATSYM $bucketFilename"[${rvName}.t.value]" )
    b=${a##*(}
    c=${b%%)*}

    echo $( echo $c | tr "," " " )
}

if [ "x$NN" == "x" ] ; then 
    ## nearest neighbour 1=touching at faces, 2=faces and edges 3=faces,
    ## edges and corners, just like in the afni clusterize window

    echo "No argument provided to -n or --nn. Defaulting to 1 (touching faces)."
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
    info_message_ln "No value provided for side. Defaulting to 1sided"
    side="1"
else
    info_message_ln "Running a $side test"
fi

if [[ "x$regressionVariable" == "x" ]] ; then
    error_message_ln "No value provided for the regressionVariable. Cannot continue. Please rerun this script and provide the -e or --regvar argument"
    exit 1
else
    info_message_ln "Clustering the following regression variable: ${regressionVariable}"
fi

if [[ "x$csimprefix" == "x" ]] ; then
    error_message_ln "No value provided for the csimprefix. Cannot continue. Please rerun this script and provide the -x or --prefix_clustsim argument"
    exit 1
else
    info_message_ln "3dClustSim file prefix: ${csimprefix}"
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
    error_message_ln "ERROR: The seed list file does not exit. Exiting"
    exit
else 
    seeds=$( eval echo $( cat $seedList ) )
    nseeds=$( cat $seedList | wc -l )
fi

cd $GROUP_RESULTS

csvFile=parameters.csv

if [[ $overwrite -eq 1 ]] || [[ ! -f $csvFile ]] ; then 
    echo "regressionVariable,seedName,infix,coefficientBrikId,statBrikId,threshold,DoF,rmm,nVoxels,pValue,cPvalue,nClusters,rlmBucketFile" > $csvFile
fi

(( seedCount=1 ))
for seed in $seeds ; do
    seedName=${seed##*/}
    if echo $seedName | grep -q "nii" ; then 
	seedName=${seedName%%.nii*}
    else 
	seedName=${seedName%%+*}
    fi

    info_message_ln "#################################################################################################"
    countMsg=$( printf '%02d of %02d' $seedCount $nseeds )
    info_message_ln "Clustering robust regressions for $seedName. ${countMsg}." 
    info_message_ln "#################################################################################################"
    
    infix="followup.analysis.${seedName}.${regressionVariable}"
    
    dataTableFilename=$GROUP_DATA/dataTable.${infix}.tab
    info_message_ln "Data table file is: $dataTableFilename"

    rlmBucketFilePrefix=stats.${infix}
    rlmBucketFile=$( pickLatestBucketFile $rlmBucketFilePrefix )
    info_message_ln "Robust regression bucket file is: $rlmBucketFile"    
    
    coefBrikId=$( 3dinfo -label2index "${regressionVariable}.Value" $rlmBucketFile 2> /dev/null )    
    statBrikId=$( 3dinfo -label2index "${regressionVariable}.t.value" $rlmBucketFile 2> /dev/null )
    
    ## now we need to estimate the average smoothing of the data to feed to 3dClustSim
    
    # first up get the list of subjects in the analysis
    blur_file=$GROUP_RESULTS/blur.errts.${regressionVariable}.1D
    if [[ ! -f $blur_file ]] || [[ ! -s $blur_file ]] ; then 
	cat /dev/null > $blur_file
	subjects=$( cat ${dataTableFilename} | awk '{ print $1 }' | sed 1d )
	
	## now get the ACF values for each subject (b and c (only for non-baseline analysis) timepoints) in the analysis
	for subject in $subjects ; do
	    tail -q --lines=1 $DATA/${subject}{b,c}/afniRsfcPreprocessed.NL/blur.errts.1D >> $blur_file
	    ## if baseline is in the infix, then DO NOT include the B
	    ## timepoint subjects in the blur.err_reml.1D file
	    #if [[ ! ${infix} =~ "baseline" ]] ; then 
	    #tail -1 $( dirname $SCRIPTS_DIR )/${subject}B/afniRsfcPreprocessed.NL/blur.errts.1D >> $blur_file
	    #fi
	done
    else
	info_message_ln "Found pre-existing blur file: $blur_file"
    fi

    ## average each of the ACF values in each column in the $GROUP_RESULTS/blur.err_reml.1D
    nColumns=$( head -1 $blur_file | wc -w  )
    declare -a avgAcf
    for (( ind=0; ind < $nColumns; ind=ind+1 )) ; do
	ind2=$( expr $ind + 1 )
	avgAcf[${ind}]=$( cat $blur_file | awk -v N=${ind2} '{ sum += $N } END { if (NR > 0) print sum / NR }' )
    done
    
    info_message_ln "Average ACF values = ${avgAcf[*]}"
    
    mask_file="/data/sanFrancisco/BrainChange/data/standard/MNI_caez_N27_brain.3mm+tlrc.HEAD"
    info_message_ln "Using mask file: $mask_file"
    
    ## now we need to run 3dClustSim
    ## if [[ ! -f $GROUP_RESULTS/${csimprefix}.${infix}.NN${NN}_${side}sided.1D ]] ; then
    if [[ ! -f $GROUP_RESULTS/${csimprefix}.${regressionVariable}.NN${NN}_${side}sided.1D ]] ; then     
	## 3dClustSim -nodec -LOTS -acf ${avgAcf[0]} ${avgAcf[1]} ${avgAcf[2]} -prefix ${csimprefix}.${infix} -mask final_mask+tlrc.HEAD
	## same subjects in all regressions so we onlyneed to run this once not once per regression
	3dClustSim -nodec -LOTS -acf ${avgAcf[0]} ${avgAcf[1]} ${avgAcf[2]} -prefix ${csimprefix}.${regressionVariable} -mask $mask_file   
    fi

    ## nVoxels=$( $SCRIPTS_DIR/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side --csimfile=$GROUP_RESULTS/${csimprefix}.${infix}.NN${NN}_${side}sided.1D )
    nVoxels=$( $SCRIPTS_DIR/get.minimum.voxel.count.r --nn $NN --alpha=$cPvalue --pthr=$pValue --side=$side --csimfile=$GROUP_RESULTS/${csimprefix}.${regressionVariable}.NN${NN}_${side}sided.1D )
    if [[ "x$nVoxels" == "x" ]] ; then
	error_message_ln "Couldn't get the correct number of voxels to go with pvalue=$pValue and corrected pvalue=$cPvalue"
	error_message_ln "You may need to pad these values with zeros to ensure you match the correct row and column in $cstempPrefix.NN${NN}_${side}.1D"
	exit
    fi
    ## this is useful if the t test is stored as such instead of a zscore
    df=$( extractTStatpars $regressionVariable $rlmBucketFile )    
    
    threshold=$( cdf -p2t fitt $pValue $df | sed 's/t = //' )
    info_message_ln "coefBrikId = $coefBrikId"
    info_message_ln "statBrikId = $statBrikId"
    info_message_ln "threshold = $threshold"
    info_message_ln "rmm = $rmm"
    info_message_ln "nVoxels = $nVoxels"
    info_message_ln "degrees of freedom = $df"
    info_message_ln "voxelwise pValue = $pValue"
    info_message_ln "corrected  pValue = $cPvalue"
    
    3dmerge -session . -prefix clorder.$infix \
	    -2thresh -$threshold $threshold \
	    -1clust_order $rmm $nVoxels \
	    -dxyz=1 \
	    -1dindex $coefBrikId -1tindex $statBrikId  -nozero \
	    $rlmBucketFile
    
    if [[ -f clorder.$infix+tlrc.HEAD ]] ; then 
	3dclust -1Dformat -nosum -dxyz=1 $rmm $nVoxels clorder.$infix+tlrc.HEAD > clust.$infix.txt
	
	3dcalc -a clorder.${infix}+tlrc.HEAD -b ${rlmBucketFile}\[$statBrikId\] -expr "step(a)*b" -prefix clust.$infix
	
	nClusters=$( 3dBrickStat -max clorder.$infix+tlrc.HEAD 2> /dev/null | tr -d ' ' )
	
	columnNumber=$( head -1 $dataTableFilename | tr '[[:space:]]' '\n' | grep -n InputFile | cut -f1 -d':' )
	if [[ -z $columnNumber ]] ; then
	    error_message_ln "Couldn't find a column named InputFile in $dataTableFilename"
	    error_message_ln "Cannot continue"
	    exit 1
	fi
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD $( tail -n +2 $dataTableFilename |     awk -v cn=$columnNumber '{ print $cn }' ) > roiStats.$infix.txt
	
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${rlmBucketFile}\[$coefBrikId\]      > roiStats.$infix.averageCoefficientValue.txt
	3dROIstats -nobriklab -mask clorder.$infix+tlrc.HEAD ${rlmBucketFile}\[$statBrikId\]      > roiStats.$infix.averageTValue.txt
	
	echo "$df" > text.$infix.degreesOfFreedom.txt
	3drefit -cmap INT_CMAP clorder.$infix+tlrc.HEAD
	
    else
	nClusters=0
	info_message_ln "WARNING No clusters found!"
    fi
    echo "$regressionVariable,$seedName,$infix,$coefBrikId,$statBrikId,$threshold,$df,$rmm,$nVoxels,$pValue,$cPvalue,$nClusters,$rlmBucketFile" >> $csvFile
    (( seedCount=seedCount+1 ))
done

cd $SCRIPTS_DIR
##info_message_ln "Making cluster location tables using Maximum intensity"
##./cluster2Table.pl --space=mni --force -mi $GROUP_RESULTS

info_message_ln "Making cluster location tables using Center of Mass"
./cluster2Table.pl --space=mni $GROUP_RESULTS
