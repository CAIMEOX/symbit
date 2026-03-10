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
/// Unify two domains where at least one side is composite.
pub fn domain_unify_composite(lhs : Domain, rhs : Domain) -> Domain raise PolyError {
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

fn expr_replace_symbol(
  expr : @symcore.Expr,
  old_name : String,
  new_name : String,
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(_) => expr
    @symcore.Expr::Symbol(name) =>
      if name == old_name {
        @symcore.symbol(new_name)
      } else {
        expr
      }
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(arg => expr_replace_symbol(arg, old_name, new_name)))
    @symcore.Expr::Mul(args) =>
      @symcore.mul(args.map(arg => expr_replace_symbol(arg, old_name, new_name)))
    @symcore.Expr::Pow(base, exp) =>
      expr_replace_symbol(base, old_name, new_name) ^
      expr_replace_symbol(exp, old_name, new_name)
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(arg => expr_replace_symbol(arg, old_name, new_name)))
  }
}

fn poly_with_generator(poly : Poly, gen : String, domain : Domain) -> Poly raise PolyError {
  guard poly.gens.length() == 1 else { raise PolyError::NotUnivariate }
  let raw = if poly.gens[0] == gen {
    poly.to_expr()
  } else {
    expr_replace_symbol(poly.to_expr(), poly.gens[0], gen)
  }
  Poly::from_expr(raw, [gen], domain)
}

fn poly_univar_coeff(poly : Poly, exp : Int) -> FieldElem raise PolyError {
  guard poly.gens.length() == 1 else { raise PolyError::NotUnivariate }
  let mono = monomial_from_array([exp])
  match poly.coeffs.get(mono) {
    Some(coeff) => coeff
    None => fe_from_int(0, poly.domain)
  }
}

fn normalize_root_index(poly : Poly, root_index : Int) -> Int raise PolyError {
  let degree = poly.degree(0)
  guard degree >= 1 else { raise PolyError::NonPolynomial }
  if root_index >= degree {
    raise PolyError::BadExponent
  }
  if root_index >= 0 {
    return root_index
  }
  let wrapped = root_index % degree
  if wrapped < 0 {
    wrapped + degree
  } else {
    wrapped
  }
}

fn default_algext_gen(poly : Poly, root_index : Int) -> String raise PolyError {
  let degree = poly.degree(0)
  if degree == 1 {
    let lead = poly_univar_coeff(poly, 1)
    let const_term = poly_univar_coeff(poly, 0)
    let root = fe_to_expr_const(fe_mul(fe_neg(const_term), fe_inv(lead)))
    return @symprint.to_string(root)
  }
  let idx = normalize_root_index(poly, root_index)
  let poly_text = @symprint.to_string(poly.to_expr()).replace_all(old="+ -", new="- ")
  return "CRootOf(\{poly_text}, \{idx})"
}

///|
pub fn domain_alg_field_from_poly(
  domain : Domain,
  poly : Poly,
  alias? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  ignore(root_index)
  let base = match domain {
    Domain::ZZ => Domain::QQ
    _ => domain
  }
  let gen = match alias {
    Some(name) if name != "" => name
    _ => default_algext_gen(poly, root_index)
  }
  let lifted = poly_with_generator(poly, gen, base)
  build_alg_extension(alg_ext_spec(base, gen, lifted))
}

fn cyclotomic_poly_domain(
  n : Int,
  gen : String,
) -> Poly raise PolyError {
  guard n > 0 else { raise PolyError::BadExponent }
  let x = @symcore.symbol(gen)
  let mut poly = Poly::from_expr((x ^ @symcore.int(n)) - @symcore.int(1), [gen], Domain::QQ)
  for d in 1..<n {
    if n % d == 0 {
      poly = poly.div_exact_univar(cyclotomic_poly_domain(d, gen))
    }
  }
  poly
}

///|
pub fn domain_cyclotomic_field(
  domain : Domain,
  n : Int,
  ss? : Bool = false,
  alias? : String = "zeta",
  gen? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  let ext_alias = if ss { "\{alias}\{n}" } else { alias }
  let poly_gen = match gen {
    Some(name) => name
    None => ext_alias
  }
  let poly = cyclotomic_poly_domain(n, poly_gen)
  domain_alg_field_from_poly(domain, poly, alias=Some(ext_alias), root_index=root_index)
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
        _ =>
          try domain_get_field(base) catch {
            _ => domain_contains_expr(base, expr)
          } noraise {
            field => domain_contains_expr(field, expr)
          }
      }
  }
}

///|
pub fn Domain::contains_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_contains_expr(self, expr)
}

///|
pub fn Domain::of_type_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_contains_expr(self, expr)
}

///|
/// Convert a SymPy-style expression into a canonical element of `domain`.
pub fn domain_from_sympy_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  match domain {
    Domain::ZZ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() => expr_from_bigint(value.numerator())
        _ => raise PolyError::DomainMismatch
      }
    Domain::QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_rational(value)
        None => raise PolyError::DomainMismatch
      }
    Domain::ZZ_I => gaussian_int_to_expr(gaussian_int_from_expr(domain, expr))
    Domain::QQ_I => gaussian_rat_to_expr(gaussian_rat_from_expr(domain, expr))
    Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::RR
    | Domain::CC =>
      domain_field_elem_to_expr(domain, field_elem_from_scalar_expr(expr, domain))
    Domain::AlgExt(base, gens, rels) =>
      if rels.is_empty() {
        guard expr_in_algext(base, gens, rels, expr) else { raise PolyError::DomainMismatch }
        expr
      } else {
        domain_field_elem_to_expr(domain, field_elem_from_scalar_expr(expr, domain))
      }
    Domain::PolyRing(base, gens)
    | Domain::QuotientRing(base, gens, _)
    | Domain::PowerSeries(base, gens, _) => Poly::from_expr(expr, gens, base).to_expr()
    Domain::RationalFunctionField(base, gens) => {
      let (numer, denom) = rational_function_pair_from_expr(base, gens, expr)
      rational_function_expr_from_pair(numer, denom, base)
    }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) => {
          let (numer, denom) = rational_function_pair_from_expr(inner, gens, expr)
          rational_function_expr_from_pair(numer, denom, inner)
        }
        _ => domain_from_sympy_expr(domain_get_field(base), expr)
      }
    Domain::EX | Domain::EXRAW => expr
  }
}

///|
/// Convert an internal domain element back to a SymPy-style expression.
pub fn domain_to_sympy_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_from_sympy_expr(domain, expr)
}

///|
/// Convert an expression from `base` into `domain`, mirroring `convert_from`.
pub fn domain_convert_from_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr raise PolyError {
  let scalar_target = match domain {
    Domain::PolyRing(_, _)
    | Domain::RationalFunctionField(_, _)
    | Domain::QuotientRing(_, _, _)
    | Domain::PowerSeries(_, _, _)
    | Domain::Frac(_) => false
    _ => true
  }
  if scalar_target {
    match base {
      Domain::PolyRing(inner, gens)
      | Domain::QuotientRing(inner, gens, _)
      | Domain::PowerSeries(inner, gens, _) => {
        guard !expr_depends_on_symbols(expr, gens) else { raise PolyError::DomainMismatch }
        return domain_convert_from_expr(domain, expr, inner)
      }
      Domain::RationalFunctionField(_, _) => raise PolyError::DomainMismatch
      Domain::Frac(inner) =>
        match inner {
          Domain::PolyRing(_, _) | Domain::RationalFunctionField(_, _) =>
            raise PolyError::DomainMismatch
          _ => ()
        }
      Domain::AlgExt(inner, gens, _) => {
        guard !expr_depends_on_symbols(expr, gens) else { raise PolyError::DomainMismatch }
        return domain_convert_from_expr(domain, expr, inner)
      }
      _ => ()
    }
  }
  let lifted = match base {
    Domain::RR | Domain::CC | Domain::EX | Domain::EXRAW => expr
    _ => domain_to_sympy_expr(base, expr)
  }
  domain_from_sympy_expr(domain, lifted)
}

fn domain_try_convert_from_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  try domain_convert_from_expr(domain, expr, base) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
pub fn domain_from_ff_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::GF(_) | Domain::GFExt(_, _, _) => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_real_field_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::RR => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_complex_field_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::CC => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_algebraic_field_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::AlgExt(_, _, _) => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_polynomial_ring_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::PolyRing(_, _) | Domain::QuotientRing(_, _, _) | Domain::PowerSeries(_, _, _) =>
      domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_fraction_field_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::RationalFunctionField(_, _) | Domain::Frac(_) =>
      domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_expression_domain_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::EX => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
