///|
#deprecated
pub extend ANP with Show::{to_string, output}

///|
#deprecated
pub extend ComplexField with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend ComplexField with Eq::{not_equal, equal}

///|
#deprecated
pub extend DomainScalar with Show::{to_string, output}

///|
#deprecated
pub extend FieldElem with Show::{to_string, output}

///|
#deprecated
pub extend ModuleElement with Show::{to_string, output}

///|
#deprecated
pub extend Monomial with Eq::{not_equal, equal}

///|
#deprecated
pub extend Monomial with Hash::{hash, hash_combine}

///|
#deprecated
pub extend NFModule with Show::{to_string, output}

///|
#deprecated
pub extend Poly with Show::{output}

///|
#deprecated
pub extend PolyConfigValue with Eq::{not_equal, equal}

///|
#deprecated
pub extend PolyError with Show::{to_string, output}

///|
#deprecated
pub extend PrimeIdeal with Show::{to_string, output}

///|
#deprecated
pub extend RealField with @moonbitlang/core/debug.Debug::{to_repr}

///|
#deprecated
pub extend RealField with Eq::{not_equal, equal}

///|
#deprecated
pub extend RootOf with Show::{to_string, output}

///|
#deprecated
pub extend RootSum with Show::{to_string, output}

///|
#deprecated
pub extend RoundTwoResult with Show::{to_string, output}

///|
#deprecated
pub extend SeriesRing with Eq::{not_equal, equal}

///|
#deprecated
pub extend TermOrder with Eq::{not_equal, equal}
