#!/bin/bash

set -x 

# Gabbay, V., Ely, B. A., Li, Q., Bangaru, S. D., Panzer, A. M.,
# Alonso, C. M., et al. (2013). Striatum-based circuitry of adolescent
# depression and anhedonia. Journal of the American Academy of Child
# and Adolescent Psychiatry, 52(6),
# 628–41.e13. http://doi.org/10.1016/j.jaac.2013.04.003


# NAcc (±9, 9, −8);
# ventral caudate (VC; ±10, 15, 0);
# dorsal caudate (DC; ±13, 15, 9),
# dorsal caudal putamen (DCP; ±28, 1, 3);
# dorsal rostral putamen (DRP; ±25, 8, 6),
# ventral rostral putamen (VRP; ±20, 12, −3)

cd ../data/seeds

echo "  9  9 -8" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_r_nacc -xyz -
echo " -9  9 -8" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_l_nacc -xyz -

echo " 10 15  0" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_r_vc -xyz -
echo "-10 15  0" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_l_vc -xyz -

echo " 13 15  9" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_r_dc -xyz -
echo "-13 15  9" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_l_dc -xyz -

echo " 28  1  3" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_r_dcp -xyz -
echo "-28  1  3" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_l_dcp -xyz -

echo " 25  8  6" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_r_drp -xyz -
echo "-25  8  6" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_l_drp -xyz -

echo "20 12 -3"  | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_r_vrp -xyz -
echo "-20 12 -3" | 3dUndump -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -srad 4 -orient LPI -prefix gabbay_l_vrp -xyz -

for ff in gabbay*+tlrc.HEAD ; do
    3dresample -dxyz 3 3 3 -master ../Group.results/MNI_caez_N27+tlrc.HEAD   -inset $ff -prefix ${ff%%+*}.3mm
done


cat <<EOF > ../config/gabbay-striatum-seeds.txt
\$DATA/seeds/gabbay_r_nacc.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_l_nacc.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_r_vc.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_l_vc.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_r_dc.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_l_dc.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_r_dcp.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_l_dcp.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_r_drp.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_l_drp.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_r_vrp.3mm+tlrc.HEAD
\$DATA/seeds/gabbay_l_vrp.3mm+tlrc.HEAD
EOF