pub fn domain_from_expression_raw_domain_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  match base {
    Domain::EXRAW => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
/// Convert an expression into `domain`, optionally using an explicit source domain.
pub fn domain_convert_expr(
  domain : Domain,
  expr : @symcore.Expr,
  base? : Domain? = None,
) -> @symcore.Expr raise PolyError {
  match base {
    Some(source) => domain_convert_from_expr(domain, expr, source)
    None => domain_from_sympy_expr(domain, expr)
  }
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
fn expr_terms_one(var_count : Int) -> Map[Monomial, @symcore.Expr] {
  let out : Map[Monomial, @symcore.Expr] = Map::new()
  out.set(monomial_one(var_count), @symcore.int(1))
  out
}

///|
fn expr_terms_from_coeff(
  coeff_domain : Domain,
  coeff : @symcore.Expr,
  var_count : Int,
) -> Map[Monomial, @symcore.Expr] {
  let out : Map[Monomial, @symcore.Expr] = Map::new()
  if !domain_is_zero_expr(coeff_domain, coeff) {
    out.set(monomial_one(var_count), coeff)
  }
  out
}

///|
fn expr_terms_add(
  coeff_domain : Domain,
  left : Map[Monomial, @symcore.Expr],
  right : Map[Monomial, @symcore.Expr],
) -> Map[Monomial, @symcore.Expr] {
  let out : Map[Monomial, @symcore.Expr] = Map::new()
  for mono, coeff in left {
    if !domain_is_zero_expr(coeff_domain, coeff) {
      out.set(mono, coeff)
    }
  }
  for mono, coeff in right {
    if domain_is_zero_expr(coeff_domain, coeff) {
      continue
    }
    match out.get(mono) {
      Some(prev) => {
        let merged = @symcore.add([prev, coeff])
        if domain_is_zero_expr(coeff_domain, merged) {
          ignore(out.remove(mono))
        } else {
          out.set(mono, merged)
        }
      }
      None => out.set(mono, coeff)
    }
  }
  out
}

///|
fn expr_terms_mul(
  coeff_domain : Domain,
  left : Map[Monomial, @symcore.Expr],
  right : Map[Monomial, @symcore.Expr],
) -> Map[Monomial, @symcore.Expr] {
  let out : Map[Monomial, @symcore.Expr] = Map::new()
  if left.is_empty() || right.is_empty() {
    return out
  }
  for lmono, lcoeff in left {
    if domain_is_zero_expr(coeff_domain, lcoeff) {
      continue
    }
    for rmono, rcoeff in right {
      if domain_is_zero_expr(coeff_domain, rcoeff) {
        continue
      }
      let mono = try! monomial_mul(lmono, rmono)
      let coeff = @symcore.mul([lcoeff, rcoeff])
      if domain_is_zero_expr(coeff_domain, coeff) {
        continue
      }
      match out.get(mono) {
        Some(prev) => {
          let merged = @symcore.add([prev, coeff])
          if domain_is_zero_expr(coeff_domain, merged) {
            ignore(out.remove(mono))
          } else {
            out.set(mono, merged)
          }
        }
        None => out.set(mono, coeff)
      }
    }
  }
  out
}

///|
fn expr_terms_pow(
  coeff_domain : Domain,
  terms : Map[Monomial, @symcore.Expr],
  exp : Int,
  var_count : Int,
) -> Map[Monomial, @symcore.Expr] {
  if exp == 0 {
    return expr_terms_one(var_count)
  }
  let mut out = expr_terms_one(var_count)
  for _ in 0..<exp {
    out = expr_terms_mul(coeff_domain, out, terms)
  }
  out
}

///|
fn reciprocal_gen_symbol_name(gen : String) -> String? {
  let text = gen.trim().to_string()
  if !text.has_prefix("1/") {
    return None
  }
  let rest = (try! text[2:text.length()]).to_string().trim().to_string()
  if rest == "" || rest.contains("/") || rest.contains("(") || rest.contains("[") ||
    rest.contains("<") {
    None
  } else {
    Some(rest)
  }
}

///|
fn expr_generator_rational(
  gens : Array[String],
  expr : @symcore.Expr,
) -> (Map[Monomial, @symcore.Expr], Map[Monomial, @symcore.Expr])? {
  let expr_text = expr_key(expr)
  for i in 0..<gens.length() {
    let gen = gens[i]
    if expr_text == gen.replace_all(old=" ", new="") {
      let numer : Map[Monomial, @symcore.Expr] = Map::new()
      let mono = monomial_one(gens.length())
      mono.exps.set(i, 1)
      numer.set(mono, @symcore.int(1))
      return Some((numer, expr_terms_one(gens.length())))
    }
    match reciprocal_gen_symbol_name(gen) {
      Some(name) =>
        match expr {
          @symcore.Expr::Symbol(expr_name) if expr_name == name => {
            let denom : Map[Monomial, @symcore.Expr] = Map::new()
            let mono = monomial_one(gens.length())
            mono.exps.set(i, 1)
            denom.set(mono, @symcore.int(1))
            return Some((expr_terms_one(gens.length()), denom))
          }
          _ => ()
        }
      None => ()
    }
  }
  None
}

///|
fn expr_collect_rational_terms(
  coeff_domain : Domain,
  gens : Array[String],
  expr : @symcore.Expr,
) -> (Map[Monomial, @symcore.Expr], Map[Monomial, @symcore.Expr])? {
  let var_count = gens.length()
  if domain_contains_expr(coeff_domain, expr) {
    return Some((expr_terms_from_coeff(coeff_domain, expr, var_count), expr_terms_one(var_count)))
  }
  match expr_generator_rational(gens, expr) {
    Some(res) => return Some(res)
    None => ()
  }
  match expr {
    @symcore.Expr::Add(args) => {
      let mut numer : Map[Monomial, @symcore.Expr] = Map::new()
      let mut denom = expr_terms_one(var_count)
      let mut first = true
      for arg in args {
        match expr_collect_rational_terms(coeff_domain, gens, arg) {
          Some((arg_num, arg_den)) =>
            if first {
              numer = arg_num
              denom = arg_den
              first = false
            } else {
              let left = expr_terms_mul(coeff_domain, numer, arg_den)
              let right = expr_terms_mul(coeff_domain, arg_num, denom)
              numer = expr_terms_add(coeff_domain, left, right)
              denom = expr_terms_mul(coeff_domain, denom, arg_den)
            }
          None => return None
        }
      }
      Some((numer, denom))
    }
    @symcore.Expr::Mul(args) => {
      let mut numer = expr_terms_one(var_count)
      let mut denom = expr_terms_one(var_count)
      for arg in args {
        match expr_collect_rational_terms(coeff_domain, gens, arg) {
          Some((arg_num, arg_den)) => {
            numer = expr_terms_mul(coeff_domain, numer, arg_num)
            denom = expr_terms_mul(coeff_domain, denom, arg_den)
          }
          None => return None
        }
      }
      Some((numer, denom))
    }
    @symcore.Expr::Pow(base, exp) =>
      if !expr_is_integer(exp) {
        None
      } else {
        let k = match exp {
          @symcore.Expr::Number(n) => n.numerator().to_int()
          _ => 0
        }
        match expr_collect_rational_terms(coeff_domain, gens, base) {
          Some((num, den)) =>
            if k >= 0 {
              Some((
                expr_terms_pow(coeff_domain, num, k, var_count),
                expr_terms_pow(coeff_domain, den, k, var_count),
              ))
            } else {
              Some((
                expr_terms_pow(coeff_domain, den, -k, var_count),
                expr_terms_pow(coeff_domain, num, -k, var_count),
              ))
            }
          None => None
        }
      }
    _ => None
  }
}

///|
fn expr_terms_is_one(
  coeff_domain : Domain,
  terms : Map[Monomial, @symcore.Expr],
  var_count : Int,
) -> Bool {
  if terms.length() != 1 {
    return false
  }
  match terms.get(monomial_one(var_count)) {
    Some(coeff) => domain_is_one_expr(coeff_domain, coeff)
    None => false
  }
}

///|
fn expr_terms_leading_coeff(
  coeff_domain : Domain,
  terms : Map[Monomial, @symcore.Expr],
) -> @symcore.Expr? {
  let mut best : (Monomial, @symcore.Expr)? = None
  for mono, coeff in terms {
    if domain_is_zero_expr(coeff_domain, coeff) {
      continue
    }
    best = match best {
      None => Some((mono, coeff))
      Some((best_mono, best_coeff)) =>
        if compare_monomial_order(mono, best_mono, TermOrder::Lex) > 0 {
          Some((mono, coeff))
        } else {
          Some((best_mono, best_coeff))
        }
    }
  }
  match best {
    Some((_, coeff)) => Some(coeff)
    None => None
  }
}

///|
fn expr_terms_constant_coeff(
  coeff_domain : Domain,
  terms : Map[Monomial, @symcore.Expr],
  var_count : Int,
) -> @symcore.Expr {
  match terms.get(monomial_one(var_count)) {
    Some(coeff) if !domain_is_zero_expr(coeff_domain, coeff) => coeff
    _ => @symcore.int(0)
  }
}

///|
fn expr_numeric_sign(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) => Some(n.compare(@symnum.BigRational::zero()))
    @symcore.Expr::Mul(args) => {
      let mut sign = 1
      for arg in args {
        match expr_numeric_sign(arg) {
          Some(0) => return Some(0)
          Some(v) => sign = sign * v
          None => return None
        }
      }
      Some(sign)
    }
    @symcore.Expr::Pow(base, exp) =>
      if !expr_is_integer(exp) {
        None
      } else {
        let k = match exp {
          @symcore.Expr::Number(n) => n.numerator().to_int()
          _ => 0
        }
        match expr_numeric_sign(base) {
          Some(0) => if k == 0 { Some(1) } else { Some(0) }
          Some(v) =>
            if k % 2 == 0 {
              Some(1)
            } else {
              Some(v)
            }
          None => None
        }
      }
    _ => None
  }
}

///|
fn expr_coeff_sign_like(expr : @symcore.Expr) -> Int {
  match expr {
    @symcore.Expr::Number(n) => n.compare(@symnum.BigRational::zero())
    @symcore.Expr::Mul(args) => {
      let mut sign = 1
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) =>
            if n.compare(@symnum.BigRational::zero()) < 0 {
              sign = -sign
            }
          _ => ()
        }
      }
      sign
    }
    _ => 1
  }
}

///|
fn domain_expr_sign(domain : Domain, expr : @symcore.Expr) -> Int? {
  if !domain_contains_expr(domain, expr) {
    return None
  }
  match domain {
    Domain::ZZ | Domain::QQ | Domain::RR =>
      expr_numeric_sign(expr)
    Domain::EX | Domain::EXRAW =>
      if domain_is_zero_expr(domain, expr) {
        Some(0)
      } else {
        Some(expr_coeff_sign_like(expr))
      }
    Domain::GF(_) | Domain::GFExt(_, _, _) =>
      if domain_is_zero_expr(domain, expr) {
        Some(0)
      } else {
        Some(1)
      }
    Domain::CC | Domain::ZZ_I | Domain::QQ_I =>
      None
    Domain::PolyRing(base, gens) | Domain::QuotientRing(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, denom)) =>
          if !expr_terms_is_one(base, denom, gens.length()) {
            None
          } else if numer.is_empty() {
            Some(0)
          } else {
            match expr_terms_leading_coeff(base, numer) {
              Some(coeff) => domain_expr_sign(base, coeff)
              None => Some(0)
            }
          }
        None => None
      }
    Domain::RationalFunctionField(base, gens) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, _)) =>
          if numer.is_empty() {
            Some(0)
          } else {
            match expr_terms_leading_coeff(base, numer) {
              Some(coeff) => domain_expr_sign(base, coeff)
              None => Some(0)
            }
          }
        None => None
      }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) =>
          domain_expr_sign(Domain::RationalFunctionField(inner, gens), expr)
        _ => domain_expr_sign(base, expr)
      }
    Domain::PowerSeries(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, denom)) =>
          if !expr_terms_is_one(base, denom, gens.length()) {
            None
          } else {
            domain_expr_sign(base, expr_terms_constant_coeff(base, numer, gens.length()))
          }
        None => None
      }
    Domain::AlgExt(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, _)) =>
          if numer.is_empty() {
            Some(0)
          } else {
            match expr_terms_leading_coeff(base, numer) {
              Some(coeff) => domain_expr_sign(base, coeff)
              None => Some(0)
            }
          }
        None => None
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
pub fn domain_is_negative_one_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  domain_contains_expr(domain, expr) && domain_expr_is_minus_one(expr)
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
pub fn domain_is_positive_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(1) => true
    _ => false
  }
}

///|
pub fn domain_is_negative_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(v) => v < 0
    None => false
  }
}

///|
pub fn domain_is_nonpositive_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(v) => v <= 0
    None => false
  }
}

///|
pub fn domain_is_nonnegative_expr(domain : Domain, expr : @symcore.Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(v) => v >= 0
    None => false
  }
}

///|
priv struct GaussianIntCompat {
  re : BigInt
  im : BigInt
}

///|
priv struct GaussianRatCompat {
  re : @symnum.BigRational
  im : @symnum.BigRational
}

fn domain_bigint_abs(x : BigInt) -> BigInt {
  if x.op_lt(BigInt::from_int(0)) {
    x.neg()
  } else {
    x
  }
}

fn domain_bigint_lcm(a : BigInt, b : BigInt) -> BigInt {
  if a.is_zero() || b.is_zero() {
    return BigInt::from_int(0)
  }
  let g = @symnum.gcd_bigint(domain_bigint_abs(a), domain_bigint_abs(b))
  domain_bigint_abs(a.div(g).mul(b))
}

fn domain_bigint_round_div(num : BigInt, den : BigInt) -> BigInt {
  if num.is_zero() {
    return BigInt::from_int(0)
  }
  let two = BigInt::from_int(2)
  let q = domain_bigint_abs(num).mul(two).add(den).div(den.mul(two))
  if num.op_lt(BigInt::from_int(0)) { q.neg() } else { q }
}

fn domain_bigint_euclid_mod(num : BigInt, den : BigInt) -> BigInt {
  let r = num.mod(den)
  if r.op_lt(BigInt::from_int(0)) {
    if den.op_lt(BigInt::from_int(0)) {
      r.sub(den)
    } else {
      r.add(den)
    }
  } else {
    r
  }
}

