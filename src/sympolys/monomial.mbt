///|
pub struct Monomial {
  exps : Array[Int]
}

///|
pub fn monomial_one(len : Int) -> Monomial {
  Monomial::{ exps: Array::make(len, 0) }
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
impl Eq for Monomial with equal(self, other : Monomial) -> Bool {
  self.exps.equal(other.exps)
}

///|
impl Eq for Monomial with not_equal(self, other : Monomial) -> Bool {
  !self.equal(other)
}

///|
impl Hash for Monomial with hash(self) -> Int {
  self.exps.hash()
}

///|
impl Hash for Monomial with hash_combine(self, hasher : Hasher) -> Unit {
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
