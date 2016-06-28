#!/usr/bin/Rscript

rm(list=ls())
graphics.off()

## Reads the seed file and does the (crude) equivalent of BASH variable
## substitution
read.seeds.file <- function (inSeedsFile, in.seeds.data.dir) {
    cat("*** Reading seed from", inSeedsFile, "\n")
    table=scan(inSeedsFile, what=character(), quiet=TRUE)
    table=gsub("$DATA", in.seeds.data.dir, table, fixed=TRUE)

    return (table)
}

## extracts the seed name from a file path name pointing to a NIfTI
## file containing the seed
get.seed.name <- function(inSeedPath){
    name=basename(inSeedPath)
    if (grepl("\\.nii", name)) {
        return(gsub("\\.nii.*", "", name))
    } else if (grepl("\\+tlrc", name)) {
        return(gsub("\\+tlrc.*", "", name))
    } else {
        return (name)
    }
}

check.for.motion.exclusion.files <- function (in.subjects) {

    build.do.not.analyze.filenames <- function(in.subjects, in.threshold=20) {
        filenames=sapply(in.subjects,
            function(ss) {
                sprintf("%s/%s/rsfcPreprocessed/00_DO_NOT_ANALYSE_%s_%dpercent.txt",  processed.data.dir, ss, ss, in.threshold)
            })
        
        return(filenames)
    }
    
    df = build.do.not.analyze.filenames(in.subjects)
    df = data.frame("do.not.analyze.filename"=df, "excessive.motion"=file.exists(df))
    df$ID=rownames(df)
    
    return(df)
}

check.for.anat.files <- function (in.subjects) {

    build.filenames <- function(in.subjects) {
        filenames=sapply(in.subjects,
            function(ss) {
                sprintf("%s/%s/anat/%s.anat+orig.HEAD",  processed.data.dir, ss, ss, ss)
            })
        
        return(filenames)
    }
    
    df = build.filenames(in.subjects)
    df = data.frame("anat.filename"=df, "anat.exists"=file.exists(df))
    df$ID=rownames(df)
    
    return(df)
}

check.for.resting.files <- function (in.subjects) {

    build.filenames <- function(in.subjects) {
        filenames=sapply(in.subjects,
            function(ss) {
                sprintf("%s/%s/resting/%s.resting+orig.HEAD",  processed.data.dir, ss, ss, ss)
            })
        
        return(filenames)
    }
    
    df = build.filenames(in.subjects)
    df = data.frame("resting.filename"=df, "resting.exists"=file.exists(df))
    df$ID=rownames(df)
    
    return(df)
}

check.for.zscore.files <- function (in.subjects, in.seed.name) {

    build.filenames <- function(in.subjects) {
        filenames=sapply(in.subjects,
            function(ss) {
                sprintf("%s/%s/rsfc/%s/%s.z-score+tlrc.HEAD",  processed.data.dir, ss, in.seed.name, in.seed.name)
            })
        
        return(filenames)
    }
    
    df = build.filenames(in.subjects)
    df = data.frame("zscore.filename"=df, "zscore.exists"=file.exists(df))
    df$ID=rownames(df)
    
    return(df)
}

check.for.errts.files <- function (in.subjects) {

    build.do.not.analyze.filenames <- function(in.subjects) {
        filenames=sapply(in.subjects,
            function(ss) {
                sprintf("%s/%s/rsfcPreprocessed/errts.%s.anaticor+tlrc.HEAD",  processed.data.dir, ss, ss)
            })
        
        return(filenames)
    }
    
    df = build.do.not.analyze.filenames(in.subjects)
    df = data.frame("errts.filename"=df, "errts.exists"=file.exists(df))
    df$ID=rownames(df)
    
    return(df)
}