fn domain_bigint_gcdex(
  a0 : BigInt,
  b0 : BigInt,
) -> (BigInt, BigInt, BigInt) {
  let mut old_r = a0
  let mut r = b0
  let mut old_s = BigInt::from_int(1)
  let mut s = BigInt::from_int(0)
  let mut old_t = BigInt::from_int(0)
  let mut t = BigInt::from_int(1)
  while !r.is_zero() {
    let q = old_r.div(r)
    let new_r = old_r.sub(q.mul(r))
    let new_s = old_s.sub(q.mul(s))
    let new_t = old_t.sub(q.mul(t))
    old_r = r
    r = new_r
    old_s = s
    s = new_s
    old_t = t
    t = new_t
  }
  if old_r.op_lt(BigInt::from_int(0)) {
    (old_s.neg(), old_t.neg(), old_r.neg())
  } else {
    (old_s, old_t, old_r)
  }
}

fn domain_bigint_factorial(n : BigInt) -> BigInt raise PolyError {
  guard !n.op_lt(BigInt::from_int(0)) else { raise PolyError::DomainMismatch }
  let one = BigInt::from_int(1)
  let mut acc = one
  let mut i = BigInt::from_int(2)
  while i.compare(n) <= 0 {
    acc = acc.mul(i)
    i = i.add(one)
  }
  acc
}

fn domain_bigint_log_floor(
  a : BigInt,
  b : BigInt,
) -> BigInt raise PolyError {
  guard a.compare(BigInt::from_int(0)) > 0 else { raise PolyError::DomainMismatch }
  guard b.compare(BigInt::from_int(0)) > 0 && !b.equal_int(1) else {
    raise PolyError::DomainMismatch
  }
  let one = BigInt::from_int(1)
  let mut count = BigInt::from_int(0)
  let mut value = a
  while value.compare(b) >= 0 {
    value = value.div(b)
    count = count.add(one)
  }
  count
}

fn domain_bigint_sqrt_floor(n : BigInt) -> BigInt raise PolyError {
  guard !n.op_lt(BigInt::from_int(0)) else { raise PolyError::DomainMismatch }
  let zero = BigInt::from_int(0)
  let one = BigInt::from_int(1)
  let two = BigInt::from_int(2)
  let mut low = zero
  let mut high = n.add(one)
  while low.add(one).compare(high) < 0 {
    let mid = low.add(high).div(two)
    let sq = mid.mul(mid)
    if sq.compare(n) <= 0 {
      low = mid
    } else {
      high = mid
    }
  }
  low
}

fn domain_bigint_exsqrt(n : BigInt) -> BigInt? {
  if n.op_lt(BigInt::from_int(0)) {
    return None
  }
  let root = domain_bigint_sqrt_floor(n) catch {
    _ => return None
  }
  if root.mul(root).compare(n) == 0 {
    Some(root)
  } else {
    None
  }
}

fn rational_abs(r : @symnum.BigRational) -> @symnum.BigRational {
  if r.compare(@symnum.BigRational::zero()) < 0 {
    r.neg_r()
  } else {
    r
  }
}

fn domain_rational_exsqrt(
  value : @symnum.BigRational,
) -> @symnum.BigRational? {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    return None
  }
  let num = domain_bigint_exsqrt(value.numerator())
  let den = domain_bigint_exsqrt(value.denominator())
  match (num, den) {
    (Some(n), Some(d)) => Some(try! @symnum.BigRational::new(n, d))
    _ => None
  }
}

fn expr_from_bigint(n : BigInt) -> @symcore.Expr {
  @symcore.number(@symnum.BigRational::from_bigint(n))
}

fn expr_from_rational(n : @symnum.BigRational) -> @symcore.Expr {
  @symcore.number(n)
}

fn expr_exact_sqrt_or_symbolic(expr : @symcore.Expr) -> @symcore.Expr {
  match expr_rational_value(expr) {
    Some(value) =>
      match domain_rational_exsqrt(value) {
        Some(root) => expr_from_rational(root)
        None => @symcore.function("sqrt", [expr])
      }
    None => @symcore.function("sqrt", [expr])
  }
}

fn expr_rational_value(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

fn expr_gaussian_coeffs(
  coeff_domain : Domain,
  expr : @symcore.Expr,
) -> GaussianRatCompat? {
  let gens = ["I"]
  match expr_collect_rational_terms(coeff_domain, gens, expr) {
    Some((numer, denom)) =>
      if !expr_terms_is_one(coeff_domain, denom, 1) {
        None
      } else {
        let mut real = @symnum.BigRational::zero()
        let mut imag = @symnum.BigRational::zero()
        for mono, coeff in numer {
          match expr_rational_value(coeff) {
            Some(value) =>
              if mono.exps.length() != 1 {
                return None
              } else {
                match mono.exps[0] {
                  0 => real = value
                  1 => imag = value
                  _ => return None
                }
              }
            None => return None
          }
        }
        Some(GaussianRatCompat::{ re: real, im: imag })
      }
    None => None
  }
}

fn gaussian_rat_to_expr(value : GaussianRatCompat) -> @symcore.Expr {
  let i_sym = @symcore.symbol("I")
  let terms : Array[@symcore.Expr] = Array::new()
  if !value.re.is_zero() {
    terms.push(@symcore.number(value.re))
  }
  if !value.im.is_zero() {
    let imag_coeff = @symcore.number(value.im)
    terms.push(
      if value.im.is_one() {
        i_sym
      } else if value.im.compare(@symnum.BigRational::from_int(-1)) == 0 {
        @symcore.int(-1) * i_sym
      } else {
        imag_coeff * i_sym
      },
    )
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.add(terms)
  }
}

fn gaussian_int_is_zero(value : GaussianIntCompat) -> Bool {
  value.re.is_zero() && value.im.is_zero()
}

fn gaussian_int_sub(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat {
  GaussianIntCompat::{
    re: left.re.sub(right.re),
    im: left.im.sub(right.im),
  }
}

fn gaussian_int_mul(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat {
  GaussianIntCompat::{
    re: left.re.mul(right.re).sub(left.im.mul(right.im)),
    im: left.re.mul(right.im).add(left.im.mul(right.re)),
  }
}

fn gaussian_int_unit_candidates() -> Array[GaussianIntCompat] {
  [
    GaussianIntCompat::{ re: BigInt::from_int(1), im: BigInt::from_int(0) },
    GaussianIntCompat::{ re: BigInt::from_int(0), im: BigInt::from_int(1) },
    GaussianIntCompat::{ re: BigInt::from_int(-1), im: BigInt::from_int(0) },
    GaussianIntCompat::{ re: BigInt::from_int(0), im: BigInt::from_int(-1) },
  ]
}

fn gaussian_int_canonical_unit(value : GaussianIntCompat) -> GaussianIntCompat {
  if gaussian_int_is_zero(value) {
    return GaussianIntCompat::{ re: BigInt::from_int(1), im: BigInt::from_int(0) }
  }
  let mut fallback : GaussianIntCompat? = None
  for unit in gaussian_int_unit_candidates() {
    let rotated = gaussian_int_mul(value, unit)
    if rotated.re.compare(BigInt::from_int(0)) > 0 &&
      rotated.im.compare(BigInt::from_int(0)) >= 0 {
      return unit
    }
    match fallback {
      None =>
        if rotated.re.compare(BigInt::from_int(0)) >= 0 &&
          rotated.im.compare(BigInt::from_int(0)) >= 0 {
          fallback = Some(unit)
        }
      Some(_) => ()
    }
  }
  match fallback {
    Some(unit) => unit
    None => GaussianIntCompat::{ re: BigInt::from_int(1), im: BigInt::from_int(0) }
  }
}

fn gaussian_rat_canonical_unit(value : GaussianRatCompat) -> GaussianRatCompat {
  if value.re.is_zero() && value.im.is_zero() {
    return GaussianRatCompat::{
      re: @symnum.BigRational::one(),
      im: @symnum.BigRational::zero(),
    }
  }
  let units = [
    GaussianRatCompat::{ re: @symnum.BigRational::one(), im: @symnum.BigRational::zero() },
    GaussianRatCompat::{ re: @symnum.BigRational::zero(), im: @symnum.BigRational::one() },
    GaussianRatCompat::{ re: @symnum.BigRational::from_int(-1), im: @symnum.BigRational::zero() },
    GaussianRatCompat::{ re: @symnum.BigRational::zero(), im: @symnum.BigRational::from_int(-1) },
  ]
  let mut fallback : GaussianRatCompat? = None
  for unit in units {
    let rotated = GaussianRatCompat::{
      re: value.re.mul_r(unit.re).add_r(value.im.mul_r(unit.im).neg_r()),
      im: value.re.mul_r(unit.im).add_r(value.im.mul_r(unit.re)),
    }
    if rotated.re.compare(@symnum.BigRational::zero()) > 0 &&
      rotated.im.compare(@symnum.BigRational::zero()) >= 0 {
      return unit
    }
    match fallback {
      None =>
        if rotated.re.compare(@symnum.BigRational::zero()) >= 0 &&
          rotated.im.compare(@symnum.BigRational::zero()) >= 0 {
          fallback = Some(unit)
        }
      Some(_) => ()
    }
  }
  match fallback {
    Some(unit) => unit
    None => GaussianRatCompat::{ re: @symnum.BigRational::one(), im: @symnum.BigRational::zero() }
  }
}

fn gaussian_int_from_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> GaussianIntCompat raise PolyError {
  let coeff_domain = match domain {
    Domain::ZZ_I => Domain::ZZ
    Domain::QQ_I => Domain::QQ
    _ => raise PolyError::DomainMismatch
  }
  match expr_gaussian_coeffs(coeff_domain, expr) {
    Some(value) =>
      if value.re.is_integral() && value.im.is_integral() {
        GaussianIntCompat::{ re: value.re.numerator(), im: value.im.numerator() }
      } else {
        raise PolyError::DomainMismatch
      }
    None => raise PolyError::DomainMismatch
  }
}

fn gaussian_rat_from_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> GaussianRatCompat raise PolyError {
  let coeff_domain = match domain {
    Domain::ZZ_I => Domain::ZZ
    Domain::QQ_I | Domain::CC => Domain::QQ
    _ => raise PolyError::DomainMismatch
  }
  match expr_gaussian_coeffs(coeff_domain, expr) {
    Some(value) => value
    None => raise PolyError::DomainMismatch
  }
}

fn gaussian_int_norm(value : GaussianIntCompat) -> BigInt {
  value.re.mul(value.re).add(value.im.mul(value.im))
}

fn gaussian_int_quo_round(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  if gaussian_int_is_zero(right) {
    raise PolyError::DivisionByZero
  }
  let denom = gaussian_int_norm(right)
  let real_num = left.re.mul(right.re).add(left.im.mul(right.im))
  let imag_num = left.im.mul(right.re).sub(left.re.mul(right.im))
  GaussianIntCompat::{
    re: domain_bigint_round_div(real_num, denom),
    im: domain_bigint_round_div(imag_num, denom),
  }
}

fn gaussian_int_rem(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  let q = gaussian_int_quo_round(left, right)
  gaussian_int_sub(left, gaussian_int_mul(right, q))
}

fn gaussian_int_div_exact(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  if gaussian_int_is_zero(right) {
    raise PolyError::DivisionByZero
  }
  let denom = gaussian_int_norm(right)
  let real_num = left.re.mul(right.re).add(left.im.mul(right.im))
  let imag_num = left.im.mul(right.re).sub(left.re.mul(right.im))
  if !real_num.mod(denom).is_zero() || !imag_num.mod(denom).is_zero() {
    raise PolyError::ExactQuotientFailed
  }
  GaussianIntCompat::{
    re: real_num.div(denom),
    im: imag_num.div(denom),
  }
}

fn gaussian_int_gcd(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  let mut a = left
  let mut b = right
  while !gaussian_int_is_zero(b) {
    let r = gaussian_int_rem(a, b)
    a = b
    b = r
  }
  gaussian_int_mul(a, gaussian_int_canonical_unit(a))
}

fn gaussian_int_lcm(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  if gaussian_int_is_zero(left) || gaussian_int_is_zero(right) {
    return GaussianIntCompat::{ re: BigInt::from_int(0), im: BigInt::from_int(0) }
  }
  gaussian_int_div_exact(gaussian_int_mul(left, right), gaussian_int_gcd(left, right))
}

fn gaussian_int_to_expr(value : GaussianIntCompat) -> @symcore.Expr {
  gaussian_rat_to_expr(
    GaussianRatCompat::{
      re: @symnum.BigRational::from_bigint(value.re),
      im: @symnum.BigRational::from_bigint(value.im),
    },
  )
}

fn gaussian_rat_numer_denom(
  value : GaussianRatCompat,
) -> (GaussianIntCompat, BigInt) {
  let den = domain_bigint_lcm(value.re.denominator(), value.im.denominator())
  let re_num = value.re.numerator().mul(den.div(value.re.denominator()))
  let im_num = value.im.numerator().mul(den.div(value.im.denominator()))
  (GaussianIntCompat::{ re: re_num, im: im_num }, den)
}

fn gaussian_rat_from_numer_denom(
  numer : GaussianIntCompat,
  den : BigInt,
) -> GaussianRatCompat {
  let den_rat = @symnum.BigRational::from_bigint(den)
  GaussianRatCompat::{
    re: @symnum.BigRational::from_bigint(numer.re).div_r(den_rat),
    im: @symnum.BigRational::from_bigint(numer.im).div_r(den_rat),
  }
}

fn gaussian_rat_mul(
  left : GaussianRatCompat,
  right : GaussianRatCompat,
) -> GaussianRatCompat {
  GaussianRatCompat::{
    re: left.re.mul_r(right.re).add_r(left.im.mul_r(right.im).neg_r()),
    im: left.re.mul_r(right.im).add_r(left.im.mul_r(right.re)),
  }
}

fn gaussian_rat_inv(value : GaussianRatCompat) -> GaussianRatCompat raise PolyError {
  let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
  if norm.is_zero() {
    raise PolyError::DivisionByZero
  }
  GaussianRatCompat::{
    re: value.re.div_r(norm),
    im: value.im.neg_r().div_r(norm),
  }
}

fn gaussian_rat_div(
  left : GaussianRatCompat,
  right : GaussianRatCompat,
) -> GaussianRatCompat raise PolyError {
  gaussian_rat_mul(left, gaussian_rat_inv(right))
}

fn gaussian_int_exsqrt(value : GaussianIntCompat) -> GaussianIntCompat? {
  if gaussian_int_is_zero(value) {
    return Some(GaussianIntCompat::{ re: BigInt::from_int(0), im: BigInt::from_int(0) })
  }
  let norm = value.re.mul(value.re).add(value.im.mul(value.im))
  let t = domain_bigint_exsqrt(norm)
  match t {
    None => None
    Some(total) => {
      let two = BigInt::from_int(2)
      let u_num = total.add(value.re)
      let v_num = total.sub(value.re)
      if !u_num.mod(two).is_zero() || !v_num.mod(two).is_zero() {
        return None
      }
      let u = u_num.div(two)
      let v = v_num.div(two)
      match (domain_bigint_exsqrt(u), domain_bigint_exsqrt(v)) {
        (Some(a), Some(b0)) => {
          let b = if value.im.op_lt(BigInt::from_int(0)) { b0.neg() } else { b0 }
          let out = GaussianIntCompat::{ re: a, im: b }
          if out.re.is_zero() && out.im.op_lt(BigInt::from_int(0)) {
            Some(GaussianIntCompat::{ re: out.re.neg(), im: out.im.neg() })
          } else {
            Some(out)
          }
        }
        _ => None
      }
    }
  }
}

fn gaussian_rat_exsqrt(value : GaussianRatCompat) -> GaussianRatCompat? {
  if value.re.is_zero() && value.im.is_zero() {
    return Some(
      GaussianRatCompat::{ re: @symnum.BigRational::zero(), im: @symnum.BigRational::zero() },
    )
  }
  let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
  let t = domain_rational_exsqrt(norm)
  match t {
    None => None
    Some(total) => {
      let half = @symnum.BigRational::from_int(2)
      let u = total.add_r(value.re).div_r(half)
      let v = total.add_r(value.re.neg_r()).div_r(half)
      match (domain_rational_exsqrt(u), domain_rational_exsqrt(v)) {
        (Some(a), Some(b0)) => {
          let b = if value.im.compare(@symnum.BigRational::zero()) < 0 { b0.neg_r() } else { b0 }
          let out = GaussianRatCompat::{ re: a, im: b }
          if out.re.is_zero() && out.im.compare(@symnum.BigRational::zero()) < 0 {
            Some(GaussianRatCompat::{ re: out.re.neg_r(), im: out.im.neg_r() })
          } else {
            Some(out)
          }
        }
        _ => None
      }
    }
  }
}

fn finite_field_order(domain : Domain) -> Int raise PolyError {
  match domain {
    Domain::GF(p) => p
    Domain::GFExt(p, k, _) => fe_int_pow(p, k)
    _ => raise PolyError::DomainMismatch
  }
}

fn finite_field_exsqrt(
  domain : Domain,
  value : FieldElem,
) -> FieldElem? raise PolyError {
  guard fe_is_zero(value) || domain_is_field_pred(domain) else { raise PolyError::DomainMismatch }
  if fe_is_zero(value) {
    return Some(value)
  }
  match domain {
    Domain::GF(p) => {
      if p == 2 {
        return Some(value)
      }
      match value {
        FieldElem::GFp(_, target) => {
          for candidate in 0..=(p / 2) {
            if fe_pos_mod(candidate * candidate, p) == target {
              return Some(FieldElem::GFp(p, candidate))
            }
          }
          None
        }
        _ => raise PolyError::DomainMismatch
      }
    }
    Domain::GFExt(p, k, mod_poly) => {
      if p == 2 {
        return Some(value)
      }
      let total = fe_int_pow(p, k)
      for raw in 0..<total {
        let coeffs : Array[Int] = Array::make(k, 0)
        let mut n = raw
        for i in 0..<k {
          coeffs.set(i, n % p)
          n = n / p
        }
        let candidate = FieldElem::GFExt(p, fe_trim(coeffs, p), mod_poly)
        if fe_is_zero(fe_add(fe_mul(candidate, candidate), fe_neg(value))) {
          return Some(candidate)
        }
      }
      None
    }
    _ => raise PolyError::DomainMismatch
  }
}

fn expr_has_leading_minus(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.compare(@symnum.BigRational::zero()) < 0
    @symcore.Expr::Add(args) =>
      if args.is_empty() {
        false
      } else {
        match args[0] {
          @symcore.Expr::Number(n) =>
            n.compare(@symnum.BigRational::zero()) < 0
          _ => expr_key(expr).has_prefix("-")
        }
      }
    @symcore.Expr::Mul(args) =>
      args.any(arg => match arg {
        @symcore.Expr::Number(n) => n.compare(@symnum.BigRational::zero()) < 0
        _ => false
      })
    _ => expr_key(expr).has_prefix("-")
  }
}

fn expr_strip_leading_minus(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Mul(args) => {
      let updated : Array[@symcore.Expr] = Array::new()
      let mut removed = false
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) if !removed &&
            n.compare(@symnum.BigRational::from_int(-1)) == 0 => removed = true
          @symcore.Expr::Number(n) if !removed &&
            n.compare(@symnum.BigRational::zero()) < 0 => {
              updated.push(@symcore.number(n.neg_r()))
              removed = true
            }
          _ => updated.push(arg)
        }
      }
      if removed {
        Some(if updated.is_empty() { @symcore.int(1) } else { @symcore.mul(updated) })
      } else {
        None
      }
    }
    @symcore.Expr::Number(n) if n.compare(@symnum.BigRational::zero()) < 0 =>
      Some(@symcore.number(n.neg_r()))
    _ => None
  }
}

