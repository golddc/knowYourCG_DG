imputeRowMean <- function(mtx) {
    k <- which(is.na(mtx), arr.ind=TRUE)
    mtx[k] <- rowMeans(mtx, na.rm=TRUE)[k[,1]]
    mtx
}


cleanMatrix <- function(mtx, f_row = 0.5, f_col = 0.5) {
    message("Before: ", nrow(mtx), " rows\n")
    namtx <- !is.na(mtx)
    good_row <- rowSums(namtx) > 1
    message("After: ", sum(good_row), " rows\n")
    mtx <- mtx[good_row,]
    imputeRowMean(mtx)
}


returnDiffCpGs <- function(
        betas, query, k=50, metric="correlation", diffThreshold=0.5) {
    refGraph <- rnndescent::nnd_knn(betas, k = k, metric=metric)
    searchGraph <- rnndescent::prepare_search_graph(
        betas,
        refGraph,
        metric=metric,
        verbose = FALSE
    )
    query_nn <- rnndescent::graph_knn_query(
        query = query,
        reference = betas,
        reference_graph = searchGraph,
        k = 1,
        metric = metric,
        verbose = FALSE
    )
    query[which(query_nn$dist > diffThreshold), ]
}


prepareSampleSet <- function(
        betas,k=50,impute=TRUE,num_row=75000,diffThreshold=0.5,
        sample_size=0.33,query_size=10000,preSorted=NULL) {

    if (is(betas, "numeric")) {
        betas <- cbind(sample = betas)
    }
    if (impute) {
        betas <- cleanMatrix(betas)
    }
    num <- ifelse(nrow(betas) < num_row,nrow(betas),num_row)
    if (is.null(preSorted)) {
        var_rows <- order(-apply(betas,1,sd))[seq(num)]
    } else {
        #var_rows <- preSorted[seq(num)] #sample this, dont take in order
        var_rows <- sample(preSorted,num)
    }
    betas <- betas[var_rows,]
    sample_size <- round(sample_size * num)
    betas_sample <- betas[sample(rownames(betas), size=sample_size), ]
    query <- betas[!rownames(betas) %in% rownames(betas_sample),]
    nQ <- nrow(query)
    if (nQ > query_size) {
        query <- query[sample(nQ,query_size),]
    }
    betas_sample <- rbind(
        betas_sample,
        returnDiffCpGs(
            betas=betas_sample,
            query=query,
            k=k,
            diffThreshold = diffThreshold
            )
        )
    betas_sample
}


detectCommunity <- function(el,edgeThreshold=.1,nodeThreshold=0) {
    g <- igraph::graph_from_data_frame(
        el,
        directed = FALSE
    )
    g <- igraph::delete.edges(
        g,
        which(igraph::E(g)$dist > edgeThreshold)
    )
    isolated <- which(igraph::degree(g)==nodeThreshold)
    g <- igraph::delete.vertices(g, isolated)
    lc <- cluster_louvain(g)
    lc
}


getJaccard <- function(a,b) {
    intersection = length(intersect(a, b))
    union = length(a) + length(b) - intersection
    return (intersection/union)
}

createMatrix <- function(mod_list,compute=FALSE) {
    n = length(mod_list)
    nms = names(mod_list)
    mtx <- matrix(0,nrow = n,ncol = n,dimnames = list(nms,nms))
    if (compute) {
        for (nm in nms) {
            for (nm2 in nms) {
                v1 = mod_list[[nm]]
                v2 = mod_list[[nm2]]
                s = getJaccard(v1,v2)
                mtx[nm,nm2] <- s
                print(paste("Done with ",nm,"---",nm2))
            }
        }
    }
    mtx
}

extractConsensus <- function(mod_mtx,mod_list,jacc_thresh=0.4) {
    merge <- apply(mod_mtx,1,function(x) {
        which(x >= jacc_thresh)
    })
    merge <- unique(merge)
    mods <- lapply(merge,function(x) {
        module <- unique(unlist(mod_list[x]))
    })
    names(mods) <- as.character(seq(mods))
    mods
}

extractConsensusModules <- function(mod_mtx,mod_list,jacc_thresh=0.4) {
    mtx <- mod_mtx
    ml <- mod_list
    sim_mods <- any(apply(mtx,1,function(x) x >= jacc_thresh & x < 1))
    while (sim_mods > 0) {
        ml <- extractConsensus(
            mod_mtx=mtx,
            mod_list=ml,
            jacc_thresh = jacc_thresh
        )
        mtx <- createMatrix(ml,compute = TRUE)
        sim_mods <- any(apply(mtx,1,function(x) x >= jacc_thresh & x < 1))
    }
    ml
}


