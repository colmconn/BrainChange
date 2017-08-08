rm(list=ls())
graphics.off()

## car for the some function
library(car)
library(reshape)
library(ggplot2)
library(robustbase)
library(MASS)
library(grid)
library(plyr)
##source('pcor.R')

####################################################################################################
### Start of functions
####################################################################################################

stack <- function(){ 
    it <- list() 
    res <- list( 
        push=function(x){ 
            it[[length(it)+1]] <<- x 
        }, 
        pop=function(){ 
            val <- it[[length(it)]] 
            it <<- it[-length(it)] 
            return(val) 
        }, 
        value=function(){ 
            return(it) 
        } 
    ) 
    class(res) <- "stack" 
    res 
}

print.stack <- function(x,...){ 
    print(x$value()) 
}

push <- function(stack,obj){ 
    stack$push(obj) 
}

pop <- function(stack){ 
    stack$pop() 
}

capwords <- function(s, strict = FALSE) {
    cap <- function(s) paste(toupper(substring(s,1,1)),
    {s <- substring(s,2); if(strict) tolower(s) else s},
    sep = "", collapse = " " )
    sapply(strsplit(s, split = " "), cap, USE.NAMES = !is.null(names(s)))
}

make.significance.indications <- function(pValues, which.pValues=c(1)) {

    Signif=symnum(pValues, corr=FALSE, na=FALSE, cutpoints = c(0,  .001,.01, .05, .1, 1),
                  symbols   =  c("***", "**", "*", ".", " "))
    f=format(Signif)

    ## only return the first one as we're only interested in marking significant group effects
    return(f[which.pValues])
}

substituteShortLabels <- function(inLevel) {
    returnSubstitutedLabel = gsub("[0-9]+ ", "", gsub("Inf", "Inferior", gsub("Sup", "Superior", gsub("Gy", "Gyrus",
                                                                                                      gsub("^R", "Right", gsub("^L", "Left", inLevel, fixed=FALSE), fixed=FALSE), fixed=TRUE), fixed=TRUE), fixed=TRUE))
    
    return (returnSubstitutedLabel)
}

stderror <- function(x) sd(x)/sqrt(length(x))

## http://wiki.stdout.org/rcookbook/Graphs/Plotting%20means%20and%20error%20bars%20(ggplot2)/
## Summarizes data.
## Gives count, mean, standard deviation, standard error of the mean, and confidence interval (default 95%).
##   data: a data frame.
##   measurevar: the name of a column that contains the variable to be summariezed
##   groupvars: a vector containing names of columns that contain grouping variables
##   na.rm: a boolean that indicates whether to ignore NA's
##   conf.interval: the percent range of the confidence interval (default is 95%)
summarySE <- function(data=NULL, measurevar, groupvars=NULL, na.rm=FALSE,
                      conf.interval=.95, .drop=TRUE) {
    require(plyr)

    ## New version of length which can handle NA's: if na.rm==T, don't count them
    length2 <- function (x, na.rm=FALSE) {
        if (na.rm) sum(!is.na(x))
        else       length(x)
    }

    ## This is does the summary; it's not easy to understand...
    datac <- ddply(data, groupvars, .drop=.drop,
                   .fun= function(xx, col, na.rm) {
                       c( N    = length2(xx[,col], na.rm=na.rm),
                         mean = mean   (xx[,col], na.rm=na.rm),
                         sd   = sd     (xx[,col], na.rm=na.rm)
                         )
                   },
                   measurevar,
                   na.rm
                   )

    ## Rename the "mean" column    
    datac <- rename(datac, c("mean"=measurevar))

    datac$se <- datac$sd / sqrt(datac$N)  ## Calculate standard error of the mean

    ## Confidence interval multiplier for standard error
    ## Calculate t-statistic for confidence interval: 
    ## e.g., if conf.interval is .95, use .975 (above/below), and use df=N-1
    ciMult <- qt(conf.interval/2 + .5, datac$N-1)
    datac$ci <- datac$se * ciMult

    return(datac)
}