fn sqrt_of_nonnegative_rational(value : @symnum.BigRational) -> @symcore.Expr {
  if value.is_zero() || value.is_one() {
    @symcore.number(value)
  } else {
    @symcore.function("sqrt", [@symcore.number(value)])
  }
}

fn poly_from_expr_terms(
  coeff_domain : Domain,
  gens : Array[String],
  terms : Map[Monomial, @symcore.Expr],
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for mono, coeff_expr in terms {
    let coeff = field_elem_from_scalar_expr(coeff_expr, coeff_domain) catch {
      _ => raise PolyError::DomainMismatch
    }
    add_term(coeffs, mono, coeff, coeff_domain)
  }
  Poly::{ coeffs, gens, domain: coeff_domain, order: TermOrder::Lex }
}

fn poly_is_ground(poly : Poly) -> Bool {
  for mono, _ in poly.coeffs {
    if !is_monomial_zero(mono) {
      return false
    }
  }
  true
}

fn poly_ground_expr(poly : Poly) -> @symcore.Expr raise PolyError {
  if !poly_is_ground(poly) {
    raise PolyError::DomainMismatch
  }
  match poly.coeffs.get(monomial_one(poly.gens.length())) {
    Some(coeff) => fe_to_expr_const(coeff)
    None => @symcore.int(0)
  }
}

fn poly_from_ground_expr(
  coeff_domain : Domain,
  gens : Array[String],
  expr : @symcore.Expr,
) -> Poly raise PolyError {
  let coeff = field_elem_from_scalar_expr(expr, coeff_domain)
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  add_term(coeffs, monomial_one(gens.length()), coeff, coeff_domain)
  Poly::{ coeffs, gens, domain: coeff_domain, order: TermOrder::Lex }
}

fn poly_exact_quo(left : Poly, right : Poly) -> Poly raise PolyError {
  if right.is_zero() {
    raise PolyError::DivisionByZero
  }
  if left.gens.length() == 1 {
    return left.div_exact_univar(right)
  }
  let (qs, rem) = left.divmod_multivar([right])
  if !rem.is_zero() {
    raise PolyError::ExactQuotientFailed
  }
  qs[0]
}

fn poly_gcd_compat(left : Poly, right : Poly) -> Poly raise PolyError {
  if left.gens.length() == 1 {
    left.gcd_univar(right)
  } else {
    left.gcd_multivar(right)
  }
}

fn poly_lcm_compat(left : Poly, right : Poly) -> Poly raise PolyError {
  if left.is_zero() || right.is_zero() {
    return Poly::zero(left.gens, left.domain).with_order(left.order)
  }
  let gcd = poly_gcd_compat(left, right)
  let raw = poly_exact_quo(left.mul(right), gcd)
  if domain_is_field_pred(left.domain) { make_monic(raw) } else { raw }
}

fn rational_function_pair_from_expr(
  coeff_domain : Domain,
  gens : Array[String],
  expr : @symcore.Expr,
) -> (Poly, Poly) raise PolyError {
  match expr_collect_rational_terms(coeff_domain, gens, expr) {
    Some((numer, denom)) => (
      poly_from_expr_terms(coeff_domain, gens, numer),
      poly_from_expr_terms(coeff_domain, gens, denom),
    )
    None => raise PolyError::DomainMismatch
  }
}

fn rational_function_expr_from_pair(
  numer : Poly,
  denom : Poly,
  coeff_domain : Domain,
) -> @symcore.Expr raise PolyError {
  let (num_s, den_s) = cancel(numer, denom)
  let den_expr = den_s.to_expr()
  if domain_is_one_expr(coeff_domain, den_expr) {
    num_s.to_expr()
  } else {
    num_s.to_expr() * (den_expr ^ @symcore.int(-1))
  }
}

