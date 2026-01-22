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
    if !c.is_one() || is_monomial_zero(m) {
      factors.push(@symcore.number(c))
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
pub fn Poly::leading_term(self : Poly) -> (Monomial, @symnum.BigRational)? {
  let mut best : (Monomial, @symnum.BigRational)? = None
  for m, c in self.coeffs {
    match best {
      None => best = Some((m, c))
      Some((bm, _)) =>
        if compare_monomial_order(m, bm, self.order) > 0 {
          best = Some((m, c))
        }
    }
  }
  best
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
      let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
      add_term(coeffs, mono, coeff, domain)
      Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
    }
    @symcore.Expr::Symbol(name) =>
      match gen_index.get(name) {
        Some(idx) => {
          let mono = monomial_one(gens.length())
          mono.exps.set(idx, 1)
          let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
          add_term(coeffs, mono, @symnum.BigRational::one(), domain)
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
