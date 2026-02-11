///|
/// Discrete (countable) distributions beyond finite support.

///|
pub fn binomial(
  name : String,
  n : @symcore.Expr,
  p : @symcore.Expr,
) -> RandomVar {
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

///|
fn binomial_bigint(n : Int, k : Int) -> BigInt {
  if k < 0 || k > n {
    return BigInt::from_int(0)
  }
  let kk = if k > n - k { n - k } else { k }
  let mut num = BigInt::from_int(1)
  let mut den = BigInt::from_int(1)
  for i in 1..<=kk {
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
      eval_arith(
        @symcore.mul([
          choose,
          @symcore.pow(p, k),
          @symcore.pow(
            discrete_one_minus(p),
            eval_arith(discrete_expr_sub(n, k)),
          ),
        ]),
      )
    }
    (Some(ni), _, Some(ki)) if ki < 0 || ki > ni => @symcore.int(0)
    _ =>
      eval_arith(
        @symcore.mul([
          @symcore.function("binomial", [n, k]),
          @symcore.pow(p, k),
          @symcore.pow(
            discrete_one_minus(p),
            eval_arith(discrete_expr_sub(n, k)),
          ),
        ]),
      )
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
      for i in 0..<=ki {
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
      eval_arith(
        @symcore.mul([
          @symcore.function("exp", [@symcore.mul([@symcore.int(-1), rate])]),
          @symcore.pow(rate, k),
          @symcore.pow(@symcore.function("factorial", [k]), @symcore.int(-1)),
        ]),
      )
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
      eval_arith(
        @symcore.mul([
          @symcore.pow(
            discrete_one_minus(p),
            eval_arith(discrete_expr_sub(k, @symcore.int(1))),
          ),
          p,
        ]),
      )
  }
}

///|
fn geometric_cdf_expr(p : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  match expr_as_int(k) {
    Some(ki) if ki < 1 => @symcore.int(0)
    _ =>
      eval_arith(
        discrete_expr_sub(
          @symcore.int(1),
          @symcore.pow(discrete_one_minus(p), k),
        ),
      )
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
      eval_arith(
        @symcore.mul([
          @symcore.function("binomial", [
            eval_arith(discrete_expr_sub(@symcore.add([k, r]), @symcore.int(1))),
            k,
          ]),
          @symcore.pow(discrete_one_minus(p), k),
          @symcore.pow(p, r),
        ]),
      )
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
      let upper = match name {
        "BetaBinomial" if params.length() == 3 =>
          match expr_as_int(params[0]) {
            Some(n) => if ki > n { n } else { ki }
            None => ki
          }
        _ => ki
      }
      let terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<=upper {
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
fn symbolic_discrete_pmf_for(
  name : String,
  params : Array[@symcore.Expr],
  k : @symcore.Expr,
) -> @symcore.Expr? {
  let tag = "D:\{name}"
  let rv = random_var("_X", RVKind::Symbolic(tag~, params~))
  discrete_pmf(rv, k)
}

///|
fn symbolic_discrete_joint_box_cdf(
  name : String,
  params : Array[@symcore.Expr],
  k : @symcore.Expr,
) -> @symcore.Expr? {
  match discrete_tuple_items(k) {
    Some(bounds) if !bounds.is_empty() => {
      let indices : Array[@symcore.Expr] = Array::new()
      let uppers : Array[@symcore.Expr] = Array::new()
      let guard_terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<bounds.length() {
        indices.push(@symcore.symbol("_k\{i + 1}"))
        uppers.push(@symcore.function("floor", [bounds[i]]))
        guard_terms.push(@symcore.function("Ge", [bounds[i], @symcore.int(0)]))
      }
      let cond = if guard_terms.is_empty() {
        @symcore.symbol("True")
      } else {
        @symcore.function("And", guard_terms)
      }
      let point = discrete_tuple_expr(indices)
      match symbolic_discrete_pmf_for(name, params, point) {
        Some(pmf) => {
          let mut sum_expr = pmf
          for i in 0..<indices.length() {
            sum_expr = @symcore.function("Sum", [
              sum_expr,
              discrete_tuple_expr([indices[i], @symcore.int(0), uppers[i]]),
            ])
          }
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([sum_expr, cond]),
              discrete_tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
            ]),
          )
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn symbolic_discrete_cdf_formula(
  name : String,
  params : Array[@symcore.Expr],
  k : @symcore.Expr,
) -> @symcore.Expr? {
  let kk = @symcore.symbol("_k")
  let fk = @symcore.function("floor", [k])
  match name {
    "BetaBinomial" if params.length() == 3 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) => {
          let n = params[0]
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [k, @symcore.int(0)]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([
                    kk,
                    @symcore.int(0),
                    @symcore.function("Min", [n, fk]),
                  ]),
                ]),
                @symcore.function("Le", [k, n]),
              ]),
              discrete_tuple_expr([@symcore.int(1), @symcore.symbol("True")]),
            ]),
          )
        }
        None => None
      }
    "Hypergeometric" if params.length() == 3 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) => {
          let pop = params[0]
          let succ = params[1]
          let draws = params[2]
          let low = @symcore.function("Max", [
            @symcore.int(0),
            eval_arith(discrete_expr_sub(@symcore.add([draws, succ]), pop)),
          ])
          let high = @symcore.function("Min", [draws, succ])
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [fk, low]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([
                    kk,
                    low,
                    @symcore.function("Min", [high, fk]),
                  ]),
                ]),
                @symcore.function("Le", [k, high]),
              ]),
              discrete_tuple_expr([@symcore.int(1), @symcore.symbol("True")]),
            ]),
          )
        }
        None => None
      }
    "IdealSoliton" if params.length() == 1 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) => {
          let n = params[0]
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [k, @symcore.int(1)]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([
                    kk,
                    @symcore.int(1),
                    @symcore.function("Min", [n, fk]),
                  ]),
                ]),
                @symcore.function("Le", [k, n]),
              ]),
              discrete_tuple_expr([@symcore.int(1), @symcore.symbol("True")]),
            ]),
          )
        }
        None => None
      }
    "RobustSoliton" if params.length() == 3 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) => {
          let n = params[0]
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [k, @symcore.int(1)]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([
                    kk,
                    @symcore.int(1),
                    @symcore.function("Min", [n, fk]),
                  ]),
                ]),
                @symcore.function("Le", [k, n]),
              ]),
              discrete_tuple_expr([@symcore.int(1), @symcore.symbol("True")]),
            ]),
          )
        }
        None => None
      }
    "Hermite" if params.length() == 2 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) =>
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [k, @symcore.int(0)]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([kk, @symcore.int(0), fk]),
                ]),
                @symcore.symbol("True"),
              ]),
            ]),
          )
        None => None
      }
    "Logarithmic" if params.length() == 1 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) =>
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [k, @symcore.int(1)]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([kk, @symcore.int(1), fk]),
                ]),
                @symcore.symbol("True"),
              ]),
            ]),
          )
        None => None
      }
    "Skellam" if params.length() == 2 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) =>
          Some(
            @symcore.function("Sum", [
              pmf,
              discrete_tuple_expr([
                kk,
                eval_arith(
                  @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")]),
                ),
                fk,
              ]),
            ]),
          )
        None => None
      }
    "Zeta" if params.length() == 1 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) =>
          Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                @symcore.int(0),
                @symcore.function("Lt", [k, @symcore.int(1)]),
              ]),
              discrete_tuple_expr([
                @symcore.function("Sum", [
                  pmf,
                  discrete_tuple_expr([kk, @symcore.int(1), fk]),
                ]),
                @symcore.symbol("True"),
              ]),
            ]),
          )
        None => None
      }
    "Multinomial" if params.length() >= 2 =>
      symbolic_discrete_joint_box_cdf(name, params, k)
    "NegativeMultinomial" if params.length() >= 2 =>
      symbolic_discrete_joint_box_cdf(name, params, k)
    _ => None
  }
}