fn domain_scalar_gcd_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ => {
      let lhs = match expr_rational_value(left) {
        Some(v) if v.is_integral() => domain_bigint_abs(v.numerator())
        _ => raise PolyError::DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) if v.is_integral() => domain_bigint_abs(v.numerator())
        _ => raise PolyError::DomainMismatch
      }
      expr_from_bigint(@symnum.gcd_bigint(lhs, rhs))
    }
    Domain::QQ => {
      let lhs = match expr_rational_value(left) {
        Some(v) => rational_abs(v)
        None => raise PolyError::DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) => rational_abs(v)
        None => raise PolyError::DomainMismatch
      }
      let num = @symnum.gcd_bigint(lhs.numerator(), rhs.numerator())
      let den = domain_bigint_lcm(lhs.denominator(), rhs.denominator())
      @symcore.number(@symnum.BigRational::from_bigint(num).div_r(@symnum.BigRational::from_bigint(den)))
    }
    Domain::ZZ_I => {
      let lhs = gaussian_int_from_expr(domain, left)
      let rhs = gaussian_int_from_expr(domain, right)
      gaussian_int_to_expr(gaussian_int_gcd(lhs, rhs))
    }
    Domain::QQ_I => {
      let lhs = gaussian_rat_from_expr(domain, left)
      let rhs = gaussian_rat_from_expr(domain, right)
      let (num_l, den_l) = gaussian_rat_numer_denom(lhs)
      let (num_r, den_r) = gaussian_rat_numer_denom(rhs)
      let numer = gaussian_int_gcd(num_l, num_r)
      let denom = domain_bigint_lcm(den_l, den_r)
      gaussian_rat_to_expr(gaussian_rat_from_numer_denom(numer, denom))
    }
    Domain::GF(_)
    | Domain::GFExt(_, _, _) => {
      let lhs = field_elem_from_scalar_expr(left, domain)
      let rhs = field_elem_from_scalar_expr(right, domain)
      if fe_is_zero(lhs) && fe_is_zero(rhs) {
        @symcore.int(1)
      } else {
        fe_to_expr_const(fe_from_int(1, domain))
      }
    }
    Domain::RR | Domain::CC => {
      if domain_is_zero_expr(domain, left) && domain_is_zero_expr(domain, right) {
        @symcore.int(1)
      } else {
        fe_to_expr_const(fe_from_int(1, domain))
      }
    }
    Domain::EX | Domain::EXRAW | Domain::AlgExt(_, _, _) =>
      if domain_is_zero_expr(domain, left) && domain_is_zero_expr(domain, right) {
        @symcore.int(1)
      } else {
        @symcore.int(1)
      }
    _ => raise PolyError::DomainMismatch
  }
}

fn domain_scalar_lcm_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ => {
      let lhs = match expr_rational_value(left) {
        Some(v) if v.is_integral() => v.numerator()
        _ => raise PolyError::DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) if v.is_integral() => v.numerator()
        _ => raise PolyError::DomainMismatch
      }
      if lhs.is_zero() || rhs.is_zero() {
        @symcore.int(0)
      } else {
        expr_from_bigint(domain_bigint_lcm(lhs, rhs))
      }
    }
    Domain::QQ => {
      let lhs = match expr_rational_value(left) {
        Some(v) => rational_abs(v)
        None => raise PolyError::DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) => rational_abs(v)
        None => raise PolyError::DomainMismatch
      }
      if lhs.is_zero() || rhs.is_zero() {
        @symcore.int(0)
      } else {
        let num = domain_bigint_lcm(lhs.numerator(), rhs.numerator())
        let den = @symnum.gcd_bigint(lhs.denominator(), rhs.denominator())
        @symcore.number(@symnum.BigRational::from_bigint(num).div_r(@symnum.BigRational::from_bigint(den)))
      }
    }
    Domain::ZZ_I => {
      let lhs = gaussian_int_from_expr(domain, left)
      let rhs = gaussian_int_from_expr(domain, right)
      gaussian_int_to_expr(gaussian_int_lcm(lhs, rhs))
    }
    Domain::QQ_I => {
      let lhs = gaussian_rat_from_expr(domain, left)
      let rhs = gaussian_rat_from_expr(domain, right)
      let (num_l, den_l) = gaussian_rat_numer_denom(lhs)
      let (num_r, den_r) = gaussian_rat_numer_denom(rhs)
      let numer = gaussian_int_lcm(num_l, num_r)
      let denom = @symnum.gcd_bigint(den_l, den_r)
      gaussian_rat_to_expr(gaussian_rat_from_numer_denom(numer, denom))
    }
    Domain::GF(_)
    | Domain::GFExt(_, _, _) => {
      let lhs = field_elem_from_scalar_expr(left, domain)
      let rhs = field_elem_from_scalar_expr(right, domain)
      fe_to_expr_const(fe_mul(lhs, rhs))
    }
    Domain::RR | Domain::CC => {
      match (
        try? field_elem_from_scalar_expr(left, domain),
        try? field_elem_from_scalar_expr(right, domain),
      ) {
        (Ok(lhs), Ok(rhs)) => fe_to_expr_const(fe_mul(lhs, rhs))
        _ =>
          if domain_is_zero_expr(domain, left) || domain_is_zero_expr(domain, right) {
            @symcore.int(0)
          } else {
            left * right
          }
      }
    }
    Domain::EX | Domain::EXRAW | Domain::AlgExt(_, _, _) =>
      if domain_is_zero_expr(domain, left) || domain_is_zero_expr(domain, right) {
        @symcore.int(0)
      } else {
        left * right
      }
    _ => raise PolyError::DomainMismatch
  }
}

fn domain_poly_gcd_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  let lhs = Poly::from_expr(left, gens, coeff_domain)
  let rhs = Poly::from_expr(right, gens, coeff_domain)
  poly_gcd_compat(lhs, rhs).to_expr()
}

fn domain_poly_lcm_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  let lhs = Poly::from_expr(left, gens, coeff_domain)
  let rhs = Poly::from_expr(right, gens, coeff_domain)
  poly_lcm_compat(lhs, rhs).to_expr()
}

fn domain_rational_function_gcd_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  let (left_num, left_den) = rational_function_pair_from_expr(coeff_domain, gens, left)
  let (right_num, right_den) = rational_function_pair_from_expr(coeff_domain, gens, right)
  let numer = if poly_is_ground(left_num) && poly_is_ground(right_num) {
    poly_from_ground_expr(
      coeff_domain,
      gens,
      domain_scalar_gcd_expr(coeff_domain, poly_ground_expr(left_num), poly_ground_expr(right_num)),
    )
  } else {
    poly_gcd_compat(left_num, right_num)
  }
  let denom = if poly_is_ground(left_den) && poly_is_ground(right_den) {
    poly_from_ground_expr(
      coeff_domain,
      gens,
      domain_scalar_lcm_expr(coeff_domain, poly_ground_expr(left_den), poly_ground_expr(right_den)),
    )
  } else {
    poly_lcm_compat(left_den, right_den)
  }
  rational_function_expr_from_pair(numer, denom, coeff_domain)
}

fn domain_rational_function_lcm_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  let (left_num, left_den) = rational_function_pair_from_expr(coeff_domain, gens, left)
  let (right_num, right_den) = rational_function_pair_from_expr(coeff_domain, gens, right)
  let numer = if poly_is_ground(left_num) && poly_is_ground(right_num) {
    let scalar_lcm = domain_scalar_lcm_expr(
      coeff_domain,
      poly_ground_expr(left_num),
      poly_ground_expr(right_num),
    )
    let ground_lcm = if domain_is_field_pred(coeff_domain) {
      domain_canonical_unit_expr(coeff_domain, scalar_lcm)
    } else {
      scalar_lcm
    }
    poly_from_ground_expr(coeff_domain, gens, ground_lcm)
  } else {
    poly_lcm_compat(left_num, right_num)
  }
  let denom = if poly_is_ground(left_den) && poly_is_ground(right_den) {
    poly_from_ground_expr(
      coeff_domain,
      gens,
      domain_scalar_gcd_expr(coeff_domain, poly_ground_expr(left_den), poly_ground_expr(right_den)),
    )
  } else {
    poly_gcd_compat(left_den, right_den)
  }
  rational_function_expr_from_pair(numer, denom, coeff_domain)
}

///|
pub fn domain_canonical_unit_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::ZZ
    | Domain::QQ
    | Domain::RR
    | Domain::GF(_)
    | Domain::GFExt(_, _, _) =>
      match domain_expr_sign(domain, expr) {
        Some(v) if v < 0 => @symcore.int(-1)
        _ => @symcore.int(1)
      }
    Domain::CC =>
      if domain_is_zero_expr(domain, expr) {
        @symcore.int(1)
      } else {
        @symcore.int(1)
      }
    Domain::ZZ_I =>
      gaussian_int_to_expr(gaussian_int_canonical_unit(gaussian_int_from_expr(domain, expr)))
    Domain::QQ_I =>
      gaussian_rat_to_expr(gaussian_rat_canonical_unit(gaussian_rat_from_expr(domain, expr)))
    Domain::EX | Domain::EXRAW =>
      if domain_is_zero_expr(domain, expr) {
        @symcore.int(1)
      } else if expr_has_leading_minus(expr) {
        @symcore.int(-1)
      } else {
        @symcore.int(1)
      }
    Domain::PolyRing(base, gens) | Domain::QuotientRing(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, denom)) =>
          if !expr_terms_is_one(base, denom, gens.length()) {
            raise PolyError::DomainMismatch
          } else {
            match expr_terms_leading_coeff(base, numer) {
              Some(coeff) => domain_canonical_unit_expr(base, coeff)
              None => @symcore.int(1)
            }
          }
        None => raise PolyError::DomainMismatch
      }
    Domain::RationalFunctionField(base, gens) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, _)) =>
          match expr_terms_leading_coeff(base, numer) {
            Some(coeff) => domain_canonical_unit_expr(base, coeff)
            None => @symcore.int(1)
          }
        None => raise PolyError::DomainMismatch
      }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) =>
          domain_canonical_unit_expr(Domain::RationalFunctionField(inner, gens), expr)
        _ => domain_canonical_unit_expr(base, expr)
      }
    Domain::PowerSeries(base, gens, _) =>
      match expr_constant_term(expr, generator_symbol_names(gens)) {
        Some(c0) => domain_canonical_unit_expr(base, c0)
        None => raise PolyError::DomainMismatch
      }
    Domain::AlgExt(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, _)) =>
          match expr_terms_leading_coeff(base, numer) {
            Some(coeff) => domain_canonical_unit_expr(base, coeff)
            None => @symcore.int(1)
          }
        None =>
          if expr_has_leading_minus(expr) {
            @symcore.int(-1)
          } else {
            @symcore.int(1)
          }
      }
  }
}

///|
pub fn domain_abs_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::ZZ | Domain::QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_rational(rational_abs(value))
        None => raise PolyError::DomainMismatch
      }
    Domain::RR =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_rational(rational_abs(value))
        None => @symcore.function("Abs", [expr])
      }
    Domain::CC => {
      let value = gaussian_rat_from_expr(domain, expr)
      let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
      sqrt_of_nonnegative_rational(norm)
    }
    Domain::EX | Domain::EXRAW => {
      match expr_numeric_sign(expr) {
        Some(v) =>
          if v < 0 {
            match expr {
              @symcore.Expr::Number(n) => @symcore.number(n.neg_r())
              _ => @symcore.function("Abs", [expr])
            }
          } else {
            expr
          }
        None =>
          match expr_gaussian_coeffs(Domain::QQ, expr) {
            Some(value) => {
              let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
              sqrt_of_nonnegative_rational(norm)
            }
            None =>
              match expr_strip_leading_minus(expr) {
                Some(inner) => @symcore.function("Abs", [inner])
                None => @symcore.function("Abs", [expr])
              }
          }
      }
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_gcd_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  match domain {
    Domain::PolyRing(base, gens) => domain_poly_gcd_expr(base, gens, left, right)
    Domain::RationalFunctionField(base, gens) =>
      domain_rational_function_gcd_expr(base, gens, left, right)
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) =>
          domain_rational_function_gcd_expr(inner, gens, left, right)
        _ => domain_scalar_gcd_expr(base, left, right)
      }
    _ => domain_scalar_gcd_expr(domain, left, right)
  }
}

