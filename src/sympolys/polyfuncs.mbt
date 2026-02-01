///|
pub struct SymmetrizeResult {
  sym : @symcore.Expr
  rem : @symcore.Expr
  mapping : Array[(@symcore.Expr, @symcore.Expr)]
}

///|
pub fn interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  gen : String,
  domain : Domain,
) -> Poly raise PolyError {
  let builder = PolyBuilder::new([gen], domain)
  let mut result = Poly::zero([gen], domain)
  for i in 0..<points.length() {
    let (xi, yi) = points[i]
    let mut basis = Poly::one([gen], domain)
    let mut denom = @symnum.BigRational::one()
    for j in 0..<points.length() {
      if i == j {
        continue
      }
      let (xj, _) = points[j]
      denom = denom.mul_r(xi.add_r(xj.neg_r()))
      let term_expr = @symcore.symbol(gen) - @symcore.number(xj)
      let term = builder.from_expr(term_expr)
      basis = basis.mul(term)
    }
    let denom_fe = ensure_coeff_domain(denom, domain)
    let denom_inv = fe_inv(denom_fe)
    basis = basis.scale_coeff(denom_inv)
    let yi_fe = ensure_coeff_domain(yi, domain)
    basis = basis.scale_coeff(yi_fe)
    result = result.add(basis)
  }
  result
}

///|
pub fn rational_interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  gen : String,
  domain : Domain,
) -> (Poly, Poly) raise PolyError {
  if points.is_empty() {
    raise PolyError::NonPolynomial
  }
  let n = points.length()
  let k = n - deg_num - 1
  if k < 0 {
    raise PolyError::NotImplemented("rational_interpolate: too few points")
  }
  let matrix = build_rational_matrix(points, deg_num, k)
  let coeffs = nullspace_vector(matrix)
  let den_start = deg_num + 1
  let den_end = den_start + k
  let mut den_deg = -1
  let mut idx = den_end
  while idx >= den_start {
    if !coeffs[idx].is_zero() {
      den_deg = idx - den_start
      break
    }
    idx = idx - 1
  }
  if den_deg < 0 {
    raise PolyError::NotImplemented("rational_interpolate: zero denominator")
  }
  let lead = coeffs[den_start + den_deg]
  let inv_lead = lead.reciprocal() catch {
    _ => raise PolyError::DivisionByZero
  }
  for i in 0..<coeffs.length() {
    coeffs.set(i, coeffs[i].mul_r(inv_lead))
  }
  let num_coeffs : Array[@symnum.BigRational] = Array::new()
  for i in 0..=deg_num {
    num_coeffs.push(coeffs[i])
  }
  let den_coeffs : Array[@symnum.BigRational] = Array::new()
  for i in 0..=den_deg {
    den_coeffs.push(coeffs[den_start + i])
  }
  let num = poly_from_coeffs(num_coeffs, gen, domain)
  let den = poly_from_coeffs(den_coeffs, gen, domain)
  (num, den)
}

