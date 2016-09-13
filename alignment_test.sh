#!/bin/bash

set -x 

#$ -S /bin/bash

studyName=BrainChange

export PYTHONPATH=/data/software/afni

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=40

subject="$@"

cd /data/sanFrancisco/${studyName}/data/processed/${subject}

outputDir=alignmentTest
rm -rf alignmentTest

mkdir alignmentTest
cd alignmentTest/
cp ../resting/${subject}.resting+orig.* ./
if [[ -f ../anat/${subject}.anat_clp+orig.HEAD ]] ; then
    3dcopy ../anat/${subject}.anat_clp+orig. ${subject}.anat_clp
    anatFile=${subject}.anat_clp+orig.HEAD
else
    cp ../anat/${subject}.anat+orig.* ./
    anatFile=${subject}.anat+orig.HEAD
fi

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
3dZeropad -I 30 -S 30 -prefix ${anatFile%%+*}.zp ${anatFile}
anatFile=${anatFile%%+*}.zp+orig.HEAD						      

## 3dTcat -prefix ${subject}.resting.tcat ${subject}.resting+orig.'[3..$]'
3dcopy ${subject}.resting+orig ${subject}.resting.tcat
3dDespike -NEW -nomask -prefix ${subject}.resting.despike ${subject}.resting.tcat+orig.
3dTshift -tzero 0 -quintic -prefix ${subject}.resting.tshift ${subject}.resting.despike+orig.

3dZeropad -I 30 -S 30 -prefix ${subject}.resting.tshift.zp ${subject}.resting.tshift+orig
epiFile=${subject}.resting.tshift.zp+orig.HEAD						      

align_epi_anat.py -anat2epi			\
		  -anat ${anatFile}		\
		  -epi ${epiFile}		\
		  -epi_base 0			\
		  -volreg off			\
		  -tshift off			\
		  -cost lpc			\
		  -multi_cost lpa lpc+ZZ mi


