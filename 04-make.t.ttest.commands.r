#!/usr/bin/Rscript

rm(list=ls())

library(getopt)
library(stringr)
library(plyr)

## Reads the seed file and does the (crude) equivalent of BASH variable
## substitution
readSeedsFile <- function (inSeedsFile) {
    cat("*** Reading seed from", inSeedsFile, "\n")
    table=scan(inSeedsFile, what=character(), quiet=TRUE)
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


readCsvFile <- function (inFilename, inSubjectColumnName="ID") {

    cat("*** Reading", inFilename, "\n")
    rCsv=read.csv(inFilename, header=T, na.strings = c("NA", "<NA>", "#N/A", "#VALUE", "#VALUE!", "n/a", "N/A", "#DIV/0!", "IGNORE THIS SUBJECT", ".", ""))
    cat(sprintf("*** Read data for %s unique subjects\n",  length(unique(rCsv[, inSubjectColumnName]))))

    return(rCsv)
}


help <- function(){

}

checkCommandLineArguments <- function (in.opt) {
    ## if help was asked for print a friendly message
    ## and exit with a non-zero error code
    if ( !is.null(in.opt$help) ) {
        cat(getopt(spec, usage=TRUE));
        q(status=1);
    }
    if (is.null(in.opt$both))
        in.opt$both=FALSE
    
    if (is.null(in.opt$qvariables)) {
        cat("*** No covariate variable names were supplied.\n")
    } else {
        in.opt$qvariables=unlist(strsplit(in.opt$qvariables, "\\s", perl=TRUE, fixed=FALSE))
        ## print(in.opt$qvariables)
    }

    if (is.null(in.opt$bsvariables)) {
        cat("*** No between subjects variables were specified.\n")
    } else {
        in.opt$bsvariables==unlist(strsplit(in.opt$bsvariables, "\\s", perl=TRUE, fixed=FALSE))
        ## print(in.opt$bsvariables)
    }
    
    if (is.null(in.opt$wsvariables)) {
        cat("*** No within subject variable names were supplied.\n")
    } else {
        in.opt$wsvariables=unlist(strsplit(in.opt$wsvariables, "\\s", perl=TRUE, fixed=FALSE))
        ## print(in.opt$wsvariables)        
    }
    if (is.null(in.opt$wsvariables) && is.null(in.opt$bsvariables) && is.null(in.opt$wsvariables)) {
        cat("*** You must specify between, within and/or quantiative variables.\n")
    }
    
    if (is.null(in.opt$mask)) {
        cat("*** No mask was specified.\n")
        if ( ! interactive() )
            q(status=1)
    }

    if (is.null(in.opt$mask)) {
        cat("*** No mask was specified.\n")
    } else {
        mask.filename=in.opt$mask
        if ( ! file.exists( mask.filename)) {
            cat("*** No such file:", mask.filename, "\n")
            if ( ! interactive() )
                q(status=1)
        }
    }

    if (is.null(in.opt$seeds)) {
        cat("*** A file name containing the list of seeds to use is required.\n")
        cat(getopt(spec, usage=TRUE));    
        q(status=1)
    }

    if (is.null(in.opt$task)) {
        cat("*** A task name is required.\n")
        cat(getopt(spec, usage=TRUE));    
        q(status=1)
    }


    ## if (is.null(in.opt$g2f)) {
    ##     cat("*** A mapping of group names to file names is required.\n")
    ##     cat(getopt(spec, usage=TRUE));    
    ##     if ( !interactive() )
    ##         q(status=1)
    ## } else {
    ##     groupings=unlist(strsplit(in.opt$g2f, "\\s", perl=TRUE, fixed=FALSE))
    ##     ## print(groupings)
    ##     ## print(length(groupings))
    ##     ## if (length(groupings) < 2) {
    ##     ##     cat("*** You must provide more than one (1) group to file name mapping\n")
    ##     ##     cat(getopt(spec, usage=TRUE));    
    ##     ##     if ( !interactive() )
    ##     ##         q(status=1) 
    ##     ## } else {
    ##     for (ii in 1:length(groupings) ) {
    ##         ## cat("Groupings: ", groupings[ii], "\n")
    ##         g2f=unlist(strsplit(groupings[ii], ":", perl=FALSE, fixed=TRUE))
    ##         ## print(g2f)
    ##         in.opt$groups.to.files.list[[g2f[1]]] = file.path(config.data.dir, g2f[2])
    ##         ## print(groups.to.files.list)
    ##         if ( ! file.exists(in.opt$groups.to.files.list[[ g2f[1] ]]) ) {
    ##             cat(sprintf("*** For the %s group, the subject list file %s does not exist\n", g2f[1], in.opt$groups.to.files.list[[ g2f[1] ]], "\n"))
    ##             if ( !interactive() )
    ##                 q(status=1) 
    ##         }
    ##     }
    ## }
    ## cat("*** At end\n")
    ## print(in.opt$groups.to.files.list)
    
    return(in.opt)
}

printDirectorySummary <- function () {

    cat("***\n")
    cat("*** Directories settings\n")
    cat("*** ====================\n")    
    for ( var in c(
        "root.dir",
        "scripts.dir",
        "data.dir",
        "admin.data.dir",
        "config.data.dir",
        "group.data.dir",
        "group.results.dir",
        "seeds.data.dir") ) {

        cat(sprintf("*** %s -> %s\n", var, eval(parse(text=var))))
    }
    cat("***\n")    
}


printOptionsSummary <- function (in.opt) {

    cat("*** Summary of ommand line arguments.\n")
    cat("*** =================================\n")
    if (in.opt$both) {
        cat ("*** Only subjects with data at both time points will be included in analysis\n")
    } else {
        cat ("*** Subjects with data at either time point A, C or both time points will be included in analysis\n")
    }
    cat("*** Prefix will be:", in.opt$prefix, "\n")
    cat("*** Within subject variable(s) will be:",  paste(in.opt$wsvariables, collapse=", "), "\n")
    cat("*** Between subject variable(s) will be:", paste(in.opt$bsvariables,  collapse=", "), "\n")
    if ( ! is.null(in.opt$qvariables) ) {
        cat("*** The following variable(s) will be used as covariates in the data table:\n")
        cat(paste("*** Quantative variable", 1:length(in.opt$qvariables), ":", in.opt$qvariables, collapse="\n"), sep="\n")
    } else {
        cat("*** No Quantative variable provided\n")
    }
    if (! is.null(in.opt$qvariables) && in.opt$center) {
        cat("*** The quantative covariates listed above will be mean centered.\n")
    }

    cat("*** Mapping of group names to files containing list of subjects.\n")
    cat("*** -------------------------------------------------------------\n")
    cat("*** Group -> Subject list file\n")
    ## print(names(in.opt$groups.to.files.list))
    for (nn in names(in.opt$groups.to.files.list) ) {
        cat(sprintf("*** %s -> %s\n", nn,in.opt$groups.to.files.list[[ nn ]] ))
    }

    cat("*** The following task name will be used:", in.opt$task, "\n")
    cat("*** Seeds will be read from:", in.opt$seeds, "\n")
    cat("*** Mask will be:", in.opt$mask, "\n")
    cat("***\n")    
}


readSubjectListFiles <- function( in.opt ) {

    subjectOrder=do.call( rbind,
        lapply(names(in.opt$groups.to.files.list), function (nn) { 
            so=read.table(in.opt$groups.to.files.list[[ nn ]])
            df=data.frame(rep(nn, 1:length(so)), so)
        }
        ))
    colnames(subjectOrder)=c("Group", "subject")
    print(subjectOrder)

    return(subjectOrder)
}

makeSubjectAndTimepointDf <- function () {
    subjects=data.frame("ID"=dir(processed.data.dir, pattern="bc[0-9][0-9][0-9][abc]$"))
    subjects$Subj     =as.factor(sub("^(bc[0-9][0-9][0-9])([abc])$", "\\1", subjects$ID, fixed=FALSE))
    subjects$timepoint=as.factor(sub("^(bc[0-9][0-9][0-9])([abc])$", "\\2", subjects$ID, fixed=FALSE))

    return(subjects)
}
    
makeInputFilename <- function (  in.subjectOrder, in.seed.name, in.task )  {

    df=cbind(in.subjectOrder,
        sapply(in.subjectOrder$ID,
               function (xx) {
                   file.path(processed.data.dir, xx, in.task, in.seed.name, sprintf("%s.z-score+tlrc.HEAD", in.seed.name))
               } )
                  )
    colnames(df)=c(colnames(in.subjectOrder), "InputFile")
    df$InputFile=as.character(df$InputFile)
    return (df)
}

checkInputFileExists <- function ( in.subjectOrder ) {

    InputFile.exist=sapply(in.subjectOrder$InputFile,
        function (xx) {
            ## print(xx)
            if ( ! file.exists(xx) ) {
                cat("*** No such file:", xx, "\n")
                return(FALSE)
            } else {
                return(TRUE)
            }
        }
                       )
    if( ! any(InputFile.exist) && ! interactive() ) {
        cat("*** Some subjects input files do not exist. Cannot continue\n")
    }

    ret.val=cbind(in.subjectOrder, InputFile.exist)
    ## print(head(ret.val))
    ## colnames(ret.val) = c(colnames(ret.val), "InputFile.exists")

    return(ret.val)
}

stopIfVariablesNotInModelMatrix <- function(in.opt, in.model.matrix ) {

    termDifference=setdiff(c(in.opt$bsvariables, in.opt$wsvariables, in.opt$qvariables), colnames(in.model.matrix))
    if (length(termDifference) > 0) {
        stop(paste("The following were in the list of between, within, and quantative variables but are not columns of the model matrix:", termDifference))
    }   
}

checkIsNa <- function (inData, inColumns) {
    for (column in inColumns) {
        
        if (any(is.na(inData[, column]))) {
            cat ("****************************************************************************************************\n")
            cat (sprintf("*** The following subjects have NA data for %s\n", column))

            print(data.frame ("Group" = as.vector ( inData[is.na(inData[, column]), "Group"]),
                              "Subj" = as.vector ( inData[is.na(inData[, column]), "Subj"])))
            
            cat ("****************************************************************************************************\n")      
        }
    } ## end of for (column in inColumns) {
    
} ## end of checkIsNa

scaleCovariates <- function ( in.data) {
    for (col in opt$qvariables) {
        if ( is.numeric(in.data[, col]) ) {
            cat("*** Mean centering quantative variable:", col, "\n")            
            in.data[, col] = scale(in.data[, col], center=TRUE, scale=FALSE)
        } else {
            cat(sprintf("*** Skipping centering for %s: Not a numeric column\n", col))
        }
    }
    return(in.data)
}

check.for.motion.exclusion.files <- function (in.subjects, in.threshold=20) {

    build.do.not.analyze.filenames <- function(in.subjects, in.motion.threshold=in.threshold) {
        filenames=sapply(in.subjects$Subj,
            function(ss) {
                sprintf("%s/%s/afniRsfcPreprocessed.NL/00_DO_NOT_ANALYSE_%s_%dpercent.txt",  processed.data.dir, ss, ss, in.motion.threshold)
            })
        
        return(filenames)
    }
    
    df = build.do.not.analyze.filenames(in.subjects)
    df = cbind(in.subjects, "do.not.analyze.filename"=df, "excessive.motion"=file.exists(df))
    ## df$ID=rownames(df)

    drop.subject.list=c()
    motion.contaminated.subjects.count=sum(df$excessive.motion)
    if (motion.contaminated.subjects.count > 0) {

        drop.subject.list=df[df$excessive.motion==TRUE, "Subj"]

        cat("***", motion.contaminated.subjects.count, "of", dim(in.subjects)[1],
            paste("(",
                  round(motion.contaminated.subjects.count/dim(in.subjects)[1] * 100 , 2) ,
                  "%)", sep=""),  "are excessively contaminated by motion\n")
        cat("*** The following subjects are excessively contaminated by motion\n")
        cat("---", str_wrap(paste (drop.subject.list, collapse=" "), width=80), "\n")

        cat("*** The following subjects are NOT excessively contaminated by motion\n")
        cat("+++", str_wrap(paste (df[df$excessive.motion==FALSE, "Subj"], collapse=" "),
                            width=80), "\n")

    }
    
    ## return(drop.subject.list)
    return(df)
}

conditionally.make.dir <- function (in.dir) {
    if ( ! dir.exists(in.dir)) {
        cat("*** Recursively creating", in.dir, "\n")
        dir.create(in.dir, recursive=TRUE)
    }
}

make.ttest.data.table <- function(in.mgd, in.seed.name) {

    dataTableFilename=
        file.path(group.data.dir,
                  paste("dataTable.ttest", opt$task,  in.seed.name,
                        paste(paste(levels(in.mgd$timepoint), collapse=".and."),
                              "timepoints", sep="."),
                        "txt", sep="."))

    cat("*** Writing data table to", dataTableFilename, "\n")
    write.table(in.mgd[1:dim(in.mgd)[1]-1, c("Subj", opt$bsvariables,
                                             opt$wsvariables,
                                             opt$qvariables,
                                             "InputFile")], file=dataTableFilename,
                quote=FALSE, col.names=TRUE,  row.names=FALSE, eol=" \\\n")
    write.table(in.mgd[  dim(in.mgd)[1],   c("Subj", opt$bsvariables,
                                             opt$wsvariables,
                                             opt$qvariables,
                                             "InputFile")], file=dataTableFilename,
                quote=FALSE, col.names=FALSE, row.names=FALSE, append=TRUE)
    
    return (dataTableFilename)
}


makeTtestPrefix <- function (in.timepoint, in.seed.name) {
    
    return(sprintf('%s.%s.%s.3dttest.bucket.$( date +%%Y%%m%%d-%%H%%M%%Z )', opt$prefix, in.seed.name, in.timepoint))
}


make.ttest.command.script <- function(in.mgd, in.timepoint) {

    three.d.ttest.command.script.filename=ifelse(! is.null(opt$qsvariables),
                                                 file.path(scripts.dir, "ttests", sprintf("07-3dttest.covaried.%s.%s.%s.sh",
                                                                                          opt$task, seedName, in.timepoint)),
                                                 file.path(scripts.dir, "ttests", sprintf("07-3dttest.%s.%s.%s.sh",
                                                                                          opt$task, seedName, in.timepoint)))
    cat("*** Writing the 3dttest++ command to:", three.d.ttest.command.script.filename, "\n")

    setA.group=levels(in.mgd$timepoint)[1]
    setA.files=paste(in.mgd[in.mgd$timepoint==setA.group, "InputFile"], collapse=" \\\n")
    setA.labels.and.files = paste(apply(in.mgd[in.mgd$timepoint==setA.group, c("Subj", "InputFile")], 1, paste, collapse=" "), collapse=" \\\n")
    
    setB.group=levels(in.mgd$timepoint)[2]
    setB.files=paste(in.mgd[in.mgd$timepoint==setB.group, "InputFile"], collapse=" \\\n")
    setB.labels.and.files = paste(apply(in.mgd[in.mgd$timepoint==setB.group, c("Subj", "InputFile")], 1, paste, collapse=" "), collapse=" \\\n")
    
 three.d.ttest.command=sprintf("#!/bin/bash
export OMP_NUM_THREADS=1
%s 

%s 

3dttest++ %s -paired \\
          -prefix %s \\
          -Clustsim			\\
	  -prefix_clustsim cc.%s \\
	  -BminusA \\
          -setA %s %s \\
	  -setB %s %s
",
ifelse(! is.null(opt$qsvariables) && opt$center, "### Variables in the data table are already mean centered\n", "\n"), #1
paste("cd", group.results.dir),                                #2
ifelse(is.null(opt$mask), "", paste("-mask", opt$mask)),       #3
makeTtestPrefix(in.timepoint, seedName), #4 ttest prefix
paste(opt$prefix, seedName, in.timepoint, sep="."), #5 clusttim prefix
setA.group, setA.labels.and.files,
setB.group, setB.labels.and.files
)

    cat(three.d.ttest.command, file=three.d.ttest.command.script.filename)
    Sys.chmod(three.d.ttest.command.script.filename, mode="0774")
}

####################################################################################################
####################################################################################################
####################################################################################################

if ( Sys.info()["sysname"] == "Darwin" ) {
    root.dir="/Volumes/data"
} else if ( Sys.info()["sysname"] == "Linux" ) {
    root.dir="/data"
} else {
    stop(paste("Sorry can't set data directories for this computer\n"))
}

scripts.dir=file.path(root.dir, "sanFrancisco/BrainChange/scripts")
data.dir=file.path(root.dir, "sanFrancisco/BrainChange/data")
admin.data.dir=file.path(data.dir, "admin")
config.data.dir=file.path(data.dir, "config")
processed.data.dir=file.path(data.dir, "processed")

group.data.dir=file.path(data.dir, "Group.data")
group.results.dir=file.path(data.dir, "Group.results")

seeds.data.dir=file.path(data.dir, "seeds")

################################################################################
NO_ARGUMENT="0"
REQUIRED_ARGUMENT="1"
OPTIONAL_ARGUMENT="2"

## process command line arguments
spec = matrix(c(
    'help',          'h', NO_ARGUMENT,       "logical",
    
    "center",        'c', NO_ARGUMENT,       "logical",
    "seeds",         's', REQUIRED_ARGUMENT, "character",
    "g2f",           'g', REQUIRED_ARGUMENT, "character",

    "task",          'k', REQUIRED_ARGUMENT, "character",
    
    "qvariables",    'q', REQUIRED_ARGUMENT, "character",
    "bsvariables",   'b', REQUIRED_ARGUMENT, "character",
    "wsvariables",   'w', REQUIRED_ARGUMENT, "character",

    "prefix",        'p', REQUIRED_ARGUMENT, "character",
    "mask",          'm', REQUIRED_ARGUMENT, "character",
    "model",         'o', REQUIRED_ARGUMENT, "character"
), byrow=TRUE, ncol=4)



################################################################################
if (interactive()) {
    ##
    ## THE FOLLOWING IS FOR TESTING PURPOSES ONLY
    ## 
    ## these arguments that are useful for testing purposes only.
    ##
    ## THE FOLLOWING IS FOR TESTING PURPOSES ONLY
    ##
    
    args=c(
        "-c",
        "-k", "rsfc",
        "-p", "restingstate",                
        
        "-m", "/data/sanFrancisco/BrainChange/data/standard/MNI_caez_N27_brain.3mm+tlrc.HEAD",

        ## the between subject b=variable Group is provided even in
        ## the case of one group only being used in the analysys
        ## because of simplified th/e code in
        ## 10-cluster-followup-lmes.sh insofar as it doesn't need to
        ## figure out whether to used the 3rd or 4th column when
        ## selecting the files that are to be fed to 3dROIstats
        ## "-b", "Group",
        "-w", "timepoint",

        ## "-s", "juelich_whole_amygdala_seeds.txt",
        ## "-s", "short_ACC_seed_list.txt",
        ## "-s", "hippocampus_ventral_striatum_seeds.txt",
        ## "-s", "followup-dlpfc-ins-IP-MPFC-seeds.txt",
        ## "-s", "Fox-Goldapple-seeds.txt",
        ## "-s", "miller-dmn.txt",
        ## "-s", "jacobs-seeds.txt",
        ## "-s", "goldapple-ofc-seeds.txt",
        ## "-s", "gabbay-striatum-seeds.txt",
        ## "-s", "tremblay-seeds.txt",
        ## "-s", "goldapple-dlpfc-seeds.txt"

        ## "-s", "../data/config/dlpfc.seed.list.txt"
        ## "-s", "../data/config/seed.list.txt"
        "-s", "../data/config/gabbay-striatum-seeds.txt"                
        
        ## "-g", "MDD:followup.baseline.3months.mdd.subjectList.txt" # NCL:followup.baseline.3months.ncl.subjectList.txt"#,
        ## "-g", "MDD:followup.baseline.3months.mdd.subjectList.txt NCL:followup.baseline.3months.ncl.subjectList.txt"#,        
        ## "-g", "MDD:followup.baseline.3months.6months.mdd.subjectList.txt"#,
        ## "-g", "MDD:followup.baseline.3months.6months.1year.mdd.subjectList.txt"

        ## "-q", "Full RSQ.fixed MASC.tscore"
        #"-q", "WASI.Full"         
    )
    opt = getopt(spec, opt=args)
} else {
    opt = getopt(spec)
}

################################################################################
printDirectorySummary()
opt=checkCommandLineArguments(opt)
printOptionsSummary(opt)

conditionally.make.dir(group.data.dir)
conditionally.make.dir(group.results.dir)

##demographics.filename=file.path(admin.data.dir, "merged.demographics.and.neuropsych.2016.04.14.csv")
## demographics.filename=file.path(admin.data.dir, "merged.demographics.and.neuropsych.2016.11.07.csv")
## demographics=read.merged.demographics.file(demographics.filename)
## stop()

seeds.filename=opt$seeds

seeds=readSeedsFile(seeds.filename)

subjects.df=(makeSubjectAndTimepointDf())
## now remove subjects at timepoint a since this will we're
## performing a paired t-test so only two timepoitns can be used
cat("*** Filtering to remove subjects at timepoint 'a'\n")
subjects.df=droplevels(subset(subjects.df, timepoint !="a"))

subjects.df=check.for.motion.exclusion.files(subjects.df, 20)
cat("*** Filtering to exclude only subjects with excessive motion\n")
cat("*** Removing data from", sum(subjects.df$excessive.motion),"subjects\n")
subjects.df=subset(subjects.df, excessive.motion==FALSE)

subjects.df.orig=subjects.df
    
for (seed in seeds) {
    seedName=getSeedName(seed)

    cat("####################################################################################################\n")
    cat(sprintf("*** Creating covariate file for the %s seed of the %s grouping\n", seedName, paste(names(opt$groups.to.files.list), collapse=", ") ))

    subjects.df=makeInputFilename(subjects.df.orig, seedName, opt$task)
    ## print(mgd.orig)
    ## stop()
    subjects.df=checkInputFileExists(subjects.df)

    subjects.df=subset(subjects.df, subjects.df$InputFile.exist==TRUE)
    cat("*** Contingency table of group-by-timepoint counts *AFTER* filtering by file existance\n")
    n.table=table(subjects.df[, c("timepoint")])
    n.table=addmargins(n.table)
    print(n.table)

    ## now filter to ensure that only subjects with data at both time
    ## points is included in the analysis
    
    subject.by.timepoint.table=table(subjects.df[, c("Subj", "timepoint")])
    subject.by.timepoint.df=as.data.frame.matrix(subject.by.timepoint.table)
    subject.by.timepoint.df$Subj = rownames(subject.by.timepoint.df)
    rownames(subject.by.timepoint.df)=NULL
    subject.by.timepoint.df$at.both.timepoints=(subject.by.timepoint.df$b + subject.by.timepoint.df$c) == 2
    subject.by.timepoint.df=subject.by.timepoint.df[, c("Subj", "b", "c", "at.both.timepoints")]
    subject.by.timepoint.df=subset(subject.by.timepoint.df, at.both.timepoints == TRUE)
    rownames(subject.by.timepoint.df)=NULL
    cat("*** Filtering to include only subjects with data at both time points\n")
    
    subjects.df=subset(subjects.df, subjects.df$Subj %in% subject.by.timepoint.df$Subj)
    subjects.df = droplevels(subjects.df [ order(subjects.df$Subj, subjects.df$timepoint), ])
    rownames(subjects.df)=NULL
    subject.by.timepoint.table=table(subjects.df[, c("Subj", "timepoint")])
    
    cat("*** Contingency table of subject-by-timepoint counts\n")
    print(addmargins(subject.by.timepoint.table))
    data.table.filename=make.ttest.data.table(subjects.df, seedName)
    make.ttest.command.script(subjects.df, paste(paste(levels(subjects.df$timepoint), collapse=".and."), "timepoints", sep="."))
    ## print(subjects.df)
    ## stop()
}
