///|
/// Public domain parsing and compatibility helpers for polynomial code.
///
/// Current Limits:
/// - this file focuses on the public compatibility layer around domains, not
///   every low-level domain operation in the package.
/// - some composite-domain coercion paths remain conservative compared with the
///   full package surface.

///|
/// Parse a high-level domain token into a `Domain`.
///
/// - Does: Converts strings such as `ZZ`, `QQ`, `GF(7)`, or composite forms
///   into the package domain descriptor.
/// - Input: A `String`.
/// - Returns: A `Domain`.
/// - Limits: Raises `PolyError` when the token is malformed or unsupported.
pub fn domain_from_string(spec : String) -> Domain raise PolyError {
  let s = spec.trim().to_owned()
  match s {
    "ZZ" | "IntegerRing" => ZZ
    "QQ" | "RationalField" => QQ
    "RR" | "RealField" => RR
    "CC" | "ComplexField" => CC
    "ZZ_I" | "GaussianIntegerRing" => ZZ_I
    "QQ_I" | "GaussianRationalField" => QQ_I
    "EX" | "ExpressionDomain" => EX
    "EXRAW" | "ExpressionRawDomain" => EXRAW
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
  if s.length() < 4 || s[s.length() - 2:s.length()].to_owned() != "]]" {
    return None
  }
  let mut depth = 0
  let mut i = s.length() - 2
  while i >= 0 {
    if i + 2 <= s.length() && s[i:i + 2].to_owned() == "]]" {
      depth += 1
      if i == 0 {
        break
      }
      i -= 1
      continue
    }
    if i + 2 <= s.length() && s[i:i + 2].to_owned() == "[[" {
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
    if s[i:i + n].to_owned() == needle {
      return Some(i)
    }
  }
  None
}

///|
fn split_gf_descriptor(
  raw : String,
  spec : String,
) -> (Int, Int?) raise PolyError {
  let body = raw.trim().to_owned()
  if body.contains("**") {
    let parts : Array[String] = Array::new()
    for p in body.split("**") {
      parts.push(p.trim().to_owned())
    }
    if parts.length() != 2 {
      raise BadGenerator(spec)
    }
    let p = @string.parse_int(parts[0]) catch { _ => raise BadGenerator(spec) }
    let k = @string.parse_int(parts[1]) catch { _ => raise BadGenerator(spec) }
    return (p, Some(k))
  }
  if body.contains(",") {
    let parts : Array[String] = Array::new()
    for p in body.split(",") {
      parts.push(p.trim().to_owned())
    }
    if parts.length() != 2 {
      raise BadGenerator(spec)
    }
    let p = @string.parse_int(parts[0]) catch { _ => raise BadGenerator(spec) }
    let k = @string.parse_int(parts[1]) catch { _ => raise BadGenerator(spec) }
    return (p, Some(k))
  }
  let p = @string.parse_int(body) catch { _ => raise BadGenerator(spec) }
  (p, None)
}

///|
fn parse_composite_domain(s : String) -> Domain raise PolyError {
  if (
      s.has_prefix("GF(") || s.has_prefix("FF(") || s.has_prefix("FiniteField(")
    ) &&
    s.has_suffix(")") {
    let left = match find_char(s, '(') {
      Some(pos) => pos
      None => raise BadGenerator(s)
    }
    let inner = s[left + 1:s.length() - 1].to_owned()
    let parsed = split_gf_descriptor(inner, s)
    let p = parsed.0
    let ext_opt = parsed.1
    match ext_opt {
      Some(k) => {
        if p <= 1 || k <= 1 {
          raise BadModulus
        }
        return GFExt(p, k, gfext_default_modulus(k))
      }
      None => {
        if p <= 1 {
          raise BadModulus
        }
        return GF(p)
      }
    }
  }
  if s.contains("[[") {
    let right = match find_last_substring(s, "]]") {
      Some(pos) => pos
      None => raise BadGenerator(s)
    }
    let ps_head = s[:right + 2].to_owned()
    let left = match find_matching_double_open_from_end(ps_head) {
      Some(pos) => pos
      None => raise BadGenerator(s)
    }
    let base = domain_from_string(s[:left].to_owned())
    let gens_str = s[left + 2:right].to_owned()
    let gens = split_gens(gens_str)
    if right + 2 == s.length() {
      return PowerSeries(base, gens, -1)
    }
    if s.has_suffix(")") &&
      right + 8 <= s.length() - 1 &&
      s[right + 2:right + 8].to_owned() == "(prec=" {
      let prec_text = s[right + 8:s.length() - 1].to_owned()
      let precision = @string.parse_int(prec_text.trim().to_owned()) catch {
        _ => raise BadGenerator(s)
      }
      return PowerSeries(base, gens, precision)
    }
    raise BadGenerator(s)
  }
  if s.contains("<") && s.has_suffix(">") {
    let left = match find_matching_open_from_end(s, '<', '>') {
      Some(pos) => pos
      None => raise BadGenerator(s)
    }
    let base = domain_from_string(s[:left].to_owned())
    let gens_str = s[left + 1:s.length() - 1].to_owned()
    let gens = split_gens(gens_str)
    return AlgExt(base, gens, [])
  }
  if s.has_prefix("Frac(") && s.has_suffix(")") {
    let inner = s[5:s.length() - 1].to_owned()
    return Frac(domain_from_string(inner))
  }
  if s.has_suffix("]") && !s.has_suffix("]]") {
    let left = match find_matching_open_from_end(s, '[', ']') {
      Some(pos) => pos
      None => raise BadGenerator(s)
    }
    let base = domain_from_string(s[:left].to_owned())
    let gens_str = s[left + 1:s.length() - 1].to_owned()
    let gens = split_gens(gens_str)
    return PolyRing(base, gens)
  }
  if s.contains("(") && s.has_suffix(")") {
    let left = match find_matching_open_from_end(s, '(', ')') {
      Some(pos) => pos
      None => raise BadGenerator(s)
    }
    let base = domain_from_string(s[:left].to_owned())
    let gens_str = s[left + 1:s.length() - 1].to_owned()
    let gens = split_gens(gens_str)
    return RationalFunctionField(base, gens)
  }
  raise BadGenerator(s)
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
  let raw = text.trim().to_owned()
  if raw == "" {
    raise BadGenerator(text)
  }
  let normalized : Array[String] = Array::new()
  for g in raw.split(",") {
    let name = g.trim().to_owned()
    if name == "" {
      raise BadGenerator(text)
    }
    if normalized.contains(name) {
      continue
    }
    normalized.push(name)
  }
  if normalized.is_empty() {
    raise BadGenerator(text)
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
/// Render a domain into its public compatibility string form.
///
/// - Does: Converts a `Domain` into the high-level string spelling used by this
///   compatibility layer.
/// - Input: A `Domain`.
/// - Returns: A `String`.
/// - Limits: The output is intended for user-facing domain spelling, not as a
///   general serialization format.
pub fn domain_to_sympy_string(domain : Domain) -> String {
  match domain {
    ZZ => "ZZ"
    QQ => "QQ"
    RR => "RR"
    CC => "CC"
    ZZ_I => "ZZ_I"
    QQ_I => "QQ_I"
    EX => "EX"
    EXRAW => "EXRAW"
    GF(p) => "GF(\{p})"
    GFExt(p, k, _) => "GF(\{p}**\{k})"
    Frac(inner) => "Frac(\{domain_to_sympy_string(inner)})"
    PolyRing(base, gens) => {
      let names = gens.join(",")
      "\{domain_to_sympy_string(base)}[\{names}]"
    }
    RationalFunctionField(base, gens) => {
      let names = gens.join(",")
      "\{domain_to_sympy_string(base)}(\{names})"
    }
    QuotientRing(base, gens, rels) => {
      let names = gens.join(",")
      let rels_str = rels.map(r => @symprint.pretty_string(r)).join(",")
      "\{domain_to_sympy_string(base)}[\{names}]/<\{rels_str}>"
    }
    PowerSeries(base, gens, prec) => {
      let names = gens.join(",")
      if prec < 0 {
        "\{domain_to_sympy_string(base)}[[\{names}]]"
      } else {
        "\{domain_to_sympy_string(base)}[[\{names}]](prec=\{prec})"
      }
    }
    AlgExt(base, gens, _) => {
      let names = gens.join(",")
      "\{domain_to_sympy_string(base)}<\{names}>"
    }
  }
}

///|
/// Tree form used by domain expression mappers.
///
/// - Does: Represents either a single coefficient expression or a nested list
///   of them for domain conversion helpers.
/// - Input: Built from the `Elem` and `List` variants.
/// - Returns: A `DomainExprTree`.
/// - Limits: This is a compatibility container, not a general expression AST.
pub enum DomainExprTree {
  Elem(Expr)
  List(Array[DomainExprTree])
}

///|
/// Wrap one expression as a tree leaf.
///
/// - Does: Builds the leaf variant used by domain tree mappers.
/// - Input: An `Expr`.
/// - Returns: A `DomainExprTree`.
/// - Limits: No normalization is applied here.
pub fn domain_expr_tree_elem(expr : Expr) -> DomainExprTree {
  Elem(expr)
}

///|
/// Wrap a list of tree nodes.
///
/// - Does: Builds the list variant used by domain tree mappers.
/// - Input: `Array[DomainExprTree]`.
/// - Returns: A `DomainExprTree`.
/// - Limits: No normalization is applied here.
pub fn domain_expr_tree_list(items : Array[DomainExprTree]) -> DomainExprTree {
  List(items)
}

///|
/// Build a prime finite-field domain.
///
/// - Does: Constructs `GF(p)` for a prime-field style modulus.
/// - Input: A positive modulus `Int`.
/// - Returns: A `Domain::GF`.
/// - Limits: Raises `PolyError::BadModulus` when `p <= 1`.
pub fn gf_domain(p : Int) -> Domain raise PolyError {
  if p <= 1 {
    raise BadModulus
  }
  GF(p)
}

///|
/// Build the integer-ring domain.
///
/// - Does: Returns the integer coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::ZZ`.
/// - Limits: This is a constructor alias only.
pub fn integer_ring_domain() -> Domain {
  ZZ
}

///|
/// Build the rational-field domain.
///
/// - Does: Returns the exact rational coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::QQ`.
/// - Limits: This is a constructor alias only.
pub fn rational_field_domain() -> Domain {
  QQ
}

///|
/// Build the real-field domain.
///
/// - Does: Returns the approximate real coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::RR`.
/// - Limits: This domain carries approximate semantics rather than exact ones.
pub fn real_field_domain() -> Domain {
  RR
}

///|
/// Build the complex-field domain.
///
/// - Does: Returns the approximate complex coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::CC`.
/// - Limits: This domain carries approximate semantics rather than exact ones.
pub fn complex_field_domain() -> Domain {
  CC
}

///|
/// Build the Gaussian-integer domain.
///
/// - Does: Returns the exact Gaussian integer coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::ZZ_I`.
/// - Limits: This is a constructor alias only.
pub fn gaussian_integer_ring_domain() -> Domain {
  ZZ_I
}

///|
/// Build the Gaussian-rational domain.
///
/// - Does: Returns the exact Gaussian rational coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::QQ_I`.
/// - Limits: This is a constructor alias only.
pub fn gaussian_rational_field_domain() -> Domain {
  QQ_I
}

///|
/// Build the expression domain.
///
/// - Does: Returns the symbolic-expression coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::EX`.
/// - Limits: Coefficients remain symbolic rather than reduced to a smaller
///   algebraic domain.
pub fn expression_domain() -> Domain {
  EX
}

///|
/// Build the raw-expression domain.
///
/// - Does: Returns the less-normalized symbolic-expression coefficient domain.
/// - Input: No arguments.
/// - Returns: `Domain::EXRAW`.
/// - Limits: Use this when normalization should stay minimal.
pub fn expression_raw_domain() -> Domain {
  EXRAW
}

///|
/// Build a finite-field domain through the generic finite-field alias.
///
/// - Does: Forwards to the prime finite-field constructor.
/// - Input: A positive modulus `Int`.
/// - Returns: A `Domain::GF`.
/// - Limits: Shares the same modulus checks as `gf_domain`.
pub fn finite_field_domain(p : Int) -> Domain raise PolyError {
  gf_domain(p)
}

///|
/// Build a finite-field domain through the `FF` alias.
///
/// - Does: Provides the alternate alias for `GF`.
/// - Input: A positive modulus `Int`.
/// - Returns: A `Domain::GF`.
/// - Limits: Shares the same modulus checks as `gf_domain`.
pub fn ff_domain(p : Int) -> Domain raise PolyError {
  gf_domain(p)
}

///|
/// Build a polynomial-ring domain.
///
/// - Does: Constructs the descriptor for `K[x1, ..., xn]`.
/// - Input: A base `Domain` and generator names.
/// - Returns: `Domain::PolyRing`.
/// - Limits: Raises `PolyError` when the generator list is malformed.
pub fn poly_ring_domain(
  base : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  PolyRing(base, split_gens(gens.join(",")))
}

///|
/// Build a rational-function field domain.
///
/// - Does: Constructs the descriptor for `K(x1, ..., xn)`.
/// - Input: A base `Domain` and generator names.
/// - Returns: `Domain::RationalFunctionField`.
/// - Limits: Raises `PolyError` when the generator list is malformed.
pub fn rational_function_field_domain(
  base : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  RationalFunctionField(base, split_gens(gens.join(",")))
}

///|
/// Build a quotient-ring domain.
///
/// - Does: Constructs the descriptor for `(K[x1, ..., xn]) / I`.
/// - Input: A base `Domain`, generator names, and defining relations.
/// - Returns: `Domain::QuotientRing`.
/// - Limits: Raises `PolyError::NonPolynomial` when the relation list is empty.
pub fn quotient_ring_domain(
  base : Domain,
  gens : Array[String],
  rels : Array[Expr],
) -> Domain raise PolyError {
  let normalized = split_gens(gens.join(","))
  if rels.is_empty() {
    raise NonPolynomial
  }
  QuotientRing(base, normalized, rels)
}

///|
/// Build a formal power-series ring domain.
///
/// - Does: Constructs the descriptor for a power-series ring over `base`.
/// - Input: A base `Domain`, generator names, and optional precision hint.
/// - Returns: `Domain::PowerSeries`.
/// - Limits: The precision is stored as metadata only at this constructor
///   layer.
pub fn power_series_domain(
  base : Domain,
  gens : Array[String],
  precision? : Int = -1,
) -> Domain raise PolyError {
  let normalized = split_gens(gens.join(","))
  PowerSeries(base, normalized, precision)
}

///|
/// True when the domain is a field in the current compatibility model.

///|
/// Public API `domain_is_field_pred`.
///
/// - Does: Provides the `domain_is_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_field_pred(domain : Domain) -> Bool {
  match domain {
    QQ
    | RR
    | CC
    | QQ_I
    | EX
    | EXRAW
    | GF(_)
    | GFExt(_, _, _)
    | Frac(_)
    | RationalFunctionField(_, _) => true
    AlgExt(base, _, _) => domain_is_field_pred(base)
    _ => false
  }
}

///|
/// True when the domain is composite in SymPy's domain hierarchy.

///|
/// Public API `domain_is_composite_pred`.
///
/// - Does: Provides the `domain_is_composite_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_composite_pred(domain : Domain) -> Bool {
  match domain {
    PolyRing(_, _)
    | RationalFunctionField(_, _)
    | QuotientRing(_, _, _)
    | PowerSeries(_, _, _) => true
    _ => false
  }
}

///|
/// True for non-composite domains except Gaussian pair domains.

///|
/// Public API `domain_is_simple_pred`.
///
/// - Does: Provides the `domain_is_simple_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_simple_pred(domain : Domain) -> Bool {
  if domain_is_composite_pred(domain) {
    return false
  }
  match domain {
    ZZ_I | QQ_I => false
    _ => true
  }
}

///|
/// True when the domain supports additive/multiplicative ring operations.

///|
/// Public API `domain_is_ring_pred`.
///
/// - Does: Provides the `domain_is_ring_pred` operation for domain compatibility.
/// - Input: parameters `_domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_ring_pred(_domain : Domain) -> Bool {
  true
}

///|
/// True when coefficients are exact (no floating approximation semantics).

///|
/// Public API `domain_is_exact_pred`.
///
/// - Does: Provides the `domain_is_exact_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_exact_pred(domain : Domain) -> Bool {
  match domain {
    RR | CC => false
    AlgExt(base, _, _) => domain_is_exact_pred(base)
    PolyRing(base, _)
    | RationalFunctionField(base, _)
    | QuotientRing(base, _, _)
    | PowerSeries(base, _, _)
    | Frac(base) => domain_is_exact_pred(base)
    _ => true
  }
}

///|
/// True when the coefficient domain has finitely many elements.

///|
/// Public API `domain_is_finite_pred`.
///
/// - Does: Provides the `domain_is_finite_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_finite_pred(domain : Domain) -> Bool {
  match domain {
    GF(_) | GFExt(_, _, _) => true
    AlgExt(base, _, _) => domain_is_finite_pred(base)
    _ => false
  }
}

///|
/// True when the domain elements are interpreted numerically.

///|
/// Public API `domain_is_numerical_pred`.
///
/// - Does: Provides the `domain_is_numerical_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_numerical_pred(domain : Domain) -> Bool {
  match domain {
    ZZ
    | QQ
    | RR
    | CC
    | ZZ_I
    | QQ_I
    | GF(_)
    | GFExt(_, _, _)
    | AlgExt(_, _, _) => true
    _ => false
  }
}

///|
/// True for algebraic domains.

///|
/// Public API `domain_is_algebraic_pred`.
///
/// - Does: Provides the `domain_is_algebraic_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_algebraic_pred(domain : Domain) -> Bool {
  match domain {
    AlgExt(_, _, _) => true
    _ => false
  }
}

///|
/// True for algebraic field domains.

///|
/// Public API `domain_is_algebraic_field_pred`.
///
/// - Does: Provides the `domain_is_algebraic_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_algebraic_field_pred(domain : Domain) -> Bool {
  domain is AlgExt(_, _, _)
}

///|
/// True for domains that have an associated ring.

///|
/// Public API `domain_has_assoc_ring_pred`.
///
/// - Does: Provides the `domain_has_assoc_ring_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_has_assoc_ring_pred(domain : Domain) -> Bool {
  match domain {
    RR | CC | GF(_) | GFExt(_, _, _) | EX | EXRAW | AlgExt(_, _, _) => false
    _ => true
  }
}

///|
/// Principal-ideal-domain predicate for migrated domain families.

///|
/// Public API `domain_is_pid_pred`.
///
/// - Does: Provides the `domain_is_pid_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_pid_pred(domain : Domain) -> Bool {
  match domain {
    RR | ZZ_I | PolyRing(_, _) | PowerSeries(_, _, _) => false
    QuotientRing(_, _, _) => false
    _ => true
  }
}

///|

///|
/// Public API `domain_is_integer_ring_pred`.
///
/// - Does: Provides the `domain_is_integer_ring_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_integer_ring_pred(domain : Domain) -> Bool {
  domain is ZZ
}

///|

///|
/// Public API `domain_is_rational_field_pred`.
///
/// - Does: Provides the `domain_is_rational_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_rational_field_pred(domain : Domain) -> Bool {
  domain is QQ
}

///|

///|
/// Public API `domain_is_real_field_pred`.
///
/// - Does: Provides the `domain_is_real_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_real_field_pred(domain : Domain) -> Bool {
  domain is RR
}

///|

///|
/// Public API `domain_is_complex_field_pred`.
///
/// - Does: Provides the `domain_is_complex_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_complex_field_pred(domain : Domain) -> Bool {
  domain is CC
}

///|

///|
/// Public API `domain_is_gaussian_ring_pred`.
///
/// - Does: Provides the `domain_is_gaussian_ring_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_gaussian_ring_pred(domain : Domain) -> Bool {
  domain is ZZ_I
}

///|

///|
/// Public API `domain_is_gaussian_field_pred`.
///
/// - Does: Provides the `domain_is_gaussian_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_gaussian_field_pred(domain : Domain) -> Bool {
  domain is QQ_I
}

