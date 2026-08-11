///|
#deprecated
pub extend Matrix with Add::{add}

///|
#deprecated
pub extend Matrix with Mul::{mul}

///|
#deprecated
pub extend Matrix with Show::{to_string, output}

///|
#deprecated
pub extend Matrix with Sub::{sub}

///|
#deprecated
pub extend MatrixError with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend MatrixError with Eq::{not_equal, equal}

///|
#deprecated
pub extend MatrixError with Show::{to_string, output}

///|
#deprecated
pub extend MatrixExpr with Show::{to_string, output}

///|
#deprecated
pub extend SparseMatrix with Add::{add}

///|
#deprecated
pub extend SparseMatrix with Mul::{mul}

///|
#deprecated
pub extend SparseMatrix with Show::{to_string, output}

///|
#deprecated
pub extend SparseMatrix with Sub::{sub}
