#!/bin/bash

## set -x 

programName=`basename $0`

trap exit SIGHUP SIGINT SIGTERM

studyName=BrainChange

GETOPT=$( which getopt )
ROOT=/data/sanFrancisco/$studyName
PROCESSED_DATA=$ROOT/data/processed
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

function doZeropad {
    local subject="$1"
    # if [[ $subject == "341_A" ]] ; then
    # 	sup="-S 30"
    # fi
    info_message_ln "Zeropadding anat and EPI for subject $subject"
    if [[ -f ${PROCESSED_DATA}/$subject/anat/${subject}.anat_clp+orig.HEAD ]] ; then
	if [[ $force -eq 1 ]] || \
	   [[ ! -f ${PROCESSED_DATA}/$subject/anat/${subject}.anat.zp+orig.HEAD ]]  || \
	   [[ ${PROCESSED_DATA}/$subject/anat/${subject}.anat_clp+orig.HEAD -nt ${PROCESSED_DATA}/$subject/anat/${subject}.anat.zp+orig.HEAD ]] ; then
	    ( cd ${PROCESSED_DATA}/$subject/anat/ ; 3dZeropad -I 30 $sup -prefix ${subject}.anat.zp ${subject}.anat_clp+orig.HEAD )
	fi
    else
	if [[ $force -eq 1 ]] || \
	   [[ ! -f ${PROCESSED_DATA}/$subject/anat/${subject}.anat.zp+orig.HEAD ]] || \
	   [[ ${PROCESSED_DATA}/$subject/anat/${subject}.anat+orig.HEAD -nt ${PROCESSED_DATA}/$subject/anat/${subject}.anat.zp+orig.HEAD ]]; then 
	    ( cd ${PROCESSED_DATA}/$subject/anat/ ; 3dZeropad -I 30 $sup -prefix ${subject}.anat.zp ${subject}.anat+orig.HEAD )
	fi
    fi
    if [[ $force -eq 1 ]] || [[ ! -f ${PROCESSED_DATA}/$subject/resting/${subject}.resting.zp+orig.HEAD ]] ; then 
	( cd ${PROCESSED_DATA}/$subject/resting/ ; 3dZeropad -I 30 $sup -prefix ${subject}.resting.zp ${subject}.resting+orig.HEAD )
    fi
}

GETOPT_OPTIONS=$( $GETOPT \
		      -o "fe:m:o:h:l:h:b:t:nq" \
		      --longoptions "force,excessiveMotionThresholdFraction:,motionThreshold:,outlierThreshold:,threads:,lowpass:,highpass:,blur:,tcat:,nonlinear,enqueue" \
		      -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

## 1 = force creation of zero padded files
force=0

## enqueue the job for execution
enqueue=0

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-f|--force)
	    force=1; shift 1;;
	-e|--excessiveMotionThresholdFraction)
	    excessiveMotionThresholdFraction=$2; shift 2 ;;	
	-m|--motionThreshold)
	    motionThreshold=$2; shift 2 ;;	
	-o|--outlierThreshold)
	    outlierThreshold=$2; shift 2 ;;	
	-h|--threads)
	    threads=$2; shift 2 ;;	
	-l|--lp)
	    lowpass=$2; shift 2 ;;	
	-h|--hp)
	    highpass=$2; shift 2 ;;	
	-b|--blur)
	    blur=$2; shift 2 ;;	
	-t|--tcat)
	    tcat=$2; shift 2 ;;	
	-n|--nonlinear)
	    nonlinear=1; shift 1 ;;	
	-q|--enqueue)
	    enqueue=1; shift 1 ;;	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [[ $force -eq 1 ]] ; then
    info_message_ln "Forcing recreation of ZEROPADed files"
fi

####################################################################################################
## Check that appropriate values are used to initialize arguments that
## control analysis if no values were provided on the command line

## The following values are used to exclude subjects based on the
## number of volumes censored during analysis
if [[ "x$excessiveMotionThresholdFraction" == "x" ]] ; then
    excessiveMotionThresholdFraction=0.2
    excessiveMotionThresholdPercentage=20
    warn_message_ln "No excessiveMotionThresholdFraction threshold was provided. Defaulting to $excessiveMotionThresholdFraction => ${excessiveMotionThresholdPercentage}%"