///|
pub fn domain_lcm_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  match domain {
    Domain::PolyRing(base, gens) => domain_poly_lcm_expr(base, gens, left, right)
    Domain::RationalFunctionField(base, gens) =>
      domain_rational_function_lcm_expr(base, gens, left, right)
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) =>
          domain_rational_function_lcm_expr(inner, gens, left, right)
        _ => domain_scalar_lcm_expr(base, left, right)
      }
    _ => domain_scalar_lcm_expr(domain, left, right)
  }
}

///|
pub fn domain_cofactors_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PolyError {
  let gcd = domain_gcd_expr(domain, left, right)
  let cfa = match domain {
    Domain::ZZ =>
      match (expr_rational_value(left), expr_rational_value(gcd)) {
        (Some(lhs), Some(g)) if lhs.is_integral() && g.is_integral() && !g.is_zero() =>
          expr_from_bigint(lhs.numerator().div(g.numerator()))
        _ => raise PolyError::ExactQuotientFailed
      }
    Domain::QQ =>
      match (expr_rational_value(left), expr_rational_value(gcd)) {
        (Some(lhs), Some(g)) if !g.is_zero() => expr_from_rational(lhs.div_r(g))
        _ => raise PolyError::ExactQuotientFailed
      }
    Domain::ZZ_I => {
      let q = gaussian_int_div_exact(
        gaussian_int_from_expr(domain, left),
        gaussian_int_from_expr(domain, gcd),
      )
      gaussian_int_to_expr(q)
    }
    Domain::QQ_I => {
      let q = gaussian_rat_div(
        gaussian_rat_from_expr(domain, left),
        gaussian_rat_from_expr(domain, gcd),
      )
      gaussian_rat_to_expr(q)
    }
    Domain::PolyRing(coeff_domain, gens) => {
      let lhs = Poly::from_expr(left, gens, coeff_domain)
      let g = Poly::from_expr(gcd, gens, coeff_domain)
      poly_exact_quo(lhs, g).to_expr()
    }
    Domain::RationalFunctionField(coeff_domain, gens) => {
      let (left_num, left_den) = rational_function_pair_from_expr(coeff_domain, gens, left)
      let (g_num, g_den) = rational_function_pair_from_expr(coeff_domain, gens, gcd)
      rational_function_expr_from_pair(left_num.mul(g_den), left_den.mul(g_num), coeff_domain)
    }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(coeff_domain, gens) | Domain::RationalFunctionField(coeff_domain, gens) => {
          let (left_num, left_den) = rational_function_pair_from_expr(coeff_domain, gens, left)
          let (g_num, g_den) = rational_function_pair_from_expr(coeff_domain, gens, gcd)
          rational_function_expr_from_pair(left_num.mul(g_den), left_den.mul(g_num), coeff_domain)
        }
        _ =>
          if domain_is_one_expr(base, gcd) {
            left
          } else {
            left * (gcd ^ @symcore.int(-1))
          }
      }
    _ =>
      if domain_is_one_expr(domain, gcd) {
        left
      } else {
        left * (gcd ^ @symcore.int(-1))
      }
  }
  let cfb = match domain {
    Domain::ZZ =>
      match (expr_rational_value(right), expr_rational_value(gcd)) {
        (Some(rhs), Some(g)) if rhs.is_integral() && g.is_integral() && !g.is_zero() =>
          expr_from_bigint(rhs.numerator().div(g.numerator()))
        _ => raise PolyError::ExactQuotientFailed
      }
    Domain::QQ =>
      match (expr_rational_value(right), expr_rational_value(gcd)) {
        (Some(rhs), Some(g)) if !g.is_zero() => expr_from_rational(rhs.div_r(g))
        _ => raise PolyError::ExactQuotientFailed
      }
    Domain::ZZ_I => {
      let q = gaussian_int_div_exact(
        gaussian_int_from_expr(domain, right),
        gaussian_int_from_expr(domain, gcd),
      )
      gaussian_int_to_expr(q)
    }
    Domain::QQ_I => {
      let q = gaussian_rat_div(
        gaussian_rat_from_expr(domain, right),
        gaussian_rat_from_expr(domain, gcd),
      )
      gaussian_rat_to_expr(q)
    }
    Domain::PolyRing(coeff_domain, gens) => {
      let rhs = Poly::from_expr(right, gens, coeff_domain)
      let g = Poly::from_expr(gcd, gens, coeff_domain)
      poly_exact_quo(rhs, g).to_expr()
    }
    Domain::RationalFunctionField(coeff_domain, gens) => {
      let (right_num, right_den) = rational_function_pair_from_expr(coeff_domain, gens, right)
      let (g_num, g_den) = rational_function_pair_from_expr(coeff_domain, gens, gcd)
      rational_function_expr_from_pair(right_num.mul(g_den), right_den.mul(g_num), coeff_domain)
    }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(coeff_domain, gens) | Domain::RationalFunctionField(coeff_domain, gens) => {
          let (right_num, right_den) = rational_function_pair_from_expr(coeff_domain, gens, right)
          let (g_num, g_den) = rational_function_pair_from_expr(coeff_domain, gens, gcd)
          rational_function_expr_from_pair(right_num.mul(g_den), right_den.mul(g_num), coeff_domain)
        }
        _ =>
          if domain_is_one_expr(base, gcd) {
            right
          } else {
            right * (gcd ^ @symcore.int(-1))
          }
      }
    _ =>
      if domain_is_one_expr(domain, gcd) {
        right
      } else {
        right * (gcd ^ @symcore.int(-1))
      }
  }
  (gcd, cfa, cfb)
}

fn domain_poly_gcdex_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PolyError {
  if gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  guard domain_is_field_pred(coeff_domain) else { raise PolyError::DomainNotField }
  let a = Poly::from_expr(left, gens, coeff_domain)
  let b = Poly::from_expr(right, gens, coeff_domain)
  let zero = Poly::zero(gens, coeff_domain)
  let one = Poly::one(gens, coeff_domain)
  if a.is_zero() && b.is_zero() {
    return (zero.to_expr(), one.to_expr(), zero.to_expr())
  }
  let mut old_r = a
  let mut r = b
  let mut old_s = one
  let mut s = zero
  let mut old_t = Poly::zero(gens, coeff_domain)
  let mut t = Poly::one(gens, coeff_domain)
  while !r.is_zero() {
    let (q, rem) = old_r.divmod_univar(r)
    let new_s = old_s.sub(q.mul(s))
    let new_t = old_t.sub(q.mul(t))
    old_r = r
    r = rem
    old_s = s
    s = new_s
    old_t = t
    t = new_t
  }
  match old_r.leading_term() {
    Some((_, lc)) => {
      let inv = fe_inv(lc)
      old_r = old_r.scale_coeff(inv)
      old_s = old_s.scale_coeff(inv)
      old_t = old_t.scale_coeff(inv)
    }
    None => ()
  }
  (old_s.to_expr(), old_t.to_expr(), old_r.to_expr())
}

///|
pub fn domain_gcdex_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  if domain_is_field_pred(domain) {
    let gcd = domain_gcd_expr(domain, left, right)
    if domain_is_zero_expr(domain, left) {
      if domain_is_zero_expr(domain, right) {
        return (domain_zero_like_expr(domain), domain_one_like_expr(domain), domain_zero_like_expr(domain))
      } else {
        return (
          domain_zero_like_expr(domain),
          domain_quo_expr(domain, gcd, right),
          gcd,
        )
      }
    } else {
      return (
        domain_quo_expr(domain, gcd, left),
        domain_zero_like_expr(domain),
        gcd,
      )
    }
  }
  match domain {
    Domain::ZZ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() && rhs.is_integral() => {
          let (s, t, g) = domain_bigint_gcdex(lhs.numerator(), rhs.numerator())
          (expr_from_bigint(s), expr_from_bigint(t), expr_from_bigint(g))
        }
        _ => raise PolyError::DomainMismatch
      }
    Domain::ZZ_I => {
      let zero = GaussianIntCompat::{ re: BigInt::from_int(0), im: BigInt::from_int(0) }
      let one = GaussianIntCompat::{ re: BigInt::from_int(1), im: BigInt::from_int(0) }
      let mut old_r = gaussian_int_from_expr(domain, left)
      let mut r = gaussian_int_from_expr(domain, right)
      if gaussian_int_is_zero(old_r) && gaussian_int_is_zero(r) {
        return (gaussian_int_to_expr(zero), gaussian_int_to_expr(one), gaussian_int_to_expr(zero))
      }
      let mut old_s = one
      let mut s = zero
      let mut old_t = zero
      let mut t = one
      while !gaussian_int_is_zero(r) {
        let q = gaussian_int_quo_round(old_r, r)
        let new_r = gaussian_int_sub(old_r, gaussian_int_mul(q, r))
        let new_s = gaussian_int_sub(old_s, gaussian_int_mul(q, s))
        let new_t = gaussian_int_sub(old_t, gaussian_int_mul(q, t))
        old_r = r
        r = new_r
        old_s = s
        s = new_s
        old_t = t
        t = new_t
      }
      let unit = gaussian_int_canonical_unit(old_r)
      old_r = gaussian_int_mul(old_r, unit)
      old_s = gaussian_int_mul(old_s, unit)
      old_t = gaussian_int_mul(old_t, unit)
      (gaussian_int_to_expr(old_s), gaussian_int_to_expr(old_t), gaussian_int_to_expr(old_r))
    }
    Domain::PolyRing(coeff_domain, gens) =>
      domain_poly_gcdex_expr(coeff_domain, gens, left, right)
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_half_gcdex_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) raise PolyError {
  let (s, _, g) = domain_gcdex_expr(domain, left, right)
  (s, g)
}

///|
pub fn domain_invert_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  let (s, _, h) = domain_gcdex_expr(domain, left, right)
  guard domain_is_one_expr(domain, h) else { raise PolyError::ExactQuotientFailed }
  domain_rem_expr(domain, s, right)
}

