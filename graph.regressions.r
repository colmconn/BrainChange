rm(list=ls())
graphics.off()

##library(gdata)
library(reshape)
library(ggplot2)
library(robustbase)
library(MASS)
library(grid)
library(plyr)
library(scales)

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

makePublicationTable <- function(inClusterWhereAmI, inClusters, inRoistats,
                                 inRoistats.averageStatValue=NULL, inRoistats.averageCoefficientValue=NULL, inRoistats.averageBiasValue=NULL,
                                 inStatColumnName="Default Stat Name",
                                 inCoefficientColumnName="Default Coefficient Name",
                                 inBiasColumnName="Default Bias Name",
                                 in.dof=NULL,
                                 inCom=TRUE) {

    hemisphere=gsub("[^RL]", "", substr(inClusterWhereAmI, 1, 1))
    ## print(hemisphere)
    if ( inCom ) {
        locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "CM RL", "CM AP", "CM IS")], 0))
    } else {
        locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "MI RL", "MI AP", "MI IS")], 0))
    }

    publication.table.header=c("Structure", colnames(locations)[-1])

    ## now add the average T stat values to the publication table and,
    ## if degrees of freedom are supplied, add a Cohen's d column for
    ## a one tampple t-test
    
    if (! is.null(inRoistats.averageStatValue) ) {
        ## cat("Adding average t stats\n")
        pubTable=cbind(locations, round(t(inRoistats.averageStatValue), 2))
        publication.table.header=c(publication.table.header, inStatColumnName)
        
        if ( ! is.null(in.dof)) {
            ## print((inRoistats.averageStatValue * 2) / sqrt(in.dof))
            ## print("before")
            ## print(pubTable)
            ## ##stop()
            pubTable=cbind(pubTable, round(t((inRoistats.averageStatValue * 2) / sqrt(in.dof)), 3))
            ## print("after")
            ## print(pubTable)

            publication.table.header=c(publication.table.header, "Cohen's d")
        }
    }

    ## now add the average of the coefficient, if it is supplied
    if (! is.null(inRoistats.averageCoefficientValue) ) {
        ## cat("Adding average coefficient values\n")      
        pubTable=cbind(pubTable, round(t(inRoistats.averageCoefficientValue), 2))
        publication.table.header=c(publication.table.header, inCoefficientColumnName)
        ## print(pubTable)      
    }

    ## now add the average of the contrast, if it is supplied
    if (! is.null(inRoistats.averageBiasValue) ) {
        ## cat("Adding average coefficient values\n")      
        pubTable=cbind(pubTable, round(t(inRoistats.averageBiasValue), 2))
        publication.table.header=c(publication.table.header, inBiasColumnName)
        ## print(pubTable)      
    }
    
    ## cat("Locations: Volume and coordinates\n")
    ## print(locations)

    if (length(grep("Mean", colnames(inRoistats))) == 0 ) {
        stop("*** Cat there are no columns in the inRoistats data frame that begin with Mean_\n")
    }
    
    ## cat ("Columns matching Mean: ", grep("Mean", colnames(inRoistats)), "\n")
    ## cat ("Data from the above columns:\n")
    ## print(inRoistats[, grep("Mean", colnames(inRoistats))])
    ## print(list(inRoistats$Group))
    agg=aggregate(inRoistats[, grep("Mean", colnames(inRoistats))], list(inRoistats$Group), mean)
    ## cat("agg: mean for each group in each ROI\n")  
    ## print(agg)
    mns=round(t(agg[, -1]), 2)
    ## cat("mns: transposed mean for each group in each ROI\n")    
    ## colnames(mns)=levels(agg[,1])
    ## publication.table.header=c(publication.table.header, levels(agg[,1]))
    cat(" ** WARNING: Adding hard coded group label", toupper(groups), "to the publication table header\n")
    publication.table.header=c(publication.table.header, toupper(groups))
    
    ## print(mns)

    agg=aggregate(inRoistats[, grep("Mean", colnames(inRoistats))], list(inRoistats$Group), sd)
    ## cat("agg: mean for each group in each ROI\n")  
    ## print(agg)
    sds=round(t(agg[, -1]), 2)
    ## cat("mns: transposed mean for each group in each ROI\n")    
    ## colnames(mns)=levels(agg[,1])
    publication.table.header=c(publication.table.header, "SD")

    
    pubTable=cbind(pubTable, mns, sds)
    colnames(pubTable)=publication.table.header
    rownames(pubTable)=NULL
    ## print(pubTable)
    ## stop()
    
    return(pubTable)
}


