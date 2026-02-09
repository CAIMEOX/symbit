///|
/// Discrete (countable) distributions beyond finite support.

///|
pub fn binomial(name : String, n : @symcore.Expr, p : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Binomial(n~, p~))
}

///|
pub fn poisson(name : String, rate : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Poisson(rate~))
}

///|
pub fn geometric(name : String, p : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Geometric(p~))
}

///|
pub fn negative_binomial(
  name : String,
  r : @symcore.Expr,
  p : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::NegativeBinomial(r~, p~))
}

///|
fn discrete_expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.add([a, @symcore.mul([@symcore.int(-1), b])])
}

///|
fn discrete_one_minus(x : @symcore.Expr) -> @symcore.Expr {
  discrete_expr_sub(@symcore.int(1), x)
}

///|
fn discrete_tuple_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function("Tuple", items)
}

///|
fn discrete_tuple_matrix(rows : Array[Array[@symcore.Expr]]) -> @symcore.Expr {
  discrete_tuple_expr(rows.map(row => discrete_tuple_expr(row)))
}

///|
fn discrete_tuple_items(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function("Tuple", items) => Some(items)
    _ => None
  }
}

fn binomial_bigint(n : Int, k : Int) -> BigInt {
  if k < 0 || k > n {
    return BigInt::from_int(0)
  }
  let kk = if k > (n - k) { n - k } else { k }
  let mut num = BigInt::from_int(1)
  let mut den = BigInt::from_int(1)
  for i in 1..=kk {
    num = num.mul(BigInt::from_int(n - kk + i))
    den = den.mul(BigInt::from_int(i))
  }
  num.div(den)
}

///|
fn expr_from_bigint(v : BigInt) -> @symcore.Expr {
  expr_from_big_rational(@symnum.BigRational::from_bigint(v))
}

///|
fn discrete_extract_rel_to_var(
  event : Event,
  var_name : String,
) -> (RelOp, @symcore.Expr)? {
  let x = @symcore.symbol(var_name)
  match event {
    Event::Rel(op~, lhs~, rhs~) =>
      if @symcore.compare_expr(lhs, x) == 0 {
        Some((op, rhs))
      } else if @symcore.compare_expr(rhs, x) == 0 {
        Some((invert_relop(op), lhs))
      } else {
        None
      }
    _ => None
  }
}

///|
fn binomial_pmf_expr(
  n : @symcore.Expr,
  p : @symcore.Expr,
  k : @symcore.Expr,
) -> @symcore.Expr {
  match (expr_as_int(n), expr_as_number(p), expr_as_int(k)) {
    (Some(ni), Some(_pn), Some(ki)) if 0 <= ki && ki <= ni => {
      let choose = expr_from_bigint(binomial_bigint(ni, ki))
      eval_arith(@symcore.mul([
        choose,
        @symcore.pow(p, k),
        @symcore.pow(discrete_one_minus(p), eval_arith(discrete_expr_sub(n, k))),
      ]))
    }
    (Some(ni), _, Some(ki)) if ki < 0 || ki > ni => @symcore.int(0)
    _ =>
      eval_arith(@symcore.mul([
        @symcore.function("binomial", [n, k]),
        @symcore.pow(p, k),
        @symcore.pow(discrete_one_minus(p), eval_arith(discrete_expr_sub(n, k))),
      ]))
  }
}

///|
fn binomial_cdf_expr(
  n : @symcore.Expr,
  p : @symcore.Expr,
  k : @symcore.Expr,
) -> @symcore.Expr {
  match (expr_as_int(n), expr_as_int(k)) {
    (Some(ni), Some(ki)) => {
      if ki < 0 {
        return @symcore.int(0)
      }
      if ki >= ni {
        return @symcore.int(1)
      }
      let terms : Array[@symcore.Expr] = Array::new()
      for i in 0..=ki {
        terms.push(binomial_pmf_expr(n, p, @symcore.int(i)))
      }
      eval_arith(@symcore.add(terms))
    }
    _ => @symcore.function("binomial_cdf", [n, p, k])
  }
}