///|
pub fn symmetrize(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> SymmetrizeResult raise PolyError {
  let gens_final = if gens.is_empty() { infer_gens_expr(expr) } else { gens }
  let poly = if gens.is_empty() {
    Poly::from_expr_defaults(expr)
  } else {
    Poly::from_expr_defaults(expr, gens=gens_final)
  }
  let n = gens_final.length()
  if n == 0 {
    return SymmetrizeResult::{
      sym: expr,
      rem: @symcore.number(@symnum.BigRational::zero()),
      mapping: [],
    }
  }
  let sym_names = if symbols.is_empty() {
    default_sym_names(n)
  } else if symbols.length() == n {
    symbols
  } else {
    default_sym_names(n)
  }
  let (sym_poly, rem_poly, elem_polys) =
    symmetrize_poly(poly, sym_names)
  let mut sym_expr = sym_poly.to_expr()
  let rem_expr = rem_poly.to_expr()
  let mapping : Array[(@symcore.Expr, @symcore.Expr)] = Array::new()
  let env : Map[String, @symcore.Expr] = Map::new()
  let limit = if sym_names.length() < elem_polys.length() {
    sym_names.length()
  } else {
    elem_polys.length()
  }
  for i in 0..<limit {
    let sym_name = sym_names[i]
    let sym_var = @symcore.symbol(sym_name)
    let elem_expr = elem_polys[i].to_expr()
    mapping.push((sym_var, elem_expr))
    env.set(sym_name, elem_expr)
  }
  if !formal {
    sym_expr = @symcore.subst(sym_expr, env)
  }
  SymmetrizeResult::{ sym: sym_expr, rem: rem_expr, mapping }
}

///|
pub fn horner(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  wrt? : String = "",
) -> @symcore.Expr raise PolyError {
  let mut gens_final = if gens.is_empty() {
    infer_gens_expr(expr)
  } else {
    gens
  }
  if wrt != "" {
    let ordered : Array[String] = Array::new()
    ordered.push(wrt)
    for g in gens_final {
      if g != wrt {
        ordered.push(g)
      }
    }
    gens_final = ordered
  }
  let poly = if gens.is_empty() && wrt == "" {
    Poly::from_expr_defaults(expr)
  } else {
    Poly::from_expr_defaults(expr, gens=gens_final)
  }
  horner_poly(poly, gens_final)
}

///|
pub fn viete(
  expr : @symcore.Expr,
  roots? : Array[String] = [],
  gen? : String = "",
) -> Array[(@symcore.Expr, @symcore.Expr)] raise PolyError {
  let gens_final =
    if gen != "" {
      [gen]
    } else {
      infer_gens_expr(expr)
    }
  let poly = if gen == "" {
    Poly::from_expr_defaults(expr)
  } else {
    Poly::from_expr_defaults(expr, gens=gens_final)
  }
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let deg = poly.degree(0)
  if deg < 1 {
    raise PolyError::NotImplemented("viete: constant polynomial")
  }
  let roots_names = if roots.is_empty() {
    default_root_names(deg)
  } else {
    roots
  }
  if roots_names.length() != deg {
    raise PolyError::NotImplemented("viete: roots length mismatch")
  }
  let coeffs = univar_coeffs(poly)
  let lc = coeffs[deg]
  let inv_lc = fe_inv(lc)
  let result : Array[(@symcore.Expr, @symcore.Expr)] = Array::new()
  for i in 1..=deg {
    let coeff = coeffs[deg - i]
    let scaled = fe_mul(coeff, inv_lc)
    let mut expr_coeff = field_elem_to_expr(scaled, poly.domain)
    if i % 2 == 1 {
      expr_coeff = @symcore.int(-1) * expr_coeff
    }
    let sym_expr = elementary_sym_expr(roots_names, i)
    result.push((sym_expr, expr_coeff))
  }
  result
}

///|
fn build_rational_matrix(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  k : Int,
) -> Array[Array[@symnum.BigRational]] {
  let rows : Array[Array[@symnum.BigRational]] = Array::new()
  for i in 0..<points.length() {
    let (xi, yi) = points[i]
    let row : Array[@symnum.BigRational] = Array::new()
    let mut pow = @symnum.BigRational::one()
    for _ in 0..=deg_num {
      row.push(pow)
      pow = pow.mul_r(xi)
    }
    let mut pow_den = @symnum.BigRational::one()
    for _ in 0..=k {
      row.push(yi.neg_r().mul_r(pow_den))
      pow_den = pow_den.mul_r(xi)
    }
    rows.push(row)
  }
  rows
}

///|
fn nullspace_vector(
  matrix : Array[Array[@symnum.BigRational]],
) -> Array[@symnum.BigRational] raise PolyError {
  let rows = matrix.length()
  guard rows > 0 else { raise PolyError::NonPolynomial }
  let cols = matrix[0].length()
  let r = matrix
  let pivot_cols : Array[Int] = Array::new()
  let mut row = 0
  for col in 0..<cols {
    if row >= rows {
      break
    }
    let mut pivot = -1
    for i in row..<rows {
      if !r[i][col].is_zero() {
        pivot = i
        break
      }
    }
    if pivot == -1 {
      continue
    }
    if pivot != row {
      let tmp = r[row]
      r.set(row, r[pivot])
      r.set(pivot, tmp)
    }
    let pivot_val = r[row][col]
    for j in col..<cols {
      let v = r[row][j]
      r[row].set(j, v.div_r(pivot_val) catch {
        _ => raise PolyError::DivisionByZero
      })
    }
    for i in 0..<rows {
      if i == row {
        continue
      }
      let factor = r[i][col]
      if factor.is_zero() {
        continue
      }
      for j in col..<cols {
        let val = r[i][j]
        let sub = factor.mul_r(r[row][j])
        r[i].set(j, val.add_r(sub.neg_r()))
      }
    }
    pivot_cols.push(col)
    row += 1
  }
  let pivot_flags : Array[Bool] = Array::new()
  for _ in 0..<cols {
    pivot_flags.push(false)
  }
  for pc in pivot_cols {
    pivot_flags.set(pc, true)
  }
  let free_cols : Array[Int] = Array::new()
  for c in 0..<cols {
    if !pivot_flags[c] {
      free_cols.push(c)
    }
  }
  guard !free_cols.is_empty() else {
    raise PolyError::NotImplemented("rational_interpolate: no free column")
  }
  let free_col = free_cols[0]
  let sol : Array[@symnum.BigRational] = Array::new()
  for _ in 0..<cols {
    sol.push(@symnum.BigRational::zero())
  }
  sol.set(free_col, @symnum.BigRational::one())
  for i in 0..<pivot_cols.length() {
    let pc = pivot_cols[i]
    let coeff = r[i][free_col]
    sol.set(pc, coeff.neg_r())
  }
  sol
}

///|
fn poly_from_coeffs(
  coeffs : Array[@symnum.BigRational],
  gen : String,
  domain : Domain,
) -> Poly raise PolyError {
  let map : Map[Monomial, FieldElem] = Map::new()
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if coeff.is_zero() {
      continue
    }
    let mono = monomial_one(1)
    mono.exps.set(0, i)
    let fe = ensure_coeff_domain(coeff, domain)
    add_term(map, mono, fe, domain)
  }
  Poly::{ coeffs: map, gens: [gen], domain, order: TermOrder::Lex }
}

