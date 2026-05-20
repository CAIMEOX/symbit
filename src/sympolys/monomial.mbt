///|
/// Sparse monomial representation and term-order helpers.

///|
/// Exponent-vector monomial.
///
/// - Does: Stores one monomial as an exponent array.
/// - Input: Structured exponent data managed through the public helpers below.
/// - Returns: A `Monomial`.
/// - Limits: The raw struct does not validate exponent semantics on
///   construction.
pub struct Monomial {
  exps : Array[Int]
} derive(Eq, Hash)

///|
/// Build the multiplicative-identity monomial.
///
/// - Does: Returns `(0, ..., 0)` with the requested arity.
/// - Input: A variable count `Int`.
/// - Returns: A `Monomial`.
/// - Limits: Negative lengths are not expected by this front door.
pub fn monomial_one(len : Int) -> Monomial {
  Monomial::{ exps: Array::make(len, 0) }
}

///|
/// Build a monomial from an exponent vector.
///
/// - Does: Wraps one exponent array into a `Monomial`.
/// - Input: `Array[Int]`.
/// - Returns: A `Monomial`.
/// - Limits: No validation is performed on exponent signs.
pub fn monomial_from_array(exps : Array[Int]) -> Monomial {
  Monomial::{ exps, }
}

///|
/// Return the exponent vector.
///
/// - Does: Exposes the stored exponent array.
/// - Input: One `Monomial`.
/// - Returns: `Array[Int]`.
/// - Limits: The returned array is the stored representation.
pub fn Monomial::to_array(self : Monomial) -> Array[Int] {
  self.exps
}

///|
/// Multiply two monomials.
///
/// - Does: Adds exponents component-wise.
/// - Input: Two `Monomial` values with the same arity.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_mul(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  let exps = Array::makei(len, i => a.exps[i] + b.exps[i])
  Monomial::{ exps, }
}

///|
/// Raise a monomial to a non-negative power.
///
/// - Does: Multiplies each exponent by `k`.
/// - Input: One `Monomial` and one non-negative `Int`.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::BadExponent` for negative powers.
pub fn monomial_pow(m : Monomial, k : Int) -> Monomial raise PolyError {
  if k < 0 {
    raise PolyError::BadExponent
  }
  let len = m.exps.length()
  let exps = Array::makei(len, i => m.exps[i] * k)
  Monomial::{ exps, }
}

///|
/// Check monomial divisibility.
///
/// - Does: Tests exponent-wise divisibility.
/// - Input: Two `Monomial` values with the same arity.
/// - Returns: A `Bool`.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_divides(a : Monomial, b : Monomial) -> Bool raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  for i in 0..<len {
    if a.exps[i] > b.exps[i] {
      return false
    }
  }
  true
}

///|
/// Divide one monomial by another when possible.
///
/// - Does: Subtracts exponents when the divisor divides the numerator.
/// - Input: Numerator and denominator `Monomial`.
/// - Returns: `Monomial?`.
/// - Limits: Returns `None` when divisibility fails and raises
///   `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_div(
  numer : Monomial,
  denom : Monomial,
) -> Monomial? raise PolyError {
  if numer.exps.length() != denom.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = numer.exps.length()
  let exps = Array::make(len, 0)
  for i in 0..<len {
    if numer.exps[i] < denom.exps[i] {
      return None
    }
    exps.set(i, numer.exps[i] - denom.exps[i])
  }
  Some(Monomial::{ exps, })
}

///|
/// Return the monomial lcm.
///
/// - Does: Takes the component-wise maximum of two monomials.
/// - Input: Two `Monomial` values with the same arity.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_lcm(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  let exps = Array::makei(len, i => {
    if a.exps[i] > b.exps[i] {
      a.exps[i]
    } else {
      b.exps[i]
    }
  })
  Monomial::{ exps, }
}

///|
/// Return the monomial gcd.
///
/// - Does: Takes the component-wise minimum of two monomials.
/// - Input: Two `Monomial` values with the same arity.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_gcd(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  let exps = Array::makei(len, i => {
    if a.exps[i] < b.exps[i] {
      a.exps[i]
    } else {
      b.exps[i]
    }
  })
  Monomial::{ exps, }
}