///|

///|
/// Public API `domain_is_expression_domain_pred`.
///
/// - Does: Provides the `domain_is_expression_domain_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_expression_domain_pred(domain : Domain) -> Bool {
  domain is EX
}

///|

///|
/// Public API `domain_is_expression_raw_domain_pred`.
///
/// - Does: Provides the `domain_is_expression_raw_domain_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_expression_raw_domain_pred(domain : Domain) -> Bool {
  domain is EXRAW
}

///|

///|
/// Public API `domain_is_cc_pred`.
///
/// - Does: Provides the `domain_is_cc_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_cc_pred(domain : Domain) -> Bool {
  domain is CC
}

///|

///|
/// Public API `domain_is_rr_pred`.
///
/// - Does: Provides the `domain_is_rr_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_rr_pred(domain : Domain) -> Bool {
  domain is RR
}

///|

///|
/// Public API `domain_is_zz_pred`.
///
/// - Does: Provides the `domain_is_zz_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_zz_pred(domain : Domain) -> Bool {
  domain is ZZ
}

///|

///|
/// Public API `domain_is_qq_pred`.
///
/// - Does: Provides the `domain_is_qq_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_qq_pred(domain : Domain) -> Bool {
  domain is QQ
}

///|

///|
/// Public API `domain_is_zz_i_pred`.
///
/// - Does: Provides the `domain_is_zz_i_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_zz_i_pred(domain : Domain) -> Bool {
  domain is ZZ_I
}

///|

///|
/// Public API `domain_is_qq_i_pred`.
///
/// - Does: Provides the `domain_is_qq_i_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_qq_i_pred(domain : Domain) -> Bool {
  domain is QQ_I
}

///|

///|
/// Public API `domain_is_symbolic_domain_pred`.
///
/// - Does: Provides the `domain_is_symbolic_domain_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_symbolic_domain_pred(domain : Domain) -> Bool {
  domain is EX
}

///|

///|
/// Public API `domain_is_symbolic_raw_domain_pred`.
///
/// - Does: Provides the `domain_is_symbolic_raw_domain_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_symbolic_raw_domain_pred(domain : Domain) -> Bool {
  domain is EXRAW
}

///|

///|
/// Public API `domain_is_ff_pred`.
///
/// - Does: Provides the `domain_is_ff_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_ff_pred(domain : Domain) -> Bool {
  match domain {
    GF(_) | GFExt(_, _, _) => true
    _ => false
  }
}

///|

///|
/// Public API `domain_is_frac_pred`.
///
/// - Does: Provides the `domain_is_frac_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_frac_pred(domain : Domain) -> Bool {
  match domain {
    Frac(_) | RationalFunctionField(_, _) => true
    _ => false
  }
}

///|

///|
/// Public API `domain_is_fraction_field_pred`.
///
/// - Does: Provides the `domain_is_fraction_field_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_fraction_field_pred(domain : Domain) -> Bool {
  domain_is_frac_pred(domain)
}

///|

///|
/// Public API `domain_is_poly_pred`.
///
/// - Does: Provides the `domain_is_poly_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_poly_pred(domain : Domain) -> Bool {
  domain is PolyRing(_, _)
}

///|

///|
/// Public API `domain_is_polynomial_ring_pred`.
///
/// - Does: Provides the `domain_is_polynomial_ring_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_polynomial_ring_pred(domain : Domain) -> Bool {
  domain_is_poly_pred(domain)
}

///|

///|
/// Public API `domain_is_finite_extension_pred`.
///
/// - Does: Provides the `domain_is_finite_extension_pred` operation for domain compatibility.
/// - Input: parameters `_domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_finite_extension_pred(_domain : Domain) -> Bool {
  // SymPy finite fields and algebraic fields are not flagged as "FiniteExtension".
  false
}

///|

///|
/// Public API `domain_has_assoc_field_pred`.
///
/// - Does: Provides the `domain_has_assoc_field_pred` operation for domain compatibility.
/// - Input: parameters `_domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_has_assoc_field_pred(_domain : Domain) -> Bool {
  true
}

///|

///|
/// Public API `domain_has_default_precision_pred`.
///
/// - Does: Provides the `domain_has_default_precision_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_has_default_precision_pred(domain : Domain) -> Bool {
  match domain {
    RR | CC => true
    _ => false
  }
}

///|

///|
/// Public API `domain_has_characteristic_zero_pred`.
///
/// - Does: Provides the `domain_has_characteristic_zero_pred` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_has_characteristic_zero_pred(domain : Domain) -> Bool {
  domain_characteristic(domain) == 0
}

///|
/// Return the characteristic of a domain.
///
/// - Does: Computes the characteristic and follows nested composite domains
///   recursively.
/// - Input: A `Domain`.
/// - Returns: An `Int`, with `0` for characteristic-zero domains.
/// - Limits: This reports the compatibility-model characteristic only.
pub fn domain_characteristic(domain : Domain) -> Int {
  match domain {
    GF(p) => p
    GFExt(p, _, _) => p
    AlgExt(base, _, _)
    | PolyRing(base, _)
    | RationalFunctionField(base, _)
    | QuotientRing(base, _, _)
    | PowerSeries(base, _, _)
    | Frac(base) => domain_characteristic(base)
    _ => 0
  }
}

///|
/// Return an exact companion domain.
///
/// - Does: Rewrites approximate numeric domains into their exact companions and
///   propagates through composite domains.
/// - Input: A `Domain`.
/// - Returns: A `Domain`.
/// - Limits: The conversion is structural and does not inspect concrete
///   coefficient values.
pub fn domain_get_exact(domain : Domain) -> Domain {
  match domain {
    RR => QQ
    CC => QQ_I
    Frac(inner) => Frac(domain_get_exact(inner))
    PolyRing(base, gens) => PolyRing(domain_get_exact(base), gens)
    RationalFunctionField(base, gens) =>
      RationalFunctionField(domain_get_exact(base), gens)
    QuotientRing(base, gens, rels) =>
      QuotientRing(domain_get_exact(base), gens, rels)
    PowerSeries(base, gens, prec) =>
      PowerSeries(domain_get_exact(base), gens, prec)
    AlgExt(base, gens, rels) => AlgExt(domain_get_exact(base), gens, rels)
    _ => domain
  }
}

///|
/// Return a field associated with a domain.
///
/// - Does: Upgrades rings or composite domains to a field when the conversion
///   is known.
/// - Input: A `Domain`.
/// - Returns: A field-like `Domain`.
/// - Limits: Raises `PolyError::DomainNotField` when no compatible field view is
///   defined.
pub fn domain_get_field(domain : Domain) -> Domain raise PolyError {
  match domain {
    ZZ => QQ
    ZZ_I => QQ_I
    PolyRing(base, gens) => RationalFunctionField(base, gens)
    RationalFunctionField(_, _) => domain
    Frac(_) => domain
    QuotientRing(base, gens, rels) =>
      QuotientRing(domain_get_field(base), gens, rels)
    PowerSeries(base, gens, prec) =>
      PowerSeries(domain_get_field(base), gens, prec)
    _ =>
      if domain_is_field_pred(domain) {
        domain
      } else {
        raise DomainNotField
      }
  }
}

///|
/// Return a ring associated with a domain.
///
/// - Does: Downgrades a field or composite domain to a natural ring when one is
///   known.
/// - Input: A `Domain`.
/// - Returns: A ring-like `Domain`.
/// - Limits: Raises `PolyError::DomainMismatch` when no compatible ring view is
///   defined.
pub fn domain_get_ring(domain : Domain) -> Domain raise PolyError {
  match domain {
    QQ => ZZ
    QQ_I => ZZ_I
    ZZ | ZZ_I | RR | EX => domain
    Frac(inner) => inner
    RationalFunctionField(base, gens) => PolyRing(base, gens)
    PolyRing(_, _) => domain
    QuotientRing(base, gens, rels) =>
      QuotientRing(domain_get_ring(base), gens, rels)
    PowerSeries(base, gens, prec) =>
      PowerSeries(domain_get_ring(base), gens, prec)
    _ => raise DomainMismatch
  }
}

///|
/// Unify two domains into a common super-domain.
///
/// - Does: Computes a shared domain suitable for mixed-domain arithmetic.
/// - Input: Two `Domain` values.
/// - Returns: A unified `Domain`.
/// - Limits: Raises `PolyError::DomainMismatch` when no common domain is known.
pub fn domain_unify_pair(a : Domain, b : Domain) -> Domain raise PolyError {
  if Eq::equal(a, b) {
    return a
  }
  match (a, b) {
    (AlgExt(base1, gens1, rels1), AlgExt(base2, gens2, rels2)) =>
      if gens1.equal(gens2) && rels1.equal(rels2) {
        return AlgExt(domain_unify_pair(base1, base2), gens1, rels1)
      } else if rels1.is_empty() &&
        rels2.is_empty() &&
        gens1.length() == 1 &&
        gens2.length() == 1 {
        // Use a synthetic merged generator when two trivial algebraic extensions
        // need a common domain but no explicit shared presentation is available.
        let unified_base = domain_unify_pair(base1, base2)
        return AlgExt(unified_base, ["\{gens1[0]}+\{gens2[0]}"], [])
      } else {
        raise DomainMismatch
      }
    (AlgExt(base, gens, rels), other) | (other, AlgExt(base, gens, rels)) => {
      match other {
        RR | CC | EX | EXRAW => return other
        ZZ_I | QQ_I => {
          let lifted_base = domain_unify_pair(base, QQ)
          let merged_gen = if gens.is_empty() {
            "I"
          } else {
            let joined = gens.join("+")
            "\{joined}+I"
          }
          return AlgExt(lifted_base, [merged_gen], [])
        }
        PolyRing(other_base, syms) => {
          let merged_base = domain_unify_pair(
            AlgExt(base, gens, rels),
            other_base,
          )
          return PolyRing(merged_base, syms)
        }
        RationalFunctionField(other_base, syms) => {
          let merged_base = domain_unify_pair(
            AlgExt(base, gens, rels),
            other_base,
          )
          return RationalFunctionField(merged_base, syms)
        }
        Frac(other_inner) =>
          return Frac(domain_unify_pair(AlgExt(base, gens, rels), other_inner))
        _ => ()
      }
      let unified = domain_unify_pair(base, other)
      if domain_is_field_pred(unified) {
        return AlgExt(unified, gens, rels)
      } else {
        raise DomainMismatch
      }
    }
    (QuotientRing(base1, gens1, rels1), QuotientRing(base2, gens2, rels2)) =>
      if gens1.equal(gens2) && rels1.equal(rels2) {
        return QuotientRing(domain_unify_pair(base1, base2), gens1, rels1)
      } else {
        raise DomainMismatch
      }
    (PowerSeries(base1, gens1, prec1), PowerSeries(base2, gens2, prec2)) =>
      if gens1.equal(gens2) && prec1 == prec2 {
        return PowerSeries(domain_unify_pair(base1, base2), gens1, prec1)
      } else {
        raise DomainMismatch
      }
    _ => ()
  }
  if domain_is_composite_like(a) || domain_is_composite_like(b) {
    return unify_composite_domains(a, b)
  }
  let char_a = domain_characteristic(a)
  let char_b = domain_characteristic(b)
  if char_a != char_b {
    raise DomainMismatch
  }
  match (a, b) {
    (EXRAW, _) | (_, EXRAW) => EXRAW
    (EX, _) | (_, EX) => EX
    (CC, _) | (_, CC) => CC
    (RR, QQ_I) | (QQ_I, RR) | (RR, ZZ_I) | (ZZ_I, RR) => CC
    (RR, _) | (_, RR) => RR
    (QQ, ZZ) | (ZZ, QQ) => QQ
    (QQ_I, QQ)
    | (QQ, QQ_I)
    | (QQ_I, ZZ)
    | (ZZ, QQ_I)
    | (QQ_I, ZZ_I)
    | (ZZ_I, QQ_I)
    | (ZZ_I, QQ)
    | (QQ, ZZ_I) => QQ_I
    (ZZ_I, ZZ) | (ZZ, ZZ_I) => ZZ_I
    (GF(p1), GF(p2)) => if p1 == p2 { GF(p1) } else { raise DomainMismatch }
    (GF(p), GFExt(q, k, m)) | (GFExt(q, k, m), GF(p)) =>
      if p == q {
        GFExt(q, k, m)
      } else {
        raise DomainMismatch
      }
    (GFExt(p1, k1, m1), GFExt(p2, k2, m2)) =>
      if p1 == p2 && k1 == k2 && m1.equal(m2) {
        GFExt(p1, k1, m1)
      } else {
        raise DomainMismatch
      }
    (Frac(inner), rhs) => Frac(domain_unify_pair(inner, rhs))
    (lhs, Frac(inner)) => Frac(domain_unify_pair(lhs, inner))
    _ => {
      if domain_is_field_pred(a) && domain_is_ring_pred(b) {
        return a
      }
      if domain_is_field_pred(b) && domain_is_ring_pred(a) {
        return b
      }
      raise DomainMismatch
    }
  }
}

///|
fn domain_is_poly_ring(domain : Domain) -> Bool {
  match domain {
    PolyRing(_, _) => true
    _ => false
  }
}

///|
fn domain_is_fraction_field_like(domain : Domain) -> Bool {
  match domain {
    RationalFunctionField(_, _) => true
    _ => false
  }
}

///|
fn domain_is_composite_like(domain : Domain) -> Bool {
  match domain {
    QuotientRing(_, _, _) | PowerSeries(_, _, _) => true
    _ => domain_is_poly_ring(domain) || domain_is_fraction_field_like(domain)
  }
}

///|
fn domain_ground(domain : Domain) -> Domain {
  match domain {
    PolyRing(base, _)
    | RationalFunctionField(base, _)
    | QuotientRing(base, _, _)
    | PowerSeries(base, _, _) => base
    _ => domain
  }
}

///|
fn domain_symbols(domain : Domain) -> Array[String] {
  match domain {
    PolyRing(_, gens)
    | RationalFunctionField(_, gens)
    | QuotientRing(_, gens, _)
    | PowerSeries(_, gens, _) => gens
    _ => []
  }
}

///|
fn domain_has_assoc_ring(domain : Domain) -> Bool {
  match domain {
    RR | EX | CC | GF(_) | GFExt(_, _, _) | EXRAW | AlgExt(_, _, _) => false
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
    PolyRing(_, _) => PolyRing(base, gens)
    RationalFunctionField(_, _) => RationalFunctionField(base, gens)
    QuotientRing(_, _, rels) => QuotientRing(base, gens, rels)
    PowerSeries(_, _, prec) => PowerSeries(base, gens, prec)
    _ => raise DomainMismatch
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
      (domain_is_fraction_field_like(a) && domain_is_poly_ring(b)) ||
      (domain_is_fraction_field_like(b) && domain_is_poly_ring(a))
    ) &&
    (!domain_is_field_pred(ground_a) || !domain_is_field_pred(ground_b)) &&
    domain_is_field_pred(ground) &&
    domain_has_assoc_ring(ground) {
    ground = domain_get_ring(ground)
  }

  let use_a = domain_is_composite_like(a) &&
    (
      !domain_is_composite_like(b) ||
      domain_is_fraction_field_like(a) ||
      domain_is_poly_ring(b)
    )
  let template = if use_a { a } else { b }
  lift_composite_domain(template, ground, gens)
}

///|
/// Construct a polynomial ring over a ground domain.
///
/// - Does: Returns `domain` when no generators are requested, otherwise builds
///   `K[x1, ..., xn]`.
/// - Input: A ground `Domain` and generator names.
/// - Returns: A `Domain`.
/// - Limits: Raises `PolyError::DomainMismatch` for quotient-ring inputs.
pub fn domain_poly_ring(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    QuotientRing(_, _, _) => raise DomainMismatch
    _ => poly_ring_domain(domain, gens)
  }
}

///|
/// Construct a rational-function field over a ground domain.
///
/// - Does: Returns `domain` when no generators are requested, otherwise builds
///   `K(x1, ..., xn)`.
/// - Input: A ground `Domain` and generator names.
/// - Returns: A `Domain`.
/// - Limits: Raises `PolyError::DomainMismatch` for quotient-ring inputs.
pub fn domain_frac_field(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    QuotientRing(_, _, _) => raise DomainMismatch
    _ => rational_function_field_domain(domain, gens)
  }
}

///|
/// Compatibility alias for `domain_poly_ring`.
///
/// - Does: Preserves the old constructor spelling.
/// - Input: A ground `Domain` and generator names.
/// - Returns: A `Domain`.
/// - Limits: Shares the same validation rules as `domain_poly_ring`.
pub fn domain_old_poly_ring(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_poly_ring(domain, gens)
}

///|
/// Compatibility alias for `domain_frac_field`.
///
/// - Does: Preserves the old constructor spelling.
/// - Input: A ground `Domain` and generator names.
/// - Returns: A `Domain`.
/// - Limits: Shares the same validation rules as `domain_frac_field`.
pub fn domain_old_frac_field(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_frac_field(domain, gens)
}

///|
/// Rebase a composite domain onto a new ground domain.
///
/// - Does: Reuses the structural shape of a composite domain while replacing
///   its ground domain.
/// - Input: A `Domain` and replacement ground `Domain`.
/// - Returns: A `Domain`.
/// - Limits: Non-composite inputs collapse directly to `ground`.
pub fn domain_set_domain(domain : Domain, ground : Domain) -> Domain {
  match domain {
    PolyRing(_, gens) => PolyRing(ground, gens)
    RationalFunctionField(_, gens) => RationalFunctionField(ground, gens)
    QuotientRing(_, gens, rels) => QuotientRing(ground, gens, rels)
    PowerSeries(_, gens, prec) => PowerSeries(ground, gens, prec)
    Frac(_) => Frac(ground)
    AlgExt(_, gens, rels) => AlgExt(ground, gens, rels)
    _ => ground
  }
}

///|
/// Unify two domains while reserving external symbols.
///
/// - Does: Computes a shared domain while preventing the reserved `symbols`
///   from being captured by composite-domain generators.
/// - Input: Two `Domain` values and `Array[String]`.
/// - Returns: A unified `Domain`.
/// - Limits: Raises `PolyError::BadGenerator` when a reserved symbol would be
///   captured.
pub fn domain_unify_with_symbols(
  lhs : Domain,
  rhs : Domain,
  symbols : Array[String],
) -> Domain raise PolyError {
  if domain_is_composite_pred(lhs) &&
    domain_symbols(lhs).any(s => symbols.contains(s)) {
    raise BadGenerator(symbols.join(","))
  }
  if domain_is_composite_pred(rhs) &&
    domain_symbols(rhs).any(s => symbols.contains(s)) {
    raise BadGenerator(symbols.join(","))
  }
  domain_unify_pair(lhs, rhs)
}

///|
/// Unify two potentially composite domains.
///
/// - Does: Forwards to the main pairwise unifier for composite-domain callers.
/// - Input: Two `Domain` values.
/// - Returns: A unified `Domain`.
/// - Limits: Raises `PolyError::DomainMismatch` when no common domain is known.
pub fn domain_unify_composite(
  lhs : Domain,
  rhs : Domain,
) -> Domain raise PolyError {
  domain_unify_pair(lhs, rhs)
}

///|
fn extension_names(extension : Array[Expr]) -> Array[String] {
  let names : Array[String] = Array::new()
  for expr in extension {
    let name = @symprint.pretty_string(expr)
    if !names.contains(name) {
      names.push(name)
    }
  }
  names
}

///|
fn append_unique_exprs(lhs : Array[Expr], rhs : Array[Expr]) -> Array[Expr] {
  let out = lhs.copy()
  for expr in rhs {
    if !out.contains(expr) {
      out.push(expr)
    }
  }
  out
}