read.brik.files <- function (in.brik.filenames) {

    if (length(in.brik.filenames) == 0 ) {
        stop("*** No HEAD/BRIK filenames provided to read in. Stopping\n")
    }
    
    AFNI_R_DIR=Sys.getenv("AFNI_R_DIR", unset=NA)

    ## use the functions for loading and saving briks from the AFNI
    ## distribution as they can cleanly handle floats/doubles
    if ( ! is.na(AFNI_R_DIR) ) {
        source(file.path(AFNI_R_DIR, "AFNIio.R"))
    } else {
        stop("Couldn't find AFNI_R_DIR in environment. This points to the location from which to load functions for reading and writing AFNI BRIKS. Stopping!")
    }

    ## data=lapply(use$InputFile[1:5], read.AFNI, verb=FALSE, meth='clib', forcedset = TRUE)
    data=lapply(in.brik.filenames, read.AFNI, verb=FALSE, meth='clib', forcedset = TRUE)
    
    all.brik.dims=t(sapply(data, function(dd) { dd$dim }, simplify=TRUE ))
    ## check if any of the bricks have more than 1 value in the 4th dimension
    if ( any(all.brik.dims[, 4] > 1)) {
        cat("*** The following files have more than 1 value in the 4th dimension\n")
        cat("***", in.brik.filenames[which(all.brik.dims[, 4] > 1)], "\n")
        stop("*** Cannot continue\n")
    }
    ## now check that all the values in each column of the dimensions
    ## matrix are the same
    if ( ! all(apply(all.brik.dims, 2, function (dd) { all(abs(dd-mean(dd)) < .Machine$double.eps) })) ) {
        stop("*** The dimensions of all of the subjects files are not the same\n")
    }
    brik.dims=unique(all.brik.dims)
    mrData=unlist(lapply(data, '[[', 1))
    dim(mrData)=c(brik.dims[1, 1:3], dim(all.brik.dims)[1])

    return(mrData)
}

check.formula.terms.in.model.matrix <- function(in.model.formula, in.random.formula, in.model.matrix) {

    term.difference=setdiff(c(all.vars(in.model.formula), all.vars(in.random.formula)), colnames(in.model.matrix))
    if (length(term.difference) > 0) {
        stop(paste("The following terms were in the model forumlae but are not columns of the model matrix:", term.difference))
    }   
}

test.lme.model <- function (in.use) {
    cat("*** Reading zscore files. This will take a while. Be patient.\n")
    mrData=read.brik.files(as.character(in.use$InputFile))
    cat("*** Done\n")
    ## the formulae used for the fixed effects (model.formula) and
    ## random effects (random.formula)
    model.formula = as.formula("fmri ~ Time.Point + age + Gender")
    random.formula=as.formula("random = ~ 1 | Subj/Time.Point")
    
    ## correlation.structure=corAR1(0.3, form=as.formula("~ Subj/Time.Point"))
    ## correlation.structure=corAR1(0.3)
    correlation.structure=corAR1()
    ## set up most of the model data frame (Statistical Parametric
    ## Model)
    model=in.use[ , c("Subj", "Time.Point", "Gender", "age")]
    ## drop the last character from each subjects ID so that the
    ## random intercept is fit per subject rather than per subject per
    ## time point
    model$Subj = gsub("(bc[0-9]{3})[a-z]", "\\1", model$Subj)

    ## now test the model on a voxel at the midpoint of all 3 axes 
    i = dim(mrData)[1] %/% 2
    j = dim(mrData)[2] %/% 2
    k = dim(mrData)[3] %/% 2
    cat("*** Testing LME at voxel (", paste(i, j, k, sep=", "), ")\n", sep="")
    model$fmri = mrData[i, j, k, ]
    if (! require(nlme)) {
        stop("***Couldn't load nlme package. Stopping\n")
    }

    check.formula.terms.in.model.matrix(model.formula, random.formula, model)
    if (inherits(temp.lme <- try(lme(fixed=model.formula, random=random.formula, correlation=correlation.structure, data = model),
                                silent=FALSE),
                 "try-error") ) {
        temp.anova <- 0
        stop("Got an exception trying to setup the temp.lme variable. Cannot continue beyond this point. Stopping.")
    } else {
        print(temp.lme)
        temp.anova <- anova(temp.lme, type="marginal")
        cat("The temporary ANOVA is\n")
        print(temp.anova)
    }
    stop("Check temp.lme summary\n")
}