## makePublicationTable <- function(inClusterWhereAmI, inClusters,
##                                  inRoistats,
##                                  inRoistats.statValue=NULL,
##                                  inRoistats.contrastValue=NULL,
##                                  inStatColumnName="Default Stat Name",
##                                  inContrastColumnName="Default Contrast Name",
##                                  in.dof=NULL,
##                                  in.effect.type=c("d", "g"),
##                                  inCom=TRUE) {
    
##     hemisphere=gsub("[^RL]", "", substr(inClusterWhereAmI, 1, 1))
##     ##print(hemisphere)
##     if ( inCom ) {
##         locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "CM RL", "CM AP", "CM IS")], 0))
##     } else {
##         locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "MI RL", "MI AP", "MI IS")], 0))
##     }
    
##     publication.table.header=c("Structure", colnames(locations)[-1])
    
##     if (! is.null(inRoistats.statValue) ) {
##         ## cat("Adding average t stats\n")
##         pubTable=cbind(locations, round(t(inRoistats.statValue), 2))
##         publication.table.header=c(publication.table.header, inStatColumnName)
        
##         if ( ! is.null(in.dof)) {
##             ## print((inRoistats.statValue * 2) / sqrt(in.dof))
##             ## print("before")
##             ## print(pubTable)
##             ## ##stop()
##             in.effect.type=match.arg(in.effect.type)
            
##             n.subjects=table(inRoistats$Group)
##             ## print(n.subjects)
##             d.values=sapply(inRoistats.statValue, function (xx) { tes(xx, n.subjects[1], n.subjects[2], verbose=FALSE)[[in.effect.type]] } )
            
##             pubTable=cbind(pubTable, round(d.values, 3))
##             ## print("after")
##             ## print(pubTable)

##             publication.table.header=c(publication.table.header,
##                                        switch(in.effect.type,
##                                               "d"="Cohen's d",
##                                               "g"="Hedge's g"))
##         }
##     }

##     ## now add the average of the coefficient, if it is supplied
##     if (! is.null(inRoistats.contrastValue) ) {
##         ## cat("Adding average coefficient values\n")      
##         pubTable=cbind(pubTable, round(t(inRoistats.contrastValue), 2))
##         publication.table.header=c(publication.table.header, inContrastColumnName)
##         ## print(pubTable)      
##     }

##     ## cat("Locations: Volume and coordinates\n")
##     ## print(locations)

##     ## cat ("Columns matching Mean: ", grep("Mean", colnames(inRoistats)), "\n")
##     ## cat ("Data from the above columns:\n")
##     ## print(inRoistats[, grep("Mean", colnames(inRoistats))])
##     ## print(list(inRoistats$Group))
##     ## agg=aggregate(inRoistats[, grep("Mean", colnames(inRoistats))], list(inRoistats$Group), mean)

##     ##ddply.agg=ddply(inRoistats, .(timepoint, Group), summarise, mean)


##     ## now make a summary table with the mean of each timepoint for each
##     ## group. There will be one row for each timepoint x group with the
##     ## means for the ROIs for each timepoint x group occupying the
##     ## remaining columns
##     ddply.agg=ddply(inRoistats, .(timepoint),
##                     .fun=colwise(
##                         .fun=function (xx) {
##                             c(mean=mean(xx))
##                         },
##                         ## which columns to apply the function to are listed below
##                         colnames(inRoistats)[grep("Mean", colnames(inRoistats))]
##                     )
##                     )

    
##     ## cat("ddply.agg:\n")
##     ## print(ddply.agg)
    
##     ## cat("t(ddply.agg):\n")
##     ## print(t(ddply.agg))

##     ## now transpose the means so that there are as many rows as
##     ## columns. This is done so that it can be cbinded with the ROI
##     ## center of mass and volumes later
##     ddply.agg.means=t(ddply.agg[grep("Mean", colnames(ddply.agg))])

