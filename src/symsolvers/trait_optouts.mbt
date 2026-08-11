///|
#deprecated
pub extend SolverError with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend SolverError with Eq::{not_equal, equal}

///|
#deprecated
pub extend SolverError with Show::{to_string, output}