else
    excessiveMotionThresholdPercentage=$( echo "(($excessiveMotionThresholdFraction*100)+0.5)/1" | bc ) 

    info_message_ln "Using ${excessiveMotionThresholdFraction} as the subject exclusion motion cutoff fraction"
    info_message_ln "Using ${excessiveMotionThresholdPercentage}% as subject exclusion motion cutoff percentage"
    info_message_ln "Note that these values are used to exclude subjects based on the number of volumes censored during analysis"
fi


## motionThreshold and outlierThreshold are the values passed to
## afni_proc.py and are used when deciding to censor a volume or not
if [[ "x${motionThreshold}" == "x" ]] ; then
    motionThreshold=0.2
    warn_message_ln "No motionThreshold value was provided. Defaulting to $motionThreshold"
else
    info_message_ln "Using motionThreshold of ${motionThreshold}"
fi

if [[ "x${outlierThreshold}" == "x" ]] ; then
     outlierThreshold=0.1
     warn_message_ln "No outlierThreshold value was provided. Defaulting to $outlierThreshold"
else
    info_message_ln "Using outlierThreshold of ${outlierThreshold}"
fi

if [[ "x${threads}" == "x" ]] ; then
     threads=1
     warn_message_ln "No value for the number of parallel threads to use was provided. Defaulting to $threads"
else
    info_message_ln "Using threads value of ${threads}"
fi

if [[ "x${lowpass}" == "x" ]] ; then
     lowpass="0.01"
     warn_message_ln "No value for lowpass filter value to use was provided. Defaulting to $lowpass"
else
    info_message_ln "Using lowpass filter value of ${lowpass}"
fi

if [[ "x${highpass}" == "x" ]] ; then
     highpass="0.1"
     warn_message_ln "No value for highpass filter value to use was provided. Defaulting to $highpass"
else
    info_message_ln "Using highpass filter value of ${highpass}"
fi

if [[ "x${blur}" == "x" ]] ; then
     blur="7"
     warn_message_ln "No value for blur filter value to use was provided. Defaulting to $blur"
else
    info_message_ln "Using blur filter value of ${blur}"
fi

if [[ "x${tcat}" == "x" ]] ; then
     tcat="3"
     warn_message_ln "No value for tcat, the number of TRs to censor from the start of each volume, was provided. Defaulting to $tcat"
else
    info_message_ln "Using tcat filter value of ${tcat}"
fi

if [[ $nonlinear -eq 1 ]] ; then 
    info_message_ln "Using nonlinear alignment"
    scriptExt="NL"
else 
    info_message_ln "Using affine alignment only"
    scriptExt="aff"    
fi

####################################################################################################
if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    subjects=$( cd ${PROCESSED_DATA} ; find ./ -maxdepth 1 -type d -a -name 'bc[0-9][0-9][0-9][abc]' -printf "%f\n" | sort )

    # subjects="bc002b bc002c bc006c bc012b bc012c bc013b bc016b bc016c
    # bc018a bc018b bc019b bc023b bc024b bc026b bc030b bc039b bc040b bc039c
    # bc040c bc018c bc024c bc034c bc033c bc035c bc034b bc042a bc043a bc044a
    # bc044c bc047c bc049c bc050c bc053b bc054b bc058b bc051c bc058c"
fi

[[ -d run ]] || mkdir run