##     ##print(which (! grepl("Mean", colnames(ddply.agg))))
##     ##ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))]
##     ## now make the column names for the timepoint x group 
##     cnames=apply(ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))], 1,
##                  function(xx) {
##                      ## xx[1] is group, xx[2] is timepoint
##                      return(sprintf("%s (%s)", xx[1], xx[2]))
##                  })
##     ## cat("cnames:\n")
##     ## print(cnames)
##     publication.table.header=c(publication.table.header, cnames)
    
##     colnames(ddply.agg.means)=cnames
##     ## cat("ddply.agg.means:\n")
##     ## print(ddply.agg.means)

##     mns=round(ddply.agg.means, 2)

##     pubTable=cbind(pubTable, mns)
##     colnames(pubTable)=publication.table.header
##     rownames(pubTable)=NULL

##     ## print(pubTable)
##     ## stop()
    
##     return(pubTable)
## }


makePublicationTable <- function(inClusterWhereAmI,
                                 inClusters,
                                 inRoistats,
                                 inRoistats.averageStatValue=NULL,
                                 inRoistats.averageContrastValue=NULL,
                                 inSummaryColumns=NULL,
                                 inStatColumnName="Default Stat Name",
                                 inContrastColumnName="Default Contrast Name",
                                 inCom=TRUE) {
    hemisphere=gsub("[^RL]", "", substr(inClusterWhereAmI, 1, 1))
    ##print(hemisphere)
    if ( inCom ) {
        locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "CM RL", "CM AP", "CM IS")], 0))
    } else {
        locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "MI RL", "MI AP", "MI IS")], 0))
    }

    ## cat("Locations: Volume and coordinates\n")
    ## print(locations)

    ## cat ("Columns matching Mean: ", grep("Mean", colnames(inRoistats)), "\n")
    ## cat ("Data from the above columns:\n")
    ## print(inRoistats[, grep("Mean", colnames(inRoistats))])
    ## print(list(inRoistats$Group))
    ## agg=aggregate(inRoistats[, grep("Mean", colnames(inRoistats))], list(inRoistats$Group), mean)

    ##ddply.agg=ddply(inRoistats, .(timepoint, Group), summarise, mean)


    ## now make a summary table with the mean of each timepoint for each
    ## group. There will be one row for each timepoint x group with the
    ## means for the ROIs for each timepoint x group occupying the
    ## remaining columns
    ddply.agg=ddply(inRoistats, inSummaryColumns,
                    .fun=colwise(
                        .fun=function (xx) {
                            c(mean=mean(xx))
                        },
                        ## which columns to apply the function to are listed below
                        colnames(inRoistats)[grep("Mean", colnames(inRoistats))]
                    )
                    )

    
    ## cat("ddply.agg:\n")
    ## print(ddply.agg)
    
    ## cat("t(ddply.agg):\n")
    ## print(t(ddply.agg))

    ## now transpose the means so that there are as many rows as
    ## columns. This is done so that it can be cbinded with the ROI
    ## center of mass and volumes later
    ddply.agg.means=t(ddply.agg[grep("Mean", colnames(ddply.agg))])

    ## print ("*** Column numbers that are not Mean")
    ## print(which (! grepl("Mean", colnames(ddply.agg))))
    ## print ("*** Column names that are not Mean")  
    ## print(ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))])
    ## print("*** cnames computation")
    
    ## now make the column names
    ##
    ## the first branch handles more than two summary variables, e.g.,
    ## Group X timepoint or Group X Gender
    ##
    ## the econd branch handles only single variables as with a main
    ## effect, e.g., Group, or Gender
    if (length(which (! grepl("Mean", colnames(ddply.agg)))) > 1)
        cnames=apply(ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))], 1,
                     function(xx) {
                         ## xx[1] is group, xx[2] is timepoint
                         return(sprintf("%s (%s)", xx[1], xx[2]))
                     })
    else {
        cnames=as.character(ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))])
    }
    ## cat("cnames:\n")
    ## print(cnames)

    colnames(ddply.agg.means)=cnames
    ## cat("ddply.agg.means:\n")
    ## print(ddply.agg.means)

    mns=round(ddply.agg.means, 2)
    
    ##cat("agg: mean for each group in each ROI\n")  
    ##print(agg)
    ##mns=round(t(agg[, -1]), 2)
    ##cat("mns: transposed mean for each group in each ROI\n")    
    ##colnames(mns)=levels(agg[,1])
    ##print(mns)
    
    ## cat("inRoistats.averageStatValue\n")
    ## print (inRoistats.averageStatValue)
    if (! is.null(inRoistats.averageStatValue) ) {
        ## cat("Adding average t stats\n")
        pubTable=cbind(locations, round(t(inRoistats.averageStatValue), 2))
        ## print(pubTable)
    } else {
        pubTable=cbind(locations, mns)
    }

    if (! is.null(inRoistats.averageStatValue) & ! is.null(inRoistats.averageContrastValue) ) {
        ## cat("Adding average coefficient values\n")      
        pubTable=cbind(pubTable, round(t(inRoistats.averageContrastValue), 2))
        ## print(pubTable)      
    }

    pubTable=cbind(pubTable, mns)
    if (! is.null(inRoistats.averageStatValue) ) {
        colnames(pubTable)=
            c("Structure", "Hemisphere", "Volume", "CM RL", "CM AP", "CM IS", inStatColumnName, colnames(mns))
    } else {
        colnames(pubTable)=c("Structure", colnames(pubTable)[-1])
    }

    if (! is.null(inRoistats.averageStatValue) & ! is.null(inRoistats.averageContrastValue) ) {
        colnames(pubTable)=
            c("Structure", "Hemisphere", "Volume", "CM RL", "CM AP", "CM IS", inStatColumnName, inContrastColumnName, colnames(mns))
    }
    
    rownames(pubTable)=NULL
    ## print(pubTable)
    return(pubTable)
}