///|
fn infer_gens_expr(expr : @symcore.Expr) -> Array[String] {
  let seen : Map[String, Bool] = Map::new()
  collect_symbols_expr_pf(expr, seen)
  let names : Array[String] = Array::new()
  for name, _ in seen {
    names.push(name)
  }
  names.sort()
  names
}

///|
fn collect_symbols_expr_pf(
  expr : @symcore.Expr,
  seen : Map[String, Bool],
) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen.set(name, true)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for child in args {
        collect_symbols_expr_pf(child, seen)
      }
    @symcore.Expr::Pow(base, exp) => {
      collect_symbols_expr_pf(base, seen)
      collect_symbols_expr_pf(exp, seen)
    }
    @symcore.Expr::Function(_, args) =>
      for child in args {
        collect_symbols_expr_pf(child, seen)
      }
    _ => ()
  }
}

///|
fn default_sym_names(n : Int) -> Array[String] {
  let names : Array[String] = Array::new()
  for i in 1..=n {
    names.push("s\{i}")
  }
  names
}

///|
fn default_root_names(n : Int) -> Array[String] {
  let names : Array[String] = Array::new()
  for i in 1..=n {
    names.push("r\{i}")
  }
  names
}

///|
fn elementary_symmetric_polys(
  gens : Array[String],
  domain : Domain,
) -> Array[Poly] raise PolyError {
  let n = gens.length()
  let out : Array[Poly] = Array::new()
  for k in 1..=n {
    let coeffs : Map[Monomial, FieldElem] = Map::new()
    build_sym_terms(coeffs, n, k, 0, [], domain)
    out.push(Poly::{ coeffs, gens, domain, order: TermOrder::Lex })
  }
  out
}

///|
fn build_sym_terms(
  coeffs : Map[Monomial, FieldElem],
  n : Int,
  k : Int,
  start : Int,
  chosen : Array[Int],
  domain : Domain,
) -> Unit raise PolyError {
  if chosen.length() == k {
    let mono = monomial_one(n)
    for idx in chosen {
      mono.exps.set(idx, 1)
    }
    add_term(coeffs, mono, fe_from_int(1, domain), domain)
    return
  }
  if start >= n {
    return
  }
  let next = chosen.copy()
  next.push(start)
  build_sym_terms(coeffs, n, k, start + 1, next, domain)
  build_sym_terms(coeffs, n, k, start + 1, chosen, domain)
}

///|
fn symmetrize_poly(
  poly : Poly,
  sym_names : Array[String],
) -> (Poly, Poly, Array[Poly]) raise PolyError {
  let n = poly.gens.length()
  let elem_polys = elementary_symmetric_polys(poly.gens, poly.domain)
  let sym_poly = Poly::zero(sym_names, poly.domain)
  let mut f = poly
  if n == 0 {
    return (sym_poly, f, elem_polys)
  }
  let weights : Array[Int] = Array::new()
  for i in 0..<n {
    weights.push(n - i)
  }
  while !f.is_zero() {
    let mut best_height = -1
    let mut best_m : Monomial? = None
    let mut best_c : FieldElem? = None
    for m, c in f.coeffs {
      let mut ok = true
      for i in 0..<(n - 1) {
        if m.exps[i] < m.exps[i + 1] {
          ok = false
          break
        }
      }
      if !ok {
        continue
      }
      let mut height = 0
      for i in 0..<n {
        let candidate = weights[i] * m.exps[i]
        if candidate > height {
          height = candidate
        }
      }
      if height > best_height {
        best_height = height
        best_m = Some(m)
        best_c = Some(c)
      }
    }
    match (best_m, best_c) {
      (Some(m), Some(c)) => {
        let exps = Array::make(n, 0)
        for i in 0..<n {
          let next = if i + 1 < n { m.exps[i + 1] } else { 0 }
          exps.set(i, m.exps[i] - next)
        }
        let mono_sym = monomial_one(n)
        for i in 0..<n {
          mono_sym.exps.set(i, exps[i])
        }
        add_term(sym_poly.coeffs, mono_sym, c, poly.domain)
        let mut product = Poly::one(poly.gens, poly.domain)
        for i in 0..<n {
          let exp = exps[i]
          if exp > 0 {
            product = product.mul(elem_polys[i].pow(exp))
          }
        }
        product = product.scale_coeff(c)
        f = f.sub(product)
      }
      _ => break
    }
  }
  (sym_poly, f, elem_polys)
}