///|
fn poisson_pmf_expr(rate : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match expr_as_int(k) {
    Some(ki) if ki < 0 => @symcore.int(0)
    _ =>
      eval_arith(@symcore.mul([
        @symcore.function("exp", [@symcore.mul([@symcore.int(-1), rate])]),
        @symcore.pow(rate, k),
        @symcore.pow(@symcore.function("factorial", [k]), @symcore.int(-1)),
      ]))
  }
}

///|
fn poisson_cdf_expr(rate : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("poisson_cdf", [rate, k])
}

///|
fn geometric_pmf_expr(p : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match expr_as_int(k) {
    Some(ki) if ki < 1 => @symcore.int(0)
    _ =>
      eval_arith(@symcore.mul([
        @symcore.pow(
          discrete_one_minus(p),
          eval_arith(discrete_expr_sub(k, @symcore.int(1))),
        ),
        p,
      ]))
  }
}

///|
fn geometric_cdf_expr(p : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match expr_as_int(k) {
    Some(ki) if ki < 1 => @symcore.int(0)
    _ =>
      eval_arith(discrete_expr_sub(
        @symcore.int(1),
        @symcore.pow(discrete_one_minus(p), k),
      ))
  }
}

///|
fn negative_binomial_pmf_expr(
  r : @symcore.Expr,
  p : @symcore.Expr,
  k : @symcore.Expr,
) -> @symcore.Expr {
  match expr_as_int(k) {
    Some(ki) if ki < 0 => @symcore.int(0)
    _ =>
      eval_arith(@symcore.mul([
        @symcore.function(
          "binomial",
          [eval_arith(discrete_expr_sub(@symcore.add([k, r]), @symcore.int(1))), k],
        ),
        @symcore.pow(discrete_one_minus(p), k),
        @symcore.pow(p, r),
      ]))
  }
}

///|
fn negative_binomial_cdf_expr(
  r : @symcore.Expr,
  p : @symcore.Expr,
  k : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("negative_binomial_cdf", [r, p, k])
}

///|
fn symbolic_discrete_expr(
  name : String,
  suffix : String,
  params : Array[@symcore.Expr],
  k? : @symcore.Expr,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = Array::new()
  match k {
    Some(v) => args.push(v)
    None => ()
  }
  for p in params {
    args.push(p)
  }
  @symcore.function("\{name}\{suffix}", args)
}

///|
fn symbolic_discrete_generated_pmf(
  name : String,
  params : Array[@symcore.Expr],
  k : @symcore.Expr,
) -> @symcore.Expr? {
  match generated_pmf(name, params, k) {
    Some(v) => Some(v)
    None => generated_density(name, params, k)
  }
}

///|
fn symbolic_discrete_cdf_by_pmf_sum(
  name : String,
  params : Array[@symcore.Expr],
  k : @symcore.Expr,
) -> @symcore.Expr? {
  match expr_as_int(k) {
    Some(ki) => {
      if ki < 0 {
        return Some(@symcore.int(0))
      }
      let upper =
        match name {
          "BetaBinomial" if params.length() == 3 =>
            match expr_as_int(params[0]) {
              Some(n) => if ki > n { n } else { ki }
              None => ki
            }
          _ => ki
        }
      let terms : Array[@symcore.Expr] = Array::new()
      for i in 0..=upper {
        match symbolic_discrete_generated_pmf(name, params, @symcore.int(i)) {
          Some(v) => terms.push(v)
          None => return None
        }
      }
      if terms.is_empty() {
        Some(@symcore.int(0))
      } else {
        Some(eval_arith(@symcore.add(terms)))
      }
    }
    None => None
  }
}