savePublicationTable <- function (inPublicationTable, inPublicationTableFilename, append=TRUE) {
    cat("*** Writing publication table to", inPublicationTableFilename, "\n")
    if ( append ) {
        write.table(inPublicationTable, file=inPublicationTableFilename, quote=F, col.names=TRUE, row.names=FALSE, sep=",", append=TRUE)
    } else {
        write.table(inPublicationTable, file=inPublicationTableFilename, quote=F, col.names=FALSE, row.names=FALSE, sep=",", append=TRUE)
    }
    cat("\n", file=inPublicationTableFilename, append=TRUE)        
}

readTstatDegreesOfFreedom <- function(inFilename) {
    cat("*** Reading", inFilename, "\n")
    dof=scan(inFilename, what=integer(), quiet=TRUE)

    return(dof)
}

readStatsTable <- function (inFilename) {

    cat("*** Reading" , inFilename, "\n")
    statsTable=read.table(inFilename, header=T, sep="")
    ## dump the first column as it's only the file name
    statsTable=statsTable[, -1]
    return(statsTable)
}

readDataTable <- function (inFilename) {
    cat("*** Reading", inFilename, "\n")
    dataTable=read.table(inFilename, header=T, allowEscapes=TRUE)

    return(dataTable)
}

readClustersTable <- function (inFilename){
    cat("*** Reading", file.path(inFilename), "\n")
    clusters=read.table(file.path(inFilename))
    colnames(clusters) = clust.header
    return (clusters)
}

readClusterLocationsTable <- function (inFilename) {
    cat("*** Reading cluster locations from", inFilename, "\n")
    ## the gsub here chews up multiple consequtive spaces and replaces them with a single space
    clusterWhereAmI=gsub(" +", " ", scan(file=inFilename, what='character', sep=','))

    return (clusterWhereAmI)
}