savePublicationTable <- function (inPublicationTable, inPublicationTableFilename, append=TRUE) {
    cat("*** Writing publication table to", inPublicationTableFilename, "\n")
    if ( append ) {
        write.table(inPublicationTable, file=inPublicationTableFilename, quote=F, col.names=TRUE, row.names=FALSE, sep=",", append=TRUE)
    } else {
        write.table(inPublicationTable, file=inPublicationTableFilename, quote=F, col.names=FALSE, row.names=FALSE, sep=",", append=FALSE)
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

readClustersTable <- function (inFilename){
    cat("*** Reading", file.path(inFilename), "\n")
    clusters=read.table(file.path(inFilename))
    colnames(clusters) = clust.header
    return (clusters)
}

readClusterLocationsTable <- function (inFilename) {
    cat("*** Reading cluster locations from", inFilename, "\n")
    ## the gsub here chews up multiple consequtive spaces and replaces them with a single space
    clusterWhereAmI=gsub(" +", " ", scan(file=inFilename, what='character', sep=',', quiet=TRUE))

    return (clusterWhereAmI)
}

readDataTable <- function (inFilename) {
    cat("*** Reading", inFilename, "\n")
    dataTable=read.table(inFilename, header=T, allowEscapes=TRUE)

    return(dataTable)
}

## Reads the seed file and does the (crude) equivalent of BAS variable
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


replaceNa <- function (inData, inColumns, inSubjectColumnName="ID", inGroupColumnName="Grp", inReplaceNaWith=NULL) {

    n=length(inColumns)
    if ( ! is.null (inReplaceNaWith) && length(inReplaceNaWith) != n) {
        stop("*** ERROR: Length of inReplaceNaWith does not match that of inColumns. Cannot continue. Stopping.\n")
    }
    for (ii in seq.int(1, n)) {
        column=inColumns[ii]
        if (any(is.na(inData[, column]))) {
            cat ("****************************************************************************************************\n")
            cat (sprintf("*** The following subjects have NA data for %s\n", column))

            cat (paste (as.vector ( inData[is.na(inData[, column]), inSubjectColumnName]), collapse=" "), "\n")
            cat (paste (as.vector ( inData[is.na(inData[, column]), inGroupColumnName]), collapse=" "), "\n")            
            
            ##cat(paste(as.vector(is.na(inData[inData[, column]) & ! is.na(inData[, column]), inSubjectColumnName]), collapse=" "), "\n")
            ##cat(paste(as.vector(is.na(inData[inData[, column]) & ! is.na(inData[, column]), inGroupColumnName]), collapse=" "), "\n")
            ##cat(paste(as.vector(is.na(inData[inData[, column]) & ! is.na(inData[, column]), column]), collapse=" "), "\n")
            if (! is.null(inReplaceNaWith)) {

                replacement.value=inReplaceNaWith[ii]
                if ( ! replacement.value %in% levels(inData[, column]) ) {
                    cat("*** Warning: The replacement value", replacement.value, "is not among the levels of the", column, "column.\n")
                    cat("*** Warning: Converting", column, "to character and back to a factor to accommodate this.\n")
                    inData[, column] = as.character(inData[, column])
                }

                cat ("*** Now setting these values to NA\n")
                inData[ which(is.na(inData[, column])), column]=replacement.value

                if ( ! replacement.value %in% levels(inData[, column]) ) {
                    inData[, column] = as.factor(inData[, column])
                }
            }
            cat ("****************************************************************************************************\n")      
        }
    } ## end of for (column in inColumns) {
    
    return(inData)
} ## end of checkIsNa


generateGraphs <- function (group.data.dir, group.results.dir, rvVariable, rvName, publicationTableFilename, seed.list, bootstrapped=FALSE) {

    for (seed in seed.list) {
        seedName=getSeedName(seed)

        cat(sprintf("Seed=%s,Variable=%s (%s),\n", seedName, gsub("\n", " ", rvName), rvVariable), file=publicationTableFilename, append=TRUE)
        
        cat("####################################################################################################\n")
        cat(sprintf("*** Graphing ROIs for the %s seed that was regressed against %s (%s)\n", seedName, rvName, rvVariable))

        infix=paste("followup.analysis", seedName, rvVariable, sep=".")
        
        roistats.filename=file.path(group.results.dir, sprintf("roiStats.%s.txt", infix))
        roistats.averageTvalue.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageTValue.txt", infix))
        roistats.averageCoefficientValue.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageCoefficientValue.txt", infix))
        if (bootstrapped) {
            roistats.averageBiasValue.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageBiasValue.txt", infix))
        }
            
        if(file.exists(roistats.filename)) {
            
            ## roistats contains the avergae from the contrast in each ROI,
            ## you do not what to graph this
            
            roistats=readStatsTable(roistats.filename)
            roistats.averageTvalue=readStatsTable(roistats.averageTvalue.filename)
            roistats.averageCoefficientValue=readStatsTable(roistats.averageCoefficientValue.filename)

            degreesOfFreedom.filename=file.path(group.results.dir, sprintf("text.%s.degreesOfFreedom.txt", infix))
            cat("*** Reading", degreesOfFreedom.filename, "\n")
            
            if (bootstrapped)
                roistats.averageBiasValue=readStatsTable(roistats.averageBiasValue.filename)
            
            roistats$Sub.brick=NULL
            roistats.averageTvalue$Sub.brick=NULL
            roistats.averageCoefficientValue$Sub.brick=NULL
            if (bootstrapped)
                roistats.averageBiasValue$Sub.brick=NULL

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

                dataTableFilename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
                dataTable=readDataTable(dataTableFilename)

                if ( ! grepl("Group", colnames(roistats)) ) {
                    cat("*** WARNING: Didn't find a group column in the roistats file. Adding one based on the (capitalized) groups variable\n")
                    roistats$Group=rep(toupper(groups), dim(roistats)[1])
                }
                
                ## print(dataTable)
                ## print(roistats)

                ## print(dim(dataTable))
                ## print(dim(roistats))
                      
                mgd=cbind(dataTable, roistats)
                
                if (dim(mgd)[1] != dim(dataTable)[1] ) {
                    cat("*** The number of subjects in the merged data frame is not the same as the number of subjects in the subjectOrder file.\n")
                    cat("*** Cannot continue\n")
                    stop(status=1)
                }

                ## cat("*** clusterWhereAmI:\n")
                ## print(clusterWhereAmI)
                ## cat("*** clusters:\n")
                ## print(clusters)
                ## cat("*** mgd:\n")                
                ## print(mgd)
                
                ## cat("*** roistats.averageTvalue:\n")                
                ## print(roistats.averageTvalue)
                ## cat("*** roistats.averageCoefficientValue:\n")                
                ## print(roistats.averageCoefficientValue)

                ## print(head(mgd))
                ## stop("Check the mgd data frame\n")
                if (bootstrapped) {
                    publicationTable=makePublicationTable(clusterWhereAmI, clusters, mgd,
                                                          inRoistats.averageStatValue=roistats.averageTvalue,
                                                          inRoistats.averageCoefficientValue=roistats.averageCoefficientValue,
                                                          inRoistats.averageBiasValue=roistats.averageBiasValue,
                                                          inStatColumnName="Average t value",
                                                          inCoefficientColumnName="Average Coefficient Value",
                                                          inBiasColumnName="Average Bias Value",
                                                          in.dof=degrees.of.freedom,
                                                          inCom=TRUE)
                } else {
                    publicationTable=makePublicationTable(clusterWhereAmI, clusters, mgd,
                                                          inRoistats.averageStatValue=roistats.averageTvalue, inRoistats.averageCoefficientValue=roistats.averageCoefficientValue,
                                                          inStatColumnName="Average t value", inCoefficientColumnName="Average Coefficient Value",
                                                          in.dof=degrees.of.freedom,
                                                          inCom=TRUE)
                }

                regression.variable.summary=round(t(c(mean(mgd[, rvVariable]), sd(mgd[, rvVariable]))), 2)
                publicationTable=cbind(publicationTable, regression.variable.summary)
                colnames(publicationTable)=c(colnames(publicationTable)[-(seq(dim(publicationTable)[2]-1, dim(publicationTable)[2]))], paste(rvName, c("Mean", "SD")))
                cat("*** Publication table\n")
                print(publicationTable)
                
                savePublicationTable(publicationTable, publicationTableFilename, TRUE)
                
                ## stop("Check the publication data frame\n")
                melted.mgd=melt(mgd,  id.vars=c("Subj", "Group", rvVariable),                        
                                measure.vars=paste("Mean_", seq(1, clusterCount), sep=""),
                                variable_name="cluster")
                graph.variable=rvVariable
                
                melted.mgd$cluster=factor(melted.mgd$cluster,
                    levels=c(paste("Mean_", seq(1, clusterCount), sep="")),
                    labels=paste(sprintf("%02d", seq(1, clusterCount)), clusterWhereAmI))

                ## print (melted.mgd)
                ## print(mgd)
                ## stop("Check the melted mgd data frame\n")
                
                graphRegressions(melted.mgd, group.results.dir, graph.variable, rvName, seedName)
                
            } ## end of if (clusterCount > 0 ) {
        } else {
            cat ("*** No such file", roistats.filename, "\n")
            cat("No Clusters,\n\n", file=publicationTableFilename, append=TRUE)
        } ## end of if(file.exists(roistats.filename)) {

    } ## end of for (seed in seeds) {

} ## end of generateGraphs definition


graphRegressions <- function(melted.mgd, group.results.dir, rvVariable, rvName, seedName, in.run.correlations=FALSE) {

    ## print(head(melted.mgd))
    imageDirectory=file.path(group.results.dir, rvVariable)
    if ( ! file.exists(imageDirectory) ) {
        dir.create(imageDirectory)
    }

    for ( level in levels(melted.mgd$cluster) ) {

        ss=droplevels(subset(melted.mgd, cluster==level))
        ## print(ss)
        ## stop()
        
        imageFilename=file.path(imageDirectory, sprintf("%s.%s.pdf", gsub(" +", ".", level), rvVariable))
        cat(paste("*** Creating", imageFilename, "\n"))

        roistats.summary=summarySE(ss, measurevar="value", groupvars=c("cluster"))
        
        y.axis="value"
        x.axis=rvVariable
        y.axis.label="RSFC (Z-score)"
        x.axis.label=rvName
        
        graph = ggplot(ss, aes_string(x=x.axis, y=y.axis))
        graph = graph + stat_smooth(method="rlm", se=FALSE, color="black")
        graph = graph + labs(title = substituteShortLabels(level), x=x.axis.label, y=y.axis.label)
        graph = graph + my_theme
        graph = graph + geom_point()
        
        if (in.run.correlations) {
            change.pearson.cor=cor.test(ss[, x.axis], ss[, y.axis])
            print(change.pearson.cor)
            cat(sprintf("R=%0.3f, t(%d)=%0.3f, p=%0.5f, 95%% CI=(%0.3f, %0.3f)\n",
                        change.pearson.cor$estimate,
                        change.pearson.cor$parameter,
                        change.pearson.cor$statistic,
                        change.pearson.cor$p.value,                        
                        change.pearson.cor$conf.int[1], change.pearson.cor$conf.int[2]))
        }

        ## print(graph)
        ## stop("Check graph\n")        
        ggsave(imageFilename, graph, width=4, height=3, units="in")
        ## ggsave(imageFilename, graph)
    } ## end of for ( level in levels(roistats.summary$cluster) )
} ## end of graphRegressions




####################################################################################################
### End of functions
####################################################################################################

clust.header = c("Volume", "CM RL", "CM AP", "CM IS", "minRL",
    "maxRL", "minAP", "maxAP", "minIS", "maxIS", "Mean", "SEM", "Max Int",
    "MI RL", "MI AP", "MI IS")

task="restingstate"

if ( Sys.info()["sysname"] == "Darwin" ) {
    root.dir="/Volumes/data"
} else if ( Sys.info()["sysname"] == "Linux" ) {
    root.dir="/data"
} else {
    cat(paste("Sorry can't set data directories for this computer\n"))
}


data.dir=file.path(root.dir, "sanFrancisco/BrainChange/data/")
processed.data.dir=file.path(data.dir, "processed")
admin.data.dir=file.path(data.dir, "admin")
config.data.dir=file.path(data.dir, "config")
seeds.data.dir=file.path(data.dir, "seeds")

regressionVariables=list(
    list(variable="RADS",         name="Change in RADS Total T score"),
    list(variable="conflict",     name="Change in conflict measurement"),
    list(variable="SDQ",          name="Change in SDQ")
)

groups="healthy"

my.base.size=14
my_theme=
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
        
        ##axis.title.x=element_blank(),
        axis.title.x = element_text(size=my.base.size, vjust=0),
        axis.title.y = element_text(size=my.base.size, vjust=0.4, angle =  90),
        plot.title=element_text(size=my.base.size*1.2, vjust=1))

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

