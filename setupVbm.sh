#!/bin/bash

set -x

subjects="bc001b bc002b bc003b bc004b bc005b bc006b bc007b bc018b
bc019b bc023b bc024b bc025b bc033b bc034b bc035b bc036b bc037b bc038b
bc039b bc040b bc041b bc042b bc043b bc044b bc045b bc046b bc047b bc049b
bc050b bc051b bc052b bc053b bc054b bc055b bc056b bc057b bc058b
bc059b bc001c bc002c bc003c bc004c bc005c bc006c bc007c bc018c bc019c
bc023c bc024c bc025c bc033c bc034c bc035c bc036c bc037c bc038c bc039c
bc040c bc041c bc042c bc043c bc044c bc045c bc046c bc047c bc049c bc050c"

#subjects="bc059b bc001c"
echo $subjects

problemBrains=""

if [[ ! -d ../data/vbm ]] ; then
    mkdir -p ../data/vbm
fi

for subject in ${subjects} ; do
    echo "Working on ${subject}"
    if [[ ! -f ../data/processed/${subject}/anat/${subject}.anat+orig.HEAD ]] ; then
	problemBrains="$subject $problemBrains"
    else
	( cd ../data/processed/${subject}/anat/ ; 3dcopy ${subject}.anat+orig.HEAD ${subject}.anat.nii &&  mv -f ${subject}.anat.nii* ../../../vbm  )
    fi
   # exit
done
		    
echo "Print problem brains: $problemBrains"
