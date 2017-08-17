#!/usr/bin/Rscript

rm(list=ls())
graphics.off()

####################################################################################################
### START OF FUNCTIONS
####################################################################################################


make.data.table.and.regression.script <- function (infix, regression.formula, data.table.filename, data.table.columns, mask.filename) {

    if (is.null(data.table.columns)) {
        stop(paste("*** You must provide a vector of columns to select from the data frame to be written for regression analysis.",
                   "*** DO NOT include Subj and InputFile in this list.",
                   "*** They are included automatically.", sep="\n"))
    }
    
    cat("*** Writing data table to", data.table.filename, "\n")
    write.table(data.table[, c("Subj", data.table.columns, "InputFile")], file=data.table.filename, quote=FALSE, col.names=TRUE,  row.names=FALSE)
    
    script.file.name=sprintf("run/run-%s.sh", infix)
    cat("*** Writing regression script to", script.file.name, "\n")
    regression.command=sprintf(
        "#!/bin/bash
set -x
cd %s

./parallel.robust.regression.r -v -p --threads %d --formula \"%s\" --datatable %s --session %s --infix %s --mask %s

",
scripts.dir,
thread.count,
regression.formula,
data.table.filename,
group.results.dir,
infix,
mask.filename)
    
    cat(regression.command, file=script.file.name)
    Sys.chmod(script.file.name, mode="0774")
}

## Reads the seed file and does the (crude) equivalent of BAS variable
## substitution
readSeedsFile <- function (inSeedsFile) {
    cat("*** Reading seed from", inSeedsFile, "\n")
    table=scan(inSeedsFile, what=character())
    table=gsub("$DATA", seeds.data.dir, table, fixed=TRUE)

    return (table)
}

## extracts the seed name from a file path name pointing to a NIfTI
## file containing the seed
getSeedName <- function(inSeedPath){
    name=basename(inSeedPath)
    if (grepl("\\.nii", name)) {
        return(gsub("\\.nii.*", "", name))
    } else if (grepl("\\+tlrc", name)) {
        return(gsub("\\+tlrc.*", "", name))
    } else {
        return (name)
    }
}

####################################################################################################
### END OF FUNCTIONS
####################################################################################################


scripts.dir=getwd()

## read the clinical measures from a CSV file. Note that it has had an
## ID column with subjects IDs of the form CMIT_?? added to facilitate
## creation of a data frame for with all clinical measures
## clinical.measures=read.csv("../FOSI_widedata_rr_grief_depression_subset.csv", header=TRUE)
## clinical.measures=read.csv("../FOSI_widedata_rr_dirty17.csv", header=TRUE) 
followup.clinical.measures=read.csv("../data/admin/followup.clinical.change.measures.csv", header=TRUE)

## this is the list of regression variables from the
## followup.clinical.measures data frame for which regressiosn shoudl
## be run
regression.variables=c("conflict", "SDQ", "RADS")

## list all of the subjects directories
subject.list=dir("../data/processed/", pattern="bc[0-9]{3}[bc]$")
subject.list=subject.list[order(subject.list)]

## create a data frame with the columns:
## 1: subject column set to the subject's MRI directory
## 2: ID set to all but the last letter in the subjects's MRI directory
## 3: timepoint set the the final letter in the subject's ID
subjects.df=data.frame("subject"=subject.list, "ID"=substring(subject.list, 1, nchar(subject.list)-1), "timepoint"=substring(subject.list, 6))
subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]

## print(subjects.df)
## stop()

parent.directory=dirname(getwd())
group.data.dir=file.path(parent.directory, "data", "Group.data")
config.data.dir=file.path(parent.directory, "data", "config")
seeds.data.dir=file.path(parent.directory, "data", "seeds")
if ( ! dir.exists(group.data.dir)) {
    cat("*** Creating group data dir\n")
    dir.create(group.data.dir)
}

## the default number of threads to tell the robust regression script to use
thread.count=1
cat("*** Thread count set to", thread.count, "\n")

debug=FALSE

### These two variables control which set of regressions are to have
### files created
do.baseline.to.followup.change.regressions=TRUE
do.baseline.only.regressions=FALSE

seedFiles=
    sapply(c(
        "seed.list.txt",
        "gabbay-striatum-seeds.txt"
    ),
    function(xx) {
        file.path(config.data.dir, xx)
    })
seeds=unlist(sapply(seedFiles, readSeedsFile))
numberOfSeeds=length(seeds)
cat(sprintf("*** Found %02d seeds in the seed file\n", length(seeds)))


