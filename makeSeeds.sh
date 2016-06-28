#!/bin/bash

set -x

if [[ ! -d ../data/seeds ]] ; then
    mkdir ../data/seeds
fi
cd ../data/seeds

## setup the MNI template to 3mm resolution
3dcopy $AFNI_R_DIR/MNI_caez_N27+tlrc.HEAD MNI_caez_N27.nii
3dresample -dxyz 3 3 3 -inset MNI_caez_N27.nii.gz -prefix MNI_caez_N27.3mm.nii

####################################################################################################
## amygdala

ln -sf ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/L_whole_amygdala.3mm+tlrc.HEAD ./
ln -sf ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/L_whole_amygdala.3mm+tlrc.BRIK.gz ./
3dcopy L_whole_amygdala.3mm+tlrc.HEAD amygdala.left.3mm.new.nii


flirt -ref MNI_caez_N27.3mm.nii -in amygdala.left.3mm.new.nii -applyxfm -usesqform -out amygdala.left.3mm -interp nearestneighbour


ln -sf ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/R_whole_amygdala.3mm+tlrc.HEAD ./
ln -sf ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/R_whole_amygdala.3mm+tlrc.BRIK.gz ./
3dcopy R_whole_amygdala.3mm+tlrc.HEAD amygdala.right.3mm.new.nii


flirt -ref MNI_caez_N27.3mm.nii -in amygdala.right.3mm.new.nii -applyxfm -usesqform -out amygdala.right.3mm -interp nearestneighbour


rm -f *_whole_amygdala.3mm+tlrc.* *new*

####################################################################################################
## anterior insula

3dcopy ../../../../sanDiego/cPine/data/rois/anteriorInsula+tlrc.HEAD anteriorInsula.bilateral.nii  
flirt -ref MNI_caez_N27.3mm.nii -in anteriorInsula.bilateral.nii -applyxfm -usesqform -out anteriorInsula.bilateral.3mm.nii -interp nearestneighbour

3dcalc -a anteriorInsula.bilateral.3mm.nii -expr "isnegative(x) * a" -prefix anteriorInsula.right.3mm.nii
3dcalc -a anteriorInsula.bilateral.3mm.nii -expr "ispositive(x) * a" -prefix anteriorInsula.left.3mm.nii

####################################################################################################
## DLPFC
## coordinates from: 
## Krienen, F. M., & Buckner, R. L. (2009). Segregated
## fronto-cerebellar circuits revealed by intrinsic functional
## connectivity. Cerebral Cortex, 19(10),
## 2485–2497. http://doi.org/10.1093/cercor/bhp135

echo "42 16 36" |  3dUndump -master MNI_caez_N27.3mm.nii.gz -srad 8 -prefix dlpfc.right.nii -orient LPI -xyz -

echo "-42 16 36" |  3dUndump -master MNI_caez_N27.3mm.nii.gz -srad 8 -prefix dlpfc.left.nii -orient LPI -xyz -


####################################################################################################
## DMN Posterior cingulate and VMPFC seeds from the Fox paper

for ff in Fox_tn_MPF_3mm.nii.gz Fox_tn_PCC_3mm.nii.gz ; do
    flirt -ref MNI_caez_N27.3mm.nii -in ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/${ff} -applyxfm -usesqform -out ${ff%%.nii.gz} -interp nearestneighbour
done

## sgACC seeds from the Biol Psych 2013 paper 

for ff in acci8L.nii.gz  acci8R.nii.gz  acci9L.nii.gz  acci9R.nii.gz ; do

    ## ln -sf  ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/ACC/${ff} ./
    flirt -ref MNI_caez_N27.3mm.nii -in ../../../../sanDiego/rsfcGraphAnalysis/data/seeds/ACC/${ff} -applyxfm -usesqform -out ${ff%%.nii.gz}.3mm -interp nearestneighbour
    
done

####################################################################################################
## salience ACC
## coordinates from: 
# Pannekoek, J. N., van der Werff, S. J. A., Meens, P. H. F., van den
# Bulk, B. G., Jolles, D. D., Veer, I. M., et al. (2014). Aberrant
# resting-state functional connectivity in limbic and salience networks
# in treatment--naïve clinically depressed adolescents. Journal of Child
# Psychology and Psychiatry, and Allied Disciplines, 55(12),
# 1317–1327. http://doi.org/10.1111/jcpp.12266

## right
6 -18 28
echo "6 18 28" |  3dUndump -master MNI_caez_N27.3mm.nii.gz -srad 4 -prefix salience.acc.right.nii -orient LPI -xyz -

# left
-6 -18 28
echo "-6 18 28" |  3dUndump -master MNI_caez_N27.3mm.nii.gz -srad 4 -prefix salience.acc.left.nii -orient LPI -xyz -