///|
/// Construct an algebraic field domain.
///
/// - Does: Builds an algebraic extension over `QQ`, or enlarges an existing
///   algebraic extension with additional generators.
/// - Input: A base `Domain` and extension generators as `Array[Expr]`.
/// - Returns: `Domain::AlgExt`.
/// - Limits: Raises `PolyError` for empty extensions or unsupported base
///   domains.
pub fn domain_algebraic_field(
  domain : Domain,
  extension : Array[Expr],
) -> Domain raise PolyError {
  if extension.is_empty() {
    raise BadGenerator("algebraic_field")
  }
  let ext_names = extension_names(extension)
  let merged_ext = [ext_names.join("+")]
  match domain {
    ZZ => domain_algebraic_field(QQ, extension)
    QQ => AlgExt(QQ, merged_ext, extension.copy())
    AlgExt(base, gens, rels) =>
      AlgExt(
        base,
        [merge_gens(gens, ext_names).join("+")],
        append_unique_exprs(rels, extension),
      )
    _ => raise DomainMismatch
  }
}

///|
fn expr_replace_symbol(
  expr : Expr,
  old_name : String,
  new_name : String,
) -> Expr {
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) | Boolean(_) =>
      expr
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) | UndefinedFunction(_) => expr
    Apply(head, args) =>
      @symcore.raw_apply(
        head,
        args.map(arg => expr_replace_symbol(arg, old_name, new_name)),
      ).unwrap_or(
        Apply(
          head,
          args.map(arg => expr_replace_symbol(arg, old_name, new_name)),
        ),
      )
    Symbol(name) => if name == old_name { Symbol(new_name) } else { expr }
    Add(args) =>
      @symcore.add(
        args.map(arg => expr_replace_symbol(arg, old_name, new_name)),
      )
    Mul(args) =>
      @symcore.mul(
        args.map(arg => expr_replace_symbol(arg, old_name, new_name)),
      )
    Pow(base, exp) =>
      expr_replace_symbol(base, old_name, new_name) ^
      expr_replace_symbol(exp, old_name, new_name)
    Mod(lhs, rhs) =>
      @symcore.mod_expr(
        expr_replace_symbol(lhs, old_name, new_name),
        expr_replace_symbol(rhs, old_name, new_name),
      )
    Tuple(args) =>
      Tuple(args.map(arg => expr_replace_symbol(arg, old_name, new_name)))
    Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (
            expr_replace_symbol(key, old_name, new_name),
            expr_replace_symbol(value, old_name, new_name),
          ),
        )
      }
      Dict(out)
    }
    Relational(op, lhs, rhs) =>
      match op {
        Eq =>
          Relational(
            Eq,
            expr_replace_symbol(lhs, old_name, new_name),
            expr_replace_symbol(rhs, old_name, new_name),
          )
        Ne =>
          Relational(
            Ne,
            expr_replace_symbol(lhs, old_name, new_name),
            expr_replace_symbol(rhs, old_name, new_name),
          )
        Lt =>
          Relational(
            Lt,
            expr_replace_symbol(lhs, old_name, new_name),
            expr_replace_symbol(rhs, old_name, new_name),
          )
        Le =>
          Relational(
            Le,
            expr_replace_symbol(lhs, old_name, new_name),
            expr_replace_symbol(rhs, old_name, new_name),
          )
        Gt =>
          Relational(
            Gt,
            expr_replace_symbol(lhs, old_name, new_name),
            expr_replace_symbol(rhs, old_name, new_name),
          )
        Ge =>
          Relational(
            Ge,
            expr_replace_symbol(lhs, old_name, new_name),
            expr_replace_symbol(rhs, old_name, new_name),
          )
      }
    Derivative(inner, deriv_args) => {
      let args : Array[Expr] = []
      args.push(expr_replace_symbol(inner, old_name, new_name))
      for arg in deriv_args {
        args.push(expr_replace_symbol(arg, old_name, new_name))
      }
      @symcore.raw_function("Derivative", args)
    }
    Subs(inner, variable, value) =>
      @symcore.subs_expr(
        expr_replace_symbol(inner, old_name, new_name),
        expr_replace_symbol(variable, old_name, new_name),
        expr_replace_symbol(value, old_name, new_name),
      )
    Lambda(vars, body) =>
      @symcore.lambda_expr(
        expr_replace_symbol(vars, old_name, new_name),
        expr_replace_symbol(body, old_name, new_name),
      )
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match
            @symcore.raw_apply(
              head,
              args.map(arg => expr_replace_symbol(arg, old_name, new_name)),
            ) {
            Some(next) => next
            None => expr
          }
        None => expr
      }
  }
}

///|
fn poly_with_generator(
  poly : Poly,
  gen : String,
  domain : Domain,
) -> Poly raise PolyError {
  guard poly.gens.length() == 1 else { raise NotUnivariate }
  let raw = if poly.gens[0] == gen {
    poly.to_expr()
  } else {
    expr_replace_symbol(poly.to_expr(), poly.gens[0], gen)
  }
  Poly::from_expr(raw, [gen], domain)
}

///|
fn poly_univar_coeff(poly : Poly, exp : Int) -> FieldElem raise PolyError {
  guard poly.gens.length() == 1 else { raise NotUnivariate }
  let mono = monomial_from_array([exp])
  match poly.coeffs.get(mono) {
    Some(coeff) => coeff
    None => fe_from_int(0, poly.domain)
  }
}

///|
fn normalize_root_index(poly : Poly, root_index : Int) -> Int raise PolyError {
  let degree = poly.degree(0)
  guard degree >= 1 else { raise NonPolynomial }
  if root_index >= degree {
    raise BadExponent
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

///|
fn default_algext_gen(poly : Poly, root_index : Int) -> String raise PolyError {
  let degree = poly.degree(0)
  if degree == 1 {
    let lead = poly_univar_coeff(poly, 1)
    let const_term = poly_univar_coeff(poly, 0)
    let root = fe_to_expr_const(fe_mul(fe_neg(const_term), fe_inv(lead)))
    return @symprint.pretty_string(root)
  }
  let idx = normalize_root_index(poly, root_index)
  let poly_text = @symprint.pretty_string(poly.to_expr()).replace_all(
    old="+ -",
    new="- ",
  )
  return "CRootOf(\{poly_text}, \{idx})"
}

///|

///|
/// Public API `domain_alg_field_from_poly`.
///
/// - Does: Provides the `domain_alg_field_from_poly` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `poly : Poly`, `extension_name : String =
/// None`, `root_index : Int = -1`, using the package representation expected by the
/// signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_alg_field_from_poly(
  domain : Domain,
  poly : Poly,
  extension_name? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  ignore(root_index)
  let base = match domain {
    ZZ => Domain::QQ
    _ => domain
  }
  let gen = match extension_name {
    Some(name) if name != "" => name
    _ => default_algext_gen(poly, root_index)
  }
  let lifted = poly_with_generator(poly, gen, base)
  build_alg_extension(alg_ext_spec(base, gen, lifted))
}

///|
fn cyclotomic_poly_domain(n : Int, gen : String) -> Poly raise PolyError {
  guard n > 0 else { raise BadExponent }
  let x = Expr::Symbol(gen)
  let mut poly = Poly::from_expr((x ^ int(n)) - int(1), [gen], QQ)
  for d in 1..<n {
    if n % d == 0 {
      poly = poly.div_exact_univar(cyclotomic_poly_domain(d, gen))
    }
  }
  poly
}

///|

///|
/// Public API `domain_cyclotomic_field`.
///
/// - Does: Provides the `domain_cyclotomic_field` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `n : Int`, `ss : Bool = false`,
/// `extension_name : String = "zeta"`, `gen : String = None` and 1 more parameter(s),
/// using the package representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_cyclotomic_field(
  domain : Domain,
  n : Int,
  ss? : Bool = false,
  extension_name? : String = "zeta",
  gen? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  let ext_alias = if ss { "\{extension_name}\{n}" } else { extension_name }
  let poly_gen = match gen {
    Some(name) => name
    None => ext_alias
  }
  let poly = cyclotomic_poly_domain(n, poly_gen)
  domain_alg_field_from_poly(
    domain,
    poly,
    extension_name=Some(ext_alias),
    root_index~,
  )
}

///|
/// Inject fresh generators into `domain`.

///|
/// Public API `domain_inject`.
///
/// - Does: Provides the `domain_inject` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_inject(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    PolyRing(base, existing) => {
      if existing.any(g => gens.contains(g)) {
        raise BadGenerator(gens.join(","))
      }
      PolyRing(base, merge_gens(existing, gens))
    }
    RationalFunctionField(base, existing) => {
      if existing.any(g => gens.contains(g)) {
        raise BadGenerator(gens.join(","))
      }
      RationalFunctionField(base, merge_gens(existing, gens))
    }
    PowerSeries(base, existing, prec) => {
      if existing.any(g => gens.contains(g)) {
        raise BadGenerator(gens.join(","))
      }
      PowerSeries(base, merge_gens(existing, gens), prec)
    }
    QuotientRing(_, _, _) => raise DomainMismatch
    _ => domain_poly_ring(domain, gens)
  }
}

///|
/// Drop generators from a domain, recursively through nested composites.

///|
/// Public API `domain_drop`.
///
/// - Does: Provides the `domain_drop` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_drop(
  domain : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  if gens.is_empty() {
    return domain
  }
  match domain {
    PolyRing(base, symbols) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        PolyRing(rebased, kept)
      }
    }
    RationalFunctionField(base, symbols) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        RationalFunctionField(rebased, kept)
      }
    }
    PowerSeries(base, symbols, prec) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        PowerSeries(rebased, kept, prec)
      }
    }
    QuotientRing(base, symbols, rels) => {
      let kept = symbols.filter(s => !gens.contains(s))
      let rebased = domain_drop(base, gens)
      if kept.is_empty() {
        rebased
      } else {
        QuotientRing(rebased, kept, rels)
      }
    }
    Frac(base) => {
      let rebased = domain_drop(base, gens)
      match rebased {
        PolyRing(_, _) | RationalFunctionField(_, _) => Frac(rebased)
        _ => rebased
      }
    }
    AlgExt(base, symbols, rels) => {
      if symbols.any(s => gens.contains(s)) {
        raise BadGenerator(gens.join(","))
      }
      let rebased = domain_drop(base, gens)
      if Eq::equal(rebased, base) {
        domain
      } else {
        AlgExt(rebased, symbols, rels)
      }
    }
    _ => domain
  }
}

///|
fn expr_key(expr : Expr) -> String {
  @symprint.pretty_string(expr).replace_all(old=" ", new="")
}

///|
fn normalized_gen_keys(gens : Array[String]) -> Array[String] {
  gens.map(g => g.replace_all(old=" ", new=""))
}

///|
fn gen_symbol_name(gen : String) -> String? {
  let text = gen.trim().to_owned()
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
    let rest = text[2:text.length()].to_owned().trim().to_owned()
    if rest != "" &&
      !rest.contains("/") &&
      !rest.contains("(") &&
      !rest.contains("[") &&
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
fn expr_is_integer(expr : Expr) -> Bool {
  match expr_rational_value(expr) {
    Some(n) => n.is_integral()
    None => false
  }
}

///|
fn expr_is_nonnegative_integer(expr : Expr) -> Bool {
  match expr_rational_value(expr) {
    Some(n) => n.is_integral() && n.compare(@symnum.BigRational::zero()) >= 0
    None => false
  }
}

///|
fn expr_has_forbidden_symbol(expr : Expr, allow_i : Bool) -> Bool {
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | Boolean(_) => false
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) | UndefinedFunction(_) => true
    Apply(_, args) => args.any(arg => expr_has_forbidden_symbol(arg, allow_i))
    NumberSymbol(kind) =>
      match kind {
        ImaginaryUnit => !allow_i
        Pi | Exp1 | EulerGamma | GoldenRatio | Catalan => false
        Infinity | NegativeInfinity | ComplexInfinity | NaN => true
      }
    Symbol(name) => if allow_i { name != "I" } else { true }
    Add(args) | Mul(args) | Tuple(args) =>
      args.any(item => expr_has_forbidden_symbol(item, allow_i))
    Mod(lhs, rhs) =>
      expr_has_forbidden_symbol(lhs, allow_i) ||
      expr_has_forbidden_symbol(rhs, allow_i)
    Dict(items) =>
      items.any(item => {
        let (key, value) = item
        expr_has_forbidden_symbol(key, allow_i) ||
        expr_has_forbidden_symbol(value, allow_i)
      })
    Relational(_, lhs, rhs) =>
      expr_has_forbidden_symbol(lhs, allow_i) ||
      expr_has_forbidden_symbol(rhs, allow_i)
    Derivative(inner, deriv_args) =>
      expr_has_forbidden_symbol(inner, allow_i) ||
      deriv_args.any(arg => expr_has_forbidden_symbol(arg, allow_i))
    Subs(inner, variable, value) =>
      expr_has_forbidden_symbol(inner, allow_i) ||
      expr_has_forbidden_symbol(variable, allow_i) ||
      expr_has_forbidden_symbol(value, allow_i)
    Lambda(vars, body) =>
      expr_has_forbidden_symbol(vars, allow_i) ||
      expr_has_forbidden_symbol(body, allow_i)
    Pow(base, exp) =>
      expr_has_forbidden_symbol(base, allow_i) ||
      expr_has_forbidden_symbol(exp, allow_i)
    _ =>
      @symcore.args(expr).any(item => expr_has_forbidden_symbol(item, allow_i))
  }
}

///|
fn expr_has_nonzero_complex_float(expr : Expr) -> Bool {
  match expr {
    ComplexFloat(z) => !@symnum.is_zero(z.to_mpc().imag)
    Add(args) | Mul(args) | Tuple(args) =>
      args.any(expr_has_nonzero_complex_float)
    Relational(_, lhs, rhs) =>
      expr_has_nonzero_complex_float(lhs) || expr_has_nonzero_complex_float(rhs)
    Derivative(inner, deriv_args) =>
      expr_has_nonzero_complex_float(inner) ||
      deriv_args.any(expr_has_nonzero_complex_float)
    Subs(inner, variable, value) =>
      expr_has_nonzero_complex_float(inner) ||
      expr_has_nonzero_complex_float(variable) ||
      expr_has_nonzero_complex_float(value)
    Lambda(vars, body) =>
      expr_has_nonzero_complex_float(vars) ||
      expr_has_nonzero_complex_float(body)
    Pow(base, exp) =>
      expr_has_nonzero_complex_float(base) ||
      expr_has_nonzero_complex_float(exp)
    _ => false
  }
}

///|
fn expr_is_imaginary_unit(expr : Expr) -> Bool {
  match expr {
    NumberSymbol(ImaginaryUnit) => true
    Symbol(name) => name == "I"
    _ => false
  }
}

///|
fn gaussian_term_in_domain(expr : Expr, coeff_dom : Domain) -> Bool {
  if expr_is_imaginary_unit(expr) {
    return true
  }
  if domain_contains_expr(coeff_dom, expr) {
    return true
  }
  match expr {
    Mul(args) => {
      let mut imag_count = 0
      let coeffs : Array[Expr] = Array::new()
      for arg in args {
        if expr_is_imaginary_unit(arg) {
          imag_count += 1
        } else {
          coeffs.push(arg)
        }
      }
      imag_count == 1 &&
      domain_contains_expr(
        coeff_dom,
        if coeffs.is_empty() {
          int(1)
        } else {
          @symcore.mul(coeffs)
        },
      )
    }
    _ => false
  }
}

///|
fn expr_in_algext(
  base : Domain,
  gens : Array[String],
  rels : Array[Expr],
  expr : Expr,
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
    Add(args) | Mul(args) =>
      args.all(item => expr_in_algext(base, gens, rels, item))
    Pow(inner, exp) =>
      expr_is_integer(exp) && expr_in_algext(base, gens, rels, inner)
    _ => all_allowed.contains(expr_key(expr))
  }
}

///|
fn expr_in_polynomial_domain(
  base : Domain,
  gens : Array[String],
  expr : Expr,
) -> Bool {
  if domain_contains_expr(base, expr) {
    return true
  }
  let symbols = generator_symbol_names(gens)
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) =>
      domain_contains_expr(base, expr)
    Boolean(_) => false
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) | UndefinedFunction(_) =>
      false
    Symbol(name) => symbols.contains(name)
    Add(args) | Mul(args) =>
      args.all(item => expr_in_polynomial_domain(base, gens, item))
    Pow(inner, exp) =>
      expr_is_nonnegative_integer(exp) &&
      expr_in_polynomial_domain(base, gens, inner)
    Mod(_, _) => false
    Tuple(_)
    | Dict(_)
    | Relational(_, _, _)
    | Derivative(_, _)
    | Subs(_, _, _)
    | Lambda(_, _) => false
    _ => false
  }
}

///|
fn expr_in_fraction_domain(
  base : Domain,
  gens : Array[String],
  expr : Expr,
) -> Bool {
  if domain_contains_expr(base, expr) {
    return true
  }
  let symbols = generator_symbol_names(gens)
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) =>
      domain_contains_expr(base, expr)
    Boolean(_) => false
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) | UndefinedFunction(_) =>
      false
    Symbol(name) => symbols.contains(name)
    Add(args) | Mul(args) =>
      args.all(item => expr_in_fraction_domain(base, gens, item))
    Pow(inner, exp) =>
      expr_is_integer(exp) && expr_in_fraction_domain(base, gens, inner)
    Mod(_, _) => false
    Tuple(_)
    | Dict(_)
    | Relational(_, _, _)
    | Derivative(_, _)
    | Subs(_, _, _)
    | Lambda(_, _) => false
    _ => false
  }
}

///|
/// Check whether an expression belongs to the given domain.

///|
/// Public API `domain_contains_expr`.
///
/// - Does: Provides the `domain_contains_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_contains_expr(domain : Domain, expr : Expr) -> Bool {
  match domain {
    EX | EXRAW => true
    ZZ =>
      match expr_rational_value(expr) {
        Some(n) => n.is_integral()
        None => false
      }
    QQ => expr_rational_value(expr) is Some(_)
    RR =>
      !expr_has_forbidden_symbol(expr, false) &&
      !expr_has_nonzero_complex_float(expr)
    CC => !expr_has_forbidden_symbol(expr, true)
    ZZ_I =>
      match expr {
        Add(args) => args.all(item => gaussian_term_in_domain(item, ZZ))
        _ => gaussian_term_in_domain(expr, ZZ)
      }
    QQ_I =>
      match expr {
        Add(args) => args.all(item => gaussian_term_in_domain(item, QQ))
        _ => gaussian_term_in_domain(expr, QQ)
      }
    GF(_) | GFExt(_, _, _) =>
      match expr_rational_value(expr) {
        Some(n) => n.is_integral()
        None => false
      }
    AlgExt(base, gens, rels) => expr_in_algext(base, gens, rels, expr)
    PolyRing(base, gens)
    | QuotientRing(base, gens, _)
    | PowerSeries(base, gens, _) => expr_in_polynomial_domain(base, gens, expr)
    RationalFunctionField(base, gens) =>
      expr_in_fraction_domain(base, gens, expr)
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) =>
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

///|
/// Public API `Domain.contains_expr`.
///
/// - Does: Provides the `Domain.contains_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::contains_expr(self : Domain, expr : Expr) -> Bool {
  domain_contains_expr(self, expr)
}

///|

///|
/// Public API `Domain.of_type_expr`.
///
/// - Does: Provides the `Domain.of_type_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::of_type_expr(self : Domain, expr : Expr) -> Bool {
  domain_contains_expr(self, expr)
}

///|
/// Convert a SymPy-style expression into a canonical element of `domain`.

