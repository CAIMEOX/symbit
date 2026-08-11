///|
#deprecated
pub extend BigRational with Add::{add}

///|
#deprecated
pub extend BigRational with Eq::{not_equal, equal}

///|
#deprecated
pub extend BigRational with Hash::{hash, hash_combine}

///|
#deprecated
pub extend BigRational with Mul::{mul}

///|
#deprecated
pub extend BigRational with Neg::{neg}

///|
#deprecated
pub extend BigRational with Show::{to_string, output}

///|
#deprecated
pub extend BigRational with Sub::{sub}

///|
#deprecated
pub extend MPIntervalContext with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend MPIntervalContext with Eq::{not_equal, equal}

///|
#deprecated
pub extend RationalError with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend RationalError with Show::{to_string, output}