///|
pub fn domain_revert_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  if domain_is_field_pred(domain) {
    guard !domain_is_zero_expr(domain, expr) else { raise PolyError::DivisionByZero }
    return domain_quo_expr(domain, domain_one_like_expr(domain), expr)
  }
  if domain_is_one_expr(domain, expr) || domain_is_negative_one_expr(domain, expr) {
    expr
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
pub fn domain_factorial_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::ZZ | Domain::QQ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() && value.compare(@symnum.BigRational::zero()) >= 0 =>
          expr_from_bigint(domain_bigint_factorial(value.numerator()))
        _ => raise PolyError::DomainMismatch
      }
    Domain::PolyRing(base, gens)
    | Domain::QuotientRing(base, gens, _)
    | Domain::PowerSeries(base, gens, _) => {
      let poly = Poly::from_expr(expr, gens, base)
      let ground = poly_ground_expr(poly)
      domain_from_sympy_expr(domain, domain_factorial_expr(base, ground))
    }
    Domain::RationalFunctionField(base, gens) => {
      let (numer, denom) = rational_function_pair_from_expr(base, gens, expr)
      guard poly_is_ground(denom) && domain_is_one_expr(base, poly_ground_expr(denom)) else {
        raise PolyError::DomainMismatch
      }
      let ground = poly_ground_expr(numer)
      domain_from_sympy_expr(domain, domain_factorial_expr(base, ground))
    }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) =>
          domain_factorial_expr(Domain::RationalFunctionField(inner, gens), expr)
        _ => domain_factorial_expr(base, expr)
      }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_log_expr(
  domain : Domain,
  value : @symcore.Expr,
  base : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, value) && domain_contains_expr(domain, base) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ =>
      match (expr_rational_value(value), expr_rational_value(base)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() && rhs.is_integral() =>
          expr_from_bigint(domain_bigint_log_floor(lhs.numerator(), rhs.numerator()))
        _ => raise PolyError::DomainMismatch
      }
    Domain::PolyRing(inner, gens)
    | Domain::QuotientRing(inner, gens, _)
    | Domain::PowerSeries(inner, gens, _) => {
      let lhs = poly_ground_expr(Poly::from_expr(value, gens, inner))
      let rhs = poly_ground_expr(Poly::from_expr(base, gens, inner))
      domain_from_sympy_expr(domain, domain_log_expr(inner, lhs, rhs))
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_sqrt_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::ZZ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() =>
          expr_from_bigint(domain_bigint_sqrt_floor(value.numerator()))
        _ => raise PolyError::DomainMismatch
      }
    Domain::PolyRing(base, gens)
    | Domain::QuotientRing(base, gens, _)
    | Domain::PowerSeries(base, gens, _) => {
      let poly = Poly::from_expr(expr, gens, base)
      let ground = poly_ground_expr(poly)
      domain_from_sympy_expr(domain, domain_sqrt_expr(base, ground))
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_exsqrt_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr? raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::ZZ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() =>
          domain_bigint_exsqrt(value.numerator()).map(root => expr_from_bigint(root))
        _ => raise PolyError::DomainMismatch
      }
    Domain::QQ =>
      match expr_rational_value(expr) {
        Some(value) => domain_rational_exsqrt(value).map(root => expr_from_rational(root))
        None => raise PolyError::DomainMismatch
      }
    Domain::ZZ_I =>
      gaussian_int_exsqrt(gaussian_int_from_expr(domain, expr)).map(root => gaussian_int_to_expr(root))
    Domain::QQ_I =>
      gaussian_rat_exsqrt(gaussian_rat_from_expr(domain, expr)).map(root => gaussian_rat_to_expr(root))
    Domain::GF(_)
    | Domain::GFExt(_, _, _) =>
      finite_field_exsqrt(domain, field_elem_from_scalar_expr(expr, domain)).map(
        root => domain_field_elem_to_expr(domain, root),
      )
    Domain::RR =>
      match domain_expr_sign(domain, expr) {
        Some(v) if v < 0 => None
        _ => Some(expr_exact_sqrt_or_symbolic(expr))
      }
    Domain::CC => Some(@symcore.function("sqrt", [expr]))
    Domain::PolyRing(base, gens)
    | Domain::QuotientRing(base, gens, _)
    | Domain::PowerSeries(base, gens, _) => {
      let poly = Poly::from_expr(expr, gens, base)
      let ground = poly_ground_expr(poly)
      match domain_exsqrt_expr(base, ground) {
        Some(root) => Some(domain_from_sympy_expr(domain, root))
        None => None
      }
    }
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(inner, gens) | Domain::RationalFunctionField(inner, gens) => {
          let (numer, denom) = rational_function_pair_from_expr(inner, gens, expr)
          match (domain_exsqrt_expr(Domain::PolyRing(inner, gens), numer.to_expr()), domain_exsqrt_expr(Domain::PolyRing(inner, gens), denom.to_expr())) {
            (Some(num_root), Some(den_root)) =>
              Some(num_root * (den_root ^ @symcore.int(-1)))
            _ => None
          }
        }
        _ => domain_exsqrt_expr(base, expr)
      }
    _ => None
  }
}

///|
pub fn domain_is_square_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> Bool raise PolyError {
  match domain {
    Domain::RR =>
      match domain_expr_sign(domain, expr) {
        Some(v) => v >= 0
        None => false
      }
    Domain::CC => domain_contains_expr(domain, expr)
    Domain::GF(_)
    | Domain::GFExt(_, _, _) => {
      guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
      let value = field_elem_from_scalar_expr(expr, domain)
      if fe_is_zero(value) {
        true
      } else {
        let q = finite_field_order(domain)
        if q % 2 == 0 {
          true
        } else {
          fe_is_one(fe_pow(value, (q - 1) / 2))
        }
      }
    }
    _ => domain_exsqrt_expr(domain, expr) is Some(_)
  }
}

///|
pub fn domain_real_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  domain_from_sympy_expr(domain, expr)
}

///|
pub fn domain_imag_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  domain_zero_like_expr(domain)
}

fn gaussian_rat_almosteq(
  left : GaussianRatCompat,
  right : GaussianRatCompat,
  tolerance : @symnum.BigRational,
) -> Bool {
  rational_abs(left.re.add_r(right.re.neg_r())).compare(tolerance) <= 0 &&
  rational_abs(left.im.add_r(right.im.neg_r())).compare(tolerance) <= 0
}

///|
pub fn domain_almosteq_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
  tolerance? : @symnum.BigRational? = None,
) -> Bool {
  if !domain_contains_expr(domain, left) || !domain_contains_expr(domain, right) {
    return false
  }
  let tol = match tolerance {
    Some(value) => value
    None => @symnum.BigRational::zero()
  }
  match (expr_rational_value(left), expr_rational_value(right)) {
    (Some(lhs), Some(rhs)) =>
      if tol.is_zero() {
        lhs.compare(rhs) == 0
      } else {
        rational_abs(lhs.add_r(rhs.neg_r())).compare(tol) <= 0
      }
    _ => {
      let lhs_gauss = gaussian_rat_from_expr(domain, left) catch { _ => {
        let lhs = domain_from_sympy_expr(domain, left) catch { _ => return false }
        let rhs = domain_from_sympy_expr(domain, right) catch { _ => return false }
        return expr_key(lhs) == expr_key(rhs)
      } }
      let rhs_gauss = gaussian_rat_from_expr(domain, right) catch { _ => {
        let lhs = domain_from_sympy_expr(domain, left) catch { _ => return false }
        let rhs = domain_from_sympy_expr(domain, right) catch { _ => return false }
        return expr_key(lhs) == expr_key(rhs)
      } }
      if tol.is_zero() {
        lhs_gauss.re.compare(rhs_gauss.re) == 0 &&
        lhs_gauss.im.compare(rhs_gauss.im) == 0
      } else {
        gaussian_rat_almosteq(lhs_gauss, rhs_gauss, tol)
      }
    }
  }
}

///|
pub fn domain_evalf_expr(
  domain : Domain,
  expr : @symcore.Expr,
  prec? : Int? = None,
) -> @symcore.Expr raise PolyError {
  ignore(prec)
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  domain_to_sympy_expr(domain, expr)
}

fn domain_zero_like_expr(domain : Domain) -> @symcore.Expr raise PolyError {
  match domain {
    Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::RR
    | Domain::CC => domain_field_elem_to_expr(domain, fe_from_int(0, domain))
    _ => @symcore.int(0)
  }
}

fn domain_one_like_expr(domain : Domain) -> @symcore.Expr raise PolyError {
  match domain {
    Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::RR
    | Domain::CC => domain_field_elem_to_expr(domain, fe_from_int(1, domain))
    _ => @symcore.int(1)
  }
}

///|
/// Return the additive identity of `domain` as an expression.
pub fn domain_zero_expr(domain : Domain) -> @symcore.Expr raise PolyError {
  domain_zero_like_expr(domain)
}

///|
/// Return the multiplicative identity of `domain` as an expression.
pub fn domain_one_expr(domain : Domain) -> @symcore.Expr raise PolyError {
  domain_one_like_expr(domain)
}

///|
/// Unary plus over domain elements.
pub fn domain_pos_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_from_sympy_expr(domain, expr)
}

///|
/// Unary minus over domain elements.
pub fn domain_neg_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  domain_from_sympy_expr(domain, @symcore.int(-1) * expr)
}

///|
/// Addition over domain elements.
pub fn domain_add_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  domain_from_sympy_expr(domain, left + right)
}

///|
/// Subtraction over domain elements.
pub fn domain_sub_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  domain_from_sympy_expr(domain, left + (@symcore.int(-1) * right))
}

///|
/// Multiplication over domain elements.
pub fn domain_mul_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_mul(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    Domain::QQ_I =>
      gaussian_rat_to_expr(
        gaussian_rat_mul(
          gaussian_rat_from_expr(domain, left),
          gaussian_rat_from_expr(domain, right),
        ),
      )
    _ => domain_from_sympy_expr(domain, left * right)
  }
}

///|
/// Exponentiation over domain elements.
pub fn domain_pow_expr(
  domain : Domain,
  expr : @symcore.Expr,
  exp : Int,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  if exp == 0 {
    return domain_one_like_expr(domain)
  }
  if exp < 0 {
    guard domain_is_field_pred(domain) else { raise PolyError::DomainNotField }
    return domain_quo_expr(domain, domain_one_like_expr(domain), domain_pow_expr(domain, expr, -exp))
  }
  let mut n = exp
  let mut base = domain_from_sympy_expr(domain, expr)
  let mut acc = domain_one_like_expr(domain)
  while n > 0 {
    if n.land(1) == 1 {
      acc = domain_mul_expr(domain, acc, base)
    }
    n = n / 2
    if n > 0 {
      base = domain_mul_expr(domain, base, base)
    }
  }
  acc
}

fn domain_field_elem_to_expr(
  domain : Domain,
  elem : FieldElem,
) -> @symcore.Expr {
  match (domain, elem) {
    (Domain::GF(p), FieldElem::GFp(_, value)) => {
      let symm = if value > p / 2 { value - p } else { value }
      @symcore.number(@symnum.BigRational::from_int(symm))
    }
    _ => fe_to_expr_const(elem)
  }
}

fn domain_rational_function_quo_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  let (left_num, left_den) = rational_function_pair_from_expr(coeff_domain, gens, left)
  let (right_num, right_den) = rational_function_pair_from_expr(coeff_domain, gens, right)
  if right_num.is_zero() {
    raise PolyError::DivisionByZero
  }
  rational_function_expr_from_pair(left_num.mul(right_den), left_den.mul(right_num), coeff_domain)
}

fn domain_poly_div_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) raise PolyError {
  let lhs = Poly::from_expr(left, gens, coeff_domain)
  let rhs = Poly::from_expr(right, gens, coeff_domain)
  if rhs.is_zero() {
    raise PolyError::DivisionByZero
  }
  if gens.length() == 1 {
    let (q, r) = lhs.divmod_univar(rhs)
    (q.to_expr(), r.to_expr())
  } else {
    let (qs, r) = lhs.divmod_multivar([rhs])
    (qs[0].to_expr(), r.to_expr())
  }
}

///|
pub fn domain_numer_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::ZZ => expr
    Domain::QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_bigint(value.numerator())
        None => raise PolyError::DomainMismatch
      }
    Domain::ZZ_I => expr
    Domain::QQ_I => {
      let value = gaussian_rat_from_expr(domain, expr)
      let (numer, _) = gaussian_rat_numer_denom(value)
      gaussian_int_to_expr(numer)
    }
    Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::RR
    | Domain::CC =>
      domain_field_elem_to_expr(domain, field_elem_from_scalar_expr(expr, domain))
    Domain::PolyRing(_, _)
    | Domain::QuotientRing(_, _, _)
    | Domain::PowerSeries(_, _, _)
    | Domain::EX
    | Domain::EXRAW
    | Domain::AlgExt(_, _, _) => expr
    Domain::RationalFunctionField(coeff_domain, gens) =>
      rational_function_pair_from_expr(coeff_domain, gens, expr).0.to_expr()
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(coeff_domain, gens) | Domain::RationalFunctionField(coeff_domain, gens) =>
          rational_function_pair_from_expr(coeff_domain, gens, expr).0.to_expr()
        _ => domain_numer_expr(base, expr)
      }
  }
}

