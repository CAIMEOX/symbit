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
type SdmCriticalPair = (Int, Int, Int, Monomial)

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

///|
fn sdm_checked_monomial_div(
  numer : Monomial,
  denom : Monomial,
) -> Monomial raise PolyError {
  match monomial_div(numer, denom) {
    Some(value) => value
    None => raise PolyError::BadExponent
  }
}

///|
fn sdm_field_quo(lhs : FieldElem, rhs : FieldElem) -> FieldElem raise PolyError {
  fe_mul(lhs, fe_inv(rhs))
}

///|
/// Compute the generalized S-polynomial of two SDM elements.
///
/// - Does: Cancels matching leading module terms by multiplying both inputs
///   with the needed polynomial monomial factors.
/// - Input: Two nonzero SDM elements, a term order, and a coefficient field.
/// - Returns: The resulting SDM element, or zero if the leading basis indices
///   differ.
/// - Limits: The optional transformed-coefficient result used by extended
///   algorithms is not exposed by this front door.
pub fn sdm_spoly(
  f : Sdm,
  g : Sdm,
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  if f.is_empty() || g.is_empty() {
    return sdm_zero()
  }
  let lm1 = sdm_LM(f)
  let lm2 = sdm_LM(g)
  let lm1_exps = lm1.to_array()
  let lm2_exps = lm2.to_array()
  if lm1_exps[0] != lm2_exps[0] {
    return sdm_zero()
  }
  let tail1 = sdm_tail_monomial(lm1)
  let tail2 = sdm_tail_monomial(lm2)
  let lcm = monomial_lcm(tail1, tail2)
  let m1 = sdm_checked_monomial_div(lcm, tail1)
  let m2 = sdm_checked_monomial_div(lcm, tail2)
  let c = sdm_field_quo(fe_neg(sdm_LC(f, domain)), sdm_LC(g, domain))
  sdm_add(
    sdm_mul_term(f, (m1, fe_from_int(1, domain)), order, domain),
    sdm_mul_term(g, (m2, c), order, domain),
    order,
    domain,
  )
}

///|
/// Compute a Mora weak normal form.
///
/// - Does: Repeatedly reduces the leading module term using a divisor with
///   minimal ecart.
/// - Input: An SDM element, a basis array, a term order, and a coefficient
///   field.
/// - Returns: A weak normal form SDM element.
/// - Limits: The transformed phantom basis result is not exposed.
pub fn sdm_nf_mora(
  f : Sdm,
  basis : Array[Sdm],
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  let mut h = f
  let reducers : Array[Sdm] = []
  for g in basis {
    reducers.push(g)
  }
  while !h.is_empty() {
    let mut found = false
    let mut best : Sdm = []
    let mut best_ecart = 0
    for g in reducers {
      if g.is_empty() {
        continue
      }
      if sdm_monomial_divides(sdm_LM(g), sdm_LM(h)) {
        let current = sdm_ecart(g)
        if !found || current < best_ecart {
          found = true
          best = g
          best_ecart = current
        }
      }
    }
    if !found {
      break
    }
    if best_ecart > sdm_ecart(h) {
      reducers.push(h)
    }
    h = sdm_spoly(h, best, order, domain)
  }
  h
}

///|
/// Compute a Buchberger weak normal form.
///
/// - Does: Repeatedly reduces the leading module term by the first matching
///   divisor in the basis.
/// - Input: An SDM element, a basis array, a global term order, and a
///   coefficient field.
/// - Returns: A weak normal form SDM element.
/// - Limits: The transformed phantom basis result is not exposed.
pub fn sdm_nf_buchberger(
  f : Sdm,
  basis : Array[Sdm],
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  let mut h = f
  let reducers : Array[Sdm] = []
  for g in basis {
    reducers.push(g)
  }
  while !h.is_empty() {
    let mut found = false
    let mut reducer : Sdm = []
    for g in reducers {
      if g.is_empty() {
        continue
      }
      if sdm_monomial_divides(sdm_LM(g), sdm_LM(h)) {
        found = true
        reducer = g
        break
      }
    }
    if !found {
      break
    }
    h = sdm_spoly(h, reducer, order, domain)
  }
  h
}

///|
/// Compute a reduced Buchberger normal form.
///
/// - Does: Reduces repeatedly, appending each surviving leading term to the
///   result.
/// - Input: An SDM element, a basis array, a global term order, and a
///   coefficient field.
/// - Returns: A reduced normal form SDM element.
/// - Limits: Only the ordinary non-phantom front door is exposed.
pub fn sdm_nf_buchberger_reduced(
  f : Sdm,
  basis : Array[Sdm],
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  let mut h = sdm_zero()
  let mut g = f
  while !g.is_empty() {
    g = sdm_nf_buchberger(g, basis, order, domain)
    if !g.is_empty() {
      h = sdm_add(h, [sdm_LT(g)], order, domain)
      g = g[1:].to_owned()
    }
  }
  h
}

///|
fn sdm_pair_key_compare(
  left : SdmCriticalPair,
  right : SdmCriticalPair,
  order : TermOrder,
) -> Int {
  if left.2 != right.2 {
    return left.2 - right.2
  }
  let monom_cmp = compare_monomial_order(left.3, right.3, order)
  if monom_cmp != 0 {
    return monom_cmp
  }
  left.1 - right.1
}

///|
fn sdm_pair_sort_desc(
  pairs : Array[SdmCriticalPair],
  order : TermOrder,
) -> Unit {
  pairs.sort_by((left, right) => -sdm_pair_key_compare(left, right, order))
}