####################################################################################################
### CHANGE FROM BASELINE TO FOLLOW-UP REGRESSIONS
####################################################################################################
if (do.baseline.to.followup.change.regressions ) {
    ## now bind the data frame just created above with all of teh data
    ## from the clinical measures data frame
    ## 
    ## match looks up its first argument in its second argument and
    ## returns the index from the second argument where the first argument
    ## is found (NA if not found)
    subjects.df=cbind(subjects.df,
                      followup.clinical.measures[match(subjects.df$ID, followup.clinical.measures$ID), colnames(followup.clinical.measures)[-c(1)]])
    ## print(subjects.df)

    ## stop()

    for (seed in seeds) {
        seedName=getSeedName(seed)
        cat("####################################################################################################\n")
        cat(sprintf("*** Creating scripts and data table for the %s\n", seedName))
        
        subjects.df$stats.file=normalizePath(file.path("../data/processed", subjects.df$subject, "rsfc", seedName, paste(seedName, "z-score+tlrc.HEAD", sep=".")))
        subjects.df$stats.file.exists=file.exists(subjects.df$stats.file)
        subjects.df=droplevels(subjects.df)
        rownames(subjects.df)=NULL
        ## print(subjects.df)
        
        ## now keep only the healthy subjects
        subjects.df=droplevels(subset(subjects.df, healthy1 == 1))
        rownames(subjects.df)=NULL
        ## print(subjects.df)
        
        ## now filter out those subjects who do not have data at both time points
        subjects.to.drop=list()
        for (ss in levels(subjects.df$ID) ) {
            if (  !( length(subjects.df[subjects.df$ID==ss, "timepoint"]) == 2 && isTRUE(all(subjects.df[subjects.df$ID==ss, "stats.file.exists"])) ) )
                subjects.to.drop[[length(subjects.to.drop) + 1 ]] = ss
        }
        
        cat("*** The following subjects do not have RSFC data at both timepoints and will be dropped:",
            paste(unlist(subjects.to.drop), collapse=", "), "\n")
        subjects.df=droplevels(subset(subjects.df, ! (subjects.df$ID %in% unlist(subjects.to.drop))))
        subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]
        rownames(subjects.df)=NULL
        ## stop()
        
        group.results.dir=normalizePath(file.path("..", "data", "Group.results", "followup.regressions"))
        mask.filename="/data/sanFrancisco/BrainChange/data/standard/MNI_caez_N27_brain.3mm+tlrc.HEAD"
        
        input.files=list()
        
        for ( subject in levels(subjects.df$ID) ) {
            difference.prefix=sprintf("%s.minus.%s.%s", 
                                      subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "c" , "subject"],
                                      subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "b" , "subject"],
                                      seedName)
            difference.creation.command=
                sprintf("3dcalc -a %s -b %s -prefix %s -expr \"b-a\"",
                        subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "b" , "stats.file"],
                        subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "c" , "stats.file"],
                        difference.prefix)
            difference.creation.command = paste("(cd", group.data.dir, ";", difference.creation.command, ")")
            
            input.files[[length(input.files) + 1 ]] = file.path(group.data.dir, paste(difference.prefix, "+tlrc.HEAD", sep=""))
            
            if (! file.exists(file.path(group.data.dir, paste(difference.prefix, "+tlrc.HEAD", sep="")))) {
                cat(paste("***", subject,  "Running: ", "\n"))
                cat(difference.creation.command, "\n")
                system(difference.creation.command)
            } else {
                cat("*** Difference file for", subject, "already exists. Skipping creation.\n")
            }
        }

        ## row ids
        rids=which(subjects.df$timepoint=="b")
        ## setup the data tbale with all columns needed for the various sub-analyses
        data.table.orig=data.frame("Subj"      = subjects.df[rids, "ID"],
                                   subjects.df[rids, regression.variables],
                                   "InputFile" = unlist(input.files))
        
        if ( ! file.exists( mask.filename) ) {
            stop(paste("Mask file", mask.filename, "does not exist. Cannot continue until this is fixed!\n"))
        }
        
        for (variable in regression.variables) {
            data.table=data.table.orig[complete.cases(data.table.orig[, variable]), ]
            rownames(data.table)=NULL
            if (debug) {
                cat("*** After complete cases\n")
                print(data.table)
                stop()
            }
            infix=paste("followup.analysis", seedName, variable, sep=".")
            regression.formula=sprintf("mri ~ %s", variable)
            data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
            make.data.table.and.regression.script(infix, regression.formula, data.table.filename, variable, mask.filename)
            
            ## stop()
        }
    }        
} ## end of if (do.baseline.to.followup.change.regressions ) {


## ####################################################################################################
## ### BASELINE REGRESSIONS
## ####################################################################################################
## if (do.baseline.only.regressions ) {
##     ## now bind the data frame just created above with all of teh data
##     ## from the clinical measures data frame
##     ## 
##     ## match looks up its first argument in its second argument and
##     ## returns the index from the second argument where the first argument
##     ## is found (NA if not found)
##     subjects.df=cbind(subjects.df,
##                       baseline.clinical.measures[match(subjects.df$ID, baseline.clinical.measures$ID), colnames(baseline.clinical.measures)[-c(1:2)]])
##     ## print(subjects.df)

##     ## now for each GLT of interest we need to add a column to the
##     ## subjects data frame with the HEAD filename. This will facilitate
##     ## the creation of difference files later

##     subjects.df$stats.file=file.path(parent.directory, subjects.df$subject, "afniGriefPreprocessed.NL", paste("stats.", subjects.df$subject, "_REML+tlrc.HEAD", sep=""))
##     subjects.df$stats.file.exists=file.exists(subjects.df$stats.file)
##     subjects.df=droplevels(subjects.df)
##     ## print(subjects.df)
    
