///|
/// Parse a SymPy-like domain token (e.g. `ZZ`, `QQ`, `GF(7)`).
pub fn domain_from_string(spec : String) -> Domain raise PolyError {
  let s = spec.trim().to_string()
  match s {
    "ZZ" | "IntegerRing" => Domain::ZZ
    "QQ" | "RationalField" => Domain::QQ
    "RR" | "RealField" => Domain::RR
    "CC" | "ComplexField" => Domain::CC
    "ZZ_I" | "GaussianIntegerRing" => Domain::ZZ_I
    "QQ_I" | "GaussianRationalField" => Domain::QQ_I
    "EX" | "ExpressionDomain" => Domain::EX
    "EXRAW" | "ExpressionRawDomain" => Domain::EXRAW
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

fn find_matching_open_from_end(
  s : String,
  open_char : UInt16,
  close_char : UInt16,
) -> Int? {
  if s.is_empty() || s[s.length() - 1] != close_char {
    return None
  }
  let mut depth = 0
  let mut i = s.length()
  while i > 0 {
    i -= 1
    let ch = s[i]
    if ch == close_char {
      depth += 1
    } else if ch == open_char {
      depth -= 1
      if depth == 0 {
        return Some(i)
      }
    }
  }
  None
}

///|
fn find_matching_double_open_from_end(s : String) -> Int? {
  if s.length() < 4 || (try! s[s.length() - 2:s.length()]).to_string() != "]]" {
    return None
  }
  let mut depth = 0
  let mut i = s.length() - 2
  while i >= 0 {
    if i + 2 <= s.length() && (try! s[i:i + 2]).to_string() == "]]" {
      depth += 1
      if i == 0 {
        break
      }
      i -= 1
      continue
    }
    if i + 2 <= s.length() && (try! s[i:i + 2]).to_string() == "[[" {
      depth -= 1
      if depth == 0 {
        return Some(i)
      }
      if i == 0 {
        break
      }
      i -= 1
      continue
    }
    if i == 0 {
      break
    }
    i -= 1
  }
  None
}

///|
fn find_last_substring(s : String, needle : String) -> Int? {
  let n = needle.length()
  if n == 0 || n > s.length() {
    return None
  }
  let mut i = s.length() - n + 1
  while i > 0 {
    i -= 1
    if (try! s[i:i + n]).to_string() == needle {
      return Some(i)
    }
  }
  None
}

///|
fn split_gf_descriptor(raw : String, spec : String) -> (Int, Int?) raise PolyError {
  let body = raw.trim().to_string()
  if body.contains("**") {
    let parts : Array[String] = Array::new()
    for p in body.split("**") {
      parts.push(p.trim().to_string())
    }
    if parts.length() != 2 {
      raise PolyError::BadGenerator(spec)
    }
    let p = @strconv.parse_int(parts[0]) catch {
      _ => raise PolyError::BadGenerator(spec)
    }
    let k = @strconv.parse_int(parts[1]) catch {
      _ => raise PolyError::BadGenerator(spec)
    }
    return (p, Some(k))
  }
  if body.contains(",") {
    let parts : Array[String] = Array::new()
    for p in body.split(",") {
      parts.push(p.trim().to_string())
    }
    if parts.length() != 2 {
      raise PolyError::BadGenerator(spec)
    }
    let p = @strconv.parse_int(parts[0]) catch {
      _ => raise PolyError::BadGenerator(spec)
    }
    let k = @strconv.parse_int(parts[1]) catch {
      _ => raise PolyError::BadGenerator(spec)
    }
    return (p, Some(k))
  }
  let p = @strconv.parse_int(body) catch {
    _ => raise PolyError::BadGenerator(spec)
  }
  (p, None)
}

///|
fn parse_composite_domain(s : String) -> Domain raise PolyError {
  if (
    s.has_prefix("GF(") ||
    s.has_prefix("FF(") ||
    s.has_prefix("FiniteField(")
  ) &&
    s.has_suffix(")") {
    let left = match find_char(s, '(') {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let inner = (try! s[left + 1:s.length() - 1]).to_string()
    let parsed = split_gf_descriptor(inner, s)
    let p = parsed.0
    let ext_opt = parsed.1
    match ext_opt {
      Some(k) => {
        if p <= 1 || k <= 1 {
          raise PolyError::BadModulus
        }
        return Domain::GFExt(p, k, gfext_default_modulus(k))
      }
      None => {
        if p <= 1 {
          raise PolyError::BadModulus
        }
        return Domain::GF(p)
      }
    }
  }
  if s.contains("[[") {
    let right = match find_last_substring(s, "]]") {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let ps_head = (try! s[:right + 2]).to_string()
    let left = match find_matching_double_open_from_end(ps_head) {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let base = domain_from_string((try! s[:left]).to_string())
    let gens_str = (try! s[left + 2:right]).to_string()
    let gens = split_gens(gens_str)
    if right + 2 == s.length() {
      return Domain::PowerSeries(base, gens, -1)
    }
    if
      s.has_suffix(")") &&
      right + 8 <= s.length() - 1 &&
      (try! s[right + 2:right + 8]).to_string() == "(prec=" {
      let prec_text = (try! s[right + 8:s.length() - 1]).to_string()
      let precision = @strconv.parse_int(prec_text.trim().to_string()) catch {
        _ => raise PolyError::BadGenerator(s)
      }
      return Domain::PowerSeries(base, gens, precision)
    }
    raise PolyError::BadGenerator(s)
  }
  if s.contains("<") && s.has_suffix(">") {
    let left = match find_matching_open_from_end(s, '<', '>') {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let base = domain_from_string((try! s[:left]).to_string())
    let gens_str = (try! s[left + 1:s.length() - 1]).to_string()
    let gens = split_gens(gens_str)
    return Domain::AlgExt(base, gens, [])
  }
  if s.has_prefix("Frac(") && s.has_suffix(")") {
    let inner = (try! s[5:s.length() - 1]).to_string()
    return Domain::Frac(domain_from_string(inner))
  }
  if s.has_suffix("]") && !s.has_suffix("]]") {
    let left = match find_matching_open_from_end(s, '[', ']') {
      Some(pos) => pos
      None => raise PolyError::BadGenerator(s)
    }
    let base = domain_from_string((try! s[:left]).to_string())
    let gens_str = (try! s[left + 1:s.length() - 1]).to_string()
    let gens = split_gens(gens_str)
    return Domain::PolyRing(base, gens)
  }
  if s.contains("(") && s.has_suffix(")") {
    let left = match find_matching_open_from_end(s, '(', ')') {
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
fn gfext_default_modulus(k : Int) -> Array[Int] {
  let coeffs : Array[Int] = Array::make(k + 1, 0)
  coeffs.set(0, 1)
  coeffs.set(k, 1)
  coeffs
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
fn merge_gens(lhs : Array[String], rhs : Array[String]) -> Array[String] {
  let merged = lhs.copy()
  for g in rhs {
    if merged.contains(g) {
      continue
    }
    merged.push(g)
  }
  merged
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
      "\{domain_to_sympy_string(base)}<\{names}>"
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
/// Integer ring constructor alias.
pub fn integer_ring_domain() -> Domain {
  Domain::ZZ
}

///|
/// Rational field constructor alias.
pub fn rational_field_domain() -> Domain {
  Domain::QQ
}

///|
/// Real field constructor alias.
pub fn real_field_domain() -> Domain {
  Domain::RR
}

///|
/// Complex field constructor alias.
pub fn complex_field_domain() -> Domain {
  Domain::CC
}

///|
/// Gaussian integer ring constructor alias.
pub fn gaussian_integer_ring_domain() -> Domain {
  Domain::ZZ_I
}

///|
/// Gaussian rational field constructor alias.
pub fn gaussian_rational_field_domain() -> Domain {
  Domain::QQ_I
}

///|
/// Expression domain constructor alias.
pub fn expression_domain() -> Domain {
  Domain::EX
}

///|
/// Raw-expression domain constructor alias.
pub fn expression_raw_domain() -> Domain {
  Domain::EXRAW
}

///|
/// Alias for finite field constructors.
pub fn finite_field_domain(p : Int) -> Domain raise PolyError {
  gf_domain(p)
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
/// True when the domain is composite in SymPy's domain hierarchy.
pub fn domain_is_composite_pred(domain : Domain) -> Bool {
  match domain {
    Domain::PolyRing(_, _)
    | Domain::RationalFunctionField(_, _)
    | Domain::QuotientRing(_, _, _)
    | Domain::PowerSeries(_, _, _) => true
    _ => false
  }
}

///|
/// True for non-composite domains except Gaussian pair domains.
pub fn domain_is_simple_pred(domain : Domain) -> Bool {
  if domain_is_composite_pred(domain) {
    return false
  }
  match domain {
    Domain::ZZ_I | Domain::QQ_I => false
    _ => true
  }
}

///|
/// True when the domain supports additive/multiplicative ring operations.
pub fn domain_is_ring_pred(_domain : Domain) -> Bool {
  true
}

///|
/// True when coefficients are exact (no floating approximation semantics).
pub fn domain_is_exact_pred(domain : Domain) -> Bool {
  match domain {
    Domain::RR | Domain::CC => false
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
/// True when the domain elements are interpreted numerically.
pub fn domain_is_numerical_pred(domain : Domain) -> Bool {
  match domain {
    Domain::ZZ
    | Domain::QQ
    | Domain::RR
    | Domain::CC
    | Domain::ZZ_I
    | Domain::QQ_I
    | Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::AlgExt(_, _, _) => true
    _ => false
  }
}

///|
/// True for algebraic domains.
pub fn domain_is_algebraic_pred(domain : Domain) -> Bool {
  match domain {
    Domain::AlgExt(_, _, _) => true
    _ => false
  }
}

///|
/// True for algebraic field domains.
pub fn domain_is_algebraic_field_pred(domain : Domain) -> Bool {
  domain is Domain::AlgExt(_, _, _)
}

///|
/// True for domains that have an associated ring.
pub fn domain_has_assoc_ring_pred(domain : Domain) -> Bool {
  match domain {
    Domain::RR
    | Domain::CC
    | Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::EX
    | Domain::EXRAW
    | Domain::AlgExt(_, _, _) => false
    _ => true
  }
}

///|
/// Principal-ideal-domain predicate for migrated domain families.
pub fn domain_is_pid_pred(domain : Domain) -> Bool {
  match domain {
    Domain::RR | Domain::ZZ_I | Domain::PolyRing(_, _) | Domain::PowerSeries(_, _, _) => false
    Domain::QuotientRing(_, _, _) => false
    _ => true
  }
}

///|
pub fn domain_is_integer_ring_pred(domain : Domain) -> Bool {
  domain is Domain::ZZ
}

///|
pub fn domain_is_rational_field_pred(domain : Domain) -> Bool {
  domain is Domain::QQ
}

///|
pub fn domain_is_real_field_pred(domain : Domain) -> Bool {
  domain is Domain::RR
}

///|
pub fn domain_is_complex_field_pred(domain : Domain) -> Bool {
  domain is Domain::CC
}

///|
pub fn domain_is_gaussian_ring_pred(domain : Domain) -> Bool {
  domain is Domain::ZZ_I
}

///|
pub fn domain_is_gaussian_field_pred(domain : Domain) -> Bool {
  domain is Domain::QQ_I
}

///|
pub fn domain_is_expression_domain_pred(domain : Domain) -> Bool {
  domain is Domain::EX
}

///|
pub fn domain_is_expression_raw_domain_pred(domain : Domain) -> Bool {
  domain is Domain::EXRAW
}

///|
pub fn domain_is_cc_pred(domain : Domain) -> Bool {
  domain is Domain::CC
}

///|
pub fn domain_is_rr_pred(domain : Domain) -> Bool {
  domain is Domain::RR
}

///|
pub fn domain_is_zz_pred(domain : Domain) -> Bool {
  domain is Domain::ZZ
}

///|
pub fn domain_is_qq_pred(domain : Domain) -> Bool {
  domain is Domain::QQ
}

///|
pub fn domain_is_zz_i_pred(domain : Domain) -> Bool {
  domain is Domain::ZZ_I
}

///|
pub fn domain_is_qq_i_pred(domain : Domain) -> Bool {
  domain is Domain::QQ_I
}

///|
pub fn domain_is_symbolic_domain_pred(domain : Domain) -> Bool {
  domain is Domain::EX
}

///|
pub fn domain_is_symbolic_raw_domain_pred(domain : Domain) -> Bool {
  domain is Domain::EXRAW
}

///|
pub fn domain_is_ff_pred(domain : Domain) -> Bool {
  match domain {
    Domain::GF(_) | Domain::GFExt(_, _, _) => true
    _ => false
  }
}

///|
pub fn domain_is_frac_pred(domain : Domain) -> Bool {
  match domain {
    Domain::Frac(_) | Domain::RationalFunctionField(_, _) => true
    _ => false
  }
}

///|
pub fn domain_is_fraction_field_pred(domain : Domain) -> Bool {
  domain_is_frac_pred(domain)
}

///|
pub fn domain_is_poly_pred(domain : Domain) -> Bool {
  domain is Domain::PolyRing(_, _)
}

///|
pub fn domain_is_polynomial_ring_pred(domain : Domain) -> Bool {
  domain_is_poly_pred(domain)
}

///|
pub fn domain_is_finite_extension_pred(_domain : Domain) -> Bool {
  // SymPy finite fields and algebraic fields are not flagged as "FiniteExtension".
  false
}

///|
pub fn domain_has_assoc_field_pred(_domain : Domain) -> Bool {
  true
}

///|
pub fn domain_has_default_precision_pred(domain : Domain) -> Bool {
  match domain {
    Domain::RR | Domain::CC => true
    _ => false
  }
}

///|
pub fn domain_has_characteristic_zero_pred(domain : Domain) -> Bool {
  domain_characteristic(domain) == 0
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
/// Return an exact companion domain (`RR -> QQ`, `CC -> QQ_I`) recursively.
pub fn domain_get_exact(domain : Domain) -> Domain {
  match domain {
    Domain::RR => Domain::QQ
    Domain::CC => Domain::QQ_I
    Domain::Frac(inner) => Domain::Frac(domain_get_exact(inner))
    Domain::PolyRing(base, gens) => Domain::PolyRing(domain_get_exact(base), gens)
    Domain::RationalFunctionField(base, gens) =>
      Domain::RationalFunctionField(domain_get_exact(base), gens)
    Domain::QuotientRing(base, gens, rels) =>
      Domain::QuotientRing(domain_get_exact(base), gens, rels)
    Domain::PowerSeries(base, gens, prec) =>
      Domain::PowerSeries(domain_get_exact(base), gens, prec)
    Domain::AlgExt(base, gens, rels) =>
      Domain::AlgExt(domain_get_exact(base), gens, rels)
    _ => domain
  }
}

///|
/// Return a field associated with `domain` (when the conversion is known).
pub fn domain_get_field(domain : Domain) -> Domain raise PolyError {
  match domain {
    Domain::ZZ => Domain::QQ
    Domain::ZZ_I => Domain::QQ_I
    Domain::PolyRing(base, gens) => Domain::RationalFunctionField(base, gens)
    Domain::RationalFunctionField(_, _) => domain
    Domain::Frac(_) => domain
    Domain::QuotientRing(base, gens, rels) =>
      Domain::QuotientRing(domain_get_field(base), gens, rels)
    Domain::PowerSeries(base, gens, prec) =>
      Domain::PowerSeries(domain_get_field(base), gens, prec)
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
    Domain::ZZ | Domain::ZZ_I | Domain::RR | Domain::EX => domain
    Domain::Frac(inner) => inner
    Domain::RationalFunctionField(base, gens) =>
      Domain::PolyRing(base, gens)
    Domain::PolyRing(_, _) => domain
    Domain::QuotientRing(base, gens, rels) =>
      Domain::QuotientRing(domain_get_ring(base), gens, rels)
    Domain::PowerSeries(base, gens, prec) =>
      Domain::PowerSeries(domain_get_ring(base), gens, prec)
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Unify two domains into a common super-domain for mixed arithmetic.
pub fn domain_unify_pair(a : Domain, b : Domain) -> Domain raise PolyError {
  if a.equal(b) {
    return a
  }
  match (a, b) {
    (Domain::AlgExt(base1, gens1, rels1), Domain::AlgExt(base2, gens2, rels2)) =>
      if gens1.equal(gens2) && rels1.equal(rels2) {
        return Domain::AlgExt(domain_unify_pair(base1, base2), gens1, rels1)
      } else if rels1.is_empty() && rels2.is_empty() && gens1.length() == 1 &&
        gens2.length() == 1 {
        // SymPy often produces a primitive element for the combined extension.
        let unified_base = domain_unify_pair(base1, base2)
        return Domain::AlgExt(unified_base, ["\{gens1[0]}+\{gens2[0]}"], [])
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::AlgExt(base, gens, rels), other) | (other, Domain::AlgExt(base, gens, rels)) => {
      match other {
        Domain::RR | Domain::CC | Domain::EX | Domain::EXRAW => return other
        Domain::ZZ_I | Domain::QQ_I => {
          let lifted_base = domain_unify_pair(base, Domain::QQ)
          let merged_gen = if gens.is_empty() {
            "I"
          } else {
            let joined = gens.join("+")
            "\{joined}+I"
          }
          return Domain::AlgExt(lifted_base, [merged_gen], [])
        }
        Domain::PolyRing(other_base, syms) => {
          let merged_base = domain_unify_pair(
            Domain::AlgExt(base, gens, rels),
            other_base,
          )
          return Domain::PolyRing(merged_base, syms)
        }
        Domain::RationalFunctionField(other_base, syms) => {
          let merged_base = domain_unify_pair(
            Domain::AlgExt(base, gens, rels),
            other_base,
          )
          return Domain::RationalFunctionField(merged_base, syms)
        }
        Domain::Frac(other_inner) =>
          return Domain::Frac(
            domain_unify_pair(Domain::AlgExt(base, gens, rels), other_inner),
          )
        _ => ()
      }
      let unified = domain_unify_pair(base, other)
      if domain_is_field_pred(unified) {
        return Domain::AlgExt(unified, gens, rels)
      } else {
        raise PolyError::DomainMismatch
      }
    }
    (Domain::QuotientRing(base1, gens1, rels1), Domain::QuotientRing(base2, gens2, rels2)) =>
      if gens1.equal(gens2) && rels1.equal(rels2) {
        return Domain::QuotientRing(domain_unify_pair(base1, base2), gens1, rels1)
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::PowerSeries(base1, gens1, prec1), Domain::PowerSeries(base2, gens2, prec2)) =>
      if gens1.equal(gens2) && prec1 == prec2 {
        return Domain::PowerSeries(domain_unify_pair(base1, base2), gens1, prec1)
      } else {
        raise PolyError::DomainMismatch
      }
    _ => ()
  }
  if domain_is_composite_like(a) || domain_is_composite_like(b) {
    return unify_composite_domains(a, b)
  }
  let char_a = domain_characteristic(a)
  let char_b = domain_characteristic(b)
  if char_a != char_b {
    raise PolyError::DomainMismatch
  }
  match (a, b) {
    (Domain::EXRAW, _) | (_, Domain::EXRAW) => Domain::EXRAW
    (Domain::EX, _) | (_, Domain::EX) => Domain::EX
    (Domain::CC, _) | (_, Domain::CC) => Domain::CC
    (Domain::RR, Domain::QQ_I)
    | (Domain::QQ_I, Domain::RR)
    | (Domain::RR, Domain::ZZ_I)
    | (Domain::ZZ_I, Domain::RR) => Domain::CC
    (Domain::RR, _) | (_, Domain::RR) => Domain::RR
    (Domain::QQ, Domain::ZZ) | (Domain::ZZ, Domain::QQ) => Domain::QQ
    (Domain::QQ_I, Domain::QQ)
    | (Domain::QQ, Domain::QQ_I)
    | (Domain::QQ_I, Domain::ZZ)
    | (Domain::ZZ, Domain::QQ_I)
    | (Domain::QQ_I, Domain::ZZ_I)
    | (Domain::ZZ_I, Domain::QQ_I)
    | (Domain::ZZ_I, Domain::QQ)
    | (Domain::QQ, Domain::ZZ_I) => Domain::QQ_I
    (Domain::ZZ_I, Domain::ZZ) | (Domain::ZZ, Domain::ZZ_I) => Domain::ZZ_I
    (Domain::GF(p1), Domain::GF(p2)) =>
      if p1 == p2 {
        Domain::GF(p1)
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::GF(p), Domain::GFExt(q, k, m))
    | (Domain::GFExt(q, k, m), Domain::GF(p)) =>
      if p == q {
        Domain::GFExt(q, k, m)
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::GFExt(p1, k1, m1), Domain::GFExt(p2, k2, m2)) =>
      if p1 == p2 && k1 == k2 && m1.equal(m2) {
        Domain::GFExt(p1, k1, m1)
      } else {
        raise PolyError::DomainMismatch
      }
    (Domain::Frac(inner), rhs) => Domain::Frac(domain_unify_pair(inner, rhs))
    (lhs, Domain::Frac(inner)) => Domain::Frac(domain_unify_pair(lhs, inner))
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

///|
fn domain_is_poly_ring(domain : Domain) -> Bool {
  match domain {
    Domain::PolyRing(_, _) => true
    _ => false
  }
}

///|
fn domain_is_fraction_field_like(domain : Domain) -> Bool {
  match domain {
    Domain::RationalFunctionField(_, _) => true
    _ => false
  }
}

///|
fn domain_is_composite_like(domain : Domain) -> Bool {
  match domain {
    Domain::QuotientRing(_, _, _) | Domain::PowerSeries(_, _, _) => true
    _ => domain_is_poly_ring(domain) || domain_is_fraction_field_like(domain)
  }
}

///|
fn domain_ground(domain : Domain) -> Domain {
  match domain {
    Domain::PolyRing(base, _)
    | Domain::RationalFunctionField(base, _)
    | Domain::QuotientRing(base, _, _)
    | Domain::PowerSeries(base, _, _) => base
    _ => domain
  }
}

///|
fn domain_symbols(domain : Domain) -> Array[String] {
  match domain {
    Domain::PolyRing(_, gens)
    | Domain::RationalFunctionField(_, gens)
    | Domain::QuotientRing(_, gens, _)
    | Domain::PowerSeries(_, gens, _) => gens
    _ => []
  }
}

///|
fn domain_has_assoc_ring(domain : Domain) -> Bool {
  match domain {
    Domain::RR
    | Domain::EX
    | Domain::CC
    | Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::EXRAW
    | Domain::AlgExt(_, _, _) => false
    _ => true
  }
}

///|
fn lift_composite_domain(
  template : Domain,
  base : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  match template {
    Domain::PolyRing(_, _) => Domain::PolyRing(base, gens)
    Domain::RationalFunctionField(_, _) => Domain::RationalFunctionField(base, gens)
    Domain::QuotientRing(_, _, rels) => Domain::QuotientRing(base, gens, rels)
    Domain::PowerSeries(_, _, prec) => Domain::PowerSeries(base, gens, prec)
    _ => raise PolyError::DomainMismatch
  }
}

///|
fn unify_composite_domains(a : Domain, b : Domain) -> Domain raise PolyError {
  let ground_a = domain_ground(a)
  let ground_b = domain_ground(b)
  let mut ground = domain_unify_pair(ground_a, ground_b)
  let gens = merge_gens(domain_symbols(a), domain_symbols(b))

  // Match SymPy's composite coercion rule for PolyRing+FracField mixes.
  if (
    (
      (domain_is_fraction_field_like(a) && domain_is_poly_ring(b)) ||
      (domain_is_fraction_field_like(b) && domain_is_poly_ring(a))
    ) &&
    (!domain_is_field_pred(ground_a) || !domain_is_field_pred(ground_b)) &&
    domain_is_field_pred(ground) &&
    domain_has_assoc_ring(ground)
  ) {
    ground = domain_get_ring(ground)
  }

  let use_a = domain_is_composite_like(a) &&
    (!domain_is_composite_like(b) ||
      domain_is_fraction_field_like(a) ||
      domain_is_poly_ring(b))
  let template = if use_a { a } else { b }
  lift_composite_domain(template, ground, gens)
}

///|
/// Construct a polynomial ring over `domain`. Empty generators return `domain`.
pub fn domain_poly_ring(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    Domain::QuotientRing(_, _, _) => raise PolyError::DomainMismatch
    _ => poly_ring_domain(domain, gens)
  }
}

///|
/// Construct a fraction field over `domain`. Empty generators return `domain`.
pub fn domain_frac_field(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    Domain::QuotientRing(_, _, _) => raise PolyError::DomainMismatch
    _ => rational_function_field_domain(domain, gens)
  }
}

///|
/// Old polynomial ring compatibility alias.
pub fn domain_old_poly_ring(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_poly_ring(domain, gens)
}

///|
/// Old fraction field compatibility alias.
pub fn domain_old_frac_field(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_frac_field(domain, gens)
}

///|
/// Rebase a composite domain onto `ground`.
pub fn domain_set_domain(domain : Domain, ground : Domain) -> Domain {
  match domain {
    Domain::PolyRing(_, gens) => Domain::PolyRing(ground, gens)
    Domain::RationalFunctionField(_, gens) =>
      Domain::RationalFunctionField(ground, gens)
    Domain::QuotientRing(_, gens, rels) => Domain::QuotientRing(ground, gens, rels)
    Domain::PowerSeries(_, gens, prec) => Domain::PowerSeries(ground, gens, prec)
    Domain::Frac(_) => Domain::Frac(ground)
    Domain::AlgExt(_, gens, rels) => Domain::AlgExt(ground, gens, rels)
    _ => ground
  }
}

///|
/// Unify two domains while reserving `symbols` as external generators.
pub fn domain_unify_with_symbols(
  lhs : Domain,
  rhs : Domain,
  symbols : Array[String],
) -> Domain raise PolyError {
  if domain_is_composite_pred(lhs) && domain_symbols(lhs).any(s => symbols.contains(s)) {
    raise PolyError::BadGenerator(symbols.join(","))
  }
  if domain_is_composite_pred(rhs) && domain_symbols(rhs).any(s => symbols.contains(s)) {
    raise PolyError::BadGenerator(symbols.join(","))
  }
  domain_unify_pair(lhs, rhs)
}

///|
fn extension_names(extension : Array[@symcore.Expr]) -> Array[String] {
  let names : Array[String] = Array::new()
  for expr in extension {
    let name = @symprint.to_string(expr)
    if !names.contains(name) {
      names.push(name)
    }
  }
  names
}

///|
fn append_unique_exprs(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let out = lhs.copy()
  for expr in rhs {
    if !out.contains(expr) {
      out.push(expr)
    }
  }
  out
}

///|
/// Construct an algebraic extension over `QQ` or extend an existing one.
pub fn domain_algebraic_field(
  domain : Domain,
  extension : Array[@symcore.Expr],
) -> Domain raise PolyError {
  if extension.is_empty() {
    raise PolyError::BadGenerator("algebraic_field")
  }
  let ext_names = extension_names(extension)
  let merged_ext = [ext_names.join("+")]
  match domain {
    Domain::ZZ => domain_algebraic_field(Domain::QQ, extension)
    Domain::QQ => Domain::AlgExt(Domain::QQ, merged_ext, extension.copy())
    Domain::AlgExt(base, gens, rels) =>
      Domain::AlgExt(
        base,
        [merge_gens(gens, ext_names).join("+")],
        append_unique_exprs(rels, extension),
      )
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Inject fresh generators into `domain`.
pub fn domain_inject(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    Domain::PolyRing(base, existing) => {
      if existing.any(g => gens.contains(g)) {
        raise PolyError::BadGenerator(gens.join(","))
      }
      Domain::PolyRing(base, merge_gens(existing, gens))
    }
    Domain::RationalFunctionField(base, existing) => {
      if existing.any(g => gens.contains(g)) {
        raise PolyError::BadGenerator(gens.join(","))
      }
      Domain::RationalFunctionField(base, merge_gens(existing, gens))
    }
    Domain::PowerSeries(base, existing, prec) => {
      if existing.any(g => gens.contains(g)) {
        raise PolyError::BadGenerator(gens.join(","))
      }
      Domain::PowerSeries(base, merge_gens(existing, gens), prec)
    }
    Domain::QuotientRing(_, _, _) => raise PolyError::DomainMismatch
    _ => domain_poly_ring(domain, gens)
  }
}

///|
/// Drop generators from a domain, recursively through nested composites.
pub fn domain_drop(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    Domain::PolyRing(base, symbols) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        Domain::PolyRing(rebased, kept)
      }
    }
    Domain::RationalFunctionField(base, symbols) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        Domain::RationalFunctionField(rebased, kept)
      }
    }
    Domain::PowerSeries(base, symbols, prec) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        Domain::PowerSeries(rebased, kept, prec)
      }
    }
    Domain::QuotientRing(base, symbols, rels) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        Domain::QuotientRing(rebased, kept, rels)
      }
    }
    Domain::Frac(base) => {
      let rebased = domain_drop(base, gens)
      match rebased {
        Domain::PolyRing(_, _) | Domain::RationalFunctionField(_, _) => Domain::Frac(rebased)
        _ => rebased
      }
    }
    Domain::AlgExt(base, symbols, rels) => {
      if symbols.any(s => gens.contains(s)) {
        raise PolyError::BadGenerator(gens.join(","))
      }
      let rebased = domain_drop(base, gens)
      if rebased.equal(base) {
        domain
      } else {
        Domain::AlgExt(rebased, symbols, rels)
      }
    }
    _ => domain
  }
}

///|
fn expr_key(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr).replace_all(old=" ", new="")
}

///|
fn normalized_gen_keys(gens : Array[String]) -> Array[String] {
  gens.map(g => g.replace_all(old=" ", new=""))
}

///|
fn gen_symbol_name(gen : String) -> String? {
  let text = gen.trim().to_string()
  if text == "" {
    return None
  }
  if !text.contains("/") {
    if text.contains("(") || text.contains("[") || text.contains("<") {
      return None
    }
    return Some(text)
  }
  if text.has_prefix("1/") {
    let rest = (try! text[2:text.length()]).to_string().trim().to_string()
    if rest != "" && !rest.contains("/") && !rest.contains("(") && !rest.contains("[") &&
      !rest.contains("<") {
      return Some(rest)
    }
  }
  None
}

///|
fn generator_symbol_names(gens : Array[String]) -> Array[String] {
  let names : Array[String] = Array::new()
  for gen in gens {
    match gen_symbol_name(gen) {
      Some(name) if !names.contains(name) => names.push(name)
      _ => ()
    }
  }
  names
}

///|
fn expr_is_integer(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_integral()
    _ => false
  }
}

///|
fn expr_is_nonnegative_integer(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) =>
      n.is_integral() && n.compare(@symnum.BigRational::zero()) >= 0
    _ => false
  }
}

fn expr_has_forbidden_symbol(expr : @symcore.Expr, allow_i : Bool) -> Bool {
  match expr {
    @symcore.Expr::Number(_) => false
    @symcore.Expr::Symbol(name) => if allow_i { name != "I" } else { true }
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) => args.any(item =>
      expr_has_forbidden_symbol(item, allow_i)
    )
    @symcore.Expr::Pow(base, exp) =>
      expr_has_forbidden_symbol(base, allow_i) || expr_has_forbidden_symbol(exp, allow_i)
  }
}

///|
fn expr_is_imaginary_unit(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name == "I"
    _ => false
  }
}

///|
fn gaussian_term_in_domain(expr : @symcore.Expr, coeff_dom : Domain) -> Bool {
  if expr_is_imaginary_unit(expr) {
    return true
  }
  if domain_contains_expr(coeff_dom, expr) {
    return true
  }
  match expr {
    @symcore.Expr::Mul(args) => {
      let mut imag_count = 0
      let coeffs : Array[@symcore.Expr] = Array::new()
      for arg in args {
        if expr_is_imaginary_unit(arg) {
          imag_count += 1
        } else {
          coeffs.push(arg)
        }
      }
      imag_count == 1 && domain_contains_expr(
        coeff_dom,
        if coeffs.is_empty() { @symcore.int(1) } else { @symcore.mul(coeffs) },
      )
    }
    _ => false
  }
}

///|
fn expr_in_algext(
  base : Domain,
  gens : Array[String],
  rels : Array[@symcore.Expr],
  expr : @symcore.Expr,
) -> Bool {
  if domain_contains_expr(base, expr) {
    return true
  }
  let allowed = normalized_gen_keys(gens)
  let rel_keys = rels.map(expr_key)
  let all_allowed = allowed.copy()
  for key in rel_keys {
    if !all_allowed.contains(key) {
      all_allowed.push(key)
    }
  }
  match expr {
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) => args.all(item =>
      expr_in_algext(base, gens, rels, item)
    )
    @symcore.Expr::Pow(inner, exp) =>
      expr_is_integer(exp) && expr_in_algext(base, gens, rels, inner)
    _ => all_allowed.contains(expr_key(expr))
  }
}

///|
fn expr_in_polynomial_domain(
  base : Domain,
  gens : Array[String],
  expr : @symcore.Expr,
) -> Bool {
  if domain_contains_expr(base, expr) {
    return true
  }
  let symbols = generator_symbol_names(gens)
  match expr {
    @symcore.Expr::Number(_) => domain_contains_expr(base, expr)
    @symcore.Expr::Symbol(name) => symbols.contains(name)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.all(item => expr_in_polynomial_domain(base, gens, item))
    @symcore.Expr::Pow(inner, exp) =>
      expr_is_nonnegative_integer(exp) && expr_in_polynomial_domain(base, gens, inner)
    @symcore.Expr::Function(_, _) => false
  }
}

///|
fn expr_in_fraction_domain(
  base : Domain,
  gens : Array[String],
  expr : @symcore.Expr,
) -> Bool {
  if domain_contains_expr(base, expr) {
    return true
  }
  let symbols = generator_symbol_names(gens)
  match expr {
    @symcore.Expr::Number(_) => domain_contains_expr(base, expr)
    @symcore.Expr::Symbol(name) => symbols.contains(name)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.all(item => expr_in_fraction_domain(base, gens, item))
    @symcore.Expr::Pow(inner, exp) =>
      expr_is_integer(exp) && expr_in_fraction_domain(base, gens, inner)
    @symcore.Expr::Function(_, _) => false
  }
}

///|
/// Check whether an expression belongs to the given domain.
pub fn domain_contains_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  match domain {
    Domain::EX | Domain::EXRAW => true
    Domain::ZZ => {
      match expr {
        @symcore.Expr::Number(n) => n.is_integral()
        _ => false
      }
    }
    Domain::QQ => expr is @symcore.Expr::Number(_)
    Domain::RR => !expr_has_forbidden_symbol(expr, false)
    Domain::CC => !expr_has_forbidden_symbol(expr, true)
    Domain::ZZ_I => {
      match expr {
        @symcore.Expr::Add(args) => args.all(item => gaussian_term_in_domain(item, Domain::ZZ))
        _ => gaussian_term_in_domain(expr, Domain::ZZ)
      }
    }
    Domain::QQ_I => {
      match expr {
        @symcore.Expr::Add(args) => args.all(item => gaussian_term_in_domain(item, Domain::QQ))
        _ => gaussian_term_in_domain(expr, Domain::QQ)
      }
    }
    Domain::GF(_) | Domain::GFExt(_, _, _) => {
      match expr {
        @symcore.Expr::Number(n) => n.is_integral()
        _ => false
      }
    }
    Domain::AlgExt(base, gens, rels) => expr_in_algext(base, gens, rels, expr)
    Domain::PolyRing(base, gens)
    | Domain::QuotientRing(base, gens, _)
    | Domain::PowerSeries(base, gens, _) => expr_in_polynomial_domain(base, gens, expr)
    Domain::RationalFunctionField(base, gens) => expr_in_fraction_domain(base, gens, expr)
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) =>
          expr_in_fraction_domain(inner, gens, expr)
        _ => domain_contains_expr(base, expr)
    }
  }
}

