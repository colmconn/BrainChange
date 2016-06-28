#!/bin/bash
#

# set -x 
trap exit SIGHUP SIGINT SIGTERM
    
rm -f dcm_info.txt

find . -type d \! -name . -prune | while read d; do
    f=$( ls $d/*.DCM | head -1 )
    description=$( dicom_hdr ${f} | grep "Desc" | head -n1 | awk -F"//" '{print $3}' )
    echo $d $f $description
    echo $d $f $description >> dcm_info.txt    
done