///|
pub fn discrete_pmf(rv : RandomVar, k : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_pmf(rv, k)
    RVKind::Binomial(n~, p~) => Some(binomial_pmf_expr(n, p, k))
    RVKind::Poisson(rate~) => Some(poisson_pmf_expr(rate, k))
    RVKind::Geometric(p~) => Some(geometric_pmf_expr(p, k))
    RVKind::NegativeBinomial(r~, p~) =>
      Some(negative_binomial_pmf_expr(r, p, k))
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        if name == "DiscreteRV" ||
          name == "DiscreteDistributionHandmade" ||
          name == "FiniteDistributionHandmade" {
          return None
        }
        if name == "Hermite" && params.length() == 2 {
          let a1 = params[0]
          let a2 = params[1]
          let jj = @symcore.symbol("_j")
          let summand = eval_arith(
            @symcore.mul([
              @symcore.pow(
                a1,
                eval_arith(
                  discrete_expr_sub(
                    k,
                    eval_arith(@symcore.mul([@symcore.int(2), jj])),
                  ),
                ),
              ),
              @symcore.pow(a2, jj),
              @symcore.pow(
                @symcore.function("factorial", [
                  eval_arith(
                    discrete_expr_sub(
                      k,
                      eval_arith(@symcore.mul([@symcore.int(2), jj])),
                    ),
                  ),
                ]),
                @symcore.int(-1),
              ),
              @symcore.pow(
                @symcore.function("factorial", [jj]),
                @symcore.int(-1),
              ),
            ]),
          )
          let sum_expr = @symcore.function("Sum", [
            summand,
            discrete_tuple_expr([
              jj,
              @symcore.int(0),
              @symcore.function("floor", [
                eval_arith(
                  @symcore.mul([try! @symcore.rational_from_ints(1, 2), k]),
                ),
              ]),
            ]),
          ])
          return Some(
            eval_arith(
              @symcore.mul([
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      eval_arith(@symcore.add([a1, a2])),
                    ]),
                  ),
                ]),
                sum_expr,
              ]),
            ),
          )
        }
        if name == "IdealSoliton" && params.length() == 1 {
          let kk = params[0]
          return Some(
            @symcore.function("Piecewise", [
              discrete_tuple_expr([
                eval_arith(@symcore.pow(kk, @symcore.int(-1))),
                @symcore.function("Eq", [k, @symcore.int(1)]),
              ]),
              discrete_tuple_expr([
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.mul([
                        k,
                        eval_arith(discrete_expr_sub(k, @symcore.int(1))),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("And", [
                  @symcore.function("Ge", [k, @symcore.int(1)]),
                  @symcore.function("Le", [k, kk]),
                ]),
              ]),
              discrete_tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
            ]),
          )
        }
        if name == "RobustSoliton" && params.length() == 3 {
          let kk = params[0]
          let delta = params[1]
          let c = params[2]
          let r = eval_arith(
            @symcore.mul([
              c,
              @symcore.function("log", [
                eval_arith(
                  @symcore.mul([kk, @symcore.pow(delta, @symcore.int(-1))]),
                ),
              ]),
              @symcore.function("sqrt", [kk]),
            ]),
          )
          let rho = @symcore.function("Piecewise", [
            discrete_tuple_expr([
              eval_arith(@symcore.pow(kk, @symcore.int(-1))),
              @symcore.function("Eq", [k, @symcore.int(1)]),
            ]),
            discrete_tuple_expr([
              eval_arith(
                @symcore.pow(
                  eval_arith(
                    @symcore.mul([
                      k,
                      eval_arith(discrete_expr_sub(k, @symcore.int(1))),
                    ]),
                  ),
                  @symcore.int(-1),
                ),
              ),
              @symcore.function("And", [
                @symcore.function("Ge", [k, @symcore.int(1)]),
                @symcore.function("Le", [k, kk]),
              ]),
            ]),
            discrete_tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
          ])
          let tau = @symcore.function("Piecewise", [
            discrete_tuple_expr([
              eval_arith(
                @symcore.mul([
                  r,
                  @symcore.pow(
                    eval_arith(@symcore.mul([kk, k])),
                    @symcore.int(-1),
                  ),
                ]),
              ),
              @symcore.function("And", [
                @symcore.function("Ge", [k, @symcore.int(1)]),
                @symcore.function("Le", [
                  k,
                  eval_arith(
                    discrete_expr_sub(
                      @symcore.function("round", [
                        eval_arith(
                          @symcore.mul([kk, @symcore.pow(r, @symcore.int(-1))]),
                        ),
                      ]),
                      @symcore.int(1),
                    ),
                  ),
                ]),
              ]),
            ]),
            discrete_tuple_expr([
              eval_arith(
                @symcore.mul([
                  r,
                  @symcore.function("log", [
                    eval_arith(
                      @symcore.mul([r, @symcore.pow(delta, @symcore.int(-1))]),
                    ),
                  ]),
                  @symcore.pow(kk, @symcore.int(-1)),
                ]),
              ),
              @symcore.function("Eq", [
                k,
                @symcore.function("round", [
                  eval_arith(
                    @symcore.mul([kk, @symcore.pow(r, @symcore.int(-1))]),
                  ),
                ]),
              ]),
            ]),
            discrete_tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
          ])
          let ii = @symcore.symbol("_i")
          let harmonic = @symcore.function("Sum", [
            @symcore.pow(ii, @symcore.int(-1)),
            discrete_tuple_expr([
              ii,
              @symcore.int(1),
              eval_arith(
                discrete_expr_sub(
                  @symcore.function("round", [
                    eval_arith(
                      @symcore.mul([kk, @symcore.pow(r, @symcore.int(-1))]),
                    ),
                  ]),
                  @symcore.int(1),
                ),
              ),
            ]),
          ])
          let z = eval_arith(
            @symcore.add([
              @symcore.int(1),
              eval_arith(
                @symcore.mul([
                  r,
                  @symcore.pow(kk, @symcore.int(-1)),
                  eval_arith(
                    @symcore.add([
                      harmonic,
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            r,
                            @symcore.pow(delta, @symcore.int(-1)),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ]),
          )
          return Some(
            eval_arith(
              @symcore.mul([
                eval_arith(@symcore.add([rho, tau])),
                @symcore.pow(z, @symcore.int(-1)),
              ]),
            ),
          )
        }
        if name == "Multinomial" && params.length() >= 2 {
          match discrete_tuple_items(k) {
            Some(ks) if ks.length() == params.length() - 1 => {
              let n = params[0]
              let body_terms : Array[@symcore.Expr] = [
                @symcore.function("factorial", [n]),
              ]
              let sum_terms : Array[@symcore.Expr] = Array::new()
              for i in 0..<ks.length() {
                let ki = ks[i]
                sum_terms.push(ki)
                body_terms.push(
                  @symcore.pow(
                    @symcore.function("factorial", [ki]),
                    @symcore.int(-1),
                  ),
                )
                body_terms.push(@symcore.pow(params[i + 1], ki))
              }
              let sum_k = if sum_terms.is_empty() {
                @symcore.int(0)
              } else {
                eval_arith(@symcore.add(sum_terms))
              }
              let body = eval_arith(@symcore.mul(body_terms))
              return Some(
                @symcore.function("Piecewise", [
                  discrete_tuple_expr([
                    body,
                    @symcore.function("Eq", [sum_k, n]),
                  ]),
                  discrete_tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
                ]),
              )
            }
            _ => ()
          }
        }
        if name == "NegativeMultinomial" && params.length() >= 2 {
          match discrete_tuple_items(k) {
            Some(ks) if ks.length() == params.length() - 1 => {
              let k0 = params[0]
              let sum_k = if ks.is_empty() {
                @symcore.int(0)
              } else {
                eval_arith(@symcore.add(ks))
              }
              let ps : Array[@symcore.Expr] = Array::new()
              for i in 1..<params.length() {
                ps.push(params[i])
              }
              let q = eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), eval_arith(@symcore.add(ps))]),
                ]),
              )
              let term_1 = eval_arith(
                @symcore.mul([
                  @symcore.function("gamma", [
                    eval_arith(@symcore.add([k0, sum_k])),
                  ]),
                  @symcore.pow(
                    @symcore.function("gamma", [k0]),
                    @symcore.int(-1),
                  ),
                  @symcore.pow(q, k0),
                ]),
              )
              let term_2_factors : Array[@symcore.Expr] = Array::new()
              for i in 0..<ks.length() {
                let ki = ks[i]
                term_2_factors.push(
                  eval_arith(
                    @symcore.mul([
                      @symcore.pow(params[i + 1], ki),
                      @symcore.pow(
                        @symcore.function("factorial", [ki]),
                        @symcore.int(-1),
                      ),
                    ]),
                  ),
                )
              }
              let term_2 = if term_2_factors.is_empty() {
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
          None => Some(symbolic_discrete_expr(name, "PMF", params, k~))
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
        match
          (expr_as_number(eval_arith(value)), expr_as_number(eval_arith(k))) {
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
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        if name == "DiscreteRV" ||
          name == "DiscreteDistributionHandmade" ||
          name == "FiniteDistributionHandmade" {
          return None
        }
        match generated_cdf(name, params, k) {
          Some(v) => Some(v)
          None =>
            match symbolic_discrete_cdf_by_pmf_sum(name, params, k) {
              Some(v) => Some(v)
              None =>
                match symbolic_discrete_cdf_formula(name, params, k) {
                  Some(v) => Some(v)
                  None => Some(symbolic_discrete_expr(name, "CDF", params, k~))
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
        Event::Bool(v) =>
          Some(if v { @symcore.int(1) } else { @symcore.int(0) })
        Event::Not(inner) =>
          match discrete_probability(rv, inner) {
            Some(inner_p) =>
              Some(eval_arith(discrete_expr_sub(@symcore.int(1), inner_p)))
            None => None
          }
        Event::Rel(..) =>
          match discrete_extract_rel_to_var(event, rv.name) {
            Some((op, k)) =>
              match op {
                RelOp::Eq => discrete_pmf(rv, k)
                RelOp::Ne =>
                  match discrete_pmf(rv, k) {
                    Some(pmf) =>
                      Some(eval_arith(discrete_expr_sub(@symcore.int(1), pmf)))
                    None => None
                  }
                RelOp::Le => discrete_cdf(rv, k)
                RelOp::Lt =>
                  discrete_cdf(
                    rv,
                    eval_arith(discrete_expr_sub(k, @symcore.int(1))),
                  )
                RelOp::Ge =>
                  match
                    discrete_cdf(
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
fn symbolic_discrete_mean_by_sum(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  let kk = @symcore.symbol("_k")
  match name {
    "IdealSoliton" if params.length() == 1 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) =>
          Some(
            eval_arith(
              @symcore.function("Sum", [
                eval_arith(@symcore.mul([kk, pmf])),
                discrete_tuple_expr([kk, @symcore.int(1), params[0]]),
              ]),
            ),
          )
        None => None
      }
    "RobustSoliton" if params.length() == 3 =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) =>
          Some(
            eval_arith(
              @symcore.function("Sum", [
                eval_arith(@symcore.mul([kk, pmf])),
                discrete_tuple_expr([kk, @symcore.int(1), params[0]]),
              ]),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
fn symbolic_discrete_variance_by_sum(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  let kk = @symcore.symbol("_k")
  let bounds = match name {
    "IdealSoliton" if params.length() == 1 => Some((@symcore.int(1), params[0]))
    "RobustSoliton" if params.length() == 3 =>
      Some((@symcore.int(1), params[0]))
    "YuleSimon" if params.length() == 1 =>
      Some((@symcore.int(1), @symcore.symbol("oo")))
    _ => None
  }
  match bounds {
    Some((lower, upper)) =>
      match symbolic_discrete_pmf_for(name, params, kk) {
        Some(pmf) => {
          let tag = "D:\{name}"
          let rv = random_var("_X", RVKind::Symbolic(tag~, params~))
          let mean_expr = match discrete_mean(rv) {
            Some(v) => v
            None => symbolic_discrete_expr(name, "Mean", params)
          }
          Some(
            eval_arith(
              @symcore.function("Sum", [
                eval_arith(
                  @symcore.mul([
                    @symcore.pow(
                      discrete_expr_sub(kk, mean_expr),
                      @symcore.int(2),
                    ),
                    pmf,
                  ]),
                ),
                discrete_tuple_expr([kk, lower, upper]),
              ]),
            ),
          )
        }
        None => None
      }
    None => None
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
          @symcore.mul([
            r,
            discrete_one_minus(p),
            @symcore.pow(p, @symcore.int(-1)),
          ]),
        ),
      )
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_mean(name, params) {
          Some(v) => Some(v)
          None =>
            match symbolic_discrete_mean_by_sum(name, params) {
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
                    let q = eval_arith(
                      @symcore.add([
                        @symcore.int(1),
                        @symcore.mul([
                          @symcore.int(-1),
                          eval_arith(@symcore.add(probs)),
                        ]),
                      ]),
                    )
                    let means = probs.map(pi => {
                      eval_arith(
                        @symcore.mul([k0, pi, @symcore.pow(q, @symcore.int(-1))]),
                      )
                    })
                    Some(discrete_tuple_expr(means))
                  }
                  "BetaBinomial" if params.length() == 3 =>
                    Some(
                      eval_arith(
                        @symcore.mul([
                          params[0],
                          params[1],
                          @symcore.pow(
                            eval_arith(@symcore.add([params[1], params[2]])),
                            @symcore.int(-1),
                          ),
                        ]),
                      ),
                    )
                  "Hypergeometric" if params.length() == 3 =>
                    Some(
                      eval_arith(
                        @symcore.mul([
                          params[2],
                          params[1],
                          @symcore.pow(params[0], @symcore.int(-1)),
                        ]),
                      ),
                    )
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
      Some(
        eval_arith(
          @symcore.mul([
            discrete_one_minus(p),
            @symcore.pow(p, @symcore.int(-2)),
          ]),
        ),
      )
    RVKind::NegativeBinomial(r~, p~) =>
      Some(
        eval_arith(
          @symcore.mul([
            r,
            discrete_one_minus(p),
            @symcore.pow(p, @symcore.int(-2)),
          ]),
        ),
      )
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) != "D" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_variance(name, params) {
          Some(v) => Some(v)
          None =>
            match symbolic_discrete_variance_by_sum(name, params) {
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
                          row.push(
                            eval_arith(
                              @symcore.mul([n, pi, discrete_one_minus(pi)]),
                            ),
                          )
                        } else {
                          row.push(
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), n, pi, pj]),
                            ),
                          )
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
                    let q = eval_arith(
                      @symcore.add([
                        @symcore.int(1),
                        @symcore.mul([
                          @symcore.int(-1),
                          eval_arith(@symcore.add(ps)),
                        ]),
                      ]),
                    )
                    let rows : Array[Array[@symcore.Expr]] = Array::new()
                    for i in 0..<ps.length() {
                      let row : Array[@symcore.Expr] = Array::new()
                      let pi = ps[i]
                      for j in 0..<ps.length() {
                        let pj = ps[j]
                        if i == j {
                          row.push(
                            eval_arith(
                              @symcore.mul([
                                k0,
                                pi,
                                eval_arith(@symcore.add([q, pi])),
                                @symcore.pow(q, @symcore.int(-2)),
                              ]),
                            ),
                          )
                        } else {
                          row.push(
                            eval_arith(
                              @symcore.mul([
                                k0,
                                pi,
                                pj,
                                @symcore.pow(q, @symcore.int(-2)),
                              ]),
                            ),
                          )
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
                    Some(
                      eval_arith(
                        @symcore.mul([
                          n,
                          alpha,
                          beta,
                          eval_arith(@symcore.add([ab, n])),
                          @symcore.pow(ab, @symcore.int(-2)),
                          @symcore.pow(
                            eval_arith(@symcore.add([ab, @symcore.int(1)])),
                            @symcore.int(-1),
                          ),
                        ]),
                      ),
                    )
                  }
                  "Hypergeometric" if params.length() == 3 => {
                    let population = params[0]
                    let success = params[1]
                    let draws = params[2]
                    let p = eval_arith(
                      @symcore.mul([
                        success,
                        @symcore.pow(population, @symcore.int(-1)),
                      ]),
                    )
                    Some(
                      eval_arith(
                        @symcore.mul([
                          draws,
                          p,
                          eval_arith(
                            @symcore.add([
                              @symcore.int(1),
                              @symcore.mul([@symcore.int(-1), p]),
                            ]),
                          ),
                          eval_arith(
                            @symcore.add([
                              population,
                              @symcore.mul([@symcore.int(-1), draws]),
                            ]),
                          ),
                          @symcore.pow(
                            eval_arith(
                              @symcore.add([population, @symcore.int(-1)]),
                            ),
                            @symcore.int(-1),
                          ),
                        ]),
                      ),
                    )
                  }
                  _ => Some(symbolic_discrete_expr(name, "Variance", params))
                }
            }
        }
      }
    _ => None
  }
}