for subject in $subjects ; do
    info_message_ln "#################################################################################################"
    info_message_ln "Generating script for subject $subject"

    ## here we set up the default anatomy and resting state files to
    ## use. They can then be customized for each subject below in teh
    ## case statement depending on what aea options provide the best
    ## initial affine alignment between T1 and EPI
    
    if  [[ ! -f ${PROCESSED_DATA}/$subject/resting/${subject}.resting+orig.HEAD ]] && \
	[[ ! -f ${PROCESSED_DATA}/$subject/resting/${subject}.resting+orig.BRIK.gz ]]  ; then

	warn_message_ln "Can not find resting state EPI file for ${subject}. Skipping."
	continue
    else
	epiFile=${PROCESSED_DATA}/$subject/resting/${subject}.resting+orig.HEAD
    fi

    if  [[ ! -f ${PROCESSED_DATA}/$subject/anat/${subject}.anat+orig.HEAD ]] && \
	[[ ! -f ${PROCESSED_DATA}/$subject/anat/${subject}.anat+orig.BRIK.gz ]]  ; then

	warn_message_ln "Can not find anatomy file for subject ${subject}. Skipping."
	continue
    else
	anatFile=${PROCESSED_DATA}/$subject/anat/$subject.anat+orig.HEAD
    fi

    if [[ $nonlinear -eq 1 ]] ; then 
	outputScriptName=run/run-afniRsfcPreproc-${subject}.${scriptExt}.sh
    else
	outputScriptName=run/run-afniRsfcPreproc-${subject}.${scriptExt}.sh	
    fi

    ## load file with subject specific alignment options
    if [[ -f ${SCRIPTS_DIR}/resting_alignment_parameters.sh ]] ; then
	info_message_ln "Loading per subject alignment options from ${SCRIPTS_DIR}/resting_alignment_parameters.sh"
	. ${SCRIPTS_DIR}/resting_alignment_parameters.sh
    fi

    if [[ -z ${extraAlignmentArgs} ]] ; then
	extraAlignmentArgs="-align_opts_aea -skullstrip_opts -push_to_edge -no_avoid_eyes"
    else
	extraAlignmentArgs="${extraAlignmentArgs} -skullstrip_opts -push_to_edge -no_avoid_eyes"	
    fi
    
    extraAlignmentArgs="${extraAlignmentArgs} -align_epi_ext_dset ${epiFile}'[0]'"
    
    ## do non-linear warping? If so add the flag to the extra
    ## alignment args variable
    if [[ $nonlinear -eq 1 ]] ; then 
	extraAlignmentArgs="${extraAlignmentArgs} -tlrc_NL_warp"

	##
	## the following code is useful if you want to try to use a
	## preexisting nonlinear warped anatomy
	##
	# anat_base=$( basename $anatFile )
	# anat_base=${anat_base%%+*}
	# if [[ -f ${PROCESSED_DATA}/${subject}/afniRsfcPreprocessed.NL/${anat_base}_al_keep+tlrc.HEAD ]] && \
	#    [[ -f ${PROCESSED_DATA}/${subject}/afniRsfcPreprocessed.NL/anat.aff.Xat.1D ]] && \
	#    [[ -f ${PROCESSED_DATA}/${subject}/afniRsfcPreprocessed.NL/anat.aff.qw_WARP.nii.gz ]] ; then
	#     info_message_ln "Supplying prexisting nonlinear warped anatomy to afni_proc.py"
	#     extraAlignmentArgs="${extraAlignmentArgs} \\
	#      -tlrc_NL_warped_dsets ${PROCESSED_DATA}/${subject}/afniRsfcPreprocessed.NL/${anat_base}_al_keep+tlrc.HEAD \\
        #                            ${PROCESSED_DATA}/${subject}/afniRsfcPreprocessed.NL/anat.aff.Xat.1D \\
        #                            ${PROCESSED_DATA}/${subject}/afniRsfcPreprocessed.NL/anat.aff.qw_WARP.nii.gz"
	# fi
    fi

    info_message_ln "Writing script: $outputScriptName"


    cat <<EOF > $outputScriptName
#!/bin/bash

set -x 

#$ -S /bin/bash

## disable compression of BRIKs/nii files
unset AFNI_COMPRESSOR

export PYTHONPATH=$AFNI_R_DIR

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

# turn off anoying colorization of info/warn/error messages since they
# only result in gobbledygook
export AFNI_MESSAGE_COLORIZE=NO

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=${threads}

excessiveMotionThresholdFraction=$excessiveMotionThresholdFraction
excessiveMotionThresholdPercentage=$excessiveMotionThresholdPercentage

cd ${PROCESSED_DATA}/$subject

preprocessingScript=${subject}.afniRsfcPreprocess.$scriptExt.csh
rm -f \${preprocessingScript}

outputDir=afniRsfcPreprocessed.$scriptExt
rm -fr \${outputDir}

motionThreshold=${motionThreshold}
outlierThreshold=${outlierThreshold}

##	     -tcat_remove_first_trs ${tcat}					\\
##	     -regress_censor_first_trs ${tcat}					\\

## -tlrc_opts_at -init_xform AUTO_CENTER \\
## 	     -regress_censor_outliers \$outlierThreshold                 	\\