///|
/// Public API `domain_from_sympy_expr`.
///
/// - Does: Provides the `domain_from_sympy_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_from_sympy_expr(
  domain : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  match domain {
    ZZ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() =>
          expr_from_bigint(value.numerator())
        _ => raise DomainMismatch
      }
    QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_rational(value)
        None => raise DomainMismatch
      }
    ZZ_I => gaussian_int_to_expr(gaussian_int_from_expr(domain, expr))
    QQ_I => gaussian_rat_to_expr(gaussian_rat_from_expr(domain, expr))
    GF(_) | GFExt(_, _, _) | RR | CC =>
      domain_field_elem_to_expr(
        domain,
        field_elem_from_scalar_expr(expr, domain),
      )
    AlgExt(base, gens, rels) =>
      if rels.is_empty() {
        guard expr_in_algext(base, gens, rels, expr) else {
          raise DomainMismatch
        }
        expr
      } else {
        domain_field_elem_to_expr(
          domain,
          field_elem_from_scalar_expr(expr, domain),
        )
      }
    PolyRing(base, gens)
    | QuotientRing(base, gens, _)
    | PowerSeries(base, gens, _) => Poly::from_expr(expr, gens, base).to_expr()
    RationalFunctionField(base, gens) => {
      let (numer, denom) = rational_function_pair_from_expr(base, gens, expr)
      rational_function_expr_from_pair(numer, denom, base)
    }
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) => {
          let (numer, denom) = rational_function_pair_from_expr(
            inner, gens, expr,
          )
          rational_function_expr_from_pair(numer, denom, inner)
        }
        _ => domain_from_sympy_expr(domain_get_field(base), expr)
      }
    EX | EXRAW => expr
  }
}

///|
/// Convert an internal domain element back to a SymPy-style expression.

///|
/// Public API `domain_to_sympy_expr`.
///
/// - Does: Provides the `domain_to_sympy_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_to_sympy_expr(
  domain : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  domain_from_sympy_expr(domain, expr)
}

///|

///|
/// Public API `domain_new_expr`.
///
/// - Does: Provides the `domain_new_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_new_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  domain_from_sympy_expr(domain, expr)
}

///|

///|
/// Public API `domain_normal_expr`.
///
/// - Does: Provides the `domain_normal_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_normal_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  domain_new_expr(domain, expr)
}

///|
/// Convert an expression from `base` into `domain`, mirroring `convert_from`.

///|
/// Public API `domain_convert_from_expr`.
///
/// - Does: Provides the `domain_convert_from_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_convert_from_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr raise PolyError {
  let scalar_target = match domain {
    PolyRing(_, _)
    | RationalFunctionField(_, _)
    | QuotientRing(_, _, _)
    | PowerSeries(_, _, _)
    | Frac(_) => false
    _ => true
  }
  if scalar_target {
    match base {
      PolyRing(inner, gens)
      | QuotientRing(inner, gens, _)
      | PowerSeries(inner, gens, _) => {
        guard !expr_depends_on_symbols(expr, gens) else { raise DomainMismatch }
        return domain_convert_from_expr(domain, expr, inner)
      }
      RationalFunctionField(_, _) => raise DomainMismatch
      Frac(inner) =>
        match inner {
          PolyRing(_, _) | RationalFunctionField(_, _) => raise DomainMismatch
          _ => ()
        }
      AlgExt(inner, gens, _) => {
        guard !expr_depends_on_symbols(expr, gens) else { raise DomainMismatch }
        return domain_convert_from_expr(domain, expr, inner)
      }
      _ => ()
    }
  }
  let lifted = match base {
    RR | CC | EX | EXRAW => expr
    _ => domain_to_sympy_expr(base, expr)
  }
  domain_from_sympy_expr(domain, lifted)
}

///|
fn domain_try_convert_from_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  try domain_convert_from_expr(domain, expr, base) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|

///|
/// Public API `domain_from_ff_expr`.
///
/// - Does: Provides the `domain_from_ff_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_ff_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    GF(_) | GFExt(_, _, _) => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_ff_python_expr`.
///
/// - Does: Provides the `domain_from_ff_python_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_ff_python_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_ff_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_zz_expr`.
///
/// - Does: Provides the `domain_from_zz_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_zz_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    ZZ => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_zz_python_expr`.
///
/// - Does: Provides the `domain_from_zz_python_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_zz_python_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_zz_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_qq_expr`.
///
/// - Does: Provides the `domain_from_qq_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_qq_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    QQ => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_qq_python_expr`.
///
/// - Does: Provides the `domain_from_qq_python_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_qq_python_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_qq_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_ff_gmpy_expr`.
///
/// - Does: Provides the `domain_from_ff_gmpy_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_ff_gmpy_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_ff_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_zz_gmpy_expr`.
///
/// - Does: Provides the `domain_from_zz_gmpy_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_zz_gmpy_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_zz_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_qq_gmpy_expr`.
///
/// - Does: Provides the `domain_from_qq_gmpy_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_qq_gmpy_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_qq_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_real_field_expr`.
///
/// - Does: Provides the `domain_from_real_field_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_real_field_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    RR => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_complex_field_expr`.
///
/// - Does: Provides the `domain_from_complex_field_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_complex_field_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    CC => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_algebraic_field_expr`.
///
/// - Does: Provides the `domain_from_algebraic_field_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_algebraic_field_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    AlgExt(_, _, _) => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_gaussian_integer_ring_expr`.
///
/// - Does: Provides the `domain_from_gaussian_integer_ring_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_gaussian_integer_ring_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    ZZ_I => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_gaussian_rational_field_expr`.
///
/// - Does: Provides the `domain_from_gaussian_rational_field_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_gaussian_rational_field_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    QQ_I => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_polynomial_ring_expr`.
///
/// - Does: Provides the `domain_from_polynomial_ring_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_polynomial_ring_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    PolyRing(_, _) | QuotientRing(_, _, _) | PowerSeries(_, _, _) =>
      domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_fraction_field_expr`.
///
/// - Does: Provides the `domain_from_fraction_field_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_fraction_field_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    RationalFunctionField(_, _) | Frac(_) =>
      domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_global_polynomial_ring_expr`.
///
/// - Does: Provides the `domain_from_global_polynomial_ring_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_global_polynomial_ring_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_polynomial_ring_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_generalized_polynomial_ring_expr`.
///
/// - Does: Provides the `domain_from_generalized_polynomial_ring_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_generalized_polynomial_ring_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    RationalFunctionField(_, _) | Frac(_) =>
      match domain {
        EX | EXRAW =>
          try
            domain_from_sympy_expr(domain, domain_to_sympy_expr(base, expr))
          catch {
            _ => None
          } noraise {
            value => Some(value)
          }
        _ => domain_from_fraction_field_expr(domain, expr, base)
      }
    _ => None
  }
}

///|

///|
/// Public API `domain_from_monogenic_finite_extension_expr`.
///
/// - Does: Provides the `domain_from_monogenic_finite_extension_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_monogenic_finite_extension_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_algebraic_field_expr(domain, expr, base)
}

///|

///|
/// Public API `domain_from_expression_domain_expr`.
///
/// - Does: Provides the `domain_from_expression_domain_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_expression_domain_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    EX => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|

///|
/// Public API `domain_from_expression_raw_domain_expr`.
///
/// - Does: Provides the `domain_from_expression_raw_domain_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_from_expression_raw_domain_expr(
  domain : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  match base {
    EXRAW => domain_try_convert_from_expr(domain, expr, base)
    _ => None
  }
}

///|
/// Convert an expression into `domain`, optionally using an explicit source domain.

///|
/// Public API `domain_convert_expr`.
///
/// - Does: Provides the `domain_convert_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `base : Domain = None`, using
/// the package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_convert_expr(
  domain : Domain,
  expr : Expr,
  base? : Domain? = None,
) -> Expr raise PolyError {
  match base {
    Some(source) => domain_convert_from_expr(domain, expr, source)
    None => domain_from_sympy_expr(domain, expr)
  }
}

///|

///|
/// Public API `domain_sum_expr`.
///
/// - Does: Provides the `domain_sum_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `exprs : Array[Expr]`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_sum_expr(
  domain : Domain,
  exprs : Array[Expr],
) -> Expr raise PolyError {
  let mut acc = domain_zero_expr(domain)
  for expr in exprs {
    acc = domain_add_expr(domain, acc, domain_from_sympy_expr(domain, expr))
  }
  acc
}

///|

///|
/// Public API `domain_map_expr_tree`.
///
/// - Does: Provides the `domain_map_expr_tree` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `exprs : Array[DomainExprTree]`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[DomainExprTree]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_map_expr_tree(
  domain : Domain,
  exprs : Array[DomainExprTree],
) -> Array[DomainExprTree] raise PolyError {
  let mapped : Array[DomainExprTree] = Array::new()
  for item in exprs {
    match item {
      Elem(expr) => mapped.push(Elem(domain_new_expr(domain, expr)))
      List(items) => mapped.push(List(domain_map_expr_tree(domain, items)))
    }
  }
  mapped
}

///|
fn expr_depends_on_symbols(expr : Expr, symbols : Array[String]) -> Bool {
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | Boolean(_) => false
    NumberSymbol(_) => false
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) | UndefinedFunction(_) =>
      false
    Apply(_, args) => args.any(item => expr_depends_on_symbols(item, symbols))
    Symbol(name) => symbols.contains(name)
    Add(args) | Mul(args) | Tuple(args) =>
      args.any(item => expr_depends_on_symbols(item, symbols))
    Mod(lhs, rhs) =>
      expr_depends_on_symbols(lhs, symbols) ||
      expr_depends_on_symbols(rhs, symbols)
    Dict(items) =>
      items.any(item => {
        let (key, value) = item
        expr_depends_on_symbols(key, symbols) ||
        expr_depends_on_symbols(value, symbols)
      })
    Relational(_, lhs, rhs) =>
      expr_depends_on_symbols(lhs, symbols) ||
      expr_depends_on_symbols(rhs, symbols)
    Derivative(inner, deriv_args) =>
      expr_depends_on_symbols(inner, symbols) ||
      deriv_args.any(arg => expr_depends_on_symbols(arg, symbols))
    Subs(inner, variable, value) =>
      expr_depends_on_symbols(inner, symbols) ||
      expr_depends_on_symbols(variable, symbols) ||
      expr_depends_on_symbols(value, symbols)
    Lambda(vars, body) =>
      expr_depends_on_symbols(vars, symbols) ||
      expr_depends_on_symbols(body, symbols)
    Pow(base, exp) =>
      expr_depends_on_symbols(base, symbols) ||
      expr_depends_on_symbols(exp, symbols)
    _ => @symcore.args(expr).any(item => expr_depends_on_symbols(item, symbols))
  }
}

///|
fn domain_expr_is_zero(expr : Expr) -> Bool {
  match expr_rational_value(expr) {
    Some(n) => n.is_zero()
    None => false
  }
}

///|
fn domain_expr_is_one(expr : Expr) -> Bool {
  match expr_rational_value(expr) {
    Some(n) => n.is_one()
    None => false
  }
}

///|
fn domain_expr_is_minus_one(expr : Expr) -> Bool {
  match expr_rational_value(expr) {
    Some(n) => n.compare(@symnum.BigRational::from_int(-1)) == 0
    None => false
  }
}

///|
fn expr_constant_term(expr : Expr, symbols : Array[String]) -> Expr? {
  if !expr_depends_on_symbols(expr, symbols) {
    return Some(expr)
  }
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) | Boolean(_) =>
      Some(expr)
    Dummy(_, _) | Wild(_, _, _) | FunctionHead(_) | UndefinedFunction(_) =>
      Some(expr)
    Apply(_, args) =>
      if args.any(item => expr_depends_on_symbols(item, symbols)) {
        None
      } else {
        Some(expr)
      }
    Symbol(name) =>
      if symbols.contains(name) {
        Some(int(0))
      } else {
        Some(expr)
      }
    Add(args) => {
      let parts : Array[Expr] = Array::new()
      for arg in args {
        match expr_constant_term(arg, symbols) {
          Some(part) => parts.push(part)
          None => return None
        }
      }
      Some(@symcore.add(parts))
    }
    Mul(args) => {
      let parts : Array[Expr] = Array::new()
      for arg in args {
        match expr_constant_term(arg, symbols) {
          Some(part) => parts.push(part)
          None => return None
        }
      }
      Some(@symcore.mul(parts))
    }
    Pow(base, exp) =>
      if expr_is_nonnegative_integer(exp) {
        match expr_constant_term(base, symbols) {
          Some(term) => Some(@symcore.pow(term, exp))
          None => None
        }
      } else {
        None
      }
    Mod(lhs, rhs) =>
      if expr_depends_on_symbols(lhs, symbols) ||
        expr_depends_on_symbols(rhs, symbols) {
        None
      } else {
        Some(expr)
      }
    Tuple(_)
    | Dict(_)
    | Relational(_, _, _)
    | Derivative(_, _)
    | Subs(_, _, _)
    | Lambda(_, _) => None
    _ =>
      if @symcore.application_parts(expr) == None {
        None
      } else if @symcore.args(expr).any(arg => {
          expr_depends_on_symbols(arg, symbols)
        }) {
        None
      } else {
        Some(expr)
      }
  }
}

///|
fn expr_terms_one(var_count : Int) -> Map[Monomial, Expr] {
  let out : Map[Monomial, Expr] = Map([])
  out.set(monomial_one(var_count), int(1))
  out
}

///|
fn expr_terms_from_coeff(
  coeff_domain : Domain,
  coeff : Expr,
  var_count : Int,
) -> Map[Monomial, Expr] {
  let out : Map[Monomial, Expr] = Map([])
  if !domain_is_zero_expr(coeff_domain, coeff) {
    out.set(monomial_one(var_count), coeff)
  }
  out
}

///|
fn expr_terms_add(
  coeff_domain : Domain,
  left : Map[Monomial, Expr],
  right : Map[Monomial, Expr],
) -> Map[Monomial, Expr] {
  let out : Map[Monomial, Expr] = Map([])
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
  left : Map[Monomial, Expr],
  right : Map[Monomial, Expr],
) -> Map[Monomial, Expr] {
  let out : Map[Monomial, Expr] = Map([])
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
      let mono = monomial_mul(lmono, rmono) catch { _ => continue }
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
  terms : Map[Monomial, Expr],
  exp : Int,
  var_count : Int,
) -> Map[Monomial, Expr] {
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
  let text = gen.trim().to_owned()
  if !text.has_prefix("1/") {
    return None
  }
  let rest = text[2:text.length()].to_owned().trim().to_owned()
  if rest == "" ||
    rest.contains("/") ||
    rest.contains("(") ||
    rest.contains("[") ||
    rest.contains("<") {
    None
  } else {
    Some(rest)
  }
}

