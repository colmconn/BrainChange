#!/bin/bash

#set -x 

trap exit SIGHUP SIGINT SIGTERM

studyName=BrainChange

ROOT=/data/sanFrancisco/$studyName
DATA=$ROOT/data
RAW_DATA=$DATA/raw
PROCESSED_DATA=$DATA/processed
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts
SUBJECTS_DIR=$PROCESSED_DATA

if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    subjects=$( cd $RAW_DATA ; ls -1d b* )
fi

[[ -d run ]] || mkdir run

for subject in $subjects ; do
    echo "####################################################################################################"
    echo "*** Generating script for subject $subject"

    if  [[ ! -f ${SUBJECTS_DIR}/$subject/resting/$subject.resting+orig.HEAD ]] && \
	[[ ! -f ${SUBJECTS_DIR}/$subject/resting/$subject.resting+orig.BRIK.gz ]]  ; then

	echo "*** Can not find resting state EPI file for ${subject}. Skipping."
	continue
    fi

    if  [[ ! -f ${SUBJECTS_DIR}/$subject/anat/$subject.anat+orig.HEAD ]] && \
	[[ ! -f ${SUBJECTS_DIR}/$subject/anat/$subject.anat+orig.BRIK.gz ]]  ; then

	echo "*** Can not find anatomy file for subject ${subject}. Skipping."
	continue
    fi

    outputScriptName=run/run-rsfrcPreproc-${subject}.sh

    cat <<EOF > $outputScriptName
#!/bin/bash

set -x 

#$ -S /bin/bash

export PYTHONPATH=$AFNI_R_DIR

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=12

export SUBJECTS_DIR=$PROCESSED_DATA

cd $SUBJECTS_DIR/$subject

preprocessingScript=${subject}.rsfcPreprocess.csh
rm -f \${preprocessingScript}

outputDir=rsfcPreprocessed

motionThreshold=0.2
outlierThreshold=0.1

##	     -align_opts_aea "-giant_move"                                      \\

##	     -tlrc_NL_warp							\\
## the regress_ROI WMe is not needed when using anaticor to perform WM signal removal
##	     -regress_ROI WMe							\\

afni_proc.py -subj_id ${subject}						\\
             -script \${preprocessingScript}					\\
	     -out_dir \${outputDir}						\\
	     -blocks despike tshift align tlrc volreg blur mask	regress		\\
	     -copy_anat ${SUBJECTS_DIR}/$subject/anat/$subject.anat+orig.HEAD   \\
	     -dsets ${SUBJECTS_DIR}/$subject/resting/$subject.resting+orig.HEAD \\
	     -tcat_remove_first_trs 3						\\
	     -tlrc_base MNI_caez_N27+tlrc					\\
	     -volreg_align_to MIN_OUTLIER					\\
	     -volreg_tlrc_warp							\\
	     -tlrc_NL_warp                                                      \\
	     -blur_size 4.2							\\
	     -mask_apply group							\\
	     -mask_segment_anat yes						\\
	     -mask_segment_erode yes						\\
	     -regress_anaticor							\\
	     -regress_bandpass 0.01 0.1						\\
	     -regress_apply_mot_types demean deriv				\\
             -regress_censor_motion \$motionThreshold              		\\
	     -regress_censor_outliers \$outlierThreshold                 	\\
	     -regress_run_clustsim no						\\
	     -regress_est_blur_errts

if [[ -f \${preprocessingScript} ]] ; then 
    tcsh -xef \${preprocessingScript}

    cd \${outputDir}
    motionFile=censor_${subject}_combined_2.1D

    if [[ -f \$motionFile ]] ; then 

	motionThresholdPrecentage=0.2
	threshold=20
	numberOfCensoredVolumes=\$( cat \$motionFile | gawk '{a+=(1-\$0)}END{print a}' )
	totalNumberOfVolumes=\$( cat \$motionFile | wc -l )
	cutoff=\$( echo "scale=0; \$motionThresholdPrecentage*\$totalNumberOfVolumes" | bc | cut -f 1 -d '.' )

	if [[ \$numberOfCensoredVolumes -gt \$cutoff ]] ; then 
	    echo "*** A total of \$numberOfCensoredVolumes of \$totalNumberOfVolumes we censored which is greater than \$threshold % (n=\$cutoff) of all total volumes of this subject" > 00_DO_NOT_ANALYSE_${subject}_\${threshold}percent.txt
	    echo "*** WARNING: $subject will not be analysed due to having more than \$threshold % of their volumes censored."
	fi

        #trs=\$( 1d_tool.py -infile X.xmat.1D -show_trs_uncensored encoded -show_trs_run 01 )
        #3dFWHMx -ACF -detrend -mask full_mask.$subject+tlrc errts.$subject.fanaticor+tlrc"[$trs]" >> blur.errts.acf.1D

    fi 
else
    echo "*** No such file \${preprocessingScript}"
    echo "*** Cannot continue"
    exit 1
fi	

EOF

    chmod +x $outputScriptName
    rm -f ../log/$subject-rsfc-preproc.log
    qsub -N rsfc-$subject -q all.q -j y -m n -V -wd $( pwd )  -o ../log/$subject-rsfc-preproc.log $outputScriptName

done

qstat

# freeview -v \
# mri/T1.mgz \
# mri/wm.mgz \
# mri/brainmask.mgz \
# mri/aparc.a2009s+aseg.mgz:colormap=lut:opacity=0.2 \
# -f surf/lh.white:edgecolor=blue \
# surf/lh.pial:edgecolor=red \
# surf/rh.white:edgecolor=blue \
# surf/rh.pial:edgecolor=red