///|
pub fn Domain::contains_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_contains_expr(self, expr)
}

///|
fn expr_depends_on_symbols(expr : @symcore.Expr, symbols : Array[String]) -> Bool {
  match expr {
    @symcore.Expr::Number(_) => false
    @symcore.Expr::Symbol(name) => symbols.contains(name)
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) => args.any(item =>
      expr_depends_on_symbols(item, symbols)
    )
    @symcore.Expr::Pow(base, exp) =>
      expr_depends_on_symbols(base, symbols) || expr_depends_on_symbols(exp, symbols)
  }
}

///|
fn expr_zero() -> @symcore.Expr {
  @symcore.int(0)
}

///|
fn domain_expr_is_zero(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn domain_expr_is_one(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_one()
    _ => false
  }
}

///|
fn domain_expr_is_minus_one(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) =>
      n.compare(@symnum.BigRational::from_int(-1)) == 0
    _ => false
  }
}

fn expr_constant_term(expr : @symcore.Expr, symbols : Array[String]) -> @symcore.Expr? {
  if !expr_depends_on_symbols(expr, symbols) {
    return Some(expr)
  }
  match expr {
    @symcore.Expr::Number(_) => Some(expr)
    @symcore.Expr::Symbol(name) =>
      if symbols.contains(name) {
        Some(expr_zero())
      } else {
        Some(expr)
      }
    @symcore.Expr::Add(args) => {
      let parts : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match expr_constant_term(arg, symbols) {
          Some(part) => parts.push(part)
          None => return None
        }
      }
      Some(@symcore.add(parts))
    }
    @symcore.Expr::Mul(args) => {
      let parts : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match expr_constant_term(arg, symbols) {
          Some(part) => parts.push(part)
          None => return None
        }
      }
      Some(@symcore.mul(parts))
    }
    @symcore.Expr::Pow(base, exp) =>
      if expr_is_nonnegative_integer(exp) {
        match expr_constant_term(base, symbols) {
          Some(term) => Some(@symcore.pow(term, exp))
          None => None
        }
      } else {
        None
      }
    @symcore.Expr::Function(_, args) =>
      if args.any(arg => expr_depends_on_symbols(arg, symbols)) {
        None
      } else {
        Some(expr)
      }
  }
}