///|
pub fn domain_denom_expr(
  domain : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise PolyError::DomainMismatch }
  match domain {
    Domain::QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_bigint(value.denominator())
        None => raise PolyError::DomainMismatch
      }
    Domain::QQ_I => {
      let value = gaussian_rat_from_expr(domain, expr)
      let (_, denom) = gaussian_rat_numer_denom(value)
      expr_from_bigint(denom)
    }
    Domain::RationalFunctionField(coeff_domain, gens) =>
      rational_function_pair_from_expr(coeff_domain, gens, expr).1.to_expr()
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(coeff_domain, gens) | Domain::RationalFunctionField(coeff_domain, gens) =>
          rational_function_pair_from_expr(coeff_domain, gens, expr).1.to_expr()
        _ => domain_denom_expr(base, expr)
      }
    _ => domain_one_like_expr(domain)
  }
}

///|
pub fn domain_quo_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() && rhs.is_integral() && !rhs.is_zero() =>
          expr_from_bigint(lhs.numerator().div(rhs.numerator()))
        _ => raise PolyError::DomainMismatch
      }
    Domain::QQ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if !rhs.is_zero() => expr_from_rational(lhs.div_r(rhs))
        _ => raise PolyError::DomainMismatch
      }
    Domain::ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_quo_round(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    Domain::QQ_I =>
      gaussian_rat_to_expr(
        gaussian_rat_div(
          gaussian_rat_from_expr(domain, left),
          gaussian_rat_from_expr(domain, right),
        ),
      )
    Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::RR
    | Domain::CC => {
      let lhs = field_elem_from_scalar_expr(left, domain)
      let rhs = field_elem_from_scalar_expr(right, domain)
      domain_field_elem_to_expr(domain, fe_mul(lhs, fe_inv(rhs)))
    }
    Domain::EX | Domain::EXRAW | Domain::AlgExt(_, _, _) =>
      if domain_is_zero_expr(domain, right) {
        raise PolyError::DivisionByZero
      } else {
        left * (right ^ @symcore.int(-1))
      }
    Domain::PolyRing(coeff_domain, gens) | Domain::QuotientRing(coeff_domain, gens, _) =>
      domain_poly_div_expr(coeff_domain, gens, left, right).0
    Domain::RationalFunctionField(coeff_domain, gens) =>
      domain_rational_function_quo_expr(coeff_domain, gens, left, right)
    Domain::Frac(base) =>
      match base {
        Domain::PolyRing(coeff_domain, gens) | Domain::RationalFunctionField(coeff_domain, gens) =>
          domain_rational_function_quo_expr(coeff_domain, gens, left, right)
        _ => domain_quo_expr(base, left, right)
      }
    Domain::PowerSeries(_, _, _) => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_rem_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() && rhs.is_integral() && !rhs.is_zero() =>
          expr_from_bigint(domain_bigint_euclid_mod(lhs.numerator(), rhs.numerator()))
        _ => raise PolyError::DomainMismatch
      }
    Domain::ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_rem(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    Domain::PolyRing(coeff_domain, gens) | Domain::QuotientRing(coeff_domain, gens, _) =>
      domain_poly_div_expr(coeff_domain, gens, left, right).1
    Domain::GF(_)
    | Domain::GFExt(_, _, _)
    | Domain::QQ
    | Domain::QQ_I
    | Domain::RR
    | Domain::CC
    | Domain::EX
    | Domain::EXRAW
    | Domain::RationalFunctionField(_, _)
    | Domain::Frac(_)
    | Domain::AlgExt(_, _, _) =>
      domain_zero_like_expr(domain)
    Domain::PowerSeries(_, _, _) => raise PolyError::DomainMismatch
  }
}

///|
pub fn domain_div_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) raise PolyError {
  (domain_quo_expr(domain, left, right), domain_rem_expr(domain, left, right))
}

///|
pub fn domain_exquo_expr(
  domain : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  guard domain_contains_expr(domain, left) && domain_contains_expr(domain, right) else {
    raise PolyError::DomainMismatch
  }
  match domain {
    Domain::ZZ => {
      let q = domain_quo_expr(domain, left, right)
      guard domain_is_zero_expr(domain, domain_rem_expr(domain, left, right)) else {
        raise PolyError::ExactQuotientFailed
      }
      q
    }
    Domain::ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_div_exact(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    Domain::PolyRing(coeff_domain, gens) | Domain::QuotientRing(coeff_domain, gens, _) => {
      let (q, r) = domain_poly_div_expr(coeff_domain, gens, left, right)
      guard domain_is_zero_expr(Domain::PolyRing(coeff_domain, gens), r) else {
        raise PolyError::ExactQuotientFailed
      }
      q
    }
    _ => domain_quo_expr(domain, left, right)
  }
}

///|
pub fn Domain::is_zero_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_zero_expr(self, expr)
}

///|
pub fn Domain::zero_expr(self : Domain) -> @symcore.Expr raise PolyError {
  domain_zero_expr(self)
}

///|
pub fn Domain::one_expr(self : Domain) -> @symcore.Expr raise PolyError {
  domain_one_expr(self)
}

///|
pub fn Domain::from_sympy_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_from_sympy_expr(self, expr)
}

///|
pub fn Domain::to_sympy_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_to_sympy_expr(self, expr)
}

///|
pub fn Domain::convert_from_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr raise PolyError {
  domain_convert_from_expr(self, expr, base)
}

///|
pub fn Domain::convert_expr(
  self : Domain,
  expr : @symcore.Expr,
  base? : Domain? = None,
) -> @symcore.Expr raise PolyError {
  domain_convert_expr(self, expr, base=base)
}

///|
pub fn Domain::from_ff_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_ff_expr(self, expr, base)
}

///|
pub fn Domain::from_real_field_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_real_field_expr(self, expr, base)
}

///|
pub fn Domain::from_complex_field_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_complex_field_expr(self, expr, base)
}

///|
pub fn Domain::from_algebraic_field_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_algebraic_field_expr(self, expr, base)
}

///|
pub fn Domain::from_polynomial_ring_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_polynomial_ring_expr(self, expr, base)
}

///|
pub fn Domain::from_fraction_field_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_fraction_field_expr(self, expr, base)
}

///|
pub fn Domain::from_expression_domain_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_expression_domain_expr(self, expr, base)
}

///|
pub fn Domain::from_expression_raw_domain_expr(
  self : Domain,
  expr : @symcore.Expr,
  base : Domain,
) -> @symcore.Expr? {
  domain_from_expression_raw_domain_expr(self, expr, base)
}

///|
pub fn Domain::unify_composite(
  self : Domain,
  other : Domain,
) -> Domain raise PolyError {
  domain_unify_composite(self, other)
}

///|
pub fn Domain::is_one_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_one_expr(self, expr)
}

///|
pub fn Domain::is_negative_one_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_negative_one_expr(self, expr)
}

///|
pub fn Domain::is_unit_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_unit_expr(self, expr)
}

///|
pub fn Domain::is_positive_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_positive_expr(self, expr)
}

///|
pub fn Domain::is_negative_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_negative_expr(self, expr)
}

///|
pub fn Domain::is_nonpositive_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_nonpositive_expr(self, expr)
}

///|
pub fn Domain::is_nonnegative_expr(self : Domain, expr : @symcore.Expr) -> Bool {
  domain_is_nonnegative_expr(self, expr)
}

///|
pub fn Domain::canonical_unit_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_canonical_unit_expr(self, expr)
}

///|
pub fn Domain::abs_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_abs_expr(self, expr)
}

///|
pub fn Domain::gcd_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_gcd_expr(self, left, right)
}

///|
pub fn Domain::lcm_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_lcm_expr(self, left, right)
}

///|
pub fn Domain::cofactors_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PolyError {
  domain_cofactors_expr(self, left, right)
}

///|
pub fn Domain::numer_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_numer_expr(self, expr)
}

///|
pub fn Domain::denom_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_denom_expr(self, expr)
}

///|
pub fn Domain::quo_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_quo_expr(self, left, right)
}

///|
pub fn Domain::rem_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_rem_expr(self, left, right)
}

///|
pub fn Domain::div_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) raise PolyError {
  domain_div_expr(self, left, right)
}

///|
pub fn Domain::exquo_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_exquo_expr(self, left, right)
}

///|
pub fn Domain::half_gcdex_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) raise PolyError {
  domain_half_gcdex_expr(self, left, right)
}

///|
pub fn Domain::gcdex_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PolyError {
  domain_gcdex_expr(self, left, right)
}

///|
pub fn Domain::invert_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_invert_expr(self, left, right)
}

///|
pub fn Domain::revert_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_revert_expr(self, expr)
}

///|
pub fn Domain::factorial_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_factorial_expr(self, expr)
}

///|
pub fn Domain::log_expr(
  self : Domain,
  value : @symcore.Expr,
  base : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_log_expr(self, value, base)
}

///|
pub fn Domain::sqrt_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_sqrt_expr(self, expr)
}

///|
pub fn Domain::is_square_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> Bool raise PolyError {
  domain_is_square_expr(self, expr)
}

///|
pub fn Domain::exsqrt_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr? raise PolyError {
  domain_exsqrt_expr(self, expr)
}

///|
pub fn Domain::real_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_real_expr(self, expr)
}

///|
pub fn Domain::imag_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_imag_expr(self, expr)
}

///|
pub fn Domain::almosteq_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
  tolerance? : @symnum.BigRational? = None,
) -> Bool {
  domain_almosteq_expr(self, left, right, tolerance=tolerance)
}

///|
pub fn Domain::evalf_expr(
  self : Domain,
  expr : @symcore.Expr,
  prec? : Int? = None,
) -> @symcore.Expr raise PolyError {
  domain_evalf_expr(self, expr, prec=prec)
}

///|
pub fn Domain::pos_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_pos_expr(self, expr)
}

///|
pub fn Domain::neg_expr(
  self : Domain,
  expr : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_neg_expr(self, expr)
}

///|
pub fn Domain::add_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_add_expr(self, left, right)
}

///|
pub fn Domain::sub_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_sub_expr(self, left, right)
}

///|
pub fn Domain::mul_expr(
  self : Domain,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr raise PolyError {
  domain_mul_expr(self, left, right)
}

///|
pub fn Domain::pow_expr(
  self : Domain,
  expr : @symcore.Expr,
  exp : Int,
) -> @symcore.Expr raise PolyError {
  domain_pow_expr(self, expr, exp)
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
pub fn Domain::alg_field_from_poly(
  self : Domain,
  poly : Poly,
  alias? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  domain_alg_field_from_poly(self, poly, alias=alias, root_index=root_index)
}

///|
pub fn Domain::cyclotomic_field(
  self : Domain,
  n : Int,
  ss? : Bool = false,
  alias? : String = "zeta",
  gen? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  domain_cyclotomic_field(
    self,
    n,
    ss=ss,
    alias=alias,
    gen=gen,
    root_index=root_index,
  )
}

///|
pub fn Domain::inject(self : Domain, gens : Array[String]) -> Domain raise PolyError {
  domain_inject(self, gens)
}

///|
pub fn Domain::drop(self : Domain, gens : Array[String]) -> Domain raise PolyError {
  domain_drop(self, gens)
}
