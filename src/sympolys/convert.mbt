///|
pub fn Poly::to_expr_with_order(
  self : Poly,
  order : TermOrder,
) -> @symcore.Expr {
  let terms = self.coeffs.to_array()
  terms.sort_by((lhs, rhs) => compare_monomial_order(lhs.0, rhs.0, order))
  let expr_terms : Array[@symcore.Expr] = Array::new()
  for term in terms {
    let (m, c) = term
    let factors : Array[@symcore.Expr] = Array::new()
    let coeff_expr = fe_to_expr_const(c)
    if !fe_is_one(c) || is_monomial_zero(m) {
      factors.push(coeff_expr)
    }
    for i in 0..<m.exps.length() {
      let exp = m.exps[i]
      if exp == 0 {
        continue
      }
      let sym = @symcore.symbol(self.gens[i])
      let factor = if exp == 1 {
        sym
      } else {
        @symcore.pow(sym, @symcore.int(exp))
      }
      factors.push(factor)
    }
    let term_expr = if factors.is_empty() {
      @symcore.number(@symnum.BigRational::one())
    } else if factors.length() == 1 {
      factors[0]
    } else {
      @symcore.mul(factors)
    }
    expr_terms.push(term_expr)
  }
  if expr_terms.is_empty() {
    @symcore.number(@symnum.BigRational::zero())
  } else if expr_terms.length() == 1 {
    expr_terms[0]
  } else {
    @symcore.add(expr_terms)
  }
}

///|
pub fn Poly::to_expr(self : Poly) -> @symcore.Expr {
  Poly::to_expr_with_order(self, self.order)
}

///|
pub fn Poly::to_string(self : Poly, order? : TermOrder) -> String {
  let ord = match order {
    Some(o) => o
    None => self.order
  }
  @symprint.to_string(self.to_expr_with_order(ord))
}

///|
pub fn Poly::lc(self : Poly, order? : TermOrder) -> FieldElem raise PolyError {
  match self.leading_term_with_order(match order {
    Some(o) => o
    None => self.order
  }) {
    Some((_, c)) => c
    None => fe_from_int(0, self.domain)
  }
}

///|
pub fn Poly::lm(self : Poly, order? : TermOrder) -> Monomial? {
  match self.leading_term_with_order(match order {
    Some(o) => o
    None => self.order
  }) {
    Some((m, _)) => Some(m)
    None => None
  }
}

///|
pub fn Poly::lt(self : Poly, order? : TermOrder) -> (Monomial, FieldElem)? {
  let ord = match order {
    Some(o) => o
    None => self.order
  }
  self.leading_term_with_order(ord)
}

///|
fn fe_to_expr_const(c : FieldElem) -> @symcore.Expr {
  match c {
    FieldElem::QQ(r) => @symcore.number(r)
    FieldElem::CC(a, b) => {
      let i_sym = @symcore.symbol("I")
      let imag = if b.is_zero() {
        @symcore.number(@symnum.BigRational::zero())
      } else {
        @symcore.mul([@symcore.number(b), i_sym])
      }
      if a.is_zero() {
        imag
      } else if b.is_zero() {
        @symcore.number(a)
      } else {
        @symcore.add([@symcore.number(a), imag])
      }
    }
    FieldElem::GFp(_, v) => @symcore.number(@symnum.BigRational::from_int(v))
    FieldElem::GFExt(p, coeffs, mod_poly) => fe_ext_to_expr(p, coeffs, mod_poly)
    FieldElem::AlgExt(base, coeffs, minpoly, gen) =>
      fe_algext_to_expr(base, coeffs, minpoly, gen)
  }
}

///|
fn fe_ext_to_expr(
  p : Int,
  coeffs : Array[Int],
  mod_poly : Array[Int],
) -> @symcore.Expr {
  let alpha = @symcore.symbol(fe_ext_symbol_name(p, mod_poly))
  let terms : Array[@symcore.Expr] = Array::new()
  for i in 0..<coeffs.length() {
    let c = coeffs[i] % p
    if c == 0 {
      continue
    }
    let coeff_expr = @symcore.number(@symnum.BigRational::from_int(c))
    let term = if i == 0 {
      coeff_expr
    } else if i == 1 {
      if c == 1 {
        alpha
      } else {
        @symcore.mul([coeff_expr, alpha])
      }
    } else {
      let pow_expr = @symcore.pow(alpha, @symcore.int(i))
      if c == 1 {
        pow_expr
      } else {
        @symcore.mul([coeff_expr, pow_expr])
      }
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.number(@symnum.BigRational::zero())
  } else if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.add(terms)
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
) -> @symcore.Expr {
  let alpha = @symcore.symbol(gen)
  let terms : Array[@symcore.Expr] = Array::new()
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if fe_is_zero(c) {
      continue
    }
    let coeff_expr = fe_to_expr_const(fe_cast_to_base(c, base, minpoly, gen))
    let term = if i == 0 {
      coeff_expr
    } else {
      let pow_expr = @symcore.pow(alpha, @symcore.int(i))
      if fe_is_one(fe_cast_to_base(c, base, minpoly, gen)) {
        pow_expr
      } else {
        @symcore.mul([coeff_expr, pow_expr])
      }
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.number(@symnum.BigRational::zero())
  } else if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.add(terms)
  }
}

///|
fn fe_cast_to_base(
  c : FieldElem,
  base : Domain,
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
pub fn Poly::leading_term(self : Poly) -> (Monomial, FieldElem)? {
  self.leading_term_with_order(self.order)
}

///|
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
pub fn Poly::from_expr(
  expr : @symcore.Expr,
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
fn parse_expr(
  expr : @symcore.Expr,
  gens : Array[String],
  gen_index : Map[String, Int],
  domain : Domain,
) -> Poly raise PolyError {
  match expr {
    @symcore.Expr::Number(n) => {
      let coeff = ensure_coeff_domain(n, domain)
      let mono = monomial_one(gens.length())
      let coeffs : Map[Monomial, FieldElem] = Map::new()
      add_term(coeffs, mono, coeff, domain)
      Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
    }
    @symcore.Expr::Symbol(name) =>
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
    @symcore.Expr::Add(args) => {
      let mut acc = Poly::zero(gens, domain)
      for child in args {
        let parsed = parse_expr(child, gens, gen_index, domain)
        acc = acc.add(parsed)
      }
      acc
    }
    @symcore.Expr::Mul(args) => {
      let mut acc = Poly::one(gens, domain)
      for child in args {
        let parsed = parse_expr(child, gens, gen_index, domain)
        acc = acc.mul(parsed)
      }
      acc
    }
    @symcore.Expr::Pow(base, exp) => {
      let exp_num = match exp {
        @symcore.Expr::Number(r) => r
        _ => raise PolyError::BadExponent
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
