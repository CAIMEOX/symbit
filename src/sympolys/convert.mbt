///|
/// Convert a polynomial to an expression, sorting terms by `order`.
pub fn Poly::to_expr_with_order(self : Poly, order : TermOrder) -> Expr {
  let terms = self.coeffs.to_array()
  terms.sort_by((lhs, rhs) => compare_monomial_order(lhs.0, rhs.0, order))
  let expr_terms : Array[Expr] = Array::new()
  for term in terms {
    let (m, c) = term
    let factors : Array[Expr] = Array::new()
    let coeff_expr = fe_to_expr_const(c)
    if !fe_is_one(c) || is_monomial_zero(m) {
      factors.push(coeff_expr)
    }
    for i in 0..<m.exps.length() {
      let exp = m.exps[i]
      if exp == 0 {
        continue
      }
      let sym = Expr::Symbol(self.gens[i])
      let factor = if exp == 1 { sym } else { sym ^ int(exp) }
      factors.push(factor)
    }
    let term_expr = if factors.is_empty() {
      @symcore.Expr::Number(@symnum.BigRational::one())
    } else if factors.length() == 1 {
      factors[0]
    } else {
      expr_mul_all(factors)
    }
    expr_terms.push(term_expr)
  }
  if expr_terms.is_empty() {
    @symcore.Expr::Number(@symnum.BigRational::zero())
  } else if expr_terms.length() == 1 {
    expr_terms[0]
  } else {
    expr_add_all(expr_terms)
  }
}

///|
/// Convert a polynomial to an expression using its stored term order.
pub fn Poly::to_expr(self : Poly) -> Expr {
  Poly::to_expr_with_order(self, self.order)
}

///|
/// Return the string form of the polynomial expression.
pub fn Poly::to_string(self : Poly, order? : TermOrder) -> String {
  let ord = match order {
    Some(o) => o
    None => self.order
  }
  @symprint.to_string(self.to_expr_with_order(ord))
}

///|
/// Return the leading coefficient of `self`.
pub fn Poly::lc(self : Poly, order? : TermOrder) -> FieldElem raise PolyError {
  match
    self.leading_term_with_order(
      match order {
        Some(o) => o
        None => self.order
      },
    ) {
    Some((_, c)) => c
    None => fe_from_int(0, self.domain)
  }
}

///|
/// Return the leading monomial of `self`.
pub fn Poly::lm(self : Poly, order? : TermOrder) -> Monomial? {
  match
    self.leading_term_with_order(
      match order {
        Some(o) => o
        None => self.order
      },
    ) {
    Some((m, _)) => Some(m)
    None => None
  }
}

///|
/// Return the leading term `(monomial, coefficient)` of `self`.
pub fn Poly::lt(self : Poly, order? : TermOrder) -> (Monomial, FieldElem)? {
  let ord = match order {
    Some(o) => o
    None => self.order
  }
  self.leading_term_with_order(ord)
}

///|
fn fe_to_expr_const(c : FieldElem) -> Expr {
  match c {
    FieldElem::QQ(r) => @symcore.Expr::Number(r)
    FieldElem::CC(a, b) => {
      let i_sym = @symcore.Expr::NumberSymbol(
        @symcore.NumberSymbolKind::ImaginaryUnit,
      )
      let imag = if b.is_zero() {
        @symcore.Expr::Number(@symnum.BigRational::zero())
      } else {
        @symcore.Expr::Number(b) * i_sym
      }
      if a.is_zero() {
        imag
      } else if b.is_zero() {
        @symcore.Expr::Number(a)
      } else {
        @symcore.Expr::Number(a) + imag
      }
    }
    FieldElem::GFp(_, v) =>
      @symcore.Expr::Number(@symnum.BigRational::from_int(v))
    FieldElem::GFExt(p, coeffs, mod_poly) => fe_ext_to_expr(p, coeffs, mod_poly)
    FieldElem::AlgExt(base, coeffs, minpoly, gen) =>
      fe_algext_to_expr(base, coeffs, minpoly, gen)
  }
}