///|
/// Return the component-wise maximum of a monomial list.
///
/// - Does: Folds `max` across exponent positions.
/// - Input: A non-empty `Array[Monomial]`.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::NonPolynomial` on empty input and
///   `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_max(monoms : Array[Monomial]) -> Monomial raise PolyError {
  if monoms.is_empty() {
    raise PolyError::NonPolynomial
  }
  let len = monoms[0].exps.length()
  let exps = Array::makei(len, i => monoms[0].exps[i])
  for idx in 1..<monoms.length() {
    let m = monoms[idx]
    if m.exps.length() != len {
      raise PolyError::DomainMismatch
    }
    for i in 0..<len {
      if m.exps[i] > exps[i] {
        exps.set(i, m.exps[i])
      }
    }
  }
  Monomial::{ exps, }
}

///|
/// Return the component-wise minimum of a monomial list.
///
/// - Does: Folds `min` across exponent positions.
/// - Input: A non-empty `Array[Monomial]`.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::NonPolynomial` on empty input and
///   `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_min(monoms : Array[Monomial]) -> Monomial raise PolyError {
  if monoms.is_empty() {
    raise PolyError::NonPolynomial
  }
  let len = monoms[0].exps.length()
  let exps = Array::makei(len, i => monoms[0].exps[i])
  for idx in 1..<monoms.length() {
    let m = monoms[idx]
    if m.exps.length() != len {
      raise PolyError::DomainMismatch
    }
    for i in 0..<len {
      if m.exps[i] < exps[i] {
        exps.set(i, m.exps[i])
      }
    }
  }
  Monomial::{ exps, }
}

///|
/// Count monomials of fixed total degree.
///
/// - Does: Computes the combinations-with-repetition count.
/// - Input: Variable count and total degree as `Int`.
/// - Returns: An `Int`.
/// - Limits: Negative inputs return `0`.
pub fn monomial_count(vars : Int, degree : Int) -> Int {
  if vars < 0 || degree < 0 {
    return 0
  }
  // combinations with repetition: C(vars + degree, degree)
  let mut numer = 1
  let mut denom = 1
  for k in 1..<=degree {
    numer = numer * (vars + k)
    denom = denom * k
  }
  numer / denom
}

///|
/// Divide monomials component-wise without divisibility checking.
///
/// - Does: Subtracts exponent vectors, allowing negative exponents.
/// - Input: Two `Monomial` values with the same arity.
/// - Returns: A `Monomial`.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn monomial_ldiv(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  Monomial::{ exps: Array::makei(len, i => a.exps[i] - b.exps[i]) }
}

///|
/// Return the total degree of a monomial.
///
/// - Does: Sums the exponent vector.
/// - Input: One `Monomial`.
/// - Returns: An `Int`.
/// - Limits: Negative exponents are included literally in the sum.
pub fn monomial_deg(m : Monomial) -> Int {
  monomial_total_degree(m)
}

///|
/// Divide two polynomial terms over a domain.
///
/// - Does: Divides monomials and coefficients when exact division is possible.
/// - Input: `(Monomial, FieldElem)` numerator and denominator terms plus a
///   coefficient domain.
/// - Returns: `Some(term)` on success or `None` when the term is not divisible.
/// - Limits: Raises for zero divisor coefficients and arity mismatches.
pub fn term_div(
  a : (Monomial, FieldElem),
  b : (Monomial, FieldElem),
  domain : Domain,
) -> (Monomial, FieldElem)? raise PolyError {
  match monomial_div(a.0, b.0) {
    None => None
    Some(monom) => {
      let (ok, coeff) = fe_divides(a.1, b.1, domain)
      if ok {
        Some((monom, coeff))
      } else {
        None
      }
    }
  }
}

///|
fn monomial_total_degree(m : Monomial) -> Int {
  m.exps.fold(init=0, (acc, v) => acc + v)
}

///|
fn compare_monomial_lex(a : Monomial, b : Monomial) -> Int {
  let len = a.exps.length()
  for i in 0..<len {
    if a.exps[i] < b.exps[i] {
      return -1
    }
    if a.exps[i] > b.exps[i] {
      return 1
    }
  }
  0
}

///|
fn compare_monomial_grevlex(a : Monomial, b : Monomial) -> Int {
  let len = a.exps.length()
  for offset in 0..<len {
    let idx = len - 1 - offset
    if a.exps[idx] < b.exps[idx] {
      return 1
    }
    if a.exps[idx] > b.exps[idx] {
      return -1
    }
  }
  0
}