///|
pub fn discrete_pmf(rv : RandomVar, k : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_pmf(rv, k)
    RVKind::Binomial(n~, p~) => Some(binomial_pmf_expr(n, p, k))
    RVKind::Poisson(rate~) => Some(poisson_pmf_expr(rate, k))
    RVKind::Geometric(p~) => Some(geometric_pmf_expr(p, k))
    RVKind::NegativeBinomial(r~, p~) => Some(negative_binomial_pmf_expr(r, p, k))
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        if name == "Multinomial" && params.length() >= 2 {
          match discrete_tuple_items(k) {
            Some(ks) if ks.length() == params.length() - 1 => {
              let n = params[0]
              let body_terms : Array[@symcore.Expr] = [@symcore.function("factorial", [n])]
              let sum_terms : Array[@symcore.Expr] = Array::new()
              for i in 0..<ks.length() {
                let ki = ks[i]
                sum_terms.push(ki)
                body_terms.push(@symcore.pow(@symcore.function("factorial", [ki]), @symcore.int(-1)))
                body_terms.push(@symcore.pow(params[i + 1], ki))
              }
              let sum_k =
                if sum_terms.is_empty() {
                  @symcore.int(0)
                } else {
                  eval_arith(@symcore.add(sum_terms))
                }
              let body = eval_arith(@symcore.mul(body_terms))
              return Some(@symcore.function("Piecewise", [
                discrete_tuple_expr([body, @symcore.function("Eq", [sum_k, n])]),
                discrete_tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
              ]))
            }
            _ => ()
          }
        }
        if name == "NegativeMultinomial" && params.length() >= 2 {
          match discrete_tuple_items(k) {
            Some(ks) if ks.length() == params.length() - 1 => {
              let k0 = params[0]
              let sum_k =
                if ks.is_empty() {
                  @symcore.int(0)
                } else {
                  eval_arith(@symcore.add(ks))
                }
              let ps : Array[@symcore.Expr] = Array::new()
              for i in 1..<params.length() {
                ps.push(params[i])
              }
              let q = eval_arith(@symcore.add([
                @symcore.int(1),
                @symcore.mul([@symcore.int(-1), eval_arith(@symcore.add(ps))]),
              ]))
              let term_1 = eval_arith(@symcore.mul([
                @symcore.function("gamma", [eval_arith(@symcore.add([k0, sum_k]))]),
                @symcore.pow(@symcore.function("gamma", [k0]), @symcore.int(-1)),
                @symcore.pow(q, k0),
              ]))
              let term_2_factors : Array[@symcore.Expr] = Array::new()
              for i in 0..<ks.length() {
                let ki = ks[i]
                term_2_factors.push(eval_arith(@symcore.mul([
                  @symcore.pow(params[i + 1], ki),
                  @symcore.pow(@symcore.function("factorial", [ki]), @symcore.int(-1)),
                ])))
              }
              let term_2 =
                if term_2_factors.is_empty() {
                  @symcore.int(1)
                } else {
                  eval_arith(@symcore.mul(term_2_factors))
                }
              return Some(eval_arith(@symcore.mul([term_1, term_2])))
            }
            _ => ()
          }
        }
        match symbolic_discrete_generated_pmf(name, params, k) {
          Some(v) => Some(v)
          None => Some(symbolic_discrete_expr(name, "PMF", params, k=k))
        }
      }
    }
    _ => None
  }
}

///|
pub fn discrete_cdf(rv : RandomVar, k : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(items) => {
      let mut total = @symnum.BigRational::zero()
      for item in items {
        let (value, p) = item
        match (expr_as_number(eval_arith(value)), expr_as_number(eval_arith(k))) {
          (Some(vn), Some(kn)) if vn.compare(kn) <= 0 => total = total.add_r(p)
          _ => ()
        }
      }
      Some(expr_from_big_rational(total))
    }
    RVKind::Binomial(n~, p~) => Some(binomial_cdf_expr(n, p, k))
    RVKind::Poisson(rate~) => Some(poisson_cdf_expr(rate, k))
    RVKind::Geometric(p~) => Some(geometric_cdf_expr(p, k))
    RVKind::NegativeBinomial(r~, p~) =>
      Some(negative_binomial_cdf_expr(r, p, k))
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_cdf(name, params, k) {
          Some(v) => Some(v)
          None =>
            match symbolic_discrete_cdf_by_pmf_sum(name, params, k) {
              Some(v) => Some(v)
              None => Some(symbolic_discrete_expr(name, "CDF", params, k=k))
            }
        }
      }
    }
    _ => None
  }
}

