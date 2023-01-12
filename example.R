library(batchtools)
##setwd("/projects/biostat01/people/snf991/batchtools-example-slurm/")
## remove previous results (if necessary)
if (dir.exists(".batch_registry")){
  reg <- loadRegistry(file.dir = ".batch_registry", writeable = TRUE)
} else {
  reg <- makeRegistry(file.dir = ".batch_registry", seed = 1, packages = c("riskRegression", "data.table", "survival"))
}

reg$cluster.functions = makeClusterFunctionsSlurm(template = "slurm-simple.tmpl")

runSimulation <- function(sample.size, ...){
  learndat <- riskRegression::sampleData(round(10/9*sample.size),outcome="binary")
  lr1a = glm(Y~X1+X2+X7+X8,data=learndat,family=binomial)
  x1 = Score(list(lr1a),
             formula=Y~1,data=learndat,conf.int=TRUE,
             split.method="cv10",B=50,null.model = FALSE)
  c(AUC=x1$AUC$score$AUC, Brier=x1$Brier$score$Brier, AUC.SE = x1$AUC$score$se, Brier.SE = x1$Brier$score$se)
}

par_grid <- expand.grid(sample.size = 1000, nrep = 1:10)
jobs <- batchMap(runSimulation, par_grid)
setJobNames(jobs, paste0("myJob_",1:nrow(jobs)))
jobs$chunk <- chunk(jobs$job.id, chunk.size =  nrow(jobs))
submitJobs(jobs, resources = list(chunks.as.arrayjobs=TRUE))
#waitForJobs() # waits until all jobs are finished
#getStatus() #see how many jobs are done
# killJobs() kill all the jobs on slurm
## we can load the registry when the jobs are done
res <- reduceResultsList()
res <- do.call("rbind", res) #there is also reduceResultsDataTable, but it does not do this
res <- cbind(par_grid, res) # combine with the job parameters