///|
fn cmp_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Compare exponent arrays in lexicographic order.
///
/// - Does: Orders exponent vectors left to right.
/// - Input: Two exponent arrays.
/// - Returns: An ordering `Int`.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch.
pub fn compare_exps_lex(a : Array[Int], b : Array[Int]) -> Int raise PolyError {
  if a.length() != b.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.length()
  for i in 0..<len {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  0
}

///|
/// Compare exponent arrays in graded lexicographic order.
///
/// - Does: Orders first by total degree, then by lexicographic order.
/// - Input: Two exponent arrays.
/// - Returns: An ordering `Int`.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch.
pub fn compare_exps_grlex(
  a : Array[Int],
  b : Array[Int],
) -> Int raise PolyError {
  if a.length() != b.length() {
    raise PolyError::DomainMismatch
  }
  let da = a.fold(init=0, (s, v) => s + v)
  let db = b.fold(init=0, (s, v) => s + v)
  if da != db {
    return cmp_int(da, db)
  }
  compare_exps_lex(a, b)
}

///|
/// Compare exponent arrays in graded reverse lexicographic order.
///
/// - Does: Orders first by total degree, then by reverse lexicographic order.
/// - Input: Two exponent arrays.
/// - Returns: An ordering `Int`.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch.
pub fn compare_exps_grevlex(
  a : Array[Int],
  b : Array[Int],
) -> Int raise PolyError {
  if a.length() != b.length() {
    raise PolyError::DomainMismatch
  }
  let da = a.fold(init=0, (s, v) => s + v)
  let db = b.fold(init=0, (s, v) => s + v)
  if da != db {
    return cmp_int(da, db)
  }
  let len = a.length()
  for offset in 0..<len {
    let idx = len - 1 - offset
    if a[idx] < b[idx] {
      return 1 // reversed sense
    }
    if a[idx] > b[idx] {
      return -1
    }
  }
  0
}

///|
/// Compare exponent arrays in inverse lexicographic order.
///
/// - Does: Flips the sign of the lexicographic comparator.
/// - Input: Two exponent arrays.
/// - Returns: An ordering `Int`.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch.
pub fn compare_exps_ilex(a : Array[Int], b : Array[Int]) -> Int raise PolyError {
  let c = compare_exps_lex(a, b)
  -c
}

///|
/// Compare exponent arrays in inverse graded lexicographic order.
///
/// - Does: Flips the sign of the grlex comparator.
/// - Input: Two exponent arrays.
/// - Returns: An ordering `Int`.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch.
pub fn compare_exps_igrlex(
  a : Array[Int],
  b : Array[Int],
) -> Int raise PolyError {
  let c = compare_exps_grlex(a, b)
  -c
}

///|
/// Compare exponent arrays in inverse graded reverse lexicographic order.
///
/// - Does: Flips the sign of the grevlex comparator.
/// - Input: Two exponent arrays.
/// - Returns: An ordering `Int`.
/// - Limits: Raises `PolyError::DomainMismatch` for length mismatch.
pub fn compare_exps_igrevlex(
  a : Array[Int],
  b : Array[Int],
) -> Int raise PolyError {
  let c = compare_exps_grevlex(a, b)
  -c
}

///|
/// Compare monomials under one term order.
///
/// - Does: Dispatches to the selected monomial-order comparator.
/// - Input: Two `Monomial` values and one `TermOrder`.
/// - Returns: An ordering `Int`.
/// - Limits: This front door assumes the monomials already have matching arity.
pub fn compare_monomial_order(
  a : Monomial,
  b : Monomial,
  order : TermOrder,
) -> Int {
  match order {
    TermOrder::Lex => compare_monomial_lex(a, b)
    TermOrder::Grlex => {
      let da = monomial_total_degree(a)
      let db = monomial_total_degree(b)
      if da != db {
        return cmp_int(da, db)
      }
      compare_monomial_lex(a, b)
    }
    TermOrder::Grevlex => {
      let da = monomial_total_degree(a)
      let db = monomial_total_degree(b)
      if da != db {
        return cmp_int(da, db)
      }
      compare_monomial_grevlex(a, b)
    }
    TermOrder::Ilex => -compare_monomial_lex(a, b)
    TermOrder::Igrlex => {
      let da = monomial_total_degree(a)
      let db = monomial_total_degree(b)
      if da != db {
        return -cmp_int(da, db)
      }
      -compare_monomial_lex(a, b)
    }
    TermOrder::Igrevlex => {
      let da = monomial_total_degree(a)
      let db = monomial_total_degree(b)
      if da != db {
        return -cmp_int(da, db)
      }
      -compare_monomial_grevlex(a, b)
    }
  }
}