##     subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]
##     rownames(subjects.df)=NULL
##     group.results.dir=normalizePath(file.path("..", "Group.results", "Grief", "baseline.regressions"))
##     mask.filename=file.path(group.results.dir, "final_mask+tlrc.HEAD")
    
##     ## only interested in baseline timepoint
##     subjects.df=subset(subjects.df, timepoint=="A")
    
##     for ( glt in c("relativeVsStanger", "relativeGriefVsRelativeNeutral", "relativeGriefVsStrangerGrief") ) {
##         ## for ( glt in c("rg", "sg") ) {
##         glt.sub.brik.label=paste(substring(glt, 1, 32), "#0_Coef", sep="")

        
##         ## row ids
##         rids=which(subjects.df$timepoint=="A")
##         ## setup the data tbale with all columns needed for the various sub-analyses
##         data.table=data.frame("Subj"                 = subjects.df[rids, "ID"],
##                               "subject"              = subjects.df[rids, "subject"],
##                               "grief"                = subjects.df[rids, "mm"],
##                               "grief.a"              = subjects.df[rids, "mm_a"],
##                               "grief.b"              = subjects.df[rids, "mm_b"],
##                               "grief.c"              = subjects.df[rids, "mm_c"],
##                               "iri_pt"               = subjects.df[rids, "iri_pt"],
##                               "iri_ec"               = subjects.df[rids, "iri_ec"],                              
##                               "hamd"                 = subjects.df[rids, "ham_total"],
##                               "age"                  = subjects.df[rids, "Age"],
##                               "stats.file"           = subjects.df[rids, "stats.file"],
##                               "stats.file.exists"    = subjects.df[rids, "stats.file.exists"])
##         data.table=subset(data.table, stats.file.exists==TRUE)

##         if (debug) {
##             cat("*** Before complete cases\n")
##             print(data.table)
##         }
##         ## drop rows with missing data
##         data.table=data.table[complete.cases(data.table$grief), ]

##         if (debug) {
##             cat("*** After complete cases\n")
##             rownames(data.table)=NULL
##             print(data.table)
##             stop()
##         }
        
##         input.files=list()
##         for ( ii in seq.int(1, dim(data.table)[1]) ) {
##             ## subjects.df$stats.file=file.path(parent.directory, subjects.df$subject, "afniGriefPreprocessed.NL", paste("stats.", subjects.df$subject, "_REML+tlrc.HEAD", sep=""))
##             bucket.prefix=file.path(parent.directory, as.character(data.table[ii, "subject"]), "afniGriefPreprocessed.NL", paste(data.table[ii, "subject"], ".", glt, sep=""))
##             bucket.command=sprintf("3dcalc -a %s\'[%s]\' -expr a -prefix %s ", data.table[ii, "stats.file"], glt.sub.brik.label, bucket.prefix)
            
##             if (! file.exists(file.path(paste(bucket.prefix, "+tlrc.HEAD", sep="")))) {
##                 cat("*** Running: ", "\n")
##                 cat(bucket.command, "\n")
##                 system(bucket.command)
##             } else {
##                 cat("*** Bucket file for", as.character(data.table[ii, "subject"]), "already exists. Skipping creation.\n")
##             }
##             input.files[[ii]] = file.path(paste(bucket.prefix, "+tlrc.HEAD", sep=""))
##         }

##         data.table$InputFile = unlist(input.files)

##         ## CMIT_04 has a baseline Grief (mm.0) score of 27 which may
##         ## be driving the regression results in the whole sample. So
##         ## this line is added to facilitate its removal so that the
##         ## regressions can be run without this subject
##         data.table=subset(data.table, ! Subj %in% c("CMIT_04"))
        
##         ## stop()
        
##         if ( ! isTRUE(all(sapply(data.table$InputFile, function (xx) { file.exists(as.character(xx)) } )) ) ) {
##             stop("Some of the InputFiles files do not exist. Cannot continue\n")
##         }


##         for (variable in c("grief", "grief.a", "grief.b", "grief.c", "iri_pt", "iri_ec")) {
## ### ANALYSIS 1
##             infix=paste(glt, "baseline.analysis.one", variable, sep=".")
##             regression.formula=sprintf("mri ~ %s", variable)
##             data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
##             make.data.table.and.regression.script(infix, regression.formula, data.table.filename, variable, mask.filename)

## ### ANALYSIS 2
##             infix=paste(glt, "baseline.analysis.two", variable, "and.hamd", sep=".")
##             regression.formula=sprintf("mri ~ %s + hamd", variable)
##             data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
##             make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c(variable, "hamd"), mask.filename)
            
## ### ANALYSIS 3
##             infix=paste(glt, "baseline.analysis.three", variable, "and.age", sep=".")
##             regression.formula=sprintf("mri ~ %s + age", variable)
##             data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
##             make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c(variable, "age"), mask.filename)    
##         }
##     }

## }
