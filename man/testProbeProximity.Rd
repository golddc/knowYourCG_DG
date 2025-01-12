% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/testProbeProximity.R
\name{testProbeProximity}
\alias{testProbeProximity}
\title{testProbeProximity tests if a query set of probes share closer
genomic proximity than if randomly distributed}
\usage{
testProbeProximity(
  query,
  gr = NULL,
  platform = NULL,
  iterations = 100,
  bin_size = 1500
)
}
\arguments{
\item{query}{Vector of probes of interest (e.g., significant probes)}

\item{gr}{GRanges to draw samples and compute genomic distances}

\item{platform}{String corresponding to the type of platform to use. Either
MM285, EPIC, HM450, or HM27. If it is not provided, it will be inferred
from the query set probeIDs (Default: NA).}

\item{iterations}{Number of random samples to generate null distribution
(Default: 100).}

\item{bin_size}{the poisson interval size for computing neighboring hits}
}
\value{
list containing a dataframe for the poisson statistics and a
data frame for the probes in close proximity
}
\description{
testProbeProximity tests if a query set of probes share closer
genomic proximity than if randomly distributed
}
\examples{

library(SummarizedExperiment)
df <- rowData(sesameDataGet('MM285.tissueSignature'))
query <- df$Probe_ID[df$branch == "B_cell"]
res <- testProbeProximity(query,platform="MM285")
sesameDataGet_resetEnv()

}
