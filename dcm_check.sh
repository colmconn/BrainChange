#!/bin/bash
#

# set -x 
trap exit SIGHUP SIGINT SIGTERM
    
rm -f dcm_info.txt

find . -type d \! -name . -prune | while read d; do
    f=$( ls $d/*.DCM | head -1 )
    description=$( dicom_hdr ${f} | grep "Desc" | head -n1 | awk -F"//" '{print $3}' )

    ## the $d is actually the series order, so 1 indicates first
    ## scan/series, 2, the second , and so on.  Those with 3 digits
    ## were the result of post processing on the scanner console and
    ## to all intents and purposes are of no interest to us

    ## echo $( basename $d ) $f $description 
    echo $( basename $d ) $f $description >> dcm_info.txt    
done

## sort the dcm_info by series order, i.e., the first field
cat dcm_info.txt | sort -n -k1 > dcm_info.txt.new && mv -f dcm_info.txt.new dcm_info.txt