///|
fn fe_ext_to_expr(p : Int, coeffs : Array[Int], mod_poly : Array[Int]) -> Expr {
  let alpha = Expr::Symbol(fe_ext_symbol_name(p, mod_poly))
  let terms : Array[Expr] = Array::new()
  for i in 0..<coeffs.length() {
    let c = coeffs[i] % p
    if c == 0 {
      continue
    }
    let coeff_expr = @symcore.Expr::Number(@symnum.BigRational::from_int(c))
    let term = if i == 0 {
      coeff_expr
    } else if i == 1 {
      if c == 1 {
        alpha
      } else {
        coeff_expr * alpha
      }
    } else {
      let pow_expr = alpha ^ int(i)
      if c == 1 {
        pow_expr
      } else {
        coeff_expr * pow_expr
      }
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.Expr::Number(@symnum.BigRational::zero())
  } else if terms.length() == 1 {
    terms[0]
  } else {
    expr_add_all(terms)
  }
}

///|
fn fe_ext_symbol_name(p : Int, mod_poly : Array[Int]) -> String {
  let sb = StringBuilder::new()
  sb.write_string("alpha_p")
  sb.write_string(p.to_string())
  sb.write_string("_m")
  for i in 0..<mod_poly.length() {
    if i > 0 {
      sb.write_char('_')
    }
    sb.write_string(mod_poly[i].to_string())
  }
  sb.to_string()
}

///|
fn fe_algext_to_expr(
  base : Domain,
  coeffs : Array[FieldElem],
  minpoly : Poly,
  gen : String,
) -> Expr {
  let alpha = Expr::Symbol(gen)
  let terms : Array[Expr] = Array::new()
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if fe_is_zero(c) {
      continue
    }
    let coeff_expr = fe_to_expr_const(fe_cast_to_base(c, base, minpoly, gen))
    let term = if i == 0 {
      coeff_expr
    } else {
      let pow_expr = alpha ^ int(i)
      if fe_is_one(fe_cast_to_base(c, base, minpoly, gen)) {
        pow_expr
      } else {
        coeff_expr * pow_expr
      }
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.Expr::Number(@symnum.BigRational::zero())
  } else if terms.length() == 1 {
    terms[0]
  } else {
    expr_add_all(terms)
  }
}

///|
fn expr_mul_all(args : Array[Expr]) -> Expr {
  let mut acc = args[0]
  for i in 1..<args.length() {
    acc = acc * args[i]
  }
  acc
}

///|
fn expr_add_all(args : Array[Expr]) -> Expr {
  let mut acc = args[0]
  for i in 1..<args.length() {
    acc = acc + args[i]
  }
  acc
}

///|
fn fe_cast_to_base(
  c : FieldElem,
  _base : Domain,
  _minpoly : Poly,
  _gen : String,
) -> FieldElem {
  // Elements in the coeff array should already live in the base domain.
  match c {
    FieldElem::AlgExt(_, _, _, _) => c
    _ => c
  }
}

///|
pub impl Show for Poly with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn is_monomial_zero(m : Monomial) -> Bool {
  m.exps.all(e => e == 0)
}

///|
/// Return the degree of `self` in generator `gen_index`.
pub fn Poly::degree(self : Poly, gen_index : Int) -> Int {
  let mut max_deg = 0
  for m, _ in self.coeffs {
    if gen_index < m.exps.length() && m.exps[gen_index] > max_deg {
      max_deg = m.exps[gen_index]
    }
  }
  max_deg
}

///|
/// Return the total degree of `self`.
pub fn Poly::total_degree(self : Poly) -> Int {
  let mut max_deg = 0
  for m, _ in self.coeffs {
    let sum = m.exps.fold(init=0, (acc, v) => acc + v)
    if sum > max_deg {
      max_deg = sum
    }
  }
  max_deg
}

///|
/// Return the leading term under `self.order`.
pub fn Poly::leading_term(self : Poly) -> (Monomial, FieldElem)? {
  self.leading_term_with_order(self.order)
}

///|
/// Return the leading term under the specified monomial order.
pub fn Poly::leading_term_with_order(
  self : Poly,
  order : TermOrder,
) -> (Monomial, FieldElem)? {
  let mut best : (Monomial, FieldElem)? = None
  for m, c in self.coeffs {
    match best {
      None => best = Some((m, c))
      Some((bm, _)) =>
        if compare_monomial_order(m, bm, order) > 0 {
          best = Some((m, c))
        }
    }
  }
  match best {
    Some((m, c)) => Some((m, c))
    None => None
  }
}

///|
/// Build a polynomial from an expression over `gens` and `domain`.
pub fn Poly::from_expr(
  expr : Expr,
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  let gen_index = build_gen_index(gens)
  parse_expr(expr, gens, gen_index, domain)
}

///|
fn build_gen_index(gens : Array[String]) -> Map[String, Int] {
  let index : Map[String, Int] = Map::new()
  for i in 0..<gens.length() {
    index.set(gens[i], i)
  }
  index
}

///|
fn expr_coeff_rational_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    Expr::Float(f) =>
      if !f.is_finite() {
        None
      } else {
        let pair_res : Result[(BigInt, BigInt), @symnum.MpfError] = try? f.to_rational()
        match pair_res {
          Ok((num, den)) => {
            let rat_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
              num, den,
            )
            match rat_res {
              Ok(value) => Some(value)
              Err(_) => None
            }
          }
          Err(_) => None
        }
      }
    Expr::ComplexFloat(z) =>
      if !z.is_finite() || !@symnum.is_zero(z.to_mpc().imag) {
        None
      } else {
        let pair_res : Result[(BigInt, BigInt), @symnum.MpfError] = try? z
          .real_part()
          .to_rational()
        match pair_res {
          Ok((num, den)) =>
            match
              (
                try? @symnum.BigRational::new(num, den) :
                Result[@symnum.BigRational, @symnum.RationalError]) {
              Ok(value) => Some(value)
              Err(_) => None
            }
          Err(_) => None
        }
      }
    _ => None
  }
}