///|
pub fn domain_is_zero_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  domain_contains_expr(domain, expr) && domain_expr_is_zero(expr)
}

///|
pub fn domain_is_one_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  domain_contains_expr(domain, expr) && domain_expr_is_one(expr)
}

///|
pub fn domain_is_unit_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  if !domain_contains_expr(domain, expr) {
    return false
  }
  match domain {
    Domain::ZZ => domain_expr_is_one(expr) || domain_expr_is_minus_one(expr)
    Domain::QQ
    | Domain::RR
    | Domain::CC
    | Domain::QQ_I
    | Domain::EX
    | Domain::EXRAW
    | Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::RationalFunctionField(_, _)
    | Domain::Frac(_)
    | Domain::AlgExt(_, _, _) => !domain_expr_is_zero(expr)
    Domain::ZZ_I => domain_expr_is_one(expr) || domain_expr_is_minus_one(expr)
    Domain::PolyRing(base, gens) =>
      !expr_depends_on_symbols(expr, generator_symbol_names(gens)) &&
      domain_is_unit_expr(base, expr)
    Domain::QuotientRing(base, gens, _) =>
      !expr_depends_on_symbols(expr, generator_symbol_names(gens)) &&
      domain_is_unit_expr(base, expr)
    Domain::PowerSeries(base, gens, _) => {
      match expr_constant_term(expr, generator_symbol_names(gens)) {
        Some(c0) => domain_is_unit_expr(base, c0)
        None => false
      }
    }
  }
}

