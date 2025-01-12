% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/MCNA.R
\name{findCpGModules}
\alias{findCpGModules}
\title{findCpGModules identifies modules of co-methylated CpGs}
\usage{
findCpGModules(
  betas,
  impute = TRUE,
  diffThreshold = 0.5,
  k = 50,
  metric = "correlation",
  edgeThreshold = 0.1,
  nodeThreshold = 0,
  moduleSize = 5,
  num_row = 75000,
  sample_size = 0.33
)
}
\arguments{
\item{betas}{matrix of beta values where probes are on the rows and
samples on the columns}

\item{impute}{whether to impute missing values using the row mean
(Default: TRUE)}

\item{diffThreshold}{Distance to nearest neighbor to determine if
query gets added to reference graph}

\item{k}{# of neighbors to return from reference graph for query CpGs}

\item{metric}{metric for computing neighbor distance (Default: correlation)}

\item{edgeThreshold}{minimum inter - CpG distance threshold for community
detection (1 - correlation)}

\item{nodeThreshold}{minimum node degree for removal from graph}

\item{moduleSize}{minimum number of CpGs for module consideration}

\item{num_row}{number of variable rows to select for reference graph pool}

\item{sample_size}{number of CpGs to sample for reference graph}
}
\value{
A list of CpG modules
}
\description{
findCpGModules identifies modules of co-methylated CpGs
}
\examples{
library(SummarizedExperiment)
se <- sesameDataGet('MM285.467.SE.tissue20Kprobes')
betas <- assay(se)
modules <- findCpGModules(betas)
sesameDataGet_resetEnv()

}
