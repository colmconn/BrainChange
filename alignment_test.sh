#!/bin/bash

set -x 

#$ -S /bin/bash

studyName=BrainChange
SCRIPTS_DIR=$( pwd )

export PYTHONPATH=/data/software/afni

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=1

subject="$@"

cd /data/sanFrancisco/${studyName}/data/processed/${subject}
## nn=2

outputDir=alignmentTest.unif.nozp$nn
rm -rf alignmentTest.unif.nozp$nn

mkdir alignmentTest.unif.nozp$nn
cd alignmentTest.unif.nozp$nn/

cp ../resting/${subject}.resting+orig.* ./
if [[ -f ../anat/${subject}.anat_clp+orig.HEAD ]] ; then
    3dcopy ../anat/${subject}.anat_clp+orig. ${subject}.anat_clp
    3dUnifize -input ${subject}.anat_clp+orig -prefix ${subject}.anat_unif
    #anatFile=${subject}.anat_unif+orig.HEAD
else
    cp ../anat/${subject}.anat+orig.* ./
    3dUnifize -input ${subject}.anat+orig -prefix ${subject}.anat_unif
    #anatFile=${subject}.anat_unif+orig.HEAD
fi




## 1x1x1mm rectangular neighborhood around each voxel to be used in
## the median filtering operation. The 1x1x1 should match the
## underlying resolution of the input data.

## Unifize and median filtering are not commutative operations. If
## they were the difference between median_unif and unif_median would
## be 0 which is not the case

## -1, -1, -1 here means 1 voxel in each direction (x, y, z), remove -
## -to require measurement to be in mm rather than voxels
## 3dLocalstat -nbhd 'RECT(-1,-1,-1)' -stat median -prefix bc009a.anat_unif_median bc009a.anat_unif+orig.
## the 3x3x3 can be used to match fslmaths
## 3dLocalstat -nbhd 'RECT(-3,-3,-3)' -stat median -prefix bc009a.anat_unif_median bc009a.anat_unif+orig.
anatFile=${subject}.anat_unif+orig.HEAD

## cp ../${subject}.anat+orig.* ./
## orientation=$( 3dinfo -orient ${subject}.anat.nii.gz )
# if [[ "${orientation}" != "RPI" ]] ; then
#     echo "*** Reorienting anatomy to RPI"
#     3dresample -orient RPI -inset ${subject}.anat.nii.gz -prefix ${subject}.anat.std.nii
#     anatFile=${subject}.anat.std.nii.gz
# else
#     anatFile=${subject}.anat.nii.gz
# fi

## anatFile=${subject}.anat+orig.HEAD
##3dZeropad -I 30 -S 30 -prefix ${anatFile%%+*}.zp ${anatFile}
##anatFile=${anatFile%%+*}.zp+orig.HEAD						      

## 3dTcat -prefix ${subject}.resting.tcat ${subject}.resting+orig.'[3..$]'

3dcopy ${subject}.resting+orig ${subject}.resting.tcat

## 3dDespike -NEW -nomask -prefix ${subject}.resting.despike ${subject}.resting.tcat+orig.


3dTshift -tzero 0 -quintic -prefix ${subject}.resting.tshift ${subject}.resting.tcat+orig.
3dbucket -prefix vr_base ${subject}.resting.tshift+orig.HEAD'[0]'

## 3dZeropad -I 30 -S 30 -prefix ${subject}.resting.tshift.zp ${subject}.resting.tshift+orig
## epiFile=${subject}.resting.tshift.zp+orig.HEAD
## epiFile=${subject}.resting.tshift+orig.HEAD						      
epiFile=vr_base+orig.HEAD

epiFile=vr_base+orig.HEAD
align_epi_anat.py -anat2epi			\
		  -anat ${anatFile}		\
		  -epi ${epiFile}		\
		  -epi_strip 3dAutomask         \
		  -epi_base 0			\
		  -volreg off			\
		  -tshift off			\
		  -cost lpc			\
		  -multi_cost lpa lpc+ZZ mi


for metric in _al _al_lpc+ZZ _al_lpa _al_mi ; do 
    ##     $SCRIPTS_DIR/snapshot_volreg.sh ${anatFile%%+*}${metric}+orig.HEAD ${epiFile} ${anatFile%%+*}${metric}.alignment
    $SCRIPTS_DIR/snapshot_volreg.sh ${anatFile%%+*}${metric}+orig.HEAD ${epiFile} ${anatFile%%+*}${metric}.overlay    
done
