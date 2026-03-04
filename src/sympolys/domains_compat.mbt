///|
/// Parse a SymPy-like domain token (e.g. `ZZ`, `QQ`, `GF(7)`).
pub fn domain_from_string(spec : String) -> Domain raise PolyError {
  let s = spec.trim().to_string()
  match s {
    "ZZ" => Domain::ZZ
    "QQ" => Domain::QQ
    "RR" => Domain::RR
    "CC" => Domain::CC
    "ZZ_I" => Domain::ZZ_I
    "QQ_I" => Domain::QQ_I
    "EX" => Domain::EX
    "EXRAW" => Domain::EXRAW
    _ => parse_composite_domain(s)
  }
}

///|
fn find_char(s : String, needle : UInt16) -> Int? {
  for i in 0..<s.length() {
    if s[i] == needle {
      return Some(i)
    }
  }
  None
}

///|
fn parse_composite_domain(s : String) -> Domain raise PolyError {
  if s.has_prefix("GF(") && s.has_suffix(")") {
    let inner = (try! s[3:s.length() - 1]).to_string()
    let p = @strconv.parse_int(inner) catch {
      _ => raise PolyError::BadGenerator(s)
    }
    if p <= 1 {
      raise PolyError::BadModulus
    }
    return Domain::GF(p)
  }
  if s.contains("[") && s.has_suffix("]") {
    let left = match find_char(s, '[') {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let base = domain_from_string((try! s[:left]).to_string())
    let gens_str = (try! s[left + 1:s.length() - 1]).to_string()
    let gens = split_gens(gens_str)
    return Domain::PolyRing(base, gens)
  }
  if s.contains("(") && s.has_suffix(")") {
    let left = match find_char(s, '(') {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let base = domain_from_string((try! s[:left]).to_string())
    let gens_str = (try! s[left + 1:s.length() - 1]).to_string()
    let gens = split_gens(gens_str)
    return Domain::RationalFunctionField(base, gens)
  }
  raise PolyError::BadGenerator(s)
}

///|
fn split_gens(text : String) -> Array[String] raise PolyError {
  let raw = text.trim().to_string()
  if raw == "" {
    raise PolyError::BadGenerator(text)
  }
  let normalized : Array[String] = Array::new()
  for g in raw.split(",") {
    let name = g.trim().to_string()
    if name == "" {
      raise PolyError::BadGenerator(text)
    }
    if normalized.contains(name) {
      continue
    }
    normalized.push(name)
  }
  if normalized.is_empty() {
    raise PolyError::BadGenerator(text)
  }
  normalized
}

///|
/// Render a domain with a SymPy-compatible high-level string form.
pub fn domain_to_sympy_string(domain : Domain) -> String {
  match domain {
    Domain::ZZ => "ZZ"
    Domain::QQ => "QQ"
    Domain::RR => "RR"
    Domain::CC => "CC"
    Domain::ZZ_I => "ZZ_I"
    Domain::QQ_I => "QQ_I"
    Domain::EX => "EX"
    Domain::EXRAW => "EXRAW"
    Domain::GF(p) => "GF(\{p})"
    Domain::GFExt(p, k, _) => "GF(\{p}**\{k})"
    Domain::Frac(inner) => "Frac(\{domain_to_sympy_string(inner)})"
    Domain::PolyRing(base, gens) => {
      let names = gens.join(",")
      "\{domain_to_sympy_string(base)}[\{names}]"
    }
    Domain::RationalFunctionField(base, gens) => {
      let names = gens.join(",")
      "\{domain_to_sympy_string(base)}(\{names})"
    }
    Domain::QuotientRing(base, gens, rels) => {
      let names = gens.join(",")
      let rels_str = rels.map(r => @symprint.to_string(r)).join(",")
      "\{domain_to_sympy_string(base)}[\{names}]/<\{rels_str}>"
    }
    Domain::PowerSeries(base, gens, prec) => {
      let names = gens.join(",")
      if prec < 0 {
        "\{domain_to_sympy_string(base)}[[\{names}]]"
      } else {
        "\{domain_to_sympy_string(base)}[[\{names}]](prec=\{prec})"
      }
    }
    Domain::AlgExt(base, gens, _) => {
      let names = gens.join(",")
      "\{domain_to_sympy_string(base)}(\{names})"
    }
  }
}

///|
/// Alias of SymPy `GF` constructor for prime finite fields.
pub fn gf_domain(p : Int) -> Domain raise PolyError {
  if p <= 1 {
    raise PolyError::BadModulus
  }
  Domain::GF(p)
}

///|
/// Alias for `GF` used in SymPy (`FF == GF`).
pub fn ff_domain(p : Int) -> Domain raise PolyError {
  gf_domain(p)
}

///|
/// Build a polynomial ring descriptor `K[x1, ..., xn]`.
pub fn poly_ring_domain(
  base : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  Domain::PolyRing(base, split_gens(gens.join(",")))
}

///|
/// Build a rational-function field descriptor `K(x1, ..., xn)`.
pub fn rational_function_field_domain(
  base : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  Domain::RationalFunctionField(base, split_gens(gens.join(",")))
}

///|
/// Build a quotient-ring descriptor `(K[x])/I`.
pub fn quotient_ring_domain(
  base : Domain,
  gens : Array[String],
  rels : Array[@symcore.Expr],
) -> Domain raise PolyError {
  let normalized = split_gens(gens.join(","))
  if rels.is_empty() {
    raise PolyError::NonPolynomial
  }
  Domain::QuotientRing(base, normalized, rels)
}

///|
/// Build a formal power-series ring descriptor.
pub fn power_series_domain(
  base : Domain,
  gens : Array[String],
  precision? : Int = -1,
) -> Domain raise PolyError {
  let normalized = split_gens(gens.join(","))
  Domain::PowerSeries(base, normalized, precision)
}

///|
/// True when the domain is a field in the current compatibility model.
pub fn domain_is_field_pred(domain : Domain) -> Bool {
  match domain {
    Domain::QQ
    | Domain::RR
    | Domain::CC
    | Domain::QQ_I
    | Domain::EX
    | Domain::EXRAW
    | Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::Frac(_)
    | Domain::RationalFunctionField(_, _) => true
    Domain::AlgExt(base, _, _) => domain_is_field_pred(base)
    _ => false
  }
}

///|
/// True when the domain supports additive/multiplicative ring operations.
pub fn domain_is_ring_pred(domain : Domain) -> Bool {
  match domain {
    Domain::RationalFunctionField(_, _) => false
    _ => true
  }
}

///|
/// True when coefficients are exact (no floating approximation semantics).
pub fn domain_is_exact_pred(domain : Domain) -> Bool {
  match domain {
    Domain::RR | Domain::CC | Domain::EX | Domain::EXRAW => false
    Domain::AlgExt(base, _, _) => domain_is_exact_pred(base)
    Domain::PolyRing(base, _)
    | Domain::RationalFunctionField(base, _)
    | Domain::QuotientRing(base, _, _)
    | Domain::PowerSeries(base, _, _)
    | Domain::Frac(base) => domain_is_exact_pred(base)
    _ => true
  }
}

///|
/// True when the coefficient domain has finitely many elements.
pub fn domain_is_finite_pred(domain : Domain) -> Bool {
  match domain {
    Domain::GF(_) | Domain::GFExt(_, _, _) => true
    Domain::AlgExt(base, _, _) => domain_is_finite_pred(base)
    _ => false
  }
}

///|
/// Return the domain characteristic (`0` for characteristic-zero domains).
pub fn domain_characteristic(domain : Domain) -> Int {
  match domain {
    Domain::GF(p) => p
    Domain::GFExt(p, _, _) => p
    Domain::AlgExt(base, _, _)
    | Domain::PolyRing(base, _)
    | Domain::RationalFunctionField(base, _)
    | Domain::QuotientRing(base, _, _)
    | Domain::PowerSeries(base, _, _)
    | Domain::Frac(base) => domain_characteristic(base)
    _ => 0
  }
}

///|
/// Return a field associated with `domain` (when the conversion is known).
pub fn domain_get_field(domain : Domain) -> Domain raise PolyError {
  match domain {
    Domain::ZZ => Domain::QQ
    Domain::ZZ_I => Domain::QQ_I
    Domain::PolyRing(base, gens) =>
      Domain::RationalFunctionField(domain_get_field(base), gens)
    Domain::QuotientRing(base, gens, rels) =>
      Domain::QuotientRing(domain_get_field(base), gens, rels)
    Domain::PowerSeries(base, gens, prec) =>
      Domain::PowerSeries(domain_get_field(base), gens, prec)
    Domain::Frac(inner) => Domain::Frac(domain_get_field(inner))
    _ =>
      if domain_is_field_pred(domain) {
        domain
      } else {
        raise PolyError::DomainNotField
      }
  }
}

///|
/// Return a ring associated with `domain` (when one is naturally defined).
pub fn domain_get_ring(domain : Domain) -> Domain raise PolyError {
  match domain {
    Domain::QQ => Domain::ZZ
    Domain::QQ_I => Domain::ZZ_I
    Domain::Frac(inner) => inner
    Domain::RationalFunctionField(base, gens) =>
      Domain::PolyRing(domain_get_ring(base), gens)
    Domain::PolyRing(base, gens) =>
      Domain::PolyRing(domain_get_ring(base), gens)
    Domain::QuotientRing(base, gens, rels) =>
      Domain::QuotientRing(domain_get_ring(base), gens, rels)
    _ =>
      if domain_is_ring_pred(domain) {
        domain
      } else {
        raise PolyError::DomainMismatch
      }
  }
}

///|
/// Unify two domains into a common super-domain for mixed arithmetic.
pub fn domain_unify_pair(a : Domain, b : Domain) -> Domain raise PolyError {
  if a.equal(b) {
    return a
  }
  match (a, b) {
    (Domain::EXRAW, _) | (_, Domain::EXRAW) => Domain::EXRAW
    (Domain::EX, _) | (_, Domain::EX) => Domain::EX
    (Domain::QQ, Domain::ZZ) | (Domain::ZZ, Domain::QQ) => Domain::QQ
    (Domain::QQ_I, Domain::ZZ_I) | (Domain::ZZ_I, Domain::QQ_I) => Domain::QQ_I
    (Domain::GF(p1), Domain::GF(p2)) =>
      if p1 == p2 {
        Domain::GF(p1)
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::GFExt(p1, k1, m1), Domain::GFExt(p2, k2, m2)) =>
      if p1 == p2 && k1 == k2 && m1.equal(m2) {
        Domain::GFExt(p1, k1, m1)
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::PolyRing(base, gens), rhs) =>
      Domain::PolyRing(domain_unify_pair(base, rhs), gens)
    (lhs, Domain::PolyRing(base, gens)) =>
      Domain::PolyRing(domain_unify_pair(lhs, base), gens)
    (Domain::RationalFunctionField(base, gens), rhs) =>
      Domain::RationalFunctionField(domain_unify_pair(base, rhs), gens)
    (lhs, Domain::RationalFunctionField(base, gens)) =>
      Domain::RationalFunctionField(domain_unify_pair(lhs, base), gens)
    (Domain::Frac(inner), rhs) => Domain::Frac(domain_unify_pair(inner, rhs))
    (lhs, Domain::Frac(inner)) => Domain::Frac(domain_unify_pair(lhs, inner))
    (Domain::RR, Domain::CC) | (Domain::CC, Domain::RR) => Domain::CC
    _ => {
      if domain_is_field_pred(a) && domain_is_ring_pred(b) {
        return a
      }
      if domain_is_field_pred(b) && domain_is_ring_pred(a) {
        return b
      }
      raise PolyError::DomainMismatch
    }
  }
}