readSubjectOrderTable <- function (inFilename) {
    cat("*** Reading", inFilename, "\n")
    subjectOrder=read.csv(inFilename, header=T)

    return(subjectOrder)
}

fixSubjectOrderTable <- function (inSubjectOrderTable) {
    inSubjectOrderTable$subject=gsub("300", "169/300", as.character(inSubjectOrderTable$subject), fixed=TRUE)
    inSubjectOrderTable$subject=as.factor(inSubjectOrderTable$subject)

    return(inSubjectOrderTable)
}

splitSubjectOrderIntoIdAndTimepoint <- function(inSubjectOrderTable) {

    new.subject.order.table=cbind(inSubjectOrderTable, as.data.frame(t(as.data.frame(strsplit(as.character(inSubjectOrderTable$subject), "_", fixed=TRUE)))))
    rownames(new.subject.order.table)=NULL
    colnames(new.subject.order.table)=c("id", "subject", "timepoint")

    return(new.subject.order.table)
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

readCsvFile <- function (inFilename, inSubjectColumnName="ID") {

    cat("*** Reading", inFilename, "\n")
    rCsv=read.csv(inFilename, header=T, na.strings = c("NA", "<NA>", "#N/A", "#VALUE", "#VALUE!", "n/a", "N/A", "#DIV/0!", "IGNORE THIS SUBJECT", ".", ""))
    cat(sprintf("*** Read data for %s unique subjects\n",  length(unique(rCsv[, inSubjectColumnName]))))

    return(rCsv)
}

generateGraphs <- function () {

    for (seed in seeds) {
        seedName=getSeedName(seed)

        publicationTableFilename=file.path(group.results.dir, paste("publicationTable", seedName, "csv", sep="."))
        if (file.exists(publicationTableFilename)) {
            file.remove(publicationTableFilename)
        }

        cat("####################################################################################################\n")
        cat(sprintf("*** Graphing ROIs from the %s seed for the %s groups\n", seedName, groups))

        ## infix=sprintf("fwhm%s.%s.%s", usedFwhm, groups, seedName)
        infix=seedName
        
        roistats.filename=file.path(group.results.dir, sprintf("roiStats.%s.txt", infix))            
        roistats.averageZscore.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageZscore.txt", infix))
        roistats.averageContrastValue.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageContrastValue.txt", infix))
        
        if(file.exists(roistats.filename)) {
            
            ## roistats contains the avergae from the contrast in each ROI,
            ## you do not what to graph this
            
            roistats=readStatsTable(roistats.filename)
            roistats$Sub.brick=NULL

            roistats.averageZscore=readStatsTable(roistats.averageZscore.filename)
            roistats.averageContrastValue=readStatsTable(roistats.averageContrastValue.filename)
            roistats.averageZscore$Sub.brick=NULL
            roistats.averageContrastValue$Sub.brick=NULL

            degreesOfFreedom.filename=file.path(group.results.dir, sprintf("text.%s.degreesOfFreedom.txt", infix))
            if ( file.exists(degreesOfFreedom.filename) ) {
                degrees.of.freedom=readTstatDegreesOfFreedom(degreesOfFreedom.filename)
            } else {
                cat ("*** No such file", degreesOfFreedom.filename, "\n")
                degrees.of.freedom=NULL
            }
            cat("*** Degrees of freedom set to:", degrees.of.freedom, "\n")

            clusterCount=length(grep("Mean", colnames(roistats)))
            if (clusterCount > 0 ) {
                cat(sprintf("*** %d ** clusters found in %s\n", clusterCount, roistats.filename))
                
### Most of the following code up the the first long row of # is book-keeping to get the data frame in order
                
                clustersFilename=file.path(group.results.dir, sprintf("clust.%s.txt", infix))
                clusters=readClustersTable(clustersFilename)
                
                ## this table contains the locations, as text, of the clusters and is the output of a perl script
                clusterLocationsFilename=file.path(group.results.dir, sprintf("clusterLocations.%s.csv", infix))
                clusterWhereAmI=readClusterLocationsTable(clusterLocationsFilename)
                
                ## this file stores the order of the subjects in each of the following BRIK files
                dataTableFilename=file.path(group.data.dir, paste("dataTable.ttest.rsfc", seedName, "b.and.c.timepoints", "txt", sep="."))
                dataTable=readDataTable(dataTableFilename)
                ## print(dataTable)

                mgd=cbind(dataTable, roistats)#, demographics[match(subjectOrder$subject, demographics$ID), c("Group", "Gender")])
                ## print(mgd)

                ## rownames(mgd)=NULL
                ## ## ensure that subject is s factor
                ## mgd$subject=as.factor(mgd$subject)
                ## mgd=droplevels(mgd)
                
                ## print(clusterWhereAmI)
                ## print(clusters)
                ## print(roistats)
                ## print(roistats.averageZscore)
                ## print(roistats.averageContrastValue)
                
                ## print(mgd)
                ## cat("*** Some of the mgd data frame\n")
                ## print(some(mgd))

                ## stop("Check the mgd data frame\n")

                publicationTable=makePublicationTable(clusterWhereAmI,
                                                      clusters,
                                                      mgd,
                                                      roistats.averageZscore,
                                                      roistats.averageContrastValue,
                                                      c("timepoint"),
                                                      inStatColumnName="Average Z score",
                                                      inContrastColumnName="Average Contrast Value",
                                                      inCom=TRUE)
                print(publicationTable)
                ## stop("Check the publication data frame\n")
                savePublicationTable(publicationTable, publicationTableFilename, TRUE)
                
                melted.mgd=melt(mgd,  id.vars=c("Subj", "timepoint"),
                                measure.vars=paste("Mean_", seq(1, clusterCount), sep=""),
                                variable_name="cluster")
                
                melted.mgd$cluster=factor(melted.mgd$cluster,
                                          levels=c(paste("Mean_", seq(1, clusterCount), sep="")),
                                          labels=paste(sprintf("%02d", seq(1, clusterCount)), clusterWhereAmI))
                
                ## print (head((melted.mgd)))
                ## stop("Check the melted mgd data frame\n")
                
                graphTStats(melted.mgd, seedName)
                ## stop("Do the graphs look ok?\n")
                
            } ## end of if (clusterCount > 0 ) {
        }##  else {
        ##     cat("No Clusters,\n\n", file=publicationTableFilename, append=TRUE)
        ## }
    } ## end of for (seed in seeds) {
    
} ## end of generateGraphs definition


graphTStats <-function(inMeltedRoistats, inSeed) {

    imageDirectory=file.path(group.results.dir, inSeed)
    
    if ( ! file.exists(imageDirectory) ) {
        dir.create(imageDirectory)
    }

    for ( level in levels(inMeltedRoistats$cluster) ) {

        ss=subset(inMeltedRoistats, cluster==level)

        levels(ss$timepoint)=c("Baseline", "Follow-up")

        imageFilename=file.path(imageDirectory, sprintf("%s.pdf", gsub(" +", ".", level)))
        cat(paste("*** Creating", imageFilename, "\n"))
        
        roistats.summary=summarySE(ss, measurevar="value", groupvars=c("timepoint", "cluster"))
        print(roistats.summary)
        x.axis="timepoint"
        y.axis="value"
        xlabel="Timepoint"
        group=1
        my.dodge=position_dodge(.2)

        ## this works for time point or group
        graph=ggplot(data=roistats.summary, aes_string(x=x.axis, y=y.axis)) +
            geom_point(position=my.dodge) +
            ## geom_bar(stat="identity") +
            geom_jitter(data=ss, width=0.2) +
            ## geom_errorbar(aes(ymin=value-se, ymax=value+se), width=0.5, size=1, color="black", position=my.dodge) +
            geom_errorbar(aes(ymin=value-se, ymax=value+se), width=0.5, color="black", position=my.dodge) +            
            labs(title = substituteShortLabels(level), x=xlabel, y="RSFC (Z-score)") +
            my.theme 
        ## print(graph)
        ## stop()
        ggsave(imageFilename, graph, width=4, height=3.5, units="in")
        ## ggsave(imageFilename, graph, width=1.15, height=1, units="in")
        ## stop()
        ## ggsave(imageFilename, graph, units="in")        
    } ## end of for ( level in levels(roistats.summary$cluster) )
}

####################################################################################################
### End of functions
####################################################################################################


if ( Sys.info()["sysname"] == "Darwin" ) {
    root.dir="/Volumes/data"
} else if ( Sys.info()["sysname"] == "Linux" ) {
    root.dir="/data"
} else {
    cat(paste("Sorry can't set data directories for this computer\n"))
}

data.dir=file.path(root.dir, "sanFrancisco/BrainChange/data/")
admin.data.dir=file.path(data.dir, "admin")
config.data.dir=file.path(data.dir, "config")
seeds.data.dir=file.path(data.dir, "seeds")

group.data.dir=file.path(data.dir, "Group.data")
group.results.dir=file.path(data.dir, "Group.results")

clust.header = c("Volume", "CM RL", "CM AP", "CM IS", "minRL",
                 "maxRL", "minAP", "maxAP", "minIS", "maxIS", "Mean", "SEM", "Max Int",
                 "MI RL", "MI AP", "MI IS")

groups="mddOnly"
task="restingstate"

seeds=readSeedsFile(file.path(config.data.dir, "gabbay-striatum-seeds.txt"))
seeds=readSeedsFile(file.path(config.data.dir, "seed.list.txt"))
## seedFiles=
##     ## sapply(c(
##     ##     "juelich_whole_amygdala_seeds.txt",
##     ##     "short_ACC_seed_list.txt",
##     ##     "hippocampus_ventral_striatum_seeds.txt",
##     ##     "followup-dlpfc-ins-IP-MPFC-seeds.txt",
##     ##     "Fox-Goldapple-seeds.txt",
##     ##     "miller-dmn.txt",
##     ##     "jacobs-seeds.txt",
##     ##     "goldapple-ofc-seeds.txt",
##     ##     "gabbay-striatum-seeds.txt",
##     ##     "tremblay-seeds.txt"
##     sapply(c(
##         "juelich_whole_amygdala_seeds.txt",
##         "Fox-Goldapple-seeds.txt",
##         "jacobs-seeds.txt",
##         "gabbay-striatum-seeds.txt"
##     ),
##     function(xx) {
##         file.path(config.data.dir, xx)
##     })
## seeds=unlist(sapply(seedFiles, readSeedsFile))

numberOfSeeds=length(seeds)
cat(sprintf("*** Found %02d seeds in the seed file\n", length(seeds)))

my.base.size=12
my.theme=
    theme_bw(base_size =  my.base.size) +
    theme(
        legend.position="none",
        ## legend.position="bottom",        
        ## panel.grid.major = element_blank(),
        ## panel.grid.minor = element_blank(),

        ##remove the panel border
        ## panel.border = element_blank(),

        ## add back the axis lines
        axis.line=element_line(colour = "grey50"),
        
        axis.title.x=element_blank(),
        ## axis.title.x = element_text(size=my.base.size, vjust=0),
        axis.title.y = element_text(size=my.base.size, vjust=0.4, angle =  90),
        plot.title=element_text(size=my.base.size, vjust=1))

## date.tag=format(Sys.time(), "%Y%m%d.%H%M%Z")
## output.file=file.path(group.results.dir, paste("ttest-graphing-results", date.tag, "txt", sep="."))
## cat("*** See", output.file, "for statistics\n")
## sink(output.file, append=FALSE)

generateGraphs()

sink()