####################################################################################################
### END OF FUNCTIONS
####################################################################################################

### setup path variables
if ( Sys.info()["sysname"] == "Darwin" ) {
    root.dir="/Volumes/data"
} else if ( Sys.info()["sysname"] == "Linux" ) {
    root.dir="/data"
} else {
    cat(paste("Sorry can't set data directories for this computer\n"))
}

study.root.dir=file.path(root.dir, "sanFrancisco/BrainChange")

scripts.dir=file.path(study.root.dir, "scripts")
data.dir=file.path(study.root.dir, "data")
processed.data.dir=file.path(study.root.dir, "data", "processed")
admin.data.dir=file.path(data.dir, "admin")
config.data.dir=file.path(data.dir, "config")
group.results.dir=file.path(data.dir, "Group.results")

seeds=read.seeds.file(file.path(config.data.dir, "seed.list.txt"), config.data.dir)
number.of.seeds=length(seeds)
## 40 is the (hard coded) max number of cores devoted to the parallel
## queue on kryten
max.number.of.jobs.per.seed=floor(40/number.of.seeds)

## now build the errts filename list
subjects=dir(processed.data.dir, pattern="bc[0-9][0-9][0-9][abcd]")

demographics.filename=file.path(admin.data.dir, "BrainChange.raw.sheet.csv")
demographics=read.csv(demographics.filename, header=TRUE)

## just keep a few columen as we dont need the rest
brain.change.sheet=demographics[, c("ID", "Gender", "Time.Point", "StartDate", "age.in.years")]

cat("*** Checking for motion/outlier exclusion files\n")
motion.exclusion.df=check.for.motion.exclusion.files(subjects)
cat("*** Checking for errts files\n")
errts.files.df=check.for.errts.files(subjects)
cat("*** Checking for T1 anatomy files\n")
anat.files.df=check.for.anat.files(subjects)
cat("*** Checking for EPI resting state files\n")
resting.files.df=check.for.resting.files(subjects)

cat("*** Merging motion/outlier exclusion, errts, T1 anatomy, and EPI resting state data frames\n")
mgd.df=merge(brain.change.sheet, motion.exclusion.df, by.x="ID", by.y="ID", all.x=TRUE, all.y=TRUE)
mgd.df=merge(mgd.df,             errts.files.df,      by.x="ID", by.y="ID", all.x=TRUE, all.y=TRUE)
mgd.df=merge(mgd.df,             anat.files.df,       by.x="ID", by.y="ID", all.x=TRUE, all.y=TRUE)
mgd.df=merge(mgd.df,             resting.files.df,    by.x="ID", by.y="ID", all.x=TRUE, all.y=TRUE)

cat("*** Creating data frame of usable subjects\n")
base.use=subset(mgd.df, ( !is.na(Gender)) & excessive.motion==FALSE & anat.exists==TRUE & resting.exists==TRUE & errts.exists==TRUE) ##),
##        select=grep("filename", colnames(mgd.df), invert=TRUE))

## select only the oclumns we'll need in the data table and order the
## use data frame in the manner required by 3dLME
base.use = base.use[, c("ID", "Time.Point", "Gender", "age.in.years")]

## now rename Time.Point values to include an initial T so that it
## cannot be mistaken for a continuous variable but rather will be
## interpreted as a factor in R, specifically in the 3dLME command
base.use$Time.Point=as.factor(paste("T", base.use$Time.Point, sep=""))

## now rename the columns to suit 3dLME
colnames(base.use) = c("Subj", "Time.Point", "Gender", "age")

cat("*** Scaling age to mean 0\n")
base.use$age = scale(base.use$age, center=TRUE, scale=FALSE)

## dump incomplete cases, i.e., rows with one or more NA in any column
base.use=base.use[complete.cases(base.use), ]

