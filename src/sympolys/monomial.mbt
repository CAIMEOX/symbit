///|
pub struct Monomial {
  exps : Array[Int]
}

///|
pub fn monomial_one(len : Int) -> Monomial {
  Monomial::{ exps: Array::make(len, 0) }
}

///|
pub fn monomial_from_array(exps : Array[Int]) -> Monomial {
  Monomial::{ exps, }
}

///|
pub fn Monomial::to_array(self : Monomial) -> Array[Int] {
  self.exps
}

///|
pub fn monomial_mul(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  let exps = Array::makei(len, i => a.exps[i] + b.exps[i])
  Monomial::{ exps, }
}

///|
pub fn monomial_pow(m : Monomial, k : Int) -> Monomial raise PolyError {
  if k < 0 {
    raise PolyError::BadExponent
  }
  let len = m.exps.length()
  let exps = Array::makei(len, i => m.exps[i] * k)
  Monomial::{ exps, }
}

///|
/// Check if a divides b (exponent-wise).
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
pub fn monomial_lcm(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  let exps = Array::makei(len, i => if a.exps[i] > b.exps[i] {
    a.exps[i]
  } else {
    b.exps[i]
  })
  Monomial::{ exps, }
}

///|
/// Element-wise minimum exponents across inputs.
pub fn monomial_gcd(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.exps.length() != b.exps.length() {
    raise PolyError::DomainMismatch
  }
  let len = a.exps.length()
  let exps = Array::makei(len, i => if a.exps[i] < b.exps[i] {
    a.exps[i]
  } else {
    b.exps[i]
  })
  Monomial::{ exps, }
}

///|
/// Element-wise maximum exponents across inputs.
pub fn monomial_max(monoms : Array[Monomial]) -> Monomial raise PolyError {
  if monoms.is_empty() {
    raise PolyError::NotImplemented("monomial_max empty input")
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
/// Element-wise minimum exponents across inputs.
pub fn monomial_min(monoms : Array[Monomial]) -> Monomial raise PolyError {
  if monoms.is_empty() {
    raise PolyError::NotImplemented("monomial_min empty input")
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
pub impl Eq for Monomial with equal(self, other : Monomial) -> Bool {
  self.exps.equal(other.exps)
}

///|
pub impl Eq for Monomial with not_equal(self, other : Monomial) -> Bool {
  !self.equal(other)
}

///|
pub impl Hash for Monomial with hash(self) -> Int {
  self.exps.hash()
}

///|
pub impl Hash for Monomial with hash_combine(self, hasher : Hasher) -> Unit {
  self.exps.hash_combine(hasher)
}

///|
fn total_degree(m : Monomial) -> Int {
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
/// Compare exponent arrays with lexicographic order.
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
/// Graded lex (grlex) comparison on exponent arrays.
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
/// Graded reverse lex (grevlex) comparison on exponent arrays.
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
/// Inverse lex: flip the comparison sign of lex.
pub fn compare_exps_ilex(a : Array[Int], b : Array[Int]) -> Int raise PolyError {
  let c = compare_exps_lex(a, b)
  -c
}

///|
/// Inverse grlex: flip comparison sign of grlex.
pub fn compare_exps_igrlex(
  a : Array[Int],
  b : Array[Int],
) -> Int raise PolyError {
  let c = compare_exps_grlex(a, b)
  -c
}

///|
pub fn compare_monomial_order(
  a : Monomial,
  b : Monomial,
  order : TermOrder,
) -> Int {
  match order {
    TermOrder::Lex => compare_monomial_lex(a, b)
    TermOrder::Grlex => {
      let da = total_degree(a)
      let db = total_degree(b)
      if da != db {
        return cmp_int(da, db)
      }
      compare_monomial_lex(a, b)
    }
    TermOrder::Grevlex => {
      let da = total_degree(a)
      let db = total_degree(b)
      if da != db {
        return cmp_int(da, db)
      }
      compare_monomial_grevlex(a, b)
    }
  }
}