///|
fn expr_generator_rational(
  gens : Array[String],
  expr : Expr,
) -> (Map[Monomial, Expr], Map[Monomial, Expr])? {
  let expr_text = expr_key(expr)
  for i in 0..<gens.length() {
    let gen = gens[i]
    if expr_text == gen.replace_all(old=" ", new="") {
      let numer : Map[Monomial, Expr] = Map([])
      let mono = monomial_one(gens.length())
      mono.exps.set(i, 1)
      numer.set(mono, int(1))
      return Some((numer, expr_terms_one(gens.length())))
    }
    match reciprocal_gen_symbol_name(gen) {
      Some(name) =>
        match expr {
          Symbol(expr_name) if expr_name == name => {
            let denom : Map[Monomial, Expr] = Map([])
            let mono = monomial_one(gens.length())
            mono.exps.set(i, 1)
            denom.set(mono, int(1))
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
  expr : Expr,
) -> (Map[Monomial, Expr], Map[Monomial, Expr])? {
  let var_count = gens.length()
  if domain_contains_expr(coeff_domain, expr) {
    return Some(
      (
        expr_terms_from_coeff(coeff_domain, expr, var_count),
        expr_terms_one(var_count),
      ),
    )
  }
  match expr_generator_rational(gens, expr) {
    Some(res) => return Some(res)
    None => ()
  }
  match expr {
    Add(args) => {
      let mut numer : Map[Monomial, Expr] = Map([])
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
    Mul(args) => {
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
    Pow(base, exp) =>
      if !expr_is_integer(exp) {
        None
      } else {
        let k = match exp {
          Number(n) => n.numerator().to_int()
          _ => 0
        }
        match expr_collect_rational_terms(coeff_domain, gens, base) {
          Some((num, den)) =>
            if k >= 0 {
              Some(
                (
                  expr_terms_pow(coeff_domain, num, k, var_count),
                  expr_terms_pow(coeff_domain, den, k, var_count),
                ),
              )
            } else {
              Some(
                (
                  expr_terms_pow(coeff_domain, den, -k, var_count),
                  expr_terms_pow(coeff_domain, num, -k, var_count),
                ),
              )
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
  terms : Map[Monomial, Expr],
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
  terms : Map[Monomial, Expr],
) -> Expr? {
  let mut best : (Monomial, Expr)? = None
  for mono, coeff in terms {
    if domain_is_zero_expr(coeff_domain, coeff) {
      continue
    }
    best = match best {
      None => Some((mono, coeff))
      Some((best_mono, best_coeff)) =>
        if compare_monomial_order(mono, best_mono, Lex) > 0 {
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
  terms : Map[Monomial, Expr],
  var_count : Int,
) -> Expr {
  match terms.get(monomial_one(var_count)) {
    Some(coeff) if !domain_is_zero_expr(coeff_domain, coeff) => coeff
    _ => int(0)
  }
}

///|
fn expr_numeric_sign(expr : Expr) -> Int? {
  match expr {
    Number(n) => Some(n.compare(@symnum.BigRational::zero()))
    Mul(args) => {
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
    Pow(base, exp) =>
      if !expr_is_integer(exp) {
        None
      } else {
        let k = match exp {
          Number(n) => n.numerator().to_int()
          _ => 0
        }
        match expr_numeric_sign(base) {
          Some(0) => if k == 0 { Some(1) } else { Some(0) }
          Some(v) => if k % 2 == 0 { Some(1) } else { Some(v) }
          None => None
        }
      }
    _ => None
  }
}

///|
fn expr_coeff_sign_like(expr : Expr) -> Int {
  match expr {
    Number(n) => n.compare(@symnum.BigRational::zero())
    Mul(args) => {
      let mut sign = 1
      for arg in args {
        match arg {
          Number(n) =>
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
fn domain_expr_sign(domain : Domain, expr : Expr) -> Int? {
  if !domain_contains_expr(domain, expr) {
    return None
  }
  match domain {
    ZZ | QQ | RR => expr_numeric_sign(expr)
    EX | EXRAW =>
      if domain_is_zero_expr(domain, expr) {
        Some(0)
      } else {
        Some(expr_coeff_sign_like(expr))
      }
    GF(_) | GFExt(_, _, _) =>
      if domain_is_zero_expr(domain, expr) {
        Some(0)
      } else {
        Some(1)
      }
    CC | ZZ_I | QQ_I => None
    PolyRing(base, gens) | QuotientRing(base, gens, _) =>
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
    RationalFunctionField(base, gens) =>
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
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) =>
          domain_expr_sign(RationalFunctionField(inner, gens), expr)
        _ => domain_expr_sign(base, expr)
      }
    PowerSeries(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, denom)) =>
          if !expr_terms_is_one(base, denom, gens.length()) {
            None
          } else {
            domain_expr_sign(
              base,
              expr_terms_constant_coeff(base, numer, gens.length()),
            )
          }
        None => None
      }
    AlgExt(base, gens, _) =>
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

///|
/// Public API `domain_is_zero_expr`.
///
/// - Does: Provides the `domain_is_zero_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_zero_expr(domain : Domain, expr : Expr) -> Bool {
  domain_contains_expr(domain, expr) && domain_expr_is_zero(expr)
}

///|

///|
/// Public API `domain_is_one_expr`.
///
/// - Does: Provides the `domain_is_one_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_one_expr(domain : Domain, expr : Expr) -> Bool {
  domain_contains_expr(domain, expr) && domain_expr_is_one(expr)
}

///|

///|
/// Public API `domain_is_negative_one_expr`.
///
/// - Does: Provides the `domain_is_negative_one_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_negative_one_expr(domain : Domain, expr : Expr) -> Bool {
  domain_contains_expr(domain, expr) && domain_expr_is_minus_one(expr)
}

///|

///|
/// Public API `domain_is_unit_expr`.
///
/// - Does: Provides the `domain_is_unit_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_unit_expr(domain : Domain, expr : Expr) -> Bool {
  if !domain_contains_expr(domain, expr) {
    return false
  }
  match domain {
    ZZ => domain_expr_is_one(expr) || domain_expr_is_minus_one(expr)
    QQ
    | RR
    | CC
    | QQ_I
    | EX
    | EXRAW
    | GF(_)
    | GFExt(_, _, _)
    | RationalFunctionField(_, _)
    | Frac(_)
    | AlgExt(_, _, _) => !domain_expr_is_zero(expr)
    ZZ_I => domain_expr_is_one(expr) || domain_expr_is_minus_one(expr)
    PolyRing(base, gens) =>
      !expr_depends_on_symbols(expr, generator_symbol_names(gens)) &&
      domain_is_unit_expr(base, expr)
    QuotientRing(base, gens, _) =>
      !expr_depends_on_symbols(expr, generator_symbol_names(gens)) &&
      domain_is_unit_expr(base, expr)
    PowerSeries(base, gens, _) =>
      match expr_constant_term(expr, generator_symbol_names(gens)) {
        Some(c0) => domain_is_unit_expr(base, c0)
        None => false
      }
  }
}

///|

///|
/// Public API `domain_is_positive_expr`.
///
/// - Does: Provides the `domain_is_positive_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_positive_expr(domain : Domain, expr : Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(1) => true
    _ => false
  }
}

///|

///|
/// Public API `domain_is_negative_expr`.
///
/// - Does: Provides the `domain_is_negative_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_negative_expr(domain : Domain, expr : Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(v) => v < 0
    None => false
  }
}

///|

///|
/// Public API `domain_is_nonpositive_expr`.
///
/// - Does: Provides the `domain_is_nonpositive_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_nonpositive_expr(domain : Domain, expr : Expr) -> Bool {
  match domain_expr_sign(domain, expr) {
    Some(v) => v <= 0
    None => false
  }
}

///|

///|
/// Public API `domain_is_nonnegative_expr`.
///
/// - Does: Provides the `domain_is_nonnegative_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_is_nonnegative_expr(domain : Domain, expr : Expr) -> Bool {
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

///|
fn domain_bigint_abs(x : BigInt) -> BigInt {
  if x < BigInt::from_int(0) {
    x.neg()
  } else {
    x
  }
}

///|
fn domain_bigint_lcm(a : BigInt, b : BigInt) -> BigInt {
  if a.is_zero() || b.is_zero() {
    return BigInt::from_int(0)
  }
  let g = @symnum.gcd_bigint(domain_bigint_abs(a), domain_bigint_abs(b))
  domain_bigint_abs(a.div(g).mul(b))
}

///|
fn domain_bigint_round_div(num : BigInt, den : BigInt) -> BigInt {
  if num.is_zero() {
    return BigInt::from_int(0)
  }
  let two = BigInt::from_int(2)
  let q = domain_bigint_abs(num).mul(two).add(den).div(den.mul(two))
  if num < BigInt::from_int(0) {
    q.neg()
  } else {
    q
  }
}

///|
fn domain_bigint_euclid_mod(num : BigInt, den : BigInt) -> BigInt {
  let r = num.mod(den)
  if r < BigInt::from_int(0) {
    if den < BigInt::from_int(0) {
      r.sub(den)
    } else {
      r.add(den)
    }
  } else {
    r
  }
}

///|
fn domain_bigint_gcdex(a0 : BigInt, b0 : BigInt) -> (BigInt, BigInt, BigInt) {
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
  if old_r < BigInt::from_int(0) {
    (old_s.neg(), old_t.neg(), old_r.neg())
  } else {
    (old_s, old_t, old_r)
  }
}

///|
fn domain_bigint_factorial(n : BigInt) -> BigInt raise PolyError {
  guard n >= BigInt::from_int(0) else { raise DomainMismatch }
  let one = BigInt::from_int(1)
  let mut acc = one
  let mut i = BigInt::from_int(2)
  while i.compare(n) <= 0 {
    acc = acc.mul(i)
    i = i.add(one)
  }
  acc
}

///|
fn domain_bigint_log_floor(a : BigInt, b : BigInt) -> BigInt raise PolyError {
  guard a.compare(BigInt::from_int(0)) > 0 else { raise DomainMismatch }
  guard b.compare(BigInt::from_int(0)) > 0 && !b.equal_int(1) else {
    raise DomainMismatch
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

///|
fn domain_bigint_sqrt_floor(n : BigInt) -> BigInt raise PolyError {
  guard n >= BigInt::from_int(0) else { raise DomainMismatch }
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

///|
fn domain_bigint_exsqrt(n : BigInt) -> BigInt? {
  if n < BigInt::from_int(0) {
    return None
  }
  let root = domain_bigint_sqrt_floor(n) catch { _ => return None }
  if root.mul(root).compare(n) == 0 {
    Some(root)
  } else {
    None
  }
}

///|
fn rational_abs(r : @symnum.BigRational) -> @symnum.BigRational {
  if r.compare(@symnum.BigRational::zero()) < 0 {
    r.neg_r()
  } else {
    r
  }
}

///|
fn domain_rational_exsqrt(value : @symnum.BigRational) -> @symnum.BigRational? {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    return None
  }
  let num = domain_bigint_exsqrt(value.numerator())
  let den = domain_bigint_exsqrt(value.denominator())
  match (num, den) {
    (Some(n), Some(d)) =>
      Some(@symnum.BigRational::new(n, d) catch { _ => return None })
    _ => None
  }
}

///|
fn expr_from_bigint(n : BigInt) -> Expr {
  Number(@symnum.BigRational::from_bigint(n))
}

///|
fn expr_from_rational(n : @symnum.BigRational) -> Expr {
  Number(n)
}

///|
fn expr_exact_sqrt_or_symbolic(expr : Expr) -> Expr {
  match expr_rational_value(expr) {
    Some(value) =>
      match domain_rational_exsqrt(value) {
        Some(root) => expr_from_rational(root)
        None => @symcore.function("sqrt", [expr])
      }
    None => @symcore.function("sqrt", [expr])
  }
}

///|
fn expr_rational_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Number(n) => Some(n)
    Float(f) =>
      if !f.is_finite() {
        None
      } else {
        try f.to_rational() catch {
          _ => None
        } noraise {
          (num, den) =>
            try @symnum.BigRational::new(num, den) catch {
              _ => None
            } noraise {
              value => Some(value)
            }
        }
      }
    ComplexFloat(z) =>
      if !z.is_finite() || !@symnum.is_zero(z.to_mpc().imag) {
        None
      } else {
        try z.real_part().to_rational() catch {
          _ => None
        } noraise {
          (num, den) =>
            try @symnum.BigRational::new(num, den) catch {
              _ => None
            } noraise {
              value => Some(value)
            }
        }
      }
    _ => None
  }
}

///|
fn expr_gaussian_coeffs(
  coeff_domain : Domain,
  expr : Expr,
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
        Some({ re: real, im: imag })
      }
    None => None
  }
}

///|
fn gaussian_rat_to_expr(value : GaussianRatCompat) -> Expr {
  let i_sym = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  let terms : Array[Expr] = Array::new()
  if !value.re.is_zero() {
    terms.push(Number(value.re))
  }
  if !value.im.is_zero() {
    let imag_coeff = @symcore.Expr::Number(value.im)
    terms.push(
      if value.im.is_one() {
        i_sym
      } else if value.im.compare(@symnum.BigRational::from_int(-1)) == 0 {
        int(-1) * i_sym
      } else {
        imag_coeff * i_sym
      },
    )
  }
  if terms.is_empty() {
    int(0)
  } else if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.add(terms)
  }
}

///|
fn gaussian_int_is_zero(value : GaussianIntCompat) -> Bool {
  value.re.is_zero() && value.im.is_zero()
}

///|
fn gaussian_int_sub(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat {
  { re: left.re.sub(right.re), im: left.im.sub(right.im) }
}

///|
fn gaussian_int_mul(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat {
  {
    re: left.re.mul(right.re).sub(left.im.mul(right.im)),
    im: left.re.mul(right.im).add(left.im.mul(right.re)),
  }
}

///|
fn gaussian_int_unit_candidates() -> Array[GaussianIntCompat] {
  [
    { re: BigInt::from_int(1), im: BigInt::from_int(0) },
    { re: BigInt::from_int(0), im: BigInt::from_int(1) },
    { re: BigInt::from_int(-1), im: BigInt::from_int(0) },
    { re: BigInt::from_int(0), im: BigInt::from_int(-1) },
  ]
}

///|
fn gaussian_int_canonical_unit(value : GaussianIntCompat) -> GaussianIntCompat {
  if gaussian_int_is_zero(value) {
    return { re: BigInt::from_int(1), im: BigInt::from_int(0) }
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
    None => { re: BigInt::from_int(1), im: BigInt::from_int(0) }
  }
}

///|
fn gaussian_rat_canonical_unit(value : GaussianRatCompat) -> GaussianRatCompat {
  if value.re.is_zero() && value.im.is_zero() {
    return { re: @symnum.BigRational::one(), im: @symnum.BigRational::zero() }
  }
  let units = [
    GaussianRatCompat::{
      re: @symnum.BigRational::one(),
      im: @symnum.BigRational::zero(),
    },
    { re: @symnum.BigRational::zero(), im: @symnum.BigRational::one() },
    { re: @symnum.BigRational::from_int(-1), im: @symnum.BigRational::zero() },
    { re: @symnum.BigRational::zero(), im: @symnum.BigRational::from_int(-1) },
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
    None => { re: @symnum.BigRational::one(), im: @symnum.BigRational::zero() }
  }
}

///|
fn gaussian_int_from_expr(
  domain : Domain,
  expr : Expr,
) -> GaussianIntCompat raise PolyError {
  let coeff_domain = match domain {
    ZZ_I => Domain::ZZ
    QQ_I => QQ
    _ => raise DomainMismatch
  }
  match expr_gaussian_coeffs(coeff_domain, expr) {
    Some(value) =>
      if value.re.is_integral() && value.im.is_integral() {
        { re: value.re.numerator(), im: value.im.numerator() }
      } else {
        raise DomainMismatch
      }
    None => raise DomainMismatch
  }
}

///|
fn gaussian_rat_from_expr(
  domain : Domain,
  expr : Expr,
) -> GaussianRatCompat raise PolyError {
  if domain is CC {
    match expr {
      ComplexFloat(z) =>
        if !z.is_finite() {
          raise DomainMismatch
        } else {
          let parts = z.to_rational_parts() catch { _ => raise DomainMismatch }
          let real_pair = parts.0
          let imag_pair = parts.1
          let real = @symnum.BigRational::new(real_pair.0, real_pair.1) catch {
            _ => raise DomainMismatch
          }
          let imag = @symnum.BigRational::new(imag_pair.0, imag_pair.1) catch {
            _ => raise DomainMismatch
          }
          return { re: real, im: imag }
        }
      Float(f) =>
        if !f.is_finite() {
          raise DomainMismatch
        } else {
          let pair = f.to_rational() catch { _ => raise DomainMismatch }
          let real = @symnum.BigRational::new(pair.0, pair.1) catch {
            _ => raise DomainMismatch
          }
          return { re: real, im: @symnum.BigRational::zero() }
        }
      _ => ()
    }
  }
  let coeff_domain = match domain {
    ZZ_I => Domain::ZZ
    QQ_I | CC => QQ
    _ => raise DomainMismatch
  }
  match expr_gaussian_coeffs(coeff_domain, expr) {
    Some(value) => value
    None => raise DomainMismatch
  }
}

///|
fn gaussian_int_norm(value : GaussianIntCompat) -> BigInt {
  value.re.mul(value.re).add(value.im.mul(value.im))
}

///|
fn gaussian_int_quo_round(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  if gaussian_int_is_zero(right) {
    raise DivisionByZero
  }
  let denom = gaussian_int_norm(right)
  let real_num = left.re.mul(right.re).add(left.im.mul(right.im))
  let imag_num = left.im.mul(right.re).sub(left.re.mul(right.im))
  {
    re: domain_bigint_round_div(real_num, denom),
    im: domain_bigint_round_div(imag_num, denom),
  }
}

///|
fn gaussian_int_rem(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  let q = gaussian_int_quo_round(left, right)
  gaussian_int_sub(left, gaussian_int_mul(right, q))
}

///|
fn gaussian_int_div_exact(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  if gaussian_int_is_zero(right) {
    raise DivisionByZero
  }
  let denom = gaussian_int_norm(right)
  let real_num = left.re.mul(right.re).add(left.im.mul(right.im))
  let imag_num = left.im.mul(right.re).sub(left.re.mul(right.im))
  if !real_num.mod(denom).is_zero() || !imag_num.mod(denom).is_zero() {
    raise ExactQuotientFailed
  }
  { re: real_num.div(denom), im: imag_num.div(denom) }
}

///|
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

///|
fn gaussian_int_lcm(
  left : GaussianIntCompat,
  right : GaussianIntCompat,
) -> GaussianIntCompat raise PolyError {
  if gaussian_int_is_zero(left) || gaussian_int_is_zero(right) {
    return { re: BigInt::from_int(0), im: BigInt::from_int(0) }
  }
  gaussian_int_div_exact(
    gaussian_int_mul(left, right),
    gaussian_int_gcd(left, right),
  )
}

///|
fn gaussian_int_to_expr(value : GaussianIntCompat) -> Expr {
  gaussian_rat_to_expr({
    re: @symnum.BigRational::from_bigint(value.re),
    im: @symnum.BigRational::from_bigint(value.im),
  })
}

///|
fn gaussian_rat_numer_denom(
  value : GaussianRatCompat,
) -> (GaussianIntCompat, BigInt) {
  let den = domain_bigint_lcm(value.re.denominator(), value.im.denominator())
  let re_num = value.re.numerator().mul(den.div(value.re.denominator()))
  let im_num = value.im.numerator().mul(den.div(value.im.denominator()))
  ({ re: re_num, im: im_num }, den)
}

///|
fn gaussian_rat_from_numer_denom(
  numer : GaussianIntCompat,
  den : BigInt,
) -> GaussianRatCompat raise PolyError {
  {
    re: poly_rational_from_bigints(numer.re, den),
    im: poly_rational_from_bigints(numer.im, den),
  }
}

///|
fn gaussian_rat_mul(
  left : GaussianRatCompat,
  right : GaussianRatCompat,
) -> GaussianRatCompat {
  {
    re: left.re.mul_r(right.re).add_r(left.im.mul_r(right.im).neg_r()),
    im: left.re.mul_r(right.im).add_r(left.im.mul_r(right.re)),
  }
}

///|
fn gaussian_rat_inv(
  value : GaussianRatCompat,
) -> GaussianRatCompat raise PolyError {
  let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
  if norm.is_zero() {
    raise DivisionByZero
  }
  {
    re: poly_rational_div(value.re, norm),
    im: poly_rational_div(value.im.neg_r(), norm),
  }
}

///|
fn gaussian_rat_div(
  left : GaussianRatCompat,
  right : GaussianRatCompat,
) -> GaussianRatCompat raise PolyError {
  gaussian_rat_mul(left, gaussian_rat_inv(right))
}

///|
fn gaussian_int_exsqrt(value : GaussianIntCompat) -> GaussianIntCompat? {
  if gaussian_int_is_zero(value) {
    return Some({ re: BigInt::from_int(0), im: BigInt::from_int(0) })
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
          let b = if value.im < BigInt::from_int(0) { b0.neg() } else { b0 }
          let out = GaussianIntCompat::{ re: a, im: b }
          if out.re.is_zero() && out.im < BigInt::from_int(0) {
            Some({ re: out.re.neg(), im: out.im.neg() })
          } else {
            Some(out)
          }
        }
        _ => None
      }
    }
  }
}

///|
fn gaussian_rat_exsqrt(value : GaussianRatCompat) -> GaussianRatCompat? {
  if value.re.is_zero() && value.im.is_zero() {
    return Some({
      re: @symnum.BigRational::zero(),
      im: @symnum.BigRational::zero(),
    })
  }
  let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
  let t = domain_rational_exsqrt(norm)
  match t {
    None => None
    Some(total) => {
      let half = poly_rational_from_ints(1, 2) catch { _ => return None }
      let u = total.add_r(value.re).mul_r(half)
      let v = total.add_r(value.re.neg_r()).mul_r(half)
      match (domain_rational_exsqrt(u), domain_rational_exsqrt(v)) {
        (Some(a), Some(b0)) => {
          let b = if value.im.compare(@symnum.BigRational::zero()) < 0 {
            b0.neg_r()
          } else {
            b0
          }
          let out = GaussianRatCompat::{ re: a, im: b }
          if out.re.is_zero() && out.im.compare(@symnum.BigRational::zero()) < 0 {
            Some({ re: out.re.neg_r(), im: out.im.neg_r() })
          } else {
            Some(out)
          }
        }
        _ => None
      }
    }
  }
}

///|
fn finite_field_order(domain : Domain) -> Int raise PolyError {
  match domain {
    GF(p) => p
    GFExt(p, k, _) => fe_int_pow(p, k)
    _ => raise DomainMismatch
  }
}

///|
fn finite_field_exsqrt(
  domain : Domain,
  value : FieldElem,
) -> FieldElem? raise PolyError {
  guard fe_is_zero(value) || domain_is_field_pred(domain) else {
    raise DomainMismatch
  }
  if fe_is_zero(value) {
    return Some(value)
  }
  match domain {
    GF(p) => {
      if p == 2 {
        return Some(value)
      }
      match value {
        GFp(_, target) => {
          for candidate in 0..<=(p / 2) {
            if fe_pos_mod(candidate * candidate, p) == target {
              return Some(GFp(p, candidate))
            }
          }
          None
        }
        _ => raise DomainMismatch
      }
    }
    GFExt(p, k, mod_poly) => {
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
    _ => raise DomainMismatch
  }
}

///|
fn expr_has_leading_minus(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.compare(@symnum.BigRational::zero()) < 0
    Add(args) =>
      if args.is_empty() {
        false
      } else {
        match args[0] {
          Number(n) => n.compare(@symnum.BigRational::zero()) < 0
          _ => expr_key(expr).has_prefix("-")
        }
      }
    Mul(args) =>
      args.any(arg => {
        match arg {
          Number(n) => n.compare(@symnum.BigRational::zero()) < 0
          _ => false
        }
      })
    _ => expr_key(expr).has_prefix("-")
  }
}

///|
fn expr_strip_leading_minus(expr : Expr) -> Expr? {
  match expr {
    Mul(args) => {
      let updated : Array[Expr] = Array::new()
      let mut removed = false
      for arg in args {
        match arg {
          Number(n) if !removed &&
            n.compare(@symnum.BigRational::from_int(-1)) == 0 => removed = true
          Number(n) if !removed && n.compare(@symnum.BigRational::zero()) < 0 => {
            updated.push(Number(n.neg_r()))
            removed = true
          }
          _ => updated.push(arg)
        }
      }
      if removed {
        Some(if updated.is_empty() { int(1) } else { @symcore.mul(updated) })
      } else {
        None
      }
    }
    Number(n) if n.compare(@symnum.BigRational::zero()) < 0 =>
      Some(Number(n.neg_r()))
    _ => None
  }
}

///|
fn sqrt_of_nonnegative_rational(value : @symnum.BigRational) -> Expr {
  if value.is_zero() || value.is_one() {
    Number(value)
  } else {
    @symcore.function("sqrt", [Number(value)])
  }
}

///|
fn poly_from_expr_terms(
  coeff_domain : Domain,
  gens : Array[String],
  terms : Map[Monomial, Expr],
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map([])
  for mono, coeff_expr in terms {
    let coeff = field_elem_from_scalar_expr(coeff_expr, coeff_domain) catch {
      _ => raise DomainMismatch
    }
    add_term(coeffs, mono, coeff, coeff_domain)
  }
  { coeffs, gens, domain: coeff_domain, order: Lex }
}

///|
fn poly_is_ground(poly : Poly) -> Bool {
  for mono, _ in poly.coeffs {
    if !is_monomial_zero(mono) {
      return false
    }
  }
  true
}

///|
fn poly_ground_expr(poly : Poly) -> Expr raise PolyError {
  if !poly_is_ground(poly) {
    raise DomainMismatch
  }
  match poly.coeffs.get(monomial_one(poly.gens.length())) {
    Some(coeff) => fe_to_expr_const(coeff)
    None => int(0)
  }
}

///|
fn poly_from_ground_expr(
  coeff_domain : Domain,
  gens : Array[String],
  expr : Expr,
) -> Poly raise PolyError {
  let coeff = field_elem_from_scalar_expr(expr, coeff_domain)
  let coeffs : Map[Monomial, FieldElem] = Map([])
  add_term(coeffs, monomial_one(gens.length()), coeff, coeff_domain)
  { coeffs, gens, domain: coeff_domain, order: Lex }
}

///|
fn poly_exact_quo(left : Poly, right : Poly) -> Poly raise PolyError {
  if right.is_zero() {
    raise DivisionByZero
  }
  if left.gens.length() == 1 {
    return left.div_exact_univar(right)
  }
  let (qs, rem) = left.divmod_multivar([right])
  if !rem.is_zero() {
    raise ExactQuotientFailed
  }
  qs[0]
}

///|
fn poly_gcd_compat(left : Poly, right : Poly) -> Poly raise PolyError {
  if left.gens.length() == 1 {
    left.gcd_univar(right)
  } else {
    left.gcd_multivar(right)
  }
}

///|
fn poly_lcm_compat(left : Poly, right : Poly) -> Poly raise PolyError {
  if left.is_zero() || right.is_zero() {
    return Poly::zero(left.gens, left.domain).with_order(left.order)
  }
  let gcd = poly_gcd_compat(left, right)
  let raw = poly_exact_quo(left.mul(right), gcd)
  if domain_is_field_pred(left.domain) {
    make_monic(raw)
  } else {
    raw
  }
}

///|
fn rational_function_pair_from_expr(
  coeff_domain : Domain,
  gens : Array[String],
  expr : Expr,
) -> (Poly, Poly) raise PolyError {
  match expr_collect_rational_terms(coeff_domain, gens, expr) {
    Some((numer, denom)) =>
      (
        poly_from_expr_terms(coeff_domain, gens, numer),
        poly_from_expr_terms(coeff_domain, gens, denom),
      )
    None => raise DomainMismatch
  }
}

///|
fn rational_function_expr_from_pair(
  numer : Poly,
  denom : Poly,
  coeff_domain : Domain,
) -> Expr raise PolyError {
  let (num_s, den_s) = cancel(numer, denom)
  let den_expr = den_s.to_expr()
  if domain_is_one_expr(coeff_domain, den_expr) {
    num_s.to_expr()
  } else {
    num_s.to_expr() * (den_expr ^ int(-1))
  }
}

///|
fn domain_scalar_gcd_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  match domain {
    ZZ => {
      let lhs = match expr_rational_value(left) {
        Some(v) if v.is_integral() => domain_bigint_abs(v.numerator())
        _ => raise DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) if v.is_integral() => domain_bigint_abs(v.numerator())
        _ => raise DomainMismatch
      }
      expr_from_bigint(@symnum.gcd_bigint(lhs, rhs))
    }
    QQ => {
      let lhs = match expr_rational_value(left) {
        Some(v) => rational_abs(v)
        None => raise DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) => rational_abs(v)
        None => raise DomainMismatch
      }
      let num = @symnum.gcd_bigint(lhs.numerator(), rhs.numerator())
      let den = domain_bigint_lcm(lhs.denominator(), rhs.denominator())
      Number(poly_rational_from_bigints(num, den))
    }
    ZZ_I => {
      let lhs = gaussian_int_from_expr(domain, left)
      let rhs = gaussian_int_from_expr(domain, right)
      gaussian_int_to_expr(gaussian_int_gcd(lhs, rhs))
    }
    QQ_I => {
      let lhs = gaussian_rat_from_expr(domain, left)
      let rhs = gaussian_rat_from_expr(domain, right)
      let (num_l, den_l) = gaussian_rat_numer_denom(lhs)
      let (num_r, den_r) = gaussian_rat_numer_denom(rhs)
      let numer = gaussian_int_gcd(num_l, num_r)
      let denom = domain_bigint_lcm(den_l, den_r)
      gaussian_rat_to_expr(gaussian_rat_from_numer_denom(numer, denom))
    }
    GF(_) | GFExt(_, _, _) => {
      let lhs = field_elem_from_scalar_expr(left, domain)
      let rhs = field_elem_from_scalar_expr(right, domain)
      if fe_is_zero(lhs) && fe_is_zero(rhs) {
        int(1)
      } else {
        fe_to_expr_const(fe_from_int(1, domain))
      }
    }
    RR | CC =>
      if domain_is_zero_expr(domain, left) && domain_is_zero_expr(domain, right) {
        int(1)
      } else {
        fe_to_expr_const(fe_from_int(1, domain))
      }
    EX | EXRAW | AlgExt(_, _, _) =>
      if domain_is_zero_expr(domain, left) && domain_is_zero_expr(domain, right) {
        int(1)
      } else {
        int(1)
      }
    _ => raise DomainMismatch
  }
}

///|
fn domain_scalar_lcm_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  match domain {
    ZZ => {
      let lhs = match expr_rational_value(left) {
        Some(v) if v.is_integral() => v.numerator()
        _ => raise DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) if v.is_integral() => v.numerator()
        _ => raise DomainMismatch
      }
      if lhs.is_zero() || rhs.is_zero() {
        int(0)
      } else {
        expr_from_bigint(domain_bigint_lcm(lhs, rhs))
      }
    }
    QQ => {
      let lhs = match expr_rational_value(left) {
        Some(v) => rational_abs(v)
        None => raise DomainMismatch
      }
      let rhs = match expr_rational_value(right) {
        Some(v) => rational_abs(v)
        None => raise DomainMismatch
      }
      if lhs.is_zero() || rhs.is_zero() {
        int(0)
      } else {
        let num = domain_bigint_lcm(lhs.numerator(), rhs.numerator())
        let den = @symnum.gcd_bigint(lhs.denominator(), rhs.denominator())
        Number(poly_rational_from_bigints(num, den))
      }
    }
    ZZ_I => {
      let lhs = gaussian_int_from_expr(domain, left)
      let rhs = gaussian_int_from_expr(domain, right)
      gaussian_int_to_expr(gaussian_int_lcm(lhs, rhs))
    }
    QQ_I => {
      let lhs = gaussian_rat_from_expr(domain, left)
      let rhs = gaussian_rat_from_expr(domain, right)
      let (num_l, den_l) = gaussian_rat_numer_denom(lhs)
      let (num_r, den_r) = gaussian_rat_numer_denom(rhs)
      let numer = gaussian_int_lcm(num_l, num_r)
      let denom = @symnum.gcd_bigint(den_l, den_r)
      gaussian_rat_to_expr(gaussian_rat_from_numer_denom(numer, denom))
    }
    GF(_) | GFExt(_, _, _) => {
      let lhs = field_elem_from_scalar_expr(left, domain)
      let rhs = field_elem_from_scalar_expr(right, domain)
      fe_to_expr_const(fe_mul(lhs, rhs))
    }
    RR | CC => {
      let fallback = fn() {
        if domain_is_zero_expr(domain, left) ||
          domain_is_zero_expr(domain, right) {
          int(0)
        } else {
          left * right
        }
      }
      try field_elem_from_scalar_expr(left, domain) catch {
        _ => fallback()
      } noraise {
        lhs =>
          try field_elem_from_scalar_expr(right, domain) catch {
            _ => fallback()
          } noraise {
            rhs => fe_to_expr_const(fe_mul(lhs, rhs))
          }
      }
    }
    EX | EXRAW | AlgExt(_, _, _) =>
      if domain_is_zero_expr(domain, left) || domain_is_zero_expr(domain, right) {
        int(0)
      } else {
        left * right
      }
    _ => raise DomainMismatch
  }
}