///|
pub fn Domain::is_zero_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_zero_expr(self, expr)
}

///|
pub fn Domain::is_one_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_one_expr(self, expr)
}

///|
pub fn Domain::is_unit_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_unit_expr(self, expr)
}

///|
pub fn Domain::characteristic(self : Domain) -> Int {
  domain_characteristic(self)
}

///|
pub fn Domain::get_exact(self : Domain) -> Domain {
  domain_get_exact(self)
}

///|
pub fn Domain::get_field(self : Domain) -> Domain raise PolyError {
  domain_get_field(self)
}

///|
pub fn Domain::get_ring(self : Domain) -> Domain raise PolyError {
  domain_get_ring(self)
}

///|
pub fn Domain::unify(self : Domain, other : Domain) -> Domain raise PolyError {
  domain_unify_pair(self, other)
}

///|
pub fn Domain::unify_with_symbols(
  self : Domain,
  other : Domain,
  symbols : Array[String],
) -> Domain raise PolyError {
  domain_unify_with_symbols(self, other, symbols)
}

///|
pub fn Domain::poly_ring(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_poly_ring(self, gens)
}

///|
pub fn Domain::frac_field(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_frac_field(self, gens)
}

///|
pub fn Domain::old_poly_ring(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_old_poly_ring(self, gens)
}

///|
pub fn Domain::old_frac_field(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_old_frac_field(self, gens)
}

///|
pub fn Domain::set_domain(self : Domain, ground : Domain) -> Domain {
  domain_set_domain(self, ground)
}

///|
pub fn Domain::algebraic_field(
  self : Domain,
  extension : Array[@symcore.Expr],
) -> Domain raise PolyError {
  domain_algebraic_field(self, extension)
}

///|
pub fn Domain::inject(self : Domain, gens : Array[String]) -> Domain raise PolyError {
  domain_inject(self, gens)
}

///|
pub fn Domain::drop(self : Domain, gens : Array[String]) -> Domain raise PolyError {
  domain_drop(self, gens)
}