afni_proc.py -subj_id ${subject}						\\
             -script \${preprocessingScript}					\\
	     -out_dir \${outputDir}						\\
	     -blocks despike tshift align tlrc volreg mask blur regress		\\
	     -copy_anat $anatFile                                               \\
	     -dsets $epiFile                                                    \\
	     -tcat_remove_first_trs ${tcat}					\\
	     -tlrc_base MNI_caez_N27+tlrc					\\
	     -volreg_align_to first    						\\
	     -volreg_tlrc_warp ${extraAlignmentArgs}				\\
	     -blur_size ${blur}                                                 \\
	     -blur_to_fwhm  							\\
	     -blur_opts_B2FW "-ACF -rate 0.2 -temper"                           \\
	     -mask_apply group							\\
	     -mask_segment_anat yes						\\
	     -anat_uniform_method unifize                                       \\
	     -mask_segment_erode yes						\\
	     -regress_ROI WMe							\\
	     -regress_bandpass ${lowpass} ${highpass}				\\
	     -regress_apply_mot_types demean   					\\
             -regress_censor_motion \$motionThreshold              		\\
	     -regress_run_clustsim no						\\
	     -regress_est_blur_epits                                            \\
	     -regress_est_blur_errts

if [[ -f \${preprocessingScript} ]] ; then 
   tcsh -xef \${preprocessingScript}

    cd \${outputDir}
    xmat_regress=X.xmat.1D 

    if [[ -f \$xmat_regress ]] ; then 

        fractionOfCensoredVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts frac_cen )
        numberOfCensoredVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts trs_cen )
        totalNumberOfVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts trs_no_cen )

        ## rounding method from http://www.alecjacobson.com/weblog/?p=256
        cutoff=\$( echo "((\$excessiveMotionThresholdFraction*\$totalNumberOfVolumes)+0.5)/1" | bc )
	if [[ \$numberOfCensoredVolumes -gt \$cutoff ]] ; then 

	    echo "*** A total of \$numberOfCensoredVolumes of
	    \$totalNumberOfVolumes volumes were censored which is
	    greater than \$excessiveMotionThresholdFraction
	    (n=\$cutoff) of all total volumes of this subject" > \\
		00_DO_NOT_ANALYSE_${subject}_\${excessiveMotionThresholdPercentage}percent.txt

	    echo "*** WARNING: $subject will not be analysed due to having more than \${excessiveMotionThresholdPercentage}% of their volumes censored."
	fi

	# make an image to check alignment
	if [[ -f ext_align_epi+orig.HEAD ]] ; then 
		$SCRIPTS_DIR/snapshot_volreg.sh  ${subject}.anat_unif_al_keep+orig  ext_align_epi+orig.HEAD          ${subject}.orig.alignment
	else
		$SCRIPTS_DIR/snapshot_volreg.sh  ${subject}.anat_unif_al_keep+orig  vr_base+orig.HEAD                ${subject}.orig.alignment
	fi

	$SCRIPTS_DIR/snapshot_volreg.sh  anat_final.${subject}+tlrc         final_epi_vr_base+tlrc.HEAD      ${subject}.tlrc.alignment
    else
	touch 00_DO_NOT_ANALYSE_${subject}_\${excessiveMotionThresholdPercentage}percent.txt
    fi
    echo "Compressing BRIKs and nii files"
    find ./ \( -name "*.BRIK" -o -name "*.nii" \) -print0 | xargs -0 gzip
else
    echo "*** No such file \${preprocessingScript}"
    echo "*** Cannot continue"
    exit 1
fi	

EOF

    chmod +x $outputScriptName
    if [[ $enqueue -eq 1 ]] ; then
	info_message_ln "Submitting job for execution to queuing system"
	LOG_FILE=${PROCESSED_DATA}/$subject/$subject-rsfc-afniPreproc.${scriptExt}.log
	info_message_ln "To see progress run: tail -f $LOG_FILE"
	rm -f ${LOG_FILE}
	qsub -N rsfc-$subject -q all.q -j y -m n -V -wd $( pwd )  -o ${LOG_FILE} $outputScriptName
    else
	info_message_ln "Job *NOT* submitted for execution to queuing system"
	info_message_ln "Pass -q or --enqueue options to this script to do so"	
    fi

done

if [[ $enqueue -eq 1 ]] ; then 
    qstat
fi