///|
pub fn discrete_probability(rv : RandomVar, event : Event) -> @symcore.Expr? {
  if !event_depends_only_on(event, rv.name) {
    return None
  }
  match rv.kind {
    RVKind::Finite(_) => finite_probability(rv, event)
    _ =>
      match event {
        Event::Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
        Event::Not(inner) =>
          match discrete_probability(rv, inner) {
            Some(inner_p) => Some(eval_arith(discrete_expr_sub(@symcore.int(1), inner_p)))
            None => None
          }
        Event::Rel(..) =>
          match discrete_extract_rel_to_var(event, rv.name) {
            Some((op, k)) =>
              match op {
                RelOp::Eq => discrete_pmf(rv, k)
                RelOp::Ne =>
                  match discrete_pmf(rv, k) {
                    Some(pmf) => Some(eval_arith(discrete_expr_sub(@symcore.int(1), pmf)))
                    None => None
                  }
                RelOp::Le => discrete_cdf(rv, k)
                RelOp::Lt =>
                  discrete_cdf(rv, eval_arith(discrete_expr_sub(k, @symcore.int(1))))
                RelOp::Ge =>
                  match discrete_cdf(
                    rv,
                    eval_arith(discrete_expr_sub(k, @symcore.int(1))),
                  ) {
                    Some(cdf) =>
                      Some(eval_arith(discrete_expr_sub(@symcore.int(1), cdf)))
                    None => None
                  }
                RelOp::Gt =>
                  match discrete_cdf(rv, k) {
                    Some(cdf) =>
                      Some(eval_arith(discrete_expr_sub(@symcore.int(1), cdf)))
                    None => None
                  }
              }
            None => None
          }
        _ => None
      }
  }
}

///|
pub fn discrete_mean(rv : RandomVar) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_expectation(rv)
    RVKind::Binomial(n~, p~) => Some(eval_arith(@symcore.mul([n, p])))
    RVKind::Poisson(rate~) => Some(rate)
    RVKind::Geometric(p~) => Some(eval_arith(@symcore.pow(p, @symcore.int(-1))))
    RVKind::NegativeBinomial(r~, p~) =>
      Some(
        eval_arith(
          @symcore.mul([r, discrete_one_minus(p), @symcore.pow(p, @symcore.int(-1))]),
        ),
      )
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_mean(name, params) {
          Some(v) => Some(v)
          None =>
            match name {
              "Multinomial" if params.length() >= 2 => {
                let n = params[0]
                let means : Array[@symcore.Expr] = Array::new()
                for i in 1..<params.length() {
                  means.push(eval_arith(@symcore.mul([n, params[i]])))
                }
                Some(discrete_tuple_expr(means))
              }
              "NegativeMultinomial" if params.length() >= 2 => {
                let k0 = params[0]
                let probs : Array[@symcore.Expr] = Array::new()
                for i in 1..<params.length() {
                  probs.push(params[i])
                }
                let q = eval_arith(@symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), eval_arith(@symcore.add(probs))]),
                ]))
                let means = probs.map(pi =>
                  eval_arith(@symcore.mul([
                    k0,
                    pi,
                    @symcore.pow(q, @symcore.int(-1)),
                  ]))
                )
                Some(discrete_tuple_expr(means))
              }
              "BetaBinomial" if params.length() == 3 =>
                Some(eval_arith(@symcore.mul([
                  params[0],
                  params[1],
                  @symcore.pow(eval_arith(@symcore.add([params[1], params[2]])), @symcore.int(-1)),
                ])))
              "Hypergeometric" if params.length() == 3 =>
                Some(eval_arith(@symcore.mul([
                  params[2],
                  params[1],
                  @symcore.pow(params[0], @symcore.int(-1)),
                ])))
              _ => Some(symbolic_discrete_expr(name, "Mean", params))
            }
        }
      }
    }
    _ => None
  }
}