///|
fn sdm_sugar(
  i : Int,
  j : Int,
  basis : Array[Sdm],
  sugars : Array[Int],
) -> Int raise PolyError {
  let lm_i = sdm_LM(basis[i])
  let lm_j = sdm_LM(basis[j])
  let base = {
    let a = sugars[i] - sdm_monomial_deg(lm_i)
    let b = sugars[j] - sdm_monomial_deg(lm_j)
    if a > b {
      a
    } else {
      b
    }
  }
  base + sdm_monomial_deg(sdm_monomial_lcm(lm_i, lm_j))
}

///|
fn sdm_groebner_update(
  f : Sdm,
  sugar : Int,
  pairs : Array[SdmCriticalPair],
  basis : Array[Sdm],
  sugars : Array[Int],
  order : TermOrder,
) -> Array[SdmCriticalPair] raise PolyError {
  if f.is_empty() {
    return pairs
  }
  let k = basis.length()
  basis.push(f)
  sugars.push(sugar)
  let lm_f = sdm_LM(f)
  let lm_f_exps = lm_f.to_array()

  let filtered : Array[SdmCriticalPair] = []
  for pair in pairs {
    let (i, j, _, t) = pair
    if lm_f_exps[0] != t.to_array()[0] {
      filtered.push(pair)
      continue
    }
    let tik = sdm_monomial_lcm(lm_f, sdm_LM(basis[i]))
    let tjk = sdm_monomial_lcm(lm_f, sdm_LM(basis[j]))
    let remove = tik != t &&
      tjk != t &&
      sdm_monomial_divides(tik, t) &&
      sdm_monomial_divides(tjk, t)
    if !remove {
      filtered.push(pair)
    }
  }

  let new_pairs : Array[SdmCriticalPair] = []
  for i in 0..<k {
    let lm_i = sdm_LM(basis[i])
    if lm_f_exps[0] == lm_i.to_array()[0] {
      let lcm = sdm_monomial_lcm(lm_f, lm_i)
      new_pairs.push((i, k, sdm_sugar(i, k, basis, sugars), lcm))
    }
  }
  new_pairs.sort_by((left, right) => sdm_pair_key_compare(left, right, order))
  let remove_new = Array::make(new_pairs.length(), false)
  for i in 0..<new_pairs.length() {
    for j in (i + 1)..<new_pairs.length() {
      if sdm_monomial_divides(new_pairs[i].3, new_pairs[j].3) {
        remove_new.set(j, true)
      }
    }
  }
  for i in 0..<new_pairs.length() {
    if !remove_new[i] {
      filtered.push(new_pairs[i])
    }
  }
  sdm_pair_sort_desc(filtered, order)
  filtered
}

///|
fn sdm_apply_normal_form(
  normal_form : String,
  f : Sdm,
  basis : Array[Sdm],
  order : TermOrder,
  domain : Domain,
) -> Sdm raise PolyError {
  match normal_form {
    "buchberger" => sdm_nf_buchberger(f, basis, order, domain)
    "reduced" | "buchberger_reduced" =>
      sdm_nf_buchberger_reduced(f, basis, order, domain)
    _ => sdm_nf_mora(f, basis, order, domain)
  }
}

///|
/// Compute a minimal standard basis for sparse distributed modules.
///
/// - Does: Runs the sugar-strategy Buchberger loop over SDM generators and
///   interreduces leading module monomials at the end.
/// - Input: SDM generators, a term order, a coefficient field, and an optional
///   normal-form selector (`"mora"`, `"buchberger"`, or `"reduced"`).
/// - Returns: A minimal standard basis as an array of SDM elements.
/// - Limits: The extended transition-matrix result is not exposed.
pub fn sdm_groebner(
  generators : Array[Sdm],
  order : TermOrder,
  domain : Domain,
  normal_form? : String = "mora",
) -> Array[Sdm] raise PolyError {
  let basis : Array[Sdm] = []
  let sugars : Array[Int] = []
  let mut pairs : Array[SdmCriticalPair] = []
  let mut has_nonzero = false
  for f in generators {
    if !f.is_empty() {
      has_nonzero = true
      pairs = sdm_groebner_update(f, sdm_deg(f), pairs, basis, sugars, order)
    }
  }
  if !has_nonzero {
    return []
  }
  while !pairs.is_empty() {
    let pair = match pairs.pop() {
      Some(value) => value
      None => break
    }
    let (i, j, _, _) = pair
    let sp = sdm_spoly(basis[i], basis[j], order, domain)
    let h = sdm_apply_normal_form(normal_form, sp, basis, order, domain)
    pairs = sdm_groebner_update(
      h,
      sdm_sugar(i, j, basis, sugars),
      pairs,
      basis,
      sugars,
      order,
    )
  }

  let keep = Array::make(basis.length(), true)
  for ai in 0..<basis.length() {
    if !keep[ai] {
      continue
    }
    for bi in 0..<basis.length() {
      if ai != bi &&
        keep[bi] &&
        sdm_monomial_divides(sdm_LM(basis[ai]), sdm_LM(basis[bi])) {
        keep.set(bi, false)
      }
    }
  }
  let indexed : Array[(Sdm, Monomial)] = []
  for i in 0..<basis.length() {
    if keep[i] {
      indexed.push((basis[i], sdm_LM(basis[i])))
    }
  }
  indexed.sort_by((left, right) => {
    -compare_monomial_order(left.1, right.1, order)
  })
  indexed.map(item => item.0)
}
