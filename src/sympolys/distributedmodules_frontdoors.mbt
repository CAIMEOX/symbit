///|
/// Distributed module term `(module monomial, coefficient)`.
///
/// - Does: Names the sparse term representation used by `sdm_*` front doors.
/// - Input: A module monomial and one coefficient.
/// - Returns: A type alias, not a runtime value.
/// - Limits: The first exponent stores the module-generator index.
pub type SdmTerm = (Monomial, FieldElem)

///|
/// Sparse distributed module element.
///
/// - Does: Names an ordered sparse list of module terms.
/// - Input: An array of `SdmTerm`.
/// - Returns: A type alias, not a runtime value.
/// - Limits: Terms should be sorted by the selected monomial order.
pub type Sdm = Array[SdmTerm]

///|
fn sdm_tail_monomial(m : Monomial) -> Monomial {
  let exps = m.to_array()
  Monomial::{ exps: exps[1:].to_owned() }
}

///|
fn sdm_module_monomial(basis : Int, tail : Monomial) -> Monomial {
  let exps : Array[Int] = [basis]
  for exp in tail.to_array() {
    exps.push(exp)
  }
  Monomial::{ exps, }
}

///|
fn sdm_check_tail_arity(m : Monomial, x : Monomial) -> Unit raise PolyError {
  if m.to_array().length() != x.to_array().length() + 1 {
    raise PolyError::DomainMismatch
  }
}

///|
/// Multiply a polynomial monomial into a module monomial.
///
/// - Does: Multiplies a polynomial monomial into a module monomial.
/// - Input: A module monomial `M=(i,e...)` and polynomial monomial `X`.
/// - Returns: `(i, X+e...)`.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn sdm_monomial_mul(m : Monomial, x : Monomial) -> Monomial raise PolyError {
  sdm_check_tail_arity(m, x)
  let exps = m.to_array()
  sdm_module_monomial(exps[0], monomial_mul(x, sdm_tail_monomial(m)))
}

///|
/// Return the polynomial total degree of a module monomial.
///
/// - Does: Computes the total degree after ignoring the module index.
/// - Input: A module monomial.
/// - Returns: The total degree of its polynomial tail.
/// - Limits: Empty monomials raise `PolyError::DomainMismatch`.
pub fn sdm_monomial_deg(m : Monomial) -> Int raise PolyError {
  if m.to_array().is_empty() {
    raise PolyError::DomainMismatch
  }
  monomial_deg(sdm_tail_monomial(m))
}

///|
/// Return the module monomial lcm.
///
/// - Does: Computes an lcm over the polynomial tails.
/// - Input: Two module monomials.
/// - Returns: The first module index with lcm of polynomial tails.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn sdm_monomial_lcm(a : Monomial, b : Monomial) -> Monomial raise PolyError {
  if a.to_array().length() != b.to_array().length() || a.to_array().is_empty() {
    raise PolyError::DomainMismatch
  }
  sdm_module_monomial(
    a.to_array()[0],
    monomial_lcm(sdm_tail_monomial(a), sdm_tail_monomial(b)),
  )
}

///|
/// Test module monomial divisibility.
///
/// - Does: Checks whether one module monomial divides another.
/// - Input: Two module monomials.
/// - Returns: `true` when both basis index and tail divisibility match.
/// - Limits: Raises `PolyError::DomainMismatch` for arity mismatch.
pub fn sdm_monomial_divides(
  a_m : Monomial,
  b_m : Monomial,
) -> Bool raise PolyError {
  let a = a_m.to_array()
  let b = b_m.to_array()
  if a.length() != b.length() || a.is_empty() {
    raise PolyError::DomainMismatch
  }
  a[0] == b[0] &&
  monomial_divides(sdm_tail_monomial(a_m), sdm_tail_monomial(b_m))
}

///|
/// Return the leading coefficient of an SDM element.
///
/// - Does: Reads the leading coefficient.
/// - Input: An SDM element and coefficient domain.
/// - Returns: The first coefficient, or domain zero for the empty element.
/// - Limits: Assumes the element is already ordered.
pub fn sdm_LC(f : Sdm, domain : Domain) -> FieldElem raise PolyError {
  if f.is_empty() {
    fe_from_int(0, domain)
  } else {
    f[0].1
  }
}

///|
/// Return the leading module monomial of an SDM element.
///
/// - Does: Reads the leading module monomial.
/// - Input: A nonzero SDM element.
/// - Returns: The first monomial.
/// - Limits: Empty inputs raise `PolyError::BadExponent`.
pub fn sdm_LM(f : Sdm) -> Monomial raise PolyError {
  if f.is_empty() {
    raise PolyError::BadExponent
  }
  f[0].0
}

///|
/// Return the leading term of an SDM element.
///
/// - Does: Reads the leading term.
/// - Input: A nonzero SDM element.
/// - Returns: The first `(monomial, coefficient)` pair.
/// - Limits: Empty inputs raise `PolyError::BadExponent`.
pub fn sdm_LT(f : Sdm) -> SdmTerm raise PolyError {
  if f.is_empty() {
    raise PolyError::BadExponent
  }
  f[0]
}