///|
pub fn discrete_variance(rv : RandomVar) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_variance(rv)
    RVKind::Binomial(n~, p~) =>
      Some(eval_arith(@symcore.mul([n, p, discrete_one_minus(p)])))
    RVKind::Poisson(rate~) => Some(rate)
    RVKind::Geometric(p~) =>
      Some(eval_arith(@symcore.mul([
        discrete_one_minus(p),
        @symcore.pow(p, @symcore.int(-2)),
      ])))
    RVKind::NegativeBinomial(r~, p~) =>
      Some(eval_arith(@symcore.mul([
        r,
        discrete_one_minus(p),
        @symcore.pow(p, @symcore.int(-2)),
      ])))
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_variance(name, params) {
          Some(v) => Some(v)
          None =>
            match name {
              "Multinomial" if params.length() >= 2 => {
                let n = params[0]
                let ps : Array[@symcore.Expr] = Array::new()
                for i in 1..<params.length() {
                  ps.push(params[i])
                }
                let rows : Array[Array[@symcore.Expr]] = Array::new()
                for i in 0..<ps.length() {
                  let row : Array[@symcore.Expr] = Array::new()
                  let pi = ps[i]
                  for j in 0..<ps.length() {
                    let pj = ps[j]
                    if i == j {
                      row.push(eval_arith(@symcore.mul([
                        n,
                        pi,
                        discrete_one_minus(pi),
                      ])))
                    } else {
                      row.push(eval_arith(@symcore.mul([
                        @symcore.int(-1),
                        n,
                        pi,
                        pj,
                      ])))
                    }
                  }
                  rows.push(row)
                }
                Some(discrete_tuple_matrix(rows))
              }
              "NegativeMultinomial" if params.length() >= 2 => {
                let k0 = params[0]
                let ps : Array[@symcore.Expr] = Array::new()
                for i in 1..<params.length() {
                  ps.push(params[i])
                }
                let q = eval_arith(@symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), eval_arith(@symcore.add(ps))]),
                ]))
                let rows : Array[Array[@symcore.Expr]] = Array::new()
                for i in 0..<ps.length() {
                  let row : Array[@symcore.Expr] = Array::new()
                  let pi = ps[i]
                  for j in 0..<ps.length() {
                    let pj = ps[j]
                    if i == j {
                      row.push(eval_arith(@symcore.mul([
                        k0,
                        pi,
                        eval_arith(@symcore.add([q, pi])),
                        @symcore.pow(q, @symcore.int(-2)),
                      ])))
                    } else {
                      row.push(eval_arith(@symcore.mul([
                        k0,
                        pi,
                        pj,
                        @symcore.pow(q, @symcore.int(-2)),
                      ])))
                    }
                  }
                  rows.push(row)
                }
                Some(discrete_tuple_matrix(rows))
              }
              "BetaBinomial" if params.length() == 3 => {
                let n = params[0]
                let alpha = params[1]
                let beta = params[2]
                let ab = eval_arith(@symcore.add([alpha, beta]))
                Some(eval_arith(@symcore.mul([
                  n,
                  alpha,
                  beta,
                  eval_arith(@symcore.add([ab, n])),
                  @symcore.pow(ab, @symcore.int(-2)),
                  @symcore.pow(eval_arith(@symcore.add([ab, @symcore.int(1)])), @symcore.int(-1)),
                ])))
              }
              "Hypergeometric" if params.length() == 3 => {
                let population = params[0]
                let success = params[1]
                let draws = params[2]
                let p = eval_arith(@symcore.mul([
                  success,
                  @symcore.pow(population, @symcore.int(-1)),
                ]))
                Some(eval_arith(@symcore.mul([
                  draws,
                  p,
                  eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])])),
                  eval_arith(@symcore.add([population, @symcore.mul([@symcore.int(-1), draws])])),
                  @symcore.pow(eval_arith(@symcore.add([population, @symcore.int(-1)])), @symcore.int(-1)),
                ])))
              }
              _ => Some(symbolic_discrete_expr(name, "Variance", params))
            }
        }
      }
    }
    _ => None
  }
}