///|
fn expr_coeff_field_elem_value(expr : Expr, domain : Domain) -> FieldElem? {
  match expr {
    Expr::ComplexFloat(z) =>
      if !z.is_finite() {
        None
      } else {
        let pair_res : Result[
          ((BigInt, BigInt), (BigInt, BigInt)),
          @symnum.MpfError,
        ] = try? z.to_rational_parts()
        match pair_res {
          Ok((re_pair, im_pair)) => {
            let real_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
              re_pair.0,
              re_pair.1,
            )
            let imag_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
              im_pair.0,
              im_pair.1,
            )
            match (real_res, imag_res) {
              (Ok(real), Ok(imag)) =>
                match domain {
                  Domain::CC => Some(FieldElem::CC(real, imag))
                  Domain::RR if imag.is_zero() =>
                    Some(
                      ensure_coeff_domain(real, domain) catch {
                        _ => return None
                      },
                    )
                  _ => None
                }
              _ => None
            }
          }
          Err(_) => None
        }
      }
    _ =>
      match expr_coeff_rational_value(expr) {
        Some(value) =>
          Some(ensure_coeff_domain(value, domain) catch { _ => return None })
        None => None
      }
  }
}

///|
fn parse_expr(
  expr : Expr,
  gens : Array[String],
  gen_index : Map[String, Int],
  domain : Domain,
) -> Poly raise PolyError {
  match expr {
    Expr::Number(_) | Expr::Float(_) | Expr::ComplexFloat(_) => {
      let coeff = match expr_coeff_field_elem_value(expr, domain) {
        Some(value) => value
        None => raise PolyError::NonPolynomial
      }
      let mono = monomial_one(gens.length())
      let coeffs : Map[Monomial, FieldElem] = Map::new()
      add_term(coeffs, mono, coeff, domain)
      Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
    }
    Expr::Symbol(name) =>
      match gen_index.get(name) {
        Some(idx) => {
          let mono = monomial_one(gens.length())
          mono.exps.set(idx, 1)
          let coeffs : Map[Monomial, FieldElem] = Map::new()
          add_term(coeffs, mono, fe_from_int(1, domain), domain)
          Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
        }
        None => raise PolyError::BadGenerator(name)
      }
    Expr::Add(args) => {
      let mut acc = Poly::zero(gens, domain)
      for child in args {
        let parsed = parse_expr(child, gens, gen_index, domain)
        acc = acc.add(parsed)
      }
      acc
    }
    Expr::Mul(args) => {
      let mut acc = Poly::one(gens, domain)
      for child in args {
        let parsed = parse_expr(child, gens, gen_index, domain)
        acc = acc.mul(parsed)
      }
      acc
    }
    Expr::Pow(base, exp) => {
      let exp_num = match expr_coeff_rational_value(exp) {
        Some(value) => value
        None => raise PolyError::BadExponent
      }
      if !exp_num.is_integral() {
        raise PolyError::BadExponent
      }
      let exp_int = exp_num.numerator().to_int()
      if exp_int < 0 {
        raise PolyError::BadExponent
      }
      let base_poly = parse_expr(base, gens, gen_index, domain)
      let mut acc = Poly::one(gens, domain)
      for _ in 0..<exp_int {
        acc = acc.mul(base_poly)
      }
      acc
    }
    _ => raise PolyError::NonPolynomial
  }
}