///|
/// Convert an SDM element to a dictionary.
///
/// - Does: Builds a sparse dictionary representation.
/// - Input: An SDM element.
/// - Returns: A map from module monomial to coefficient.
/// - Limits: Duplicate monomials keep the last coefficient.
pub fn sdm_to_dict(f : Sdm) -> Map[Monomial, FieldElem] {
  let out : Map[Monomial, FieldElem] = Map([])
  for term in f {
    out[term.0] = term.1
  }
  out
}

///|
/// Remove zero coefficients from an SDM element.
///
/// - Does: Drops terms with zero coefficients.
/// - Input: An SDM element.
/// - Returns: A filtered SDM element.
/// - Limits: Coefficients are tested structurally with `fe_is_zero`.
pub fn sdm_strip(f : Sdm) -> Sdm {
  let out : Sdm = []
  for term in f {
    if !fe_is_zero(term.1) {
      out.push(term)
    }
  }
  out
}

///|
/// Sort SDM terms by a monomial order.
///
/// - Does: Sorts terms in descending monomial-order priority.
/// - Input: An SDM element and term order.
/// - Returns: A sorted SDM element.
/// - Limits: Assumes all module monomials have compatible arity.
pub fn sdm_sort(f : Sdm, order : TermOrder) -> Sdm {
  let out = f.copy()
  out.sort_by((a, b) => compare_monomial_order(b.0, a.0, order))
  out
}

///|
/// Build an SDM element from a dictionary.
///
/// - Does: Builds an ordered sparse distributed module from a dictionary.
/// - Input: A monomial-to-coefficient map and term order.
/// - Returns: A sorted SDM element without zero terms.
/// - Limits: Duplicate keys are already collapsed by the map.
pub fn sdm_from_dict(d : Map[Monomial, FieldElem], order : TermOrder) -> Sdm {
  let terms : Sdm = []
  for item in d {
    terms.push(item)
  }
  sdm_strip(sdm_sort(terms, order))
}

///|
/// Add two SDM elements.
///
/// - Does: Adds two sparse distributed module elements.
/// - Input: Two SDM elements, term order, and coefficient domain.
/// - Returns: Their sorted sparse sum.
/// - Limits: Raises when coefficient arithmetic fails in the chosen domain.
pub fn sdm_add(
  f : Sdm,
  g : Sdm,
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  let h = sdm_to_dict(f)
  for term in g {
    let monom = term.0
    let coeff = term.1
    match h.get(monom) {
      Some(prev) => {
        let total = fe_add(prev, coeff)
        if fe_is_zero(total) {
          let _ = h.remove(monom)
        } else {
          h[monom] = total
        }
      }
      None => h[monom] = coeff
    }
  }
  ignore(domain)
  sdm_from_dict(h, order)
}

///|
/// Return the zero SDM element.
///
/// - Does: Constructs the zero sparse distributed module element.
/// - Input: No input.
/// - Returns: An empty SDM element.
/// - Limits: None.
pub fn sdm_zero() -> Sdm {
  []
}

///|
/// Multiply an SDM element by a polynomial term.
///
/// - Does: Multiplies every module term by one polynomial term.
/// - Input: An SDM element, polynomial term `(monomial, coeff)`, order, and
///   coefficient domain.
/// - Returns: The scaled SDM element.
/// - Limits: Raises when monomial or coefficient arithmetic is invalid.
pub fn sdm_mul_term(
  f : Sdm,
  term : (Monomial, FieldElem),
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  ignore(order)
  if f.is_empty() || fe_is_zero(term.1) {
    return []
  }
  let out : Sdm = []
  for item in f {
    let coeff = if fe_is_one(term.1) { item.1 } else { fe_mul(item.1, term.1) }
    out.push((sdm_monomial_mul(item.0, term.0), coeff))
  }
  ignore(domain)
  out
}

///|
/// Return the total degree of an SDM element.
///
/// - Does: Computes the maximum tail degree among terms.
/// - Input: A nonzero SDM element.
/// - Returns: The maximum module-monomial tail degree.
/// - Limits: Empty inputs raise `PolyError::BadExponent`.
pub fn sdm_deg(f : Sdm) -> Int raise PolyError {
  if f.is_empty() {
    raise PolyError::BadExponent
  }
  let mut out = sdm_monomial_deg(f[0].0)
  for i in 1..<f.length() {
    let d = sdm_monomial_deg(f[i].0)
    if d > out {
      out = d
    }
  }
  out
}

///|
/// Compute the ecart of an SDM element.
///
/// - Does: Computes `degree(f) - degree(LM(f))`.
/// - Input: A nonzero SDM element.
/// - Returns: An integer degree gap.
/// - Limits: Empty inputs raise `PolyError::BadExponent`.
pub fn sdm_ecart(f : Sdm) -> Int raise PolyError {
  sdm_deg(f) - sdm_monomial_deg(sdm_LM(f))
}