task.list.filename=file.path(scripts.dir, "run", paste("3dlmes-Taskfile", Sys.getpid(), sep="."))
cat("*** Writing list of LME commands to", task.list.filename, "\n")
if (file.exists(task.list.filename)) {
    file.remove(task.list.filename)
}

test.model=FALSE

for (seed in seeds)  {
    
    seed.name=get.seed.name(seed)
    cat("####################################################################################################\n")
    cat(sprintf("*** Creating covariate file for the %s seed\n", seed.name))

    zscore.files.df=check.for.zscore.files(as.character(base.use$Subj), seed.name)
    use = merge(base.use, zscore.files.df, by.x="Subj", by.y="ID")
    
    if (any(use$zscore.exists==FALSE)) {
        cat("*** The following subjects are missing zscore files for this seed\n")
        cat("---", as.character(use[which(use$zscore.exists==FALSE), "Subj"]), "\n")
        cat("*** They will be dropped\n")
        use = use[use$zscore.exists==TRUE, ]
    }
    ## the drop zscore.exists column since we dont need it any more
    use$zscore.exists=NULL
    colnames(use) = c(colnames(use)[-length(colnames(use))], "InputFile")

    if (test.model) {
        cat("*** Testing LME model\n")
        test.lme.model(use)
    }

    ## drop the last character from each subjects ID
    use$Subj = gsub("(bc[0-9]{3})[a-z]", "\\1", use$Subj)
    
    data.table.filename=file.path(group.results.dir, paste("data.table", seed.name, "txt", sep="."))
    cat("*** Writing data table to", data.table.filename, "\n")
    write.table(use, file=data.table.filename, quote=FALSE, col.names=TRUE, row.names=FALSE, eol=" \\\n")

    lme.command.filename = file.path(scripts.dir, paste("3dlme", seed.name, "sh", sep="."))
    cat("*** Writing 3dLME command to", lme.command.filename, "\n")
    lme.cmd=sprintf("#!/bin/bash
GROUP_RESULTS=%s
cd $GROUP_RESULTS
timestamp=$( date +%%Y%%m%%d-%%H%%M%%Z )
3dLME      -prefix $GROUP_RESULTS/restingstate.%s.lme.bucket.$timestamp \\
  -jobs     %d \\
  -mask     %s \\
  -model    'Time.Point+age+Gender' \\
  -ranEff   '~1/Time.Point'             \\
  -qVars    'age'                       \\
  -SS_type  3                           \\
  -num_glt  2                                                         \\
  -gltLabel 1 'T1-T2'    -gltCode  1 'Time.Point :  1*T1 -1*T2'       \\
  -gltLabel 2 'T2-T3'    -gltCode  2 'Time.Point :  1*T2 -1*T3'       \\
  -dataTable @%s
", group.results.dir, seed.name, 10, "MNI_caez_N27_brain.3mm+tlrc.HEAD", data.table.filename)
##", group.results.dir, seed.name, max.number.of.jobs.per.seed, "MNI_caez_N27_brain.3mm+tlrc.HEAD", data.table.filename)    
    cat(lme.cmd, file=lme.command.filename, append=FALSE)
    ##    cat(paste("@", data.table.filename, "\n", sep=""), file=lme.command.filename, append=TRUE)
    cat(lme.command.filename, "\n", file=task.list.filename, append=TRUE)

####################################################################################################

    
}

##  -num_glt  2                                                         \\
##  -gltLabel 1 'T1-T2'    -gltCode  1 'Time.Point :  1*T1 -1*T2'       \\
##  -gltLabel 2 'T2-T3'    -gltCode  2 'Time.Point :  1*T2 -1*T3'       \\
##  -gltLabel 3 'Time.pos' -gltCode  3 'Time.Point : -1*T1 +0*T2 +1*T3' \\
##  -gltLabel 4 'Time.neg' -gltCode  4 'Time.Point :  1*T1 +0*T2 -1*T3' \\
