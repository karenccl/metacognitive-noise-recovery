# Single named function implementing the locked K=4 rank-based,
# within-subject discretisation rule applied to a continuous confidence
# readout (protocol sections 1.3, 1.4). Must preserve/return cut-points
# per subject and be usable for the K=6 / fixed-cutpoint sensitivity
# analysis as well.
#
# Contract:
#   input:  data.frame with participant id column and a continuous
#           confidence readout column
#   output: input augmented with an integer confidence column in 1:K
#           and, separately, the per-subject cut-points used

discretise_confidence <- function(data, participant_col, value_col, k = 4) {
  stop("not yet implemented")
}