intraModCor <- function(x,betas) {
    b <- betas[x,]
    cors <- do.call(c,lapply(1:nrow(b),function(xx) {
        v2 <- b[xx,]
        r <- apply(b[-xx,],1,cor,v2,use="complete.obs")
    }))
    mean(unique(cors))
}

interModCor <- function(mod1,mod2,betas) {
    cgs <- unlist(c(mod1,mod2))
    b <- betas[cgs,]
    mtx <- matrix(0,nrow = length(mod1),ncol = length(mod2),
                  dimnames = list(mod1,mod2))
    for (nm in rownames(mtx)) {
        for (nm2 in colnames(mtx)) {
            r <- cor(b[nm,],b[nm2,],use = "complete.obs")
            mtx[nm,nm2] <- r
        }
    }
    mean(as.vector(mtx))
}

getInterModCors <- function(mod_list,betas) {
    len <- length(mod_list)
    cors <- vector(mode = "double",length = len * (len - 1))
    for (i in seq(mod_list)) {
        for (j in seq(mod_list)) {
            if (i == j) next
            ind <- 1
            r <- interModCor(mod_list[[i]],mod_list[[j]],betas)
            cors[ind] <- r
            ind <- ind + 1
        }
    }
}

#' findCpGModules identifies modules of co-methylated CpGs
#'
#' @param betas matrix of beta values where probes are on the rows and
#' samples on the columns
#' @param k # of neighbors to return from reference graph for query CpGs
#' @param diffThreshold Distance to nearest neighbor to determine if
#' query gets added to reference graph
#' @param impute whether to impute missing values using the row mean
#' (Default: TRUE)
#' @param edgeThreshold minimum inter - CpG distance threshold for community
#' detection (1 - correlation)
#' @param nodeThreshold minimum node degree for removal from graph
#' @param metric metric for computing neighbor distance (Default: correlation)
#' @param moduleSize minimum number of CpGs for module consideration
#' @param num_row number of variable rows to select for reference graph pool
#' @param sample_size number of CpGs to sample for reference graph
#' @param query_size number of CpGs to query reference graph
#' @param preSorted optional vector of sorted indices
#' @return A list of CpG modules
#' @importFrom igraph graph_from_data_frame delete.edges delete.vertices
#' @importFrom igraph cluster_louvain degree communities sizes
#' @examples
#' library(SummarizedExperiment)
#' se <- sesameDataGet('MM285.467.SE.tissue20Kprobes')
#' betas <- assay(se)
#' modules <- findCpGModules(betas)
#' sesameDataGet_resetEnv()
#'
#' @export
findCpGModules <- function (
        betas,impute=TRUE,diffThreshold=.5,k=50,metric="correlation",
        edgeThreshold=.1,nodeThreshold=0,moduleSize = 5,
        num_row = 75000, sample_size=0.33, query_size=10000,
        preSorted=NULL) {

    beta_sample <- prepareSampleSet(
        betas=betas,
        impute=impute,
        num_row=num_row,
        preSorted=preSorted,
        sample_size=sample_size,
        query_size=query_size,
        diffThreshold=diffThreshold
    )
    nnr <- rnndescent::nnd_knn(beta_sample, k = k, metric=metric)
    nbr_mtx <- nnr$idx[,-1]
    nbrs <- as.vector(nbr_mtx)
    dist <- as.vector(nnr$dist[,-1])
    el <- matrix(0, nrow = nrow(nbr_mtx) * ncol(nbr_mtx), ncol = 2)
    el[,2] <- nbrs
    el[,1] <- rep(seq(nrow(nbr_mtx)), times=ncol(nbr_mtx))
    el_df <- as.data.frame(el);
    select <- !duplicated(t(apply(el_df,1,sort)))
    el_df <- el_df[select,]
    el_df$dist <- dist[select]
    lc <- detectCommunity(
        el=el_df,
        edgeThreshold = edgeThreshold,
        nodeThreshold = nodeThreshold
    )
    communities <- igraph::communities(lc)[igraph::sizes(lc) >= moduleSize]
    modules <- lapply(communities,function(x) {
        indices <- as.numeric(x)
        rownames(beta_sample)[indices]
    })
    names(modules) <- as.character(seq(modules))
    modules
}
