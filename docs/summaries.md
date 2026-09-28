# Short-form summaries

For reuse in an application or CV. Every number below comes from the tracked results tables; update them if the analyses change.

## CV line

Metacognitive noise recovery with hmetad: designed and ran a reproducible R/Stan simulation study (1,440 hierarchical Bayesian meta-d′ fits; open code and dated analysis log) testing what a static meta-d′ model recovers when confidence is generated dynamically or non-Gaussianly.

## Short summary (about 100 words)

I built a fully scripted simulation study of the hmetad package. Confidence ratings were generated from a drift-diffusion process with post-decisional readout noise, from the meta-d′ model itself, and from a Gumbel-min signal distribution, and 1,440 hierarchical Bayesian models were fitted. The static model ordered conditions by readout noise reliably (a validity check). When the signal distribution was misspecified, leave-one-out comparison preferred the correct family in 96% of datasets and log M was biased upward, while aggregate posterior predictive discrepancy stayed small. Errors I found along the way, including a flawed robustness check, are documented and corrected in the log.

## Caveats to keep with any summary

Simulation only, with no human data; the report has not been peer reviewed; the reference list was checked only against Crossref metadata; and results are conditional on the generators chosen.