///|
fn domain_poly_gcd_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  let lhs = Poly::from_expr(left, gens, coeff_domain)
  let rhs = Poly::from_expr(right, gens, coeff_domain)
  poly_gcd_compat(lhs, rhs).to_expr()
}

///|
fn domain_poly_lcm_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  let lhs = Poly::from_expr(left, gens, coeff_domain)
  let rhs = Poly::from_expr(right, gens, coeff_domain)
  poly_lcm_compat(lhs, rhs).to_expr()
}

///|
fn domain_rational_function_gcd_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  let (left_num, left_den) = rational_function_pair_from_expr(
    coeff_domain, gens, left,
  )
  let (right_num, right_den) = rational_function_pair_from_expr(
    coeff_domain, gens, right,
  )
  let numer = if poly_is_ground(left_num) && poly_is_ground(right_num) {
    poly_from_ground_expr(
      coeff_domain,
      gens,
      domain_scalar_gcd_expr(
        coeff_domain,
        poly_ground_expr(left_num),
        poly_ground_expr(right_num),
      ),
    )
  } else {
    poly_gcd_compat(left_num, right_num)
  }
  let denom = if poly_is_ground(left_den) && poly_is_ground(right_den) {
    poly_from_ground_expr(
      coeff_domain,
      gens,
      domain_scalar_lcm_expr(
        coeff_domain,
        poly_ground_expr(left_den),
        poly_ground_expr(right_den),
      ),
    )
  } else {
    poly_lcm_compat(left_den, right_den)
  }
  rational_function_expr_from_pair(numer, denom, coeff_domain)
}

///|
fn domain_rational_function_lcm_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  let (left_num, left_den) = rational_function_pair_from_expr(
    coeff_domain, gens, left,
  )
  let (right_num, right_den) = rational_function_pair_from_expr(
    coeff_domain, gens, right,
  )
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
      domain_scalar_gcd_expr(
        coeff_domain,
        poly_ground_expr(left_den),
        poly_ground_expr(right_den),
      ),
    )
  } else {
    poly_gcd_compat(left_den, right_den)
  }
  rational_function_expr_from_pair(numer, denom, coeff_domain)
}

///|

///|
/// Public API `domain_canonical_unit_expr`.
///
/// - Does: Provides the `domain_canonical_unit_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_canonical_unit_expr(
  domain : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    ZZ | QQ | RR | GF(_) | GFExt(_, _, _) =>
      match domain_expr_sign(domain, expr) {
        Some(v) if v < 0 => int(-1)
        _ => int(1)
      }
    CC => if domain_is_zero_expr(domain, expr) { int(1) } else { int(1) }
    ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_canonical_unit(gaussian_int_from_expr(domain, expr)),
      )
    QQ_I =>
      gaussian_rat_to_expr(
        gaussian_rat_canonical_unit(gaussian_rat_from_expr(domain, expr)),
      )
    EX | EXRAW =>
      if domain_is_zero_expr(domain, expr) {
        int(1)
      } else if expr_has_leading_minus(expr) {
        int(-1)
      } else {
        int(1)
      }
    PolyRing(base, gens) | QuotientRing(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, denom)) =>
          if !expr_terms_is_one(base, denom, gens.length()) {
            raise DomainMismatch
          } else {
            match expr_terms_leading_coeff(base, numer) {
              Some(coeff) => domain_canonical_unit_expr(base, coeff)
              None => int(1)
            }
          }
        None => raise DomainMismatch
      }
    RationalFunctionField(base, gens) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, _)) =>
          match expr_terms_leading_coeff(base, numer) {
            Some(coeff) => domain_canonical_unit_expr(base, coeff)
            None => int(1)
          }
        None => raise DomainMismatch
      }
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) =>
          domain_canonical_unit_expr(RationalFunctionField(inner, gens), expr)
        _ => domain_canonical_unit_expr(base, expr)
      }
    PowerSeries(base, gens, _) =>
      match expr_constant_term(expr, generator_symbol_names(gens)) {
        Some(c0) => domain_canonical_unit_expr(base, c0)
        None => raise DomainMismatch
      }
    AlgExt(base, gens, _) =>
      match expr_collect_rational_terms(base, gens, expr) {
        Some((numer, _)) =>
          match expr_terms_leading_coeff(base, numer) {
            Some(coeff) => domain_canonical_unit_expr(base, coeff)
            None => int(1)
          }
        None => if expr_has_leading_minus(expr) { int(-1) } else { int(1) }
      }
  }
}

///|

///|
/// Public API `domain_abs_expr`.
///
/// - Does: Provides the `domain_abs_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_abs_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    ZZ | QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_rational(rational_abs(value))
        None => raise DomainMismatch
      }
    RR =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_rational(rational_abs(value))
        None => @symcore.function("Abs", [expr])
      }
    CC => {
      let value = gaussian_rat_from_expr(domain, expr)
      let norm = value.re.mul_r(value.re).add_r(value.im.mul_r(value.im))
      sqrt_of_nonnegative_rational(norm)
    }
    EX | EXRAW =>
      match expr_numeric_sign(expr) {
        Some(v) =>
          if v < 0 {
            match expr {
              Number(n) => Number(n.neg_r())
              _ => @symcore.function("Abs", [expr])
            }
          } else {
            expr
          }
        None =>
          match expr_gaussian_coeffs(QQ, expr) {
            Some(value) => {
              let norm = value.re
                .mul_r(value.re)
                .add_r(value.im.mul_r(value.im))
              sqrt_of_nonnegative_rational(norm)
            }
            None =>
              match expr_strip_leading_minus(expr) {
                Some(inner) => @symcore.function("Abs", [inner])
                None => @symcore.function("Abs", [expr])
              }
          }
      }
    _ => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_gcd_expr`.
///
/// - Does: Provides the `domain_gcd_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_gcd_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  match domain {
    PolyRing(base, gens) => domain_poly_gcd_expr(base, gens, left, right)
    RationalFunctionField(base, gens) =>
      domain_rational_function_gcd_expr(base, gens, left, right)
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) =>
          domain_rational_function_gcd_expr(inner, gens, left, right)
        _ => domain_scalar_gcd_expr(base, left, right)
      }
    _ => domain_scalar_gcd_expr(domain, left, right)
  }
}

///|

///|
/// Public API `domain_lcm_expr`.
///
/// - Does: Provides the `domain_lcm_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_lcm_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  match domain {
    PolyRing(base, gens) => domain_poly_lcm_expr(base, gens, left, right)
    RationalFunctionField(base, gens) =>
      domain_rational_function_lcm_expr(base, gens, left, right)
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) =>
          domain_rational_function_lcm_expr(inner, gens, left, right)
        _ => domain_scalar_lcm_expr(base, left, right)
      }
    _ => domain_scalar_lcm_expr(domain, left, right)
  }
}

///|

///|
/// Public API `domain_cofactors_expr`.
///
/// - Does: Provides the `domain_cofactors_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr` and 1 more parameter(s), using the package representation expected by the
/// signature.
/// - Returns: a `(Expr, Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_cofactors_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr, Expr) raise PolyError {
  let gcd = domain_gcd_expr(domain, left, right)
  let cfa = match domain {
    ZZ =>
      match (expr_rational_value(left), expr_rational_value(gcd)) {
        (Some(lhs), Some(g)) if lhs.is_integral() &&
          g.is_integral() &&
          !g.is_zero() => expr_from_bigint(lhs.numerator().div(g.numerator()))
        _ => raise ExactQuotientFailed
      }
    QQ =>
      match (expr_rational_value(left), expr_rational_value(gcd)) {
        (Some(lhs), Some(g)) if !g.is_zero() =>
          expr_from_rational(poly_rational_div(lhs, g))
        _ => raise ExactQuotientFailed
      }
    ZZ_I => {
      let q = gaussian_int_div_exact(
        gaussian_int_from_expr(domain, left),
        gaussian_int_from_expr(domain, gcd),
      )
      gaussian_int_to_expr(q)
    }
    QQ_I => {
      let q = gaussian_rat_div(
        gaussian_rat_from_expr(domain, left),
        gaussian_rat_from_expr(domain, gcd),
      )
      gaussian_rat_to_expr(q)
    }
    PolyRing(coeff_domain, gens) => {
      let lhs = Poly::from_expr(left, gens, coeff_domain)
      let g = Poly::from_expr(gcd, gens, coeff_domain)
      poly_exact_quo(lhs, g).to_expr()
    }
    RationalFunctionField(coeff_domain, gens) => {
      let (left_num, left_den) = rational_function_pair_from_expr(
        coeff_domain, gens, left,
      )
      let (g_num, g_den) = rational_function_pair_from_expr(
        coeff_domain, gens, gcd,
      )
      rational_function_expr_from_pair(
        left_num.mul(g_den),
        left_den.mul(g_num),
        coeff_domain,
      )
    }
    Frac(base) =>
      match base {
        PolyRing(coeff_domain, gens)
        | RationalFunctionField(coeff_domain, gens) => {
          let (left_num, left_den) = rational_function_pair_from_expr(
            coeff_domain, gens, left,
          )
          let (g_num, g_den) = rational_function_pair_from_expr(
            coeff_domain, gens, gcd,
          )
          rational_function_expr_from_pair(
            left_num.mul(g_den),
            left_den.mul(g_num),
            coeff_domain,
          )
        }
        _ =>
          if domain_is_one_expr(base, gcd) {
            left
          } else {
            left * (gcd ^ int(-1))
          }
      }
    _ =>
      if domain_is_one_expr(domain, gcd) {
        left
      } else {
        left * (gcd ^ int(-1))
      }
  }
  let cfb = match domain {
    ZZ =>
      match (expr_rational_value(right), expr_rational_value(gcd)) {
        (Some(rhs), Some(g)) if rhs.is_integral() &&
          g.is_integral() &&
          !g.is_zero() => expr_from_bigint(rhs.numerator().div(g.numerator()))
        _ => raise ExactQuotientFailed
      }
    QQ =>
      match (expr_rational_value(right), expr_rational_value(gcd)) {
        (Some(rhs), Some(g)) if !g.is_zero() =>
          expr_from_rational(poly_rational_div(rhs, g))
        _ => raise ExactQuotientFailed
      }
    ZZ_I => {
      let q = gaussian_int_div_exact(
        gaussian_int_from_expr(domain, right),
        gaussian_int_from_expr(domain, gcd),
      )
      gaussian_int_to_expr(q)
    }
    QQ_I => {
      let q = gaussian_rat_div(
        gaussian_rat_from_expr(domain, right),
        gaussian_rat_from_expr(domain, gcd),
      )
      gaussian_rat_to_expr(q)
    }
    PolyRing(coeff_domain, gens) => {
      let rhs = Poly::from_expr(right, gens, coeff_domain)
      let g = Poly::from_expr(gcd, gens, coeff_domain)
      poly_exact_quo(rhs, g).to_expr()
    }
    RationalFunctionField(coeff_domain, gens) => {
      let (right_num, right_den) = rational_function_pair_from_expr(
        coeff_domain, gens, right,
      )
      let (g_num, g_den) = rational_function_pair_from_expr(
        coeff_domain, gens, gcd,
      )
      rational_function_expr_from_pair(
        right_num.mul(g_den),
        right_den.mul(g_num),
        coeff_domain,
      )
    }
    Frac(base) =>
      match base {
        PolyRing(coeff_domain, gens)
        | RationalFunctionField(coeff_domain, gens) => {
          let (right_num, right_den) = rational_function_pair_from_expr(
            coeff_domain, gens, right,
          )
          let (g_num, g_den) = rational_function_pair_from_expr(
            coeff_domain, gens, gcd,
          )
          rational_function_expr_from_pair(
            right_num.mul(g_den),
            right_den.mul(g_num),
            coeff_domain,
          )
        }
        _ =>
          if domain_is_one_expr(base, gcd) {
            right
          } else {
            right * (gcd ^ int(-1))
          }
      }
    _ =>
      if domain_is_one_expr(domain, gcd) {
        right
      } else {
        right * (gcd ^ int(-1))
      }
  }
  (gcd, cfa, cfb)
}

