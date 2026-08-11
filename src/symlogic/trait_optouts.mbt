///|
#deprecated
pub extend BoolExpr with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
pub extend BoolExpr with Eq::{not_equal, equal}

///|
#deprecated
pub extend BoolExpr with Hash::{hash, hash_combine}

///|
#deprecated
pub extend LinearConstraint with Show::{to_string, output}

///|
#deprecated
pub extend LraConflictLit with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend LraConflictLit with Eq::{not_equal, equal}

///|
#deprecated
pub extend RelOp with Eq::{not_equal, equal}

///|
#deprecated
pub extend SatResult with Show::{to_string, output}

///|
#deprecated
pub extend TruthTableRow with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend TruthTableRow with Eq::{not_equal, equal}

///|
#deprecated
pub extend TruthTableRow with Show::{to_string, output}