regressionCount=1
for ( regressionVariableCount in 1:length(regressionVariables ) ) {
    
    rvVariable=regressionVariables[[regressionVariableCount]]$variable
    rvName=regressionVariables[[regressionVariableCount]]$name
    
    group.data.dir=file.path(data.dir, "Group.data")
    group.results.dir=file.path(data.dir, "Group.results", "followup.regressions")
    
    ## output.filename=file.path(group.results.dir, paste("clinical.rlm.results.output", format(Sys.time(), "%Y%m%d-%H%M%Z"), "txt", sep="."))
    ## cat("*** Output table is in ", output.filename, "\n")
    ## ff=file(output.filename, open="w", encoding="utf-8")
    ## sink(ff, append=FALSE)

    for (seedFile in seedFiles) {
        
        seeds=readSeedsFile(seedFile)
        
        publicationTableFilename=file.path(group.results.dir, paste("publicationTable", "csv", sep="."))
        ## if (file.exists(publicationTableFilename)) {
        ##     file.remove(publicationTableFilename)
        ## }
        
        generateGraphs(group.data.dir, group.results.dir, rvVariable, rvName, publicationTableFilename, seeds, bootstrapped=FALSE)        
    } ## end of for (seedFile in seedFiles) {
    regressionCount=regressionCount+1
    sink()
} ## end of for ( regressionVariableCount in 1:length(regressionVariables ) ) {