///|
fn horner_poly(poly : Poly, gens : Array[String]) -> @symcore.Expr raise PolyError {
  if poly.is_zero() {
    return @symcore.number(@symnum.BigRational::zero())
  }
  if gens.length() <= 1 {
    if gens.length() == 0 {
      return poly.to_expr()
    }
    let deg = poly.degree(0)
    let coeff_polys = univar_coeff_polys(poly, [])
    let sym = @symcore.symbol(gens[0])
    let mut form = coeff_polys[deg].to_expr()
    let mut d = deg - 1
    while d >= 0 {
      let term_expr = coeff_polys[d].to_expr()
      form = (form * sym) + term_expr
      d = d - 1
    }
    return form
  }
  let rest_gens : Array[String] = Array::new()
  for i in 1..<gens.length() {
    rest_gens.push(gens[i])
  }
  let deg = poly.degree(0)
  let coeff_polys = univar_coeff_polys(poly, rest_gens)
  let sym = @symcore.symbol(gens[0])
  let mut form = horner_poly(coeff_polys[deg], rest_gens)
  let mut d = deg - 1
  while d >= 0 {
    let term_expr = horner_poly(coeff_polys[d], rest_gens)
    form = (form * sym) + term_expr
    d = d - 1
  }
  form
}

///|
fn univar_coeff_polys(
  poly : Poly,
  rest_gens : Array[String],
) -> Array[Poly] raise PolyError {
  let deg = poly.degree(0)
  let coeffs : Array[Poly] = Array::new()
  for _ in 0..=deg {
    coeffs.push(Poly::zero(rest_gens, poly.domain))
  }
  for m, c in poly.coeffs {
    let exp0 = m.exps[0]
    let mono = monomial_one(rest_gens.length())
    for i in 0..<rest_gens.length() {
      mono.exps.set(i, m.exps[i + 1])
    }
    let target = coeffs[exp0]
    add_term(target.coeffs, mono, c, poly.domain)
  }
  coeffs
}

///|
fn univar_coeffs(poly : Poly) -> Array[FieldElem] raise PolyError {
  let deg = poly.degree(0)
  let coeffs : Array[FieldElem] = Array::new()
  for _ in 0..=deg {
    coeffs.push(fe_from_int(0, poly.domain))
  }
  for m, c in poly.coeffs {
    let exp0 = m.exps[0]
    coeffs.set(exp0, c)
  }
  coeffs
}

///|
fn elementary_sym_expr(roots : Array[String], k : Int) -> @symcore.Expr {
  let terms : Array[@symcore.Expr] = Array::new()
  build_sym_expr_terms(terms, roots, k, 0, [])
  if terms.is_empty() {
    @symcore.number(@symnum.BigRational::zero())
  } else if terms.length() == 1 {
    terms[0]
  } else {
    expr_add_all_pf(terms)
  }
}

///|
fn build_sym_expr_terms(
  terms : Array[@symcore.Expr],
  roots : Array[String],
  k : Int,
  start : Int,
  chosen : Array[String],
) -> Unit {
  if chosen.length() == k {
    let factors : Array[@symcore.Expr] = Array::new()
    for name in chosen {
      factors.push(@symcore.symbol(name))
    }
    let term = if factors.is_empty() {
      @symcore.number(@symnum.BigRational::one())
    } else if factors.length() == 1 {
      factors[0]
    } else {
      expr_mul_all_pf(factors)
    }
    terms.push(term)
    return
  }
  if start >= roots.length() {
    return
  }
  let next = chosen.copy()
  next.push(roots[start])
  build_sym_expr_terms(terms, roots, k, start + 1, next)
  build_sym_expr_terms(terms, roots, k, start + 1, chosen)
}

///|
fn field_elem_to_expr(
  fe : FieldElem,
  domain : Domain,
) -> @symcore.Expr raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  let mono = monomial_one(1)
  add_term(coeffs, mono, fe, domain)
  let poly = Poly::{ coeffs, gens: ["x"], domain, order: TermOrder::Lex }
  poly.to_expr()
}

///|
fn expr_mul_all_pf(args : Array[@symcore.Expr]) -> @symcore.Expr {
  let mut acc = args[0]
  for i in 1..<args.length() {
    acc = acc * args[i]
  }
  acc
}

///|
fn expr_add_all_pf(args : Array[@symcore.Expr]) -> @symcore.Expr {
  let mut acc = args[0]
  for i in 1..<args.length() {
    acc = acc + args[i]
  }
  acc
}