///|
fn domain_poly_gcdex_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> (Expr, Expr, Expr) raise PolyError {
  if gens.length() != 1 {
    raise NotUnivariate
  }
  guard domain_is_field_pred(coeff_domain) else { raise DomainNotField }
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

///|
/// Public API `domain_gcdex_expr`.
///
/// - Does: Provides the `domain_gcdex_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr` and 1 more parameter(s), using the package representation expected by the
/// signature.
/// - Returns: a `(Expr, Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_gcdex_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr, Expr) raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  if domain_is_field_pred(domain) {
    let gcd = domain_gcd_expr(domain, left, right)
    if domain_is_zero_expr(domain, left) {
      if domain_is_zero_expr(domain, right) {
        return (
          domain_zero_like_expr(domain),
          domain_one_like_expr(domain),
          domain_zero_like_expr(domain),
        )
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
    ZZ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() && rhs.is_integral() => {
          let (s, t, g) = domain_bigint_gcdex(lhs.numerator(), rhs.numerator())
          (expr_from_bigint(s), expr_from_bigint(t), expr_from_bigint(g))
        }
        _ => raise DomainMismatch
      }
    ZZ_I => {
      let zero = GaussianIntCompat::{
        re: BigInt::from_int(0),
        im: BigInt::from_int(0),
      }
      let one = GaussianIntCompat::{
        re: BigInt::from_int(1),
        im: BigInt::from_int(0),
      }
      let mut old_r = gaussian_int_from_expr(domain, left)
      let mut r = gaussian_int_from_expr(domain, right)
      if gaussian_int_is_zero(old_r) && gaussian_int_is_zero(r) {
        return (
          gaussian_int_to_expr(zero),
          gaussian_int_to_expr(one),
          gaussian_int_to_expr(zero),
        )
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
      (
        gaussian_int_to_expr(old_s),
        gaussian_int_to_expr(old_t),
        gaussian_int_to_expr(old_r),
      )
    }
    PolyRing(coeff_domain, gens) =>
      domain_poly_gcdex_expr(coeff_domain, gens, left, right)
    _ => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_half_gcdex_expr`.
///
/// - Does: Provides the `domain_half_gcdex_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr`, using the package representation expected by the signature.
/// - Returns: a `(Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_half_gcdex_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr) raise PolyError {
  let (s, _, g) = domain_gcdex_expr(domain, left, right)
  (s, g)
}

///|

///|
/// Public API `domain_invert_expr`.
///
/// - Does: Provides the `domain_invert_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_invert_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  let (s, _, h) = domain_gcdex_expr(domain, left, right)
  guard domain_is_one_expr(domain, h) else { raise ExactQuotientFailed }
  domain_rem_expr(domain, s, right)
}

///|

///|
/// Public API `domain_revert_expr`.
///
/// - Does: Provides the `domain_revert_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_revert_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  if domain_is_field_pred(domain) {
    guard !domain_is_zero_expr(domain, expr) else { raise DivisionByZero }
    return domain_quo_expr(domain, domain_one_like_expr(domain), expr)
  }
  if domain_is_one_expr(domain, expr) ||
    domain_is_negative_one_expr(domain, expr) {
    expr
  } else {
    raise ExactQuotientFailed
  }
}

///|

///|
/// Public API `domain_factorial_expr`.
///
/// - Does: Provides the `domain_factorial_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_factorial_expr(
  domain : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    ZZ | QQ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() &&
          value.compare(@symnum.BigRational::zero()) >= 0 =>
          expr_from_bigint(domain_bigint_factorial(value.numerator()))
        _ => raise DomainMismatch
      }
    PolyRing(base, gens)
    | QuotientRing(base, gens, _)
    | PowerSeries(base, gens, _) => {
      let poly = Poly::from_expr(expr, gens, base)
      let ground = poly_ground_expr(poly)
      domain_from_sympy_expr(domain, domain_factorial_expr(base, ground))
    }
    RationalFunctionField(base, gens) => {
      let (numer, denom) = rational_function_pair_from_expr(base, gens, expr)
      guard poly_is_ground(denom) &&
        domain_is_one_expr(base, poly_ground_expr(denom)) else {
        raise DomainMismatch
      }
      let ground = poly_ground_expr(numer)
      domain_from_sympy_expr(domain, domain_factorial_expr(base, ground))
    }
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) =>
          domain_factorial_expr(RationalFunctionField(inner, gens), expr)
        _ => domain_factorial_expr(base, expr)
      }
    _ => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_log_expr`.
///
/// - Does: Provides the `domain_log_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `value : Expr`, `base : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_log_expr(
  domain : Domain,
  value : Expr,
  base : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, value) &&
    domain_contains_expr(domain, base) else {
    raise DomainMismatch
  }
  match domain {
    ZZ =>
      match (expr_rational_value(value), expr_rational_value(base)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() && rhs.is_integral() =>
          expr_from_bigint(
            domain_bigint_log_floor(lhs.numerator(), rhs.numerator()),
          )
        _ => raise DomainMismatch
      }
    PolyRing(inner, gens)
    | QuotientRing(inner, gens, _)
    | PowerSeries(inner, gens, _) => {
      let lhs = poly_ground_expr(Poly::from_expr(value, gens, inner))
      let rhs = poly_ground_expr(Poly::from_expr(base, gens, inner))
      domain_from_sympy_expr(domain, domain_log_expr(inner, lhs, rhs))
    }
    _ => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_sqrt_expr`.
///
/// - Does: Provides the `domain_sqrt_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_sqrt_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    ZZ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() =>
          expr_from_bigint(domain_bigint_sqrt_floor(value.numerator()))
        _ => raise DomainMismatch
      }
    PolyRing(base, gens)
    | QuotientRing(base, gens, _)
    | PowerSeries(base, gens, _) => {
      let poly = Poly::from_expr(expr, gens, base)
      let ground = poly_ground_expr(poly)
      domain_from_sympy_expr(domain, domain_sqrt_expr(base, ground))
    }
    _ => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_exsqrt_expr`.
///
/// - Does: Provides the `domain_exsqrt_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_exsqrt_expr(
  domain : Domain,
  expr : Expr,
) -> Expr? raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    ZZ =>
      match expr_rational_value(expr) {
        Some(value) if value.is_integral() =>
          domain_bigint_exsqrt(value.numerator()).map(root => {
            expr_from_bigint(root)
          })
        _ => raise DomainMismatch
      }
    QQ =>
      match expr_rational_value(expr) {
        Some(value) =>
          domain_rational_exsqrt(value).map(root => expr_from_rational(root))
        None => raise DomainMismatch
      }
    ZZ_I =>
      gaussian_int_exsqrt(gaussian_int_from_expr(domain, expr)).map(root => {
        gaussian_int_to_expr(root)
      })
    QQ_I =>
      gaussian_rat_exsqrt(gaussian_rat_from_expr(domain, expr)).map(root => {
        gaussian_rat_to_expr(root)
      })
    GF(_) | GFExt(_, _, _) =>
      finite_field_exsqrt(domain, field_elem_from_scalar_expr(expr, domain)).map(root => {
          domain_field_elem_to_expr(domain, root)
        },
      )
    RR =>
      match domain_expr_sign(domain, expr) {
        Some(v) if v < 0 => None
        _ => Some(expr_exact_sqrt_or_symbolic(expr))
      }
    CC => Some(@symcore.function("sqrt", [expr]))
    PolyRing(base, gens)
    | QuotientRing(base, gens, _)
    | PowerSeries(base, gens, _) => {
      let poly = Poly::from_expr(expr, gens, base)
      let ground = poly_ground_expr(poly)
      match domain_exsqrt_expr(base, ground) {
        Some(root) => Some(domain_from_sympy_expr(domain, root))
        None => None
      }
    }
    Frac(base) =>
      match base {
        PolyRing(inner, gens) | RationalFunctionField(inner, gens) => {
          let (numer, denom) = rational_function_pair_from_expr(
            inner, gens, expr,
          )
          match
            (
              domain_exsqrt_expr(PolyRing(inner, gens), numer.to_expr()),
              domain_exsqrt_expr(PolyRing(inner, gens), denom.to_expr()),
            ) {
            (Some(num_root), Some(den_root)) =>
              Some(num_root * (den_root ^ int(-1)))
            _ => None
          }
        }
        _ => domain_exsqrt_expr(base, expr)
      }
    _ => None
  }
}

///|

///|
/// Public API `domain_is_square_expr`.
///
/// - Does: Provides the `domain_is_square_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_is_square_expr(
  domain : Domain,
  expr : Expr,
) -> Bool raise PolyError {
  match domain {
    RR =>
      match domain_expr_sign(domain, expr) {
        Some(v) => v >= 0
        None => false
      }
    CC => domain_contains_expr(domain, expr)
    GF(_) | GFExt(_, _, _) => {
      guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
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

///|
/// Public API `domain_real_expr`.
///
/// - Does: Provides the `domain_real_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_real_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  domain_from_sympy_expr(domain, expr)
}

///|

///|
/// Public API `domain_imag_expr`.
///
/// - Does: Provides the `domain_imag_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_imag_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  domain_zero_like_expr(domain)
}

///|
fn gaussian_rat_almosteq(
  left : GaussianRatCompat,
  right : GaussianRatCompat,
  tolerance : @symnum.BigRational,
) -> Bool {
  rational_abs(left.re.add_r(right.re.neg_r())).compare(tolerance) <= 0 &&
  rational_abs(left.im.add_r(right.im.neg_r())).compare(tolerance) <= 0
}

///|

///|
/// Public API `domain_almosteq_expr`.
///
/// - Does: Provides the `domain_almosteq_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, `tolerance :
/// @symnum.BigRational = None`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn domain_almosteq_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
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
      let lhs_gauss = gaussian_rat_from_expr(domain, left) catch {
        _ => {
          let lhs = domain_from_sympy_expr(domain, left) catch {
            _ => return false
          }
          let rhs = domain_from_sympy_expr(domain, right) catch {
            _ => return false
          }
          return expr_key(lhs) == expr_key(rhs)
        }
      }
      let rhs_gauss = gaussian_rat_from_expr(domain, right) catch {
        _ => {
          let lhs = domain_from_sympy_expr(domain, left) catch {
            _ => return false
          }
          let rhs = domain_from_sympy_expr(domain, right) catch {
            _ => return false
          }
          return expr_key(lhs) == expr_key(rhs)
        }
      }
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

///|
/// Public API `domain_evalf_expr`.
///
/// - Does: Provides the `domain_evalf_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `prec : Int = None`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_evalf_expr(
  domain : Domain,
  expr : Expr,
  prec? : Int? = None,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  let p = match prec {
    Some(value) if value > 0 => value
    _ => 53
  }
  match domain {
    RR => @symcore.evalf(expr, prec=p)
    CC => {
      let numeric = @symcore.evalf(expr, prec=p)
      match numeric {
        Float(_) | ComplexFloat(_) => numeric
        _ =>
          complex_float_expr_from_gaussian(
            gaussian_rat_from_expr(domain, expr),
            p,
          )
      }
    }
    _ => domain_to_sympy_expr(domain, expr)
  }
}

///|
fn domain_zero_like_expr(domain : Domain) -> Expr raise PolyError {
  match domain {
    GF(_) | GFExt(_, _, _) | RR | CC =>
      domain_field_elem_to_expr(domain, fe_from_int(0, domain))
    _ => int(0)
  }
}

///|
fn domain_one_like_expr(domain : Domain) -> Expr raise PolyError {
  match domain {
    GF(_) | GFExt(_, _, _) | RR | CC =>
      domain_field_elem_to_expr(domain, fe_from_int(1, domain))
    _ => int(1)
  }
}

///|
/// Return the additive identity of `domain` as an expression.

///|
/// Public API `domain_zero_expr`.
///
/// - Does: Provides the `domain_zero_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_zero_expr(domain : Domain) -> Expr raise PolyError {
  domain_zero_like_expr(domain)
}

///|
/// Return the multiplicative identity of `domain` as an expression.

///|
/// Public API `domain_one_expr`.
///
/// - Does: Provides the `domain_one_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_one_expr(domain : Domain) -> Expr raise PolyError {
  domain_one_like_expr(domain)
}

///|
/// Unary plus over domain elements.

///|
/// Public API `domain_pos_expr`.
///
/// - Does: Provides the `domain_pos_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_pos_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  domain_from_sympy_expr(domain, expr)
}

///|
/// Unary minus over domain elements.

///|
/// Public API `domain_neg_expr`.
///
/// - Does: Provides the `domain_neg_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_neg_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  domain_from_sympy_expr(domain, int(-1) * expr)
}

///|
/// Addition over domain elements.

///|
/// Public API `domain_add_expr`.
///
/// - Does: Provides the `domain_add_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_add_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  domain_from_sympy_expr(domain, left + right)
}

///|
/// Subtraction over domain elements.

///|
/// Public API `domain_sub_expr`.
///
/// - Does: Provides the `domain_sub_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_sub_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  domain_from_sympy_expr(domain, left + int(-1) * right)
}

///|
/// Multiplication over domain elements.

///|
/// Public API `domain_mul_expr`.
///
/// - Does: Provides the `domain_mul_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_mul_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  match domain {
    ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_mul(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    QQ_I =>
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

///|
/// Public API `domain_pow_expr`.
///
/// - Does: Provides the `domain_pow_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, `exp : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_pow_expr(
  domain : Domain,
  expr : Expr,
  exp : Int,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  if exp == 0 {
    return domain_one_like_expr(domain)
  }
  if exp < 0 {
    guard domain_is_field_pred(domain) else { raise DomainNotField }
    return domain_quo_expr(
      domain,
      domain_one_like_expr(domain),
      domain_pow_expr(domain, expr, -exp),
    )
  }
  let mut n = exp
  let mut base = domain_from_sympy_expr(domain, expr)
  let mut acc = domain_one_like_expr(domain)
  while n > 0 {
    if (n & 1) == 1 {
      acc = domain_mul_expr(domain, acc, base)
    }
    n = n / 2
    if n > 0 {
      base = domain_mul_expr(domain, base, base)
    }
  }
  acc
}

///|
fn domain_field_elem_to_expr(domain : Domain, elem : FieldElem) -> Expr {
  match (domain, elem) {
    (GF(p), GFp(_, value)) => {
      let symm = if value > p / 2 { value - p } else { value }
      Number(@symnum.BigRational::from_int(symm))
    }
    _ => fe_to_expr_const(elem)
  }
}

///|
fn domain_rational_function_quo_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  let (left_num, left_den) = rational_function_pair_from_expr(
    coeff_domain, gens, left,
  )
  let (right_num, right_den) = rational_function_pair_from_expr(
    coeff_domain, gens, right,
  )
  if right_num.is_zero() {
    raise DivisionByZero
  }
  rational_function_expr_from_pair(
    left_num.mul(right_den),
    left_den.mul(right_num),
    coeff_domain,
  )
}

///|
fn domain_poly_div_expr(
  coeff_domain : Domain,
  gens : Array[String],
  left : Expr,
  right : Expr,
) -> (Expr, Expr) raise PolyError {
  let lhs = Poly::from_expr(left, gens, coeff_domain)
  let rhs = Poly::from_expr(right, gens, coeff_domain)
  if rhs.is_zero() {
    raise DivisionByZero
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

///|
/// Public API `domain_numer_expr`.
///
/// - Does: Provides the `domain_numer_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_numer_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    ZZ => expr
    QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_bigint(value.numerator())
        None => raise DomainMismatch
      }
    ZZ_I => expr
    QQ_I => {
      let value = gaussian_rat_from_expr(domain, expr)
      let (numer, _) = gaussian_rat_numer_denom(value)
      gaussian_int_to_expr(numer)
    }
    GF(_) | GFExt(_, _, _) | RR | CC =>
      domain_field_elem_to_expr(
        domain,
        field_elem_from_scalar_expr(expr, domain),
      )
    PolyRing(_, _)
    | QuotientRing(_, _, _)
    | PowerSeries(_, _, _)
    | EX
    | EXRAW
    | AlgExt(_, _, _) => expr
    RationalFunctionField(coeff_domain, gens) =>
      rational_function_pair_from_expr(coeff_domain, gens, expr).0.to_expr()
    Frac(base) =>
      match base {
        PolyRing(coeff_domain, gens)
        | RationalFunctionField(coeff_domain, gens) =>
          rational_function_pair_from_expr(coeff_domain, gens, expr).0.to_expr()
        _ => domain_numer_expr(base, expr)
      }
  }
}

///|

///|
/// Public API `domain_denom_expr`.
///
/// - Does: Provides the `domain_denom_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `expr : Expr`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_denom_expr(domain : Domain, expr : Expr) -> Expr raise PolyError {
  guard domain_contains_expr(domain, expr) else { raise DomainMismatch }
  match domain {
    QQ =>
      match expr_rational_value(expr) {
        Some(value) => expr_from_bigint(value.denominator())
        None => raise DomainMismatch
      }
    QQ_I => {
      let value = gaussian_rat_from_expr(domain, expr)
      let (_, denom) = gaussian_rat_numer_denom(value)
      expr_from_bigint(denom)
    }
    RationalFunctionField(coeff_domain, gens) =>
      rational_function_pair_from_expr(coeff_domain, gens, expr).1.to_expr()
    Frac(base) =>
      match base {
        PolyRing(coeff_domain, gens)
        | RationalFunctionField(coeff_domain, gens) =>
          rational_function_pair_from_expr(coeff_domain, gens, expr).1.to_expr()
        _ => domain_denom_expr(base, expr)
      }
    _ => domain_one_like_expr(domain)
  }
}

///|

///|
/// Public API `domain_quo_expr`.
///
/// - Does: Provides the `domain_quo_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_quo_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  match domain {
    ZZ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() &&
          rhs.is_integral() &&
          !rhs.is_zero() =>
          expr_from_bigint(lhs.numerator().div(rhs.numerator()))
        _ => raise DomainMismatch
      }
    QQ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if !rhs.is_zero() =>
          expr_from_rational(poly_rational_div(lhs, rhs))
        _ => raise DomainMismatch
      }
    ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_quo_round(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    QQ_I =>
      gaussian_rat_to_expr(
        gaussian_rat_div(
          gaussian_rat_from_expr(domain, left),
          gaussian_rat_from_expr(domain, right),
        ),
      )
    GF(_) | GFExt(_, _, _) | RR | CC => {
      let lhs = field_elem_from_scalar_expr(left, domain)
      let rhs = field_elem_from_scalar_expr(right, domain)
      domain_field_elem_to_expr(domain, fe_mul(lhs, fe_inv(rhs)))
    }
    EX | EXRAW | AlgExt(_, _, _) =>
      if domain_is_zero_expr(domain, right) {
        raise DivisionByZero
      } else {
        left * (right ^ int(-1))
      }
    PolyRing(coeff_domain, gens) | QuotientRing(coeff_domain, gens, _) =>
      domain_poly_div_expr(coeff_domain, gens, left, right).0
    RationalFunctionField(coeff_domain, gens) =>
      domain_rational_function_quo_expr(coeff_domain, gens, left, right)
    Frac(base) =>
      match base {
        PolyRing(coeff_domain, gens)
        | RationalFunctionField(coeff_domain, gens) =>
          domain_rational_function_quo_expr(coeff_domain, gens, left, right)
        _ => domain_quo_expr(base, left, right)
      }
    PowerSeries(_, _, _) => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_rem_expr`.
///
/// - Does: Provides the `domain_rem_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_rem_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  match domain {
    ZZ =>
      match (expr_rational_value(left), expr_rational_value(right)) {
        (Some(lhs), Some(rhs)) if lhs.is_integral() &&
          rhs.is_integral() &&
          !rhs.is_zero() =>
          expr_from_bigint(
            domain_bigint_euclid_mod(lhs.numerator(), rhs.numerator()),
          )
        _ => raise DomainMismatch
      }
    ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_rem(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    PolyRing(coeff_domain, gens) | QuotientRing(coeff_domain, gens, _) =>
      domain_poly_div_expr(coeff_domain, gens, left, right).1
    GF(_)
    | GFExt(_, _, _)
    | QQ
    | QQ_I
    | RR
    | CC
    | EX
    | EXRAW
    | RationalFunctionField(_, _)
    | Frac(_)
    | AlgExt(_, _, _) => domain_zero_like_expr(domain)
    PowerSeries(_, _, _) => raise DomainMismatch
  }
}

///|

///|
/// Public API `domain_div_expr`.
///
/// - Does: Provides the `domain_div_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr`, using the package representation expected by the signature.
/// - Returns: a `(Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_div_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr) raise PolyError {
  (domain_quo_expr(domain, left, right), domain_rem_expr(domain, left, right))
}

///|

///|
/// Public API `domain_exquo_expr`.
///
/// - Does: Provides the `domain_exquo_expr` operation for domain compatibility.
/// - Input: parameters `domain : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn domain_exquo_expr(
  domain : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  guard domain_contains_expr(domain, left) &&
    domain_contains_expr(domain, right) else {
    raise DomainMismatch
  }
  match domain {
    ZZ => {
      let q = domain_quo_expr(domain, left, right)
      guard domain_is_zero_expr(domain, domain_rem_expr(domain, left, right)) else {
        raise ExactQuotientFailed
      }
      q
    }
    ZZ_I =>
      gaussian_int_to_expr(
        gaussian_int_div_exact(
          gaussian_int_from_expr(domain, left),
          gaussian_int_from_expr(domain, right),
        ),
      )
    PolyRing(coeff_domain, gens) | QuotientRing(coeff_domain, gens, _) => {
      let (q, r) = domain_poly_div_expr(coeff_domain, gens, left, right)
      guard domain_is_zero_expr(PolyRing(coeff_domain, gens), r) else {
        raise ExactQuotientFailed
      }
      q
    }
    _ => domain_quo_expr(domain, left, right)
  }
}

///|

///|
/// Public API `Domain.is_zero_expr`.
///
/// - Does: Provides the `Domain.is_zero_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_zero_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_zero_expr(self, expr)
}

///|

///|
/// Public API `Domain.zero_expr`.
///
/// - Does: Provides the `Domain.zero_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::zero_expr(self : Domain) -> Expr raise PolyError {
  domain_zero_expr(self)
}

///|

///|
/// Public API `Domain.one_expr`.
///
/// - Does: Provides the `Domain.one_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::one_expr(self : Domain) -> Expr raise PolyError {
  domain_one_expr(self)
}

///|

///|
/// Public API `Domain.from_sympy_expr`.
///
/// - Does: Provides the `Domain.from_sympy_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::from_sympy_expr(
  self : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  domain_from_sympy_expr(self, expr)
}

///|

///|
/// Public API `Domain.new_expr`.
///
/// - Does: Provides the `Domain.new_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::new_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_new_expr(self, expr)
}

///|

///|
/// Public API `Domain.normal_expr`.
///
/// - Does: Provides the `Domain.normal_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::normal_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_normal_expr(self, expr)
}

///|

///|
/// Public API `Domain.to_sympy_expr`.
///
/// - Does: Provides the `Domain.to_sympy_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::to_sympy_expr(
  self : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  domain_to_sympy_expr(self, expr)
}

///|

///|
/// Public API `Domain.convert_from_expr`.
///
/// - Does: Provides the `Domain.convert_from_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::convert_from_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr raise PolyError {
  domain_convert_from_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.convert_expr`.
///
/// - Does: Provides the `Domain.convert_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain = None`, using
/// the package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::convert_expr(
  self : Domain,
  expr : Expr,
  base? : Domain? = None,
) -> Expr raise PolyError {
  domain_convert_expr(self, expr, base~)
}

///|

///|
/// Public API `Domain.sum_expr`.
///
/// - Does: Provides the `Domain.sum_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `exprs : Array[Expr]`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::sum_expr(
  self : Domain,
  exprs : Array[Expr],
) -> Expr raise PolyError {
  domain_sum_expr(self, exprs)
}

///|

///|
/// Public API `Domain.map_expr_tree`.
///
/// - Does: Provides the `Domain.map_expr_tree` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `exprs : Array[DomainExprTree]`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[DomainExprTree]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::map_expr_tree(
  self : Domain,
  exprs : Array[DomainExprTree],
) -> Array[DomainExprTree] raise PolyError {
  domain_map_expr_tree(self, exprs)
}

///|

///|
/// Public API `Domain.from_ff_expr`.
///
/// - Does: Provides the `Domain.from_ff_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_ff_expr(self : Domain, expr : Expr, base : Domain) -> Expr? {
  domain_from_ff_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_ff_python_expr`.
///
/// - Does: Provides the `Domain.from_ff_python_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_ff_python_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_ff_python_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_zz_expr`.
///
/// - Does: Provides the `Domain.from_zz_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_zz_expr(self : Domain, expr : Expr, base : Domain) -> Expr? {
  domain_from_zz_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_zz_python_expr`.
///
/// - Does: Provides the `Domain.from_zz_python_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_zz_python_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_zz_python_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_qq_expr`.
///
/// - Does: Provides the `Domain.from_qq_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_qq_expr(self : Domain, expr : Expr, base : Domain) -> Expr? {
  domain_from_qq_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_qq_python_expr`.
///
/// - Does: Provides the `Domain.from_qq_python_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_qq_python_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_qq_python_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_ff_gmpy_expr`.
///
/// - Does: Provides the `Domain.from_ff_gmpy_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_ff_gmpy_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_ff_gmpy_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_zz_gmpy_expr`.
///
/// - Does: Provides the `Domain.from_zz_gmpy_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_zz_gmpy_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_zz_gmpy_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_qq_gmpy_expr`.
///
/// - Does: Provides the `Domain.from_qq_gmpy_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_qq_gmpy_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_qq_gmpy_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_real_field_expr`.
///
/// - Does: Provides the `Domain.from_real_field_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_real_field_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_real_field_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_complex_field_expr`.
///
/// - Does: Provides the `Domain.from_complex_field_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_complex_field_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_complex_field_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_algebraic_field_expr`.
///
/// - Does: Provides the `Domain.from_algebraic_field_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_algebraic_field_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_algebraic_field_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_gaussian_integer_ring_expr`.
///
/// - Does: Provides the `Domain.from_gaussian_integer_ring_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_gaussian_integer_ring_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_gaussian_integer_ring_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_gaussian_rational_field_expr`.
///
/// - Does: Provides the `Domain.from_gaussian_rational_field_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_gaussian_rational_field_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_gaussian_rational_field_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_polynomial_ring_expr`.
///
/// - Does: Provides the `Domain.from_polynomial_ring_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_polynomial_ring_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_polynomial_ring_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_fraction_field_expr`.
///
/// - Does: Provides the `Domain.from_fraction_field_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_fraction_field_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_fraction_field_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_global_polynomial_ring_expr`.
///
/// - Does: Provides the `Domain.from_global_polynomial_ring_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_global_polynomial_ring_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_global_polynomial_ring_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_generalized_polynomial_ring_expr`.
///
/// - Does: Provides the `Domain.from_generalized_polynomial_ring_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_generalized_polynomial_ring_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_generalized_polynomial_ring_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_monogenic_finite_extension_expr`.
///
/// - Does: Provides the `Domain.from_monogenic_finite_extension_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_monogenic_finite_extension_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_monogenic_finite_extension_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_expression_domain_expr`.
///
/// - Does: Provides the `Domain.from_expression_domain_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_expression_domain_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_expression_domain_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.from_expression_raw_domain_expr`.
///
/// - Does: Provides the `Domain.from_expression_raw_domain_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `base : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::from_expression_raw_domain_expr(
  self : Domain,
  expr : Expr,
  base : Domain,
) -> Expr? {
  domain_from_expression_raw_domain_expr(self, expr, base)
}

///|

///|
/// Public API `Domain.unify_composite`.
///
/// - Does: Provides the `Domain.unify_composite` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `other : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::unify_composite(
  self : Domain,
  other : Domain,
) -> Domain raise PolyError {
  domain_unify_composite(self, other)
}

///|

///|
/// Public API `Domain.is_one_expr`.
///
/// - Does: Provides the `Domain.is_one_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_one_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_one_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_negative_one_expr`.
///
/// - Does: Provides the `Domain.is_negative_one_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_negative_one_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_negative_one_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_unit_expr`.
///
/// - Does: Provides the `Domain.is_unit_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_unit_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_unit_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_positive_expr`.
///
/// - Does: Provides the `Domain.is_positive_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_positive_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_positive_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_negative_expr`.
///
/// - Does: Provides the `Domain.is_negative_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_negative_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_negative_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_nonpositive_expr`.
///
/// - Does: Provides the `Domain.is_nonpositive_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_nonpositive_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_nonpositive_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_nonnegative_expr`.
///
/// - Does: Provides the `Domain.is_nonnegative_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::is_nonnegative_expr(self : Domain, expr : Expr) -> Bool {
  domain_is_nonnegative_expr(self, expr)
}

///|

///|
/// Public API `Domain.canonical_unit_expr`.
///
/// - Does: Provides the `Domain.canonical_unit_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::canonical_unit_expr(
  self : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  domain_canonical_unit_expr(self, expr)
}

///|

///|
/// Public API `Domain.abs_expr`.
///
/// - Does: Provides the `Domain.abs_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::abs_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_abs_expr(self, expr)
}

///|

///|
/// Public API `Domain.gcd_expr`.
///
/// - Does: Provides the `Domain.gcd_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::gcd_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_gcd_expr(self, left, right)
}

///|

///|
/// Public API `Domain.lcm_expr`.
///
/// - Does: Provides the `Domain.lcm_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::lcm_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_lcm_expr(self, left, right)
}

///|

///|
/// Public API `Domain.cofactors_expr`.
///
/// - Does: Provides the `Domain.cofactors_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr` and 1 more parameter(s), using the package representation expected by the
/// signature.
/// - Returns: a `(Expr, Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::cofactors_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr, Expr) raise PolyError {
  domain_cofactors_expr(self, left, right)
}

///|

///|
/// Public API `Domain.numer_expr`.
///
/// - Does: Provides the `Domain.numer_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::numer_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_numer_expr(self, expr)
}

///|

///|
/// Public API `Domain.denom_expr`.
///
/// - Does: Provides the `Domain.denom_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::denom_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_denom_expr(self, expr)
}

///|

///|
/// Public API `Domain.quo_expr`.
///
/// - Does: Provides the `Domain.quo_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::quo_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_quo_expr(self, left, right)
}

///|

///|
/// Public API `Domain.rem_expr`.
///
/// - Does: Provides the `Domain.rem_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::rem_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_rem_expr(self, left, right)
}

///|

///|
/// Public API `Domain.div_expr`.
///
/// - Does: Provides the `Domain.div_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr`, using the package representation expected by the signature.
/// - Returns: a `(Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::div_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr) raise PolyError {
  domain_div_expr(self, left, right)
}

///|

///|
/// Public API `Domain.exquo_expr`.
///
/// - Does: Provides the `Domain.exquo_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::exquo_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_exquo_expr(self, left, right)
}

///|

///|
/// Public API `Domain.half_gcdex_expr`.
///
/// - Does: Provides the `Domain.half_gcdex_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr`, using the package representation expected by the signature.
/// - Returns: a `(Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::half_gcdex_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr) raise PolyError {
  domain_half_gcdex_expr(self, left, right)
}

///|

///|
/// Public API `Domain.gcdex_expr`.
///
/// - Does: Provides the `Domain.gcdex_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, `) -> (Expr`,
/// `Expr` and 1 more parameter(s), using the package representation expected by the
/// signature.
/// - Returns: a `(Expr, Expr, Expr)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::gcdex_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> (Expr, Expr, Expr) raise PolyError {
  domain_gcdex_expr(self, left, right)
}

///|

///|
/// Public API `Domain.invert_expr`.
///
/// - Does: Provides the `Domain.invert_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::invert_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_invert_expr(self, left, right)
}

///|

///|
/// Public API `Domain.revert_expr`.
///
/// - Does: Provides the `Domain.revert_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::revert_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_revert_expr(self, expr)
}

///|

///|
/// Public API `Domain.factorial_expr`.
///
/// - Does: Provides the `Domain.factorial_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::factorial_expr(
  self : Domain,
  expr : Expr,
) -> Expr raise PolyError {
  domain_factorial_expr(self, expr)
}

///|

///|
/// Public API `Domain.log_expr`.
///
/// - Does: Provides the `Domain.log_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `value : Expr`, `base : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::log_expr(
  self : Domain,
  value : Expr,
  base : Expr,
) -> Expr raise PolyError {
  domain_log_expr(self, value, base)
}

///|

///|
/// Public API `Domain.sqrt_expr`.
///
/// - Does: Provides the `Domain.sqrt_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::sqrt_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_sqrt_expr(self, expr)
}

///|

///|
/// Public API `Domain.is_square_expr`.
///
/// - Does: Provides the `Domain.is_square_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::is_square_expr(
  self : Domain,
  expr : Expr,
) -> Bool raise PolyError {
  domain_is_square_expr(self, expr)
}

///|

///|
/// Public API `Domain.exsqrt_expr`.
///
/// - Does: Provides the `Domain.exsqrt_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr?` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::exsqrt_expr(self : Domain, expr : Expr) -> Expr? raise PolyError {
  domain_exsqrt_expr(self, expr)
}

///|

///|
/// Public API `Domain.real_expr`.
///
/// - Does: Provides the `Domain.real_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::real_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_real_expr(self, expr)
}

///|

///|
/// Public API `Domain.imag_expr`.
///
/// - Does: Provides the `Domain.imag_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::imag_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_imag_expr(self, expr)
}

///|

///|
/// Public API `Domain.almosteq_expr`.
///
/// - Does: Provides the `Domain.almosteq_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, `tolerance :
/// @symnum.BigRational = None`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::almosteq_expr(
  self : Domain,
  left : Expr,
  right : Expr,
  tolerance? : @symnum.BigRational? = None,
) -> Bool {
  domain_almosteq_expr(self, left, right, tolerance~)
}

///|

///|
/// Public API `Domain.evalf_expr`.
///
/// - Does: Provides the `Domain.evalf_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `prec : Int = None`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::evalf_expr(
  self : Domain,
  expr : Expr,
  prec? : Int? = None,
) -> Expr raise PolyError {
  domain_evalf_expr(self, expr, prec~)
}

///|

///|
/// Public API `Domain.pos_expr`.
///
/// - Does: Provides the `Domain.pos_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::pos_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_pos_expr(self, expr)
}

///|

///|
/// Public API `Domain.neg_expr`.
///
/// - Does: Provides the `Domain.neg_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, using the package representation
/// expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::neg_expr(self : Domain, expr : Expr) -> Expr raise PolyError {
  domain_neg_expr(self, expr)
}

///|

///|
/// Public API `Domain.add_expr`.
///
/// - Does: Provides the `Domain.add_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::add_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_add_expr(self, left, right)
}

///|

///|
/// Public API `Domain.sub_expr`.
///
/// - Does: Provides the `Domain.sub_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::sub_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_sub_expr(self, left, right)
}

///|

///|
/// Public API `Domain.mul_expr`.
///
/// - Does: Provides the `Domain.mul_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `left : Expr`, `right : Expr`, using the
/// package representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::mul_expr(
  self : Domain,
  left : Expr,
  right : Expr,
) -> Expr raise PolyError {
  domain_mul_expr(self, left, right)
}

///|

///|
/// Public API `Domain.pow_expr`.
///
/// - Does: Provides the `Domain.pow_expr` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `expr : Expr`, `exp : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Expr` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::pow_expr(
  self : Domain,
  expr : Expr,
  exp : Int,
) -> Expr raise PolyError {
  domain_pow_expr(self, expr, exp)
}

///|

///|
/// Public API `Domain.characteristic`.
///
/// - Does: Provides the `Domain.characteristic` operation for domain compatibility.
/// - Input: parameters `self : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Int` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::characteristic(self : Domain) -> Int {
  domain_characteristic(self)
}

///|

///|
/// Public API `Domain.get_exact`.
///
/// - Does: Provides the `Domain.get_exact` operation for domain compatibility.
/// - Input: parameters `self : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Domain` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::get_exact(self : Domain) -> Domain {
  domain_get_exact(self)
}

///|

///|
/// Public API `Domain.get_field`.
///
/// - Does: Provides the `Domain.get_field` operation for domain compatibility.
/// - Input: parameters `self : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::get_field(self : Domain) -> Domain raise PolyError {
  domain_get_field(self)
}

///|

///|
/// Public API `Domain.get_ring`.
///
/// - Does: Provides the `Domain.get_ring` operation for domain compatibility.
/// - Input: parameters `self : Domain`, using the package representation expected by
/// the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::get_ring(self : Domain) -> Domain raise PolyError {
  domain_get_ring(self)
}

///|

///|
/// Public API `Domain.unify`.
///
/// - Does: Provides the `Domain.unify` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `other : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::unify(self : Domain, other : Domain) -> Domain raise PolyError {
  domain_unify_pair(self, other)
}

///|

///|
/// Public API `Domain.unify_with_symbols`.
///
/// - Does: Provides the `Domain.unify_with_symbols` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `other : Domain`, `symbols : Array[String]`,
/// using the package representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::unify_with_symbols(
  self : Domain,
  other : Domain,
  symbols : Array[String],
) -> Domain raise PolyError {
  domain_unify_with_symbols(self, other, symbols)
}

///|

///|
/// Public API `Domain.poly_ring`.
///
/// - Does: Provides the `Domain.poly_ring` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::poly_ring(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_poly_ring(self, gens)
}

///|

///|
/// Public API `Domain.frac_field`.
///
/// - Does: Provides the `Domain.frac_field` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::frac_field(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_frac_field(self, gens)
}

///|

///|
/// Public API `Domain.old_poly_ring`.
///
/// - Does: Provides the `Domain.old_poly_ring` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::old_poly_ring(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_old_poly_ring(self, gens)
}

///|

///|
/// Public API `Domain.old_frac_field`.
///
/// - Does: Provides the `Domain.old_frac_field` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::old_frac_field(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_old_frac_field(self, gens)
}

///|

///|
/// Public API `Domain.set_domain`.
///
/// - Does: Provides the `Domain.set_domain` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `ground : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn Domain::set_domain(self : Domain, ground : Domain) -> Domain {
  domain_set_domain(self, ground)
}

///|

///|
/// Public API `Domain.algebraic_field`.
///
/// - Does: Provides the `Domain.algebraic_field` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `extension : Array[Expr]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::algebraic_field(
  self : Domain,
  extension : Array[Expr],
) -> Domain raise PolyError {
  domain_algebraic_field(self, extension)
}

///|

///|
/// Public API `Domain.alg_field_from_poly`.
///
/// - Does: Provides the `Domain.alg_field_from_poly` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `poly : Poly`, `extension_name : String =
/// None`, `root_index : Int = -1`, using the package representation expected by the
/// signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::alg_field_from_poly(
  self : Domain,
  poly : Poly,
  extension_name? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  domain_alg_field_from_poly(self, poly, extension_name~, root_index~)
}

///|

///|
/// Public API `Domain.cyclotomic_field`.
///
/// - Does: Provides the `Domain.cyclotomic_field` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `n : Int`, `ss : Bool = false`, `extension_name
/// : String = "zeta"`, `gen : String = None` and 1 more parameter(s), using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::cyclotomic_field(
  self : Domain,
  n : Int,
  ss? : Bool = false,
  extension_name? : String = "zeta",
  gen? : String? = None,
  root_index? : Int = -1,
) -> Domain raise PolyError {
  domain_cyclotomic_field(self, n, ss~, extension_name~, gen~, root_index~)
}

///|

///|
/// Public API `Domain.inject`.
///
/// - Does: Provides the `Domain.inject` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::inject(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_inject(self, gens)
}

///|

///|
/// Public API `Domain.drop`.
///
/// - Does: Provides the `Domain.drop` operation for domain compatibility.
/// - Input: parameters `self : Domain`, `gens : Array[String]`, using the package
/// representation expected by the signature.
/// - Returns: a `Domain` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Domain::drop(
  self : Domain,
  gens : Array[String],
) -> Domain raise PolyError {
  domain_drop(self, gens)
}
