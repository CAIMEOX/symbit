///|
/// Continuous distributions (Normal/Exponential/Gamma).

///|
pub fn normal(
  name : String,
  mu : @symcore.Expr,
  sigma : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::Normal(mu~, sigma~))
}

///|
pub fn exponential(name : String, rate : @symcore.Expr) -> RandomVar {
  random_var(name, RVKind::Exponential(rate~))
}

///|
pub fn gamma_dist(
  name : String,
  shape : @symcore.Expr,
  scale : @symcore.Expr,
) -> RandomVar {
  random_var(name, RVKind::Gamma(shape~, scale~))
}

///|
fn cont_expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.add([a, @symcore.mul([@symcore.int(-1), b])])
}

///|
fn cont_one_minus(x : @symcore.Expr) -> @symcore.Expr {
  cont_expr_sub(@symcore.int(1), x)
}

///|
fn cont_extract_rel_to_var(
  event : Event,
  var_name : String,
) -> (RelOp, @symcore.Expr)? {
  let x = @symcore.Expr::Symbol(var_name)
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

///|
fn cont_piecewise(
  pairs : Array[(@symcore.Expr, @symcore.Expr)],
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = Array::new()
  for pair in pairs {
    let (value, cond) = pair
    args.push(@symcore.Expr::Tuple([value, cond]))
  }
  @symcore.function("Piecewise", args)
}

///|
fn cont_rel(
  name : String,
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function(name, [lhs, rhs])
}

///|
fn cont_and(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("And", [a, b])
}

///|
fn cont_param_condition(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match continuous_tag_from_name(name) {
    ContinuousTag::Arcsin if params.length() == 2 =>
      Some(cont_rel("Lt", params[0], params[1]))
    ContinuousTag::Uniform if params.length() == 2 =>
      Some(cont_rel("Lt", params[0], params[1]))
    ContinuousTag::Beta if params.length() == 2 =>
      Some(
        cont_and(
          cont_rel("Gt", params[0], @symcore.int(0)),
          cont_rel("Gt", params[1], @symcore.int(0)),
        ),
      )
    ContinuousTag::Laplace if params.length() == 2 =>
      Some(cont_rel("Gt", params[1], @symcore.int(0)))
    ContinuousTag::Cauchy if params.length() == 2 =>
      Some(cont_rel("Gt", params[1], @symcore.int(0)))
    ContinuousTag::Pareto if params.length() == 2 =>
      Some(
        cont_and(
          cont_rel("Gt", params[0], @symcore.int(0)),
          cont_rel("Gt", params[1], @symcore.int(0)),
        ),
      )
    ContinuousTag::BoundedPareto if params.length() == 3 =>
      Some(
        cont_and(
          cont_rel("Gt", params[0], @symcore.int(0)),
          cont_and(
            cont_rel("Gt", params[1], @symcore.int(0)),
            cont_rel("Lt", params[1], params[2]),
          ),
        ),
      )
    ContinuousTag::Kumaraswamy if params.length() == 2 =>
      Some(
        cont_and(
          cont_rel("Gt", params[0], @symcore.int(0)),
          cont_rel("Gt", params[1], @symcore.int(0)),
        ),
      )
    ContinuousTag::Rayleigh if params.length() == 1 =>
      Some(cont_rel("Gt", params[0], @symcore.int(0)))
    ContinuousTag::LogNormal if params.length() == 2 =>
      Some(cont_rel("Gt", params[1], @symcore.int(0)))
    ContinuousTag::Weibull if params.length() == 2 =>
      Some(
        cont_and(
          cont_rel("Gt", params[0], @symcore.int(0)),
          cont_rel("Gt", params[1], @symcore.int(0)),
        ),
      )
    ContinuousTag::PowerFunction if params.length() == 3 =>
      Some(
        cont_and(
          cont_rel("Gt", params[0], @symcore.int(0)),
          cont_rel("Lt", params[1], params[2]),
        ),
      )
    ContinuousTag::StudentT if params.length() == 1 =>
      Some(cont_rel("Gt", params[0], @symcore.int(0)))
    ContinuousTag::Moyal if params.length() == 2 =>
      Some(cont_rel("Gt", params[1], @symcore.int(0)))
    ContinuousTag::WignerSemicircle if params.length() == 1 =>
      Some(cont_rel("Gt", params[0], @symcore.int(0)))
    ContinuousTag::Trapezoidal if params.length() == 4 =>
      Some(
        cont_and(
          cont_and(
            cont_rel("Lt", params[0], params[1]),
            cont_rel("Le", params[1], params[2]),
          ),
          cont_rel("Lt", params[2], params[3]),
        ),
      )
    _ => None
  }
}

///|
fn cont_numeric_cmp(a : @symcore.Expr, b : @symcore.Expr) -> Int? {
  match (expr_as_number(eval_arith(a)), expr_as_number(eval_arith(b))) {
    (Some(an), Some(bn)) => Some(an.compare(bn))
    _ => None
  }
}

///|
fn cont_numeric_gt_zero(a : @symcore.Expr) -> Bool? {
  match cont_numeric_cmp(a, @symcore.int(0)) {
    Some(v) => Some(v > 0)
    None => None
  }
}

///|
fn cont_numeric_lt(a : @symcore.Expr, b : @symcore.Expr) -> Bool? {
  match cont_numeric_cmp(a, b) {
    Some(v) => Some(v < 0)
    None => None
  }
}

///|
fn cont_bool_and(a : Bool?, b : Bool?) -> Bool? {
  match (a, b) {
    (Some(av), Some(bv)) => Some(av && bv)
    _ => None
  }
}

///|
fn cont_known_valid(name : String, params : Array[@symcore.Expr]) -> Bool? {
  match continuous_tag_from_name(name) {
    ContinuousTag::Arcsin if params.length() == 2 =>
      cont_numeric_lt(params[0], params[1])
    ContinuousTag::Uniform if params.length() == 2 =>
      cont_numeric_lt(params[0], params[1])
    ContinuousTag::Beta if params.length() == 2 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_numeric_gt_zero(params[1]),
      )
    ContinuousTag::Laplace if params.length() == 2 =>
      cont_numeric_gt_zero(params[1])
    ContinuousTag::Cauchy if params.length() == 2 =>
      cont_numeric_gt_zero(params[1])
    ContinuousTag::Pareto if params.length() == 2 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_numeric_gt_zero(params[1]),
      )
    ContinuousTag::BoundedPareto if params.length() == 3 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_bool_and(
          cont_numeric_gt_zero(params[1]),
          cont_numeric_lt(params[1], params[2]),
        ),
      )
    ContinuousTag::Kumaraswamy if params.length() == 2 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_numeric_gt_zero(params[1]),
      )
    ContinuousTag::Rayleigh if params.length() == 1 =>
      cont_numeric_gt_zero(params[0])
    ContinuousTag::LogNormal if params.length() == 2 =>
      cont_numeric_gt_zero(params[1])
    ContinuousTag::Weibull if params.length() == 2 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_numeric_gt_zero(params[1]),
      )
    ContinuousTag::PowerFunction if params.length() == 3 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_numeric_lt(params[1], params[2]),
      )
    ContinuousTag::StudentT if params.length() == 1 =>
      cont_numeric_gt_zero(params[0])
    ContinuousTag::Moyal if params.length() == 2 =>
      cont_numeric_gt_zero(params[1])
    ContinuousTag::WignerSemicircle if params.length() == 1 =>
      cont_numeric_gt_zero(params[0])
    ContinuousTag::Trapezoidal if params.length() == 4 =>
      cont_bool_and(
        cont_bool_and(
          cont_numeric_lt(params[0], params[1]),
          match cont_numeric_cmp(params[1], params[2]) {
            Some(v) => Some(v <= 0)
            None => None
          },
        ),
        cont_numeric_lt(params[2], params[3]),
      )
    _ => None
  }
}

///|
fn cont_guard_params(
  name : String,
  params : Array[@symcore.Expr],
  expr : @symcore.Expr,
) -> @symcore.Expr {
  match cont_known_valid(name, params) {
    Some(true) => expr
    Some(false) => @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)
    None =>
      match cont_param_condition(name, params) {
        Some(valid_cond) =>
          cont_piecewise([
            (expr, valid_cond),
            (
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
              @symcore.Expr::Boolean(true),
            ),
          ])
        None => expr
      }
  }
}

///|
fn symbolic_continuous_density(
  tag : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match tag {
    "Arcsin" if params.length() == 2 => {
      let a = params[0]
      let b = params[1]
      let denom = eval_arith(
        @symcore.mul([
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          @symcore.function("sqrt", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                cont_expr_sub(x, b),
                cont_expr_sub(x, a),
              ]),
            ),
          ]),
        ]),
      )
      let body = eval_arith(
        @symcore.mul([@symcore.pow(denom, @symcore.int(-1))]),
      )
      Some(
        cont_piecewise([
          (body, cont_and(cont_rel("Le", a, x), cont_rel("Le", x, b))),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Uniform" if params.length() == 2 => {
      let a = params[0]
      let b = params[1]
      let body = eval_arith(
        @symcore.pow(eval_arith(cont_expr_sub(b, a)), @symcore.int(-1)),
      )
      Some(
        cont_piecewise([
          (body, cont_and(cont_rel("Le", a, x), cont_rel("Le", x, b))),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Beta" if params.length() == 2 => {
      let alpha = params[0]
      let beta = params[1]
      let body = eval_arith(
        @symcore.mul([
          @symcore.pow(x, cont_expr_sub(alpha, @symcore.int(1))),
          @symcore.pow(
            cont_expr_sub(@symcore.int(1), x),
            cont_expr_sub(beta, @symcore.int(1)),
          ),
          @symcore.pow(
            @symcore.function("beta", [alpha, beta]),
            @symcore.int(-1),
          ),
        ]),
      )
      Some(
        cont_piecewise([
          (
            body,
            cont_and(
              cont_rel("Le", @symcore.int(0), x),
              cont_rel("Le", x, @symcore.int(1)),
            ),
          ),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Laplace" if params.length() == 2 => {
      let mu = params[0]
      let b = params[1]
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.pow(
              eval_arith(@symcore.mul([@symcore.int(2), b])),
              @symcore.int(-1),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  @symcore.function("Abs", [cont_expr_sub(x, mu)]),
                  @symcore.pow(b, @symcore.int(-1)),
                ]),
              ),
            ]),
          ]),
        ),
      )
    }
    "Cauchy" if params.length() == 2 => {
      let x0 = params[0]
      let gamma = params[1]
      let ratio = eval_arith(
        @symcore.mul([
          cont_expr_sub(x, x0),
          @symcore.pow(gamma, @symcore.int(-1)),
        ]),
      )
      let denom = eval_arith(
        @symcore.mul([
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
          gamma,
          eval_arith(
            @symcore.add([@symcore.int(1), @symcore.pow(ratio, @symcore.int(2))]),
          ),
        ]),
      )
      Some(eval_arith(@symcore.pow(denom, @symcore.int(-1))))
    }
    "Pareto" if params.length() == 2 => {
      let xm = params[0]
      let alpha = params[1]
      let body = eval_arith(
        @symcore.mul([
          alpha,
          @symcore.pow(xm, alpha),
          @symcore.pow(
            x,
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                @symcore.add([alpha, @symcore.int(1)]),
              ]),
            ),
          ),
        ]),
      )
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, xm)),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Rayleigh" if params.length() == 1 => {
      let sigma = params[0]
      let body = eval_arith(
        @symcore.mul([
          x,
          @symcore.pow(sigma, @symcore.int(-2)),
          @symcore.function("exp", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                @symcore.pow(x, @symcore.int(2)),
                @symcore.pow(
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      @symcore.pow(sigma, @symcore.int(2)),
                    ]),
                  ),
                  @symcore.int(-1),
                ),
              ]),
            ),
          ]),
        ]),
      )
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, @symcore.int(0))),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "LogNormal" if params.length() == 2 => {
      let mu = params[0]
      let sigma = params[1]
      let logterm = cont_expr_sub(@symcore.function("log", [x]), mu)
      let body = eval_arith(
        @symcore.mul([
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                x,
                sigma,
                @symcore.function("sqrt", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.int(-1),
          ),
          @symcore.function("exp", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                @symcore.pow(logterm, @symcore.int(2)),
                @symcore.pow(
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      @symcore.pow(sigma, @symcore.int(2)),
                    ]),
                  ),
                  @symcore.int(-1),
                ),
              ]),
            ),
          ]),
        ]),
      )
      Some(
        cont_piecewise([
          (body, cont_rel("Gt", x, @symcore.int(0))),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Weibull" if params.length() == 2 => {
      let lam = params[0]
      let k = params[1]
      let ratio = eval_arith(
        @symcore.mul([x, @symcore.pow(lam, @symcore.int(-1))]),
      )
      let body = eval_arith(
        @symcore.mul([
          k,
          @symcore.pow(lam, @symcore.int(-1)),
          @symcore.pow(ratio, cont_expr_sub(k, @symcore.int(1))),
          @symcore.function("exp", [
            eval_arith(@symcore.mul([@symcore.int(-1), @symcore.pow(ratio, k)])),
          ]),
        ]),
      )
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, @symcore.int(0))),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "StudentT" if params.length() == 1 => {
      let nu = params[0]
      let coeff = eval_arith(
        @symcore.mul([
          @symcore.function("gamma", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                @symcore.add([nu, @symcore.int(1)]),
              ]),
            ),
          ]),
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                @symcore.function("sqrt", [
                  eval_arith(
                    @symcore.mul([
                      nu,
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    ]),
                  ),
                ]),
                @symcore.function("gamma", [
                  eval_arith(@symcore.mul([stats_exact_rational(1, 2), nu])),
                ]),
              ]),
            ),
            @symcore.int(-1),
          ),
        ]),
      )
      let body = eval_arith(
        @symcore.mul([
          coeff,
          @symcore.pow(
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    @symcore.pow(x, @symcore.int(2)),
                    @symcore.pow(nu, @symcore.int(-1)),
                  ]),
                ),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(-1, 2),
                @symcore.add([nu, @symcore.int(1)]),
              ]),
            ),
          ),
        ]),
      )
      Some(body)
    }
    "BetaNoncentral" if params.length() == 3 => {
      let alpha = params[0]
      let beta = params[1]
      let lamda = params[2]
      let kk = @symcore.Expr::Symbol("_k")
      let half = stats_exact_rational(1, 2)
      let summand = eval_arith(
        @symcore.mul([
          @symcore.function("exp", [
            eval_arith(@symcore.mul([@symcore.int(-1), lamda, half])),
          ]),
          @symcore.pow(eval_arith(@symcore.mul([lamda, half])), kk),
          @symcore.pow(
            x,
            eval_arith(@symcore.add([alpha, kk, @symcore.int(-1)])),
          ),
          @symcore.pow(
            eval_arith(cont_expr_sub(@symcore.int(1), x)),
            eval_arith(@symcore.add([beta, @symcore.int(-1)])),
          ),
          @symcore.pow(@symcore.function("factorial", [kk]), @symcore.int(-1)),
          @symcore.pow(
            @symcore.function("beta", [
              eval_arith(@symcore.add([alpha, kk])),
              beta,
            ]),
            @symcore.int(-1),
          ),
        ]),
      )
      Some(
        @symcore.function("Sum", [
          summand,
          @symcore.function("Tuple", [
            kk,
            @symcore.int(0),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          ]),
        ]),
      )
    }
    "UniformSum" if params.length() == 1 => {
      let n = params[0]
      let kk = @symcore.Expr::Symbol("_k")
      let summand = eval_arith(
        @symcore.mul([
          @symcore.pow(@symcore.int(-1), kk),
          @symcore.function("binomial", [n, kk]),
          @symcore.pow(
            eval_arith(cont_expr_sub(x, kk)),
            eval_arith(cont_expr_sub(n, @symcore.int(1))),
          ),
        ]),
      )
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.pow(
              @symcore.function("factorial", [
                eval_arith(cont_expr_sub(n, @symcore.int(1))),
              ]),
              @symcore.int(-1),
            ),
            @symcore.function("Sum", [
              summand,
              @symcore.function("Tuple", [
                kk,
                @symcore.int(0),
                @symcore.function("floor", [x]),
              ]),
            ]),
          ]),
        ),
      )
    }
    _ => None
  }
}

///|
fn symbolic_density_expr(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = [x]
  for p in params {
    args.push(p)
  }
  @symcore.function("\{name}Density", args)
}

///|
fn symbolic_continuous_integral_cdf(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
  lower : @symcore.Expr,
  guard_lower? : Bool = true,
) -> @symcore.Expr {
  let dummy = @symcore.Expr::Symbol("_x")
  let density_expr = match symbolic_continuous_density(name, params, dummy) {
    Some(v) => v
    None =>
      match generated_density(name, params, dummy) {
        Some(v) => v
        None => symbolic_density_expr(name, params, dummy)
      }
  }
  let integral = eval_arith(
    @symcore.function("Integral", [
      density_expr,
      @symcore.function("Tuple", [dummy, lower, x]),
    ]),
  )
  if guard_lower {
    cont_piecewise([
      (integral, cont_rel("Ge", x, lower)),
      (@symcore.int(0), @symcore.Expr::Boolean(true)),
    ])
  } else {
    integral
  }
}

///|
fn symbolic_continuous_cdf(
  tag : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match tag {
    "Arcsin" if params.length() == 2 => {
      let a = params[0]
      let b = params[1]
      let ratio = eval_arith(
        @symcore.mul([
          cont_expr_sub(x, a),
          @symcore.pow(cont_expr_sub(b, a), @symcore.int(-1)),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, a)),
          (
            eval_arith(
              @symcore.mul([
                stats_exact_rational(2, 1),
                @symcore.pow(
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  @symcore.int(-1),
                ),
                @symcore.function("asin", [@symcore.function("sqrt", [ratio])]),
              ]),
            ),
            cont_rel("Le", x, b),
          ),
          (@symcore.int(1), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Uniform" if params.length() == 2 => {
      let a = params[0]
      let b = params[1]
      let mid = eval_arith(
        @symcore.mul([
          cont_expr_sub(x, a),
          @symcore.pow(cont_expr_sub(b, a), @symcore.int(-1)),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, a)),
          (mid, cont_rel("Le", x, b)),
          (@symcore.int(1), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Laplace" if params.length() == 2 => {
      let mu = params[0]
      let b = params[1]
      let left = eval_arith(
        @symcore.mul([
          stats_exact_rational(1, 2),
          @symcore.function("exp", [
            eval_arith(
              @symcore.mul([
                cont_expr_sub(x, mu),
                @symcore.pow(b, @symcore.int(-1)),
              ]),
            ),
          ]),
        ]),
      )
      let right = eval_arith(
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([
            stats_exact_rational(-1, 2),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  cont_expr_sub(x, mu),
                  @symcore.pow(b, @symcore.int(-1)),
                ]),
              ),
            ]),
          ]),
        ]),
      )
      Some(
        cont_piecewise([
          (left, cont_rel("Lt", x, mu)),
          (right, @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Cauchy" if params.length() == 2 => {
      let x0 = params[0]
      let gamma = params[1]
      Some(
        eval_arith(
          @symcore.add([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.mul([
                @symcore.pow(
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  @symcore.int(-1),
                ),
                @symcore.function("atan", [
                  eval_arith(
                    @symcore.mul([
                      cont_expr_sub(x, x0),
                      @symcore.pow(gamma, @symcore.int(-1)),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    }
    "Pareto" if params.length() == 2 => {
      let xm = params[0]
      let alpha = params[1]
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, xm)),
          (
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                @symcore.mul([
                  @symcore.int(-1),
                  @symcore.pow(
                    eval_arith(
                      @symcore.mul([xm, @symcore.pow(x, @symcore.int(-1))]),
                    ),
                    alpha,
                  ),
                ]),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    }
    "Rayleigh" if params.length() == 1 => {
      let sigma = params[0]
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, @symcore.int(0))),
          (
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                @symcore.mul([
                  @symcore.int(-1),
                  @symcore.function("exp", [
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(x, @symcore.int(2)),
                        @symcore.pow(
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(2),
                              @symcore.pow(sigma, @symcore.int(2)),
                            ]),
                          ),
                          @symcore.int(-1),
                        ),
                      ]),
                    ),
                  ]),
                ]),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    }
    "WignerSemicircle" if params.length() == 1 => {
      let r = params[0]
      let r2 = eval_arith(@symcore.pow(r, @symcore.int(2)))
      let term1 = eval_arith(
        @symcore.mul([
          x,
          @symcore.function("sqrt", [
            eval_arith(cont_expr_sub(r2, @symcore.pow(x, @symcore.int(2)))),
          ]),
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                r2,
              ]),
            ),
            @symcore.int(-1),
          ),
        ]),
      )
      let term2 = eval_arith(
        @symcore.mul([
          @symcore.function("asin", [
            eval_arith(@symcore.mul([x, @symcore.pow(r, @symcore.int(-1))])),
          ]),
          @symcore.pow(
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
            @symcore.int(-1),
          ),
        ]),
      )
      let body = eval_arith(
        @symcore.add([stats_exact_rational(1, 2), term1, term2]),
      )
      Some(
        cont_piecewise([
          (
            body,
            cont_rel("Ge", x, eval_arith(@symcore.mul([@symcore.int(-1), r]))),
          ),
          (@symcore.int(0), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "Chi" if params.length() == 1 => {
      let k = params[0]
      let half = stats_exact_rational(1, 2)
      let shape = eval_arith(@symcore.mul([half, k]))
      let z = eval_arith(@symcore.mul([half, @symcore.pow(x, @symcore.int(2))]))
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, @symcore.int(0))),
          (
            eval_arith(
              @symcore.mul([
                @symcore.function("lowergamma", [shape, z]),
                @symcore.pow(
                  @symcore.function("gamma", [shape]),
                  @symcore.int(-1),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    }
    "LogNormal" if params.length() == 2 => {
      let mu = params[0]
      let sigma = params[1]
      let arg = eval_arith(
        @symcore.mul([
          cont_expr_sub(@symcore.function("log", [x]), mu),
          @symcore.pow(
            eval_arith(
              @symcore.mul([sigma, @symcore.function("sqrt", [@symcore.int(2)])]),
            ),
            @symcore.int(-1),
          ),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Le", x, @symcore.int(0))),
          (
            eval_arith(
              @symcore.add([
                stats_exact_rational(1, 2),
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(1, 2),
                    @symcore.function("erf", [arg]),
                  ]),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    }
    "Weibull" if params.length() == 2 => {
      let lam = params[0]
      let k = params[1]
      let ratio_pow = @symcore.pow(
        eval_arith(@symcore.mul([x, @symcore.pow(lam, @symcore.int(-1))])),
        k,
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, @symcore.int(0))),
          (
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                @symcore.mul([
                  @symcore.int(-1),
                  @symcore.function("exp", [
                    eval_arith(@symcore.mul([@symcore.int(-1), ratio_pow])),
                  ]),
                ]),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    }
    "Moyal" if params.length() == 2 => {
      let mu = params[0]
      let sigma = params[1]
      let arg = eval_arith(
        @symcore.mul([
          @symcore.function("exp", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                cont_expr_sub(x, mu),
                @symcore.pow(
                  eval_arith(@symcore.mul([@symcore.int(2), sigma])),
                  @symcore.int(-1),
                ),
              ]),
            ),
          ]),
          @symcore.pow(
            @symcore.function("sqrt", [@symcore.int(2)]),
            @symcore.int(-1),
          ),
        ]),
      )
      Some(@symcore.function("erfc", [arg]))
    }
    "Trapezoidal" if params.length() == 4 => {
      let a = params[0]
      let b = params[1]
      let c = params[2]
      let d = params[3]
      let span = eval_arith(
        @symcore.add([
          d,
          c,
          @symcore.mul([@symcore.int(-1), b]),
          @symcore.mul([@symcore.int(-1), a]),
        ]),
      )
      let left = eval_arith(
        @symcore.mul([
          @symcore.pow(cont_expr_sub(x, a), @symcore.int(2)),
          @symcore.pow(
            eval_arith(@symcore.mul([span, cont_expr_sub(b, a)])),
            @symcore.int(-1),
          ),
        ]),
      )
      let mid = eval_arith(
        @symcore.mul([
          eval_arith(
            @symcore.add([
              eval_arith(@symcore.mul([@symcore.int(2), x])),
              @symcore.mul([@symcore.int(-1), a]),
              @symcore.mul([@symcore.int(-1), b]),
            ]),
          ),
          @symcore.pow(span, @symcore.int(-1)),
        ]),
      )
      let right = eval_arith(
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([
            @symcore.int(-1),
            @symcore.pow(cont_expr_sub(d, x), @symcore.int(2)),
            @symcore.pow(
              eval_arith(@symcore.mul([span, cont_expr_sub(d, c)])),
              @symcore.int(-1),
            ),
          ]),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, a)),
          (left, cont_rel("Le", x, b)),
          (mid, cont_rel("Le", x, c)),
          (right, cont_rel("Le", x, d)),
          (@symcore.int(1), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "BetaNoncentral" if params.length() == 3 =>
      Some(
        symbolic_continuous_integral_cdf(
          "BetaNoncentral",
          params,
          x,
          @symcore.int(0),
        ),
      )
    "ChiNoncentral" if params.length() == 2 =>
      Some(
        symbolic_continuous_integral_cdf(
          "ChiNoncentral",
          params,
          x,
          @symcore.int(0),
        ),
      )
    "Davis" if params.length() == 3 =>
      Some(
        symbolic_continuous_integral_cdf("Davis", params, x, @symcore.int(0)),
      )
    "FDistribution" if params.length() == 2 =>
      Some(
        symbolic_continuous_integral_cdf(
          "FDistribution",
          params,
          x,
          @symcore.int(0),
        ),
      )
    "FisherZ" if params.length() == 2 =>
      Some(
        symbolic_continuous_integral_cdf(
          "FisherZ",
          params,
          x,
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ]),
          ),
          guard_lower=false,
        ),
      )
    "UniformSum" if params.length() == 1 => {
      let n = params[0]
      let kk = @symcore.Expr::Symbol("_k")
      let summand = eval_arith(
        @symcore.mul([
          @symcore.pow(@symcore.int(-1), kk),
          @symcore.function("binomial", [n, kk]),
          @symcore.pow(cont_expr_sub(x, kk), n),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, @symcore.int(0))),
          (
            eval_arith(
              @symcore.mul([
                @symcore.pow(
                  @symcore.function("factorial", [n]),
                  @symcore.int(-1),
                ),
                @symcore.function("Sum", [
                  summand,
                  @symcore.function("Tuple", [
                    kk,
                    @symcore.int(0),
                    @symcore.function("floor", [x]),
                  ]),
                ]),
              ]),
            ),
            cont_rel("Le", x, n),
          ),
          (@symcore.int(1), @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    "VonMises" if params.length() == 2 =>
      Some(
        symbolic_continuous_integral_cdf("VonMises", params, x, @symcore.int(0)),
      )
    "WignerSemicircle" if params.length() == 1 =>
      Some(
        symbolic_continuous_integral_cdf(
          "WignerSemicircle",
          params,
          x,
          eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
        ),
      )
    _ => None
  }
}

///|
fn symbolic_cdf_expr(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = [x]
  for p in params {
    args.push(p)
  }
  @symcore.function("\{name}CDF", args)
}

///|
fn symbolic_continuous_mean_bounds(
  name : String,
  params : Array[@symcore.Expr],
) -> (@symcore.Expr, @symcore.Expr)? {
  match continuous_tag_from_name(name) {
    ContinuousTag::Benini if params.length() == 3 =>
      Some(
        (
          params[2],
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::BetaNoncentral if params.length() == 3 =>
      Some((@symcore.int(0), @symcore.int(1)))
    ContinuousTag::BetaPrime if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::ChiNoncentral if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::Dagum if params.length() == 3 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::Davis if params.length() == 3 =>
      Some(
        (
          params[2],
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::ExponentialPower if params.length() == 3 =>
      Some(
        (
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ]),
          ),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::FDistribution if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::FisherZ if params.length() == 2 =>
      Some(
        (
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
            ]),
          ),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::Frechet if params.length() == 1 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::GammaInverse if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::Levy if params.length() == 2 =>
      Some(
        (
          params[0],
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::LogCauchy if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::LogitNormal if params.length() == 2 =>
      Some((@symcore.int(0), @symcore.int(1)))
    ContinuousTag::Lomax if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::Maxwell if params.length() == 1 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::Nakagami if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::PowerFunction if params.length() == 3 =>
      Some((params[1], params[2]))
    ContinuousTag::QuadraticU if params.length() == 2 =>
      Some((params[0], params[1]))
    ContinuousTag::ShiftedGompertz if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
        ),
      )
    ContinuousTag::VonMises if params.length() == 2 =>
      Some(
        (
          @symcore.int(0),
          eval_arith(
            @symcore.mul([
              @symcore.int(2),
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
            ]),
          ),
        ),
      )
    _ => None
  }
}

///|
fn symbolic_continuous_mean_via_integral(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_continuous_mean_bounds(name, params) {
    Some((lower, upper)) => {
      let dummy = @symcore.Expr::Symbol("_x")
      let density_expr = match
        symbolic_continuous_density(name, params, dummy) {
        Some(v) => v
        None =>
          match generated_density(name, params, dummy) {
            Some(v) => v
            None => symbolic_density_expr(name, params, dummy)
          }
      }
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(@symcore.mul([dummy, density_expr])),
            @symcore.function("Tuple", [dummy, lower, upper]),
          ]),
        ),
      )
    }
    None => None
  }
}

///|
fn symbolic_continuous_variance_via_integral(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_continuous_mean_bounds(name, params) {
    Some((lower, upper)) => {
      let kind = symbolic_kind_from_name(name)
      let rv = random_var("_X", RVKind::Symbolic(kind~, params~))
      let mean_expr = match continuous_mean(rv) {
        Some(v) => v
        None => symbolic_stat_expr(name, "Mean", params)
      }
      let dummy = @symcore.Expr::Symbol("_x")
      let density_expr = match continuous_density(rv, dummy) {
        Some(v) => v
        None =>
          match symbolic_continuous_density(name, params, dummy) {
            Some(v) => v
            None =>
              match generated_density(name, params, dummy) {
                Some(v) => v
                None => symbolic_density_expr(name, params, dummy)
              }
          }
      }
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(
              @symcore.mul([
                @symcore.pow(cont_expr_sub(dummy, mean_expr), @symcore.int(2)),
                density_expr,
              ]),
            ),
            @symcore.function("Tuple", [dummy, lower, upper]),
          ]),
        ),
      )
    }
    None => None
  }
}

///|
fn symbolic_stat_expr(
  name : String,
  suffix : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  @symcore.function("\{name}\{suffix}", params)
}

///|
pub fn continuous_density(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Normal(mu~, sigma~) => {
      let two = @symcore.int(2)
      let pi = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
      let diff = cont_expr_sub(x, mu)
      let numer = @symcore.function("exp", [
        @symcore.mul([
          @symcore.int(-1),
          @symcore.pow(diff, two),
          @symcore.pow(
            @symcore.mul([two, @symcore.pow(sigma, two)]),
            @symcore.int(-1),
          ),
        ]),
      ])
      let denom = @symcore.mul([
        @symcore.function("sqrt", [@symcore.mul([two, pi])]),
        sigma,
      ])
      Some(
        eval_arith(@symcore.mul([numer, @symcore.pow(denom, @symcore.int(-1))])),
      )
    }
    RVKind::Exponential(rate~) => {
      let raw = eval_arith(
        @symcore.mul([
          rate,
          @symcore.function("exp", [@symcore.mul([@symcore.int(-1), rate, x])]),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
          (raw, @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    RVKind::Gamma(shape~, scale~) => {
      let base = eval_arith(
        @symcore.mul([
          @symcore.pow(x, cont_expr_sub(shape, @symcore.int(1))),
          @symcore.function("exp", [
            @symcore.mul([
              @symcore.int(-1),
              x,
              @symcore.pow(scale, @symcore.int(-1)),
            ]),
          ]),
          @symcore.pow(@symcore.function("gamma", [shape]), @symcore.int(-1)),
          @symcore.pow(scale, @symcore.mul([@symcore.int(-1), shape])),
        ]),
      )
      Some(
        cont_piecewise([
          (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
          (base, @symcore.Expr::Boolean(true)),
        ]),
      )
    }
    RVKind::Symbolic(kind~, params~) =>
      match kind {
        SymbolicKind::Continuous(
          ContinuousTag::ContinuousRV
          | ContinuousTag::ContinuousDistributionHandmade
        ) => None
        SymbolicKind::Continuous(tag) => {
          let name = continuous_tag_name(tag)
          match symbolic_continuous_density(name, params, x) {
            Some(v) => Some(cont_guard_params(name, params, v))
            None =>
              match generated_density(name, params, x) {
                Some(v) => Some(cont_guard_params(name, params, v))
                None =>
                  Some(
                    cont_guard_params(
                      name,
                      params,
                      symbolic_density_expr(name, params, x),
                    ),
                  )
              }
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
pub fn continuous_cdf(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Normal(mu~, sigma~) => {
      let two = @symcore.int(2)
      let arg = eval_arith(
        @symcore.mul([
          cont_expr_sub(x, mu),
          @symcore.pow(
            @symcore.mul([@symcore.function("sqrt", [two]), sigma]),
            @symcore.int(-1),
          ),
        ]),
      )
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(1),
            @symcore.pow(two, @symcore.int(-1)),
            @symcore.add([@symcore.int(1), @symcore.function("erf", [arg])]),
          ]),
        ),
      )
    }
    RVKind::Exponential(rate~) =>
      Some(
        cont_piecewise([
          (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
          (
            cont_one_minus(
              @symcore.function("exp", [
                @symcore.mul([@symcore.int(-1), rate, x]),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    RVKind::Gamma(shape~, scale~) =>
      Some(
        cont_piecewise([
          (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
          (
            eval_arith(
              @symcore.mul([
                @symcore.function("lowergamma", [
                  shape,
                  eval_arith(
                    @symcore.mul([x, @symcore.pow(scale, @symcore.int(-1))]),
                  ),
                ]),
                @symcore.pow(
                  @symcore.function("gamma", [shape]),
                  @symcore.int(-1),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ),
        ]),
      )
    RVKind::Symbolic(kind~, params~) =>
      match kind {
        SymbolicKind::Continuous(
          ContinuousTag::ContinuousRV
          | ContinuousTag::ContinuousDistributionHandmade
        ) => None
        SymbolicKind::Continuous(tag) => {
          let name = continuous_tag_name(tag)
          match symbolic_continuous_cdf(name, params, x) {
            Some(v) => Some(cont_guard_params(name, params, v))
            None =>
              match generated_cdf(name, params, x) {
                Some(v) => Some(cont_guard_params(name, params, v))
                None =>
                  Some(
                    cont_guard_params(
                      name,
                      params,
                      symbolic_cdf_expr(name, params, x),
                    ),
                  )
              }
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
pub fn continuous_probability(rv : RandomVar, event : Event) -> @symcore.Expr? {
  if !event_depends_only_on(event, rv.name) {
    return None
  }
  match event {
    Event::Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Event::Not(inner) =>
      match continuous_probability(rv, inner) {
        Some(p) => Some(eval_arith(cont_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Event::Rel(..) =>
      match cont_extract_rel_to_var(event, rv.name) {
        Some((op, bnd)) =>
          match op {
            RelOp::Eq => Some(@symcore.int(0))
            RelOp::Ne => Some(@symcore.int(1))
            RelOp::Le | RelOp::Lt => continuous_cdf(rv, bnd)
            RelOp::Ge | RelOp::Gt =>
              match continuous_cdf(rv, bnd) {
                Some(cdf) =>
                  Some(eval_arith(cont_expr_sub(@symcore.int(1), cdf)))
                None => None
              }
          }
        None => None
      }
    Event::And(items) =>
      if items.length() == 2 {
        let first = cont_extract_rel_to_var(items[0], rv.name)
        let second = cont_extract_rel_to_var(items[1], rv.name)
        match (first, second) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower_opt = match (op1, op2) {
              (RelOp::Gt | RelOp::Ge, _) => Some(b1)
              (_, RelOp::Gt | RelOp::Ge) => Some(b2)
              _ => None
            }
            let upper_opt = match (op1, op2) {
              (RelOp::Lt | RelOp::Le, _) => Some(b1)
              (_, RelOp::Lt | RelOp::Le) => Some(b2)
              _ => None
            }
            match (lower_opt, upper_opt) {
              (Some(lower), Some(upper)) =>
                match (continuous_cdf(rv, lower), continuous_cdf(rv, upper)) {
                  (Some(cl), Some(cu)) =>
                    Some(eval_arith(cont_expr_sub(cu, cl)))
                  _ => None
                }
              _ => None
            }
          }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn continuous_mean(rv : RandomVar) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Normal(mu~, sigma~) => {
      ignore(sigma)
      Some(mu)
    }
    RVKind::Exponential(rate~) =>
      Some(eval_arith(@symcore.pow(rate, @symcore.int(-1))))
    RVKind::Gamma(shape~, scale~) =>
      Some(eval_arith(@symcore.mul([shape, scale])))
    RVKind::Symbolic(kind~, params~) =>
      match kind {
        SymbolicKind::Continuous(tag) => {
          let name = continuous_tag_name(tag)
          match generated_mean(name, params) {
            Some(v) => Some(cont_guard_params(name, params, v))
            None => {
              let raw = match
                symbolic_continuous_mean_via_integral(name, params) {
                Some(v) => v
                None =>
                  match tag {
                    ContinuousTag::Arcsin if params.length() == 2 =>
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 2),
                          @symcore.add([params[0], params[1]]),
                        ]),
                      )
                    ContinuousTag::Uniform if params.length() == 2 =>
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 2),
                          @symcore.add([params[0], params[1]]),
                        ]),
                      )
                    ContinuousTag::Beta if params.length() == 2 =>
                      eval_arith(
                        @symcore.mul([
                          params[0],
                          @symcore.pow(
                            @symcore.add([params[0], params[1]]),
                            @symcore.int(-1),
                          ),
                        ]),
                      )
                    ContinuousTag::Kumaraswamy if params.length() == 2 =>
                      eval_arith(
                        @symcore.mul([
                          params[1],
                          @symcore.function("beta", [
                            eval_arith(
                              @symcore.add([
                                @symcore.int(1),
                                @symcore.pow(params[0], @symcore.int(-1)),
                              ]),
                            ),
                            params[1],
                          ]),
                        ]),
                      )
                    ContinuousTag::Laplace if params.length() == 2 => params[0]
                    ContinuousTag::Cauchy if params.length() == 2 =>
                      @symcore.Expr::NumberSymbol(
                        @symcore.NumberSymbolKind::NaN,
                      )
                    ContinuousTag::Pareto if params.length() == 2 =>
                      eval_arith(
                        @symcore.mul([
                          params[1],
                          params[0],
                          @symcore.pow(
                            @symcore.add([params[1], @symcore.int(-1)]),
                            @symcore.int(-1),
                          ),
                        ]),
                      )
                    ContinuousTag::Rayleigh if params.length() == 1 =>
                      eval_arith(
                        @symcore.mul([
                          params[0],
                          @symcore.function("sqrt", [
                            @symcore.mul([
                              @symcore.Expr::NumberSymbol(
                                @symcore.NumberSymbolKind::Pi,
                              ),
                              stats_exact_rational(1, 2),
                            ]),
                          ]),
                        ]),
                      )
                    ContinuousTag::LogNormal if params.length() == 2 =>
                      eval_arith(
                        @symcore.function("exp", [
                          eval_arith(
                            @symcore.add([
                              params[0],
                              @symcore.mul([
                                stats_exact_rational(1, 2),
                                @symcore.pow(params[1], @symcore.int(2)),
                              ]),
                            ]),
                          ),
                        ]),
                      )
                    ContinuousTag::Weibull if params.length() == 2 =>
                      eval_arith(
                        @symcore.mul([
                          params[0],
                          @symcore.function("gamma", [
                            eval_arith(
                              @symcore.add([
                                @symcore.int(1),
                                @symcore.pow(params[1], @symcore.int(-1)),
                              ]),
                            ),
                          ]),
                        ]),
                      )
                    ContinuousTag::StudentT if params.length() == 1 =>
                      @symcore.int(0)
                    ContinuousTag::Trapezoidal if params.length() == 4 => {
                      let a = params[0]
                      let b = params[1]
                      let c = params[2]
                      let d = params[3]
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 3),
                          eval_arith(
                            @symcore.add([
                              @symcore.pow(
                                eval_arith(
                                  @symcore.add([
                                    a,
                                    b,
                                    @symcore.mul([@symcore.int(-1), c]),
                                    @symcore.mul([@symcore.int(-1), d]),
                                  ]),
                                ),
                                @symcore.int(-1),
                              ),
                            ]),
                          ),
                          eval_arith(
                            @symcore.add([
                              @symcore.pow(a, @symcore.int(2)),
                              @symcore.mul([a, b]),
                              @symcore.pow(b, @symcore.int(2)),
                              @symcore.mul([
                                @symcore.int(-1),
                                @symcore.pow(c, @symcore.int(2)),
                              ]),
                              @symcore.mul([@symcore.int(-1), c, d]),
                              @symcore.mul([
                                @symcore.int(-1),
                                @symcore.pow(d, @symcore.int(2)),
                              ]),
                            ]),
                          ),
                        ]),
                      )
                    }
                    _ => symbolic_stat_expr(name, "Mean", params)
                  }
              }
              Some(cont_guard_params(name, params, raw))
            }
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
pub fn continuous_variance(rv : RandomVar) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Normal(mu~, sigma~) => {
      ignore(mu)
      Some(eval_arith(@symcore.pow(sigma, @symcore.int(2))))
    }
    RVKind::Exponential(rate~) =>
      Some(eval_arith(@symcore.pow(rate, @symcore.int(-2))))
    RVKind::Gamma(shape~, scale~) =>
      Some(
        eval_arith(@symcore.mul([shape, @symcore.pow(scale, @symcore.int(2))])),
      )
    RVKind::Symbolic(kind~, params~) =>
      match kind {
        SymbolicKind::Continuous(tag) => {
          let name = continuous_tag_name(tag)
          match generated_variance(name, params) {
            Some(v) => Some(cont_guard_params(name, params, v))
            None => {
              let raw = match tag {
                ContinuousTag::Arcsin if params.length() == 0 =>
                  stats_exact_rational(1, 8)
                ContinuousTag::Arcsin if params.length() == 2 =>
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 8),
                      @symcore.pow(
                        cont_expr_sub(params[1], params[0]),
                        @symcore.int(2),
                      ),
                    ]),
                  )
                ContinuousTag::Uniform if params.length() == 2 =>
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 12),
                      @symcore.pow(
                        cont_expr_sub(params[1], params[0]),
                        @symcore.int(2),
                      ),
                    ]),
                  )
                ContinuousTag::Beta if params.length() == 2 => {
                  let a = params[0]
                  let b = params[1]
                  eval_arith(
                    @symcore.mul([
                      a,
                      b,
                      @symcore.pow(@symcore.add([a, b]), @symcore.int(-2)),
                      @symcore.pow(
                        @symcore.add([a, b, @symcore.int(1)]),
                        @symcore.int(-1),
                      ),
                    ]),
                  )
                }
                ContinuousTag::Kumaraswamy if params.length() == 2 => {
                  let a = params[0]
                  let b = params[1]
                  let m1 = eval_arith(
                    @symcore.mul([
                      b,
                      @symcore.function("beta", [
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            @symcore.pow(a, @symcore.int(-1)),
                          ]),
                        ),
                        b,
                      ]),
                    ]),
                  )
                  let m2 = eval_arith(
                    @symcore.mul([
                      b,
                      @symcore.function("beta", [
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(2),
                                @symcore.pow(a, @symcore.int(-1)),
                              ]),
                            ),
                          ]),
                        ),
                        b,
                      ]),
                    ]),
                  )
                  eval_arith(
                    @symcore.add([
                      m2,
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(m1, @symcore.int(2)),
                      ]),
                    ]),
                  )
                }
                ContinuousTag::Laplace if params.length() == 2 =>
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      @symcore.pow(params[1], @symcore.int(2)),
                    ]),
                  )
                ContinuousTag::Cauchy if params.length() == 2 =>
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN)
                ContinuousTag::Pareto if params.length() == 2 => {
                  let xm = params[0]
                  let a = params[1]
                  eval_arith(
                    @symcore.mul([
                      @symcore.pow(xm, @symcore.int(2)),
                      a,
                      @symcore.pow(
                        @symcore.add([a, @symcore.int(-2)]),
                        @symcore.int(-1),
                      ),
                      @symcore.pow(
                        @symcore.add([a, @symcore.int(-1)]),
                        @symcore.int(-2),
                      ),
                    ]),
                  )
                }
                ContinuousTag::BoundedPareto if params.length() == 3 => {
                  let a = params[0]
                  let l = params[1]
                  let h = params[2]
                  let one_minus = eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(
                          eval_arith(
                            @symcore.mul([l, @symcore.pow(h, @symcore.int(-1))]),
                          ),
                          a,
                        ),
                      ]),
                    ]),
                  )
                  let common = eval_arith(
                    @symcore.mul([
                      a,
                      @symcore.pow(l, a),
                      @symcore.pow(one_minus, @symcore.int(-1)),
                    ]),
                  )
                  let e1 = eval_arith(
                    @symcore.mul([
                      common,
                      eval_arith(
                        @symcore.add([
                          @symcore.pow(
                            h,
                            eval_arith(
                              @symcore.add([
                                @symcore.int(1),
                                @symcore.mul([@symcore.int(-1), a]),
                              ]),
                            ),
                          ),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(
                              l,
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(1),
                                  @symcore.mul([@symcore.int(-1), a]),
                                ]),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), a]),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ]),
                  )
                  let e2 = eval_arith(
                    @symcore.mul([
                      common,
                      eval_arith(
                        @symcore.add([
                          @symcore.pow(
                            h,
                            eval_arith(
                              @symcore.add([
                                @symcore.int(2),
                                @symcore.mul([@symcore.int(-1), a]),
                              ]),
                            ),
                          ),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(
                              l,
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(2),
                                  @symcore.mul([@symcore.int(-1), a]),
                                ]),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(2),
                            @symcore.mul([@symcore.int(-1), a]),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ]),
                  )
                  eval_arith(
                    @symcore.add([
                      e2,
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(e1, @symcore.int(2)),
                      ]),
                    ]),
                  )
                }
                ContinuousTag::Rayleigh if params.length() == 1 =>
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      @symcore.add([
                        @symcore.int(4),
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.Expr::NumberSymbol(
                            @symcore.NumberSymbolKind::Pi,
                          ),
                        ]),
                      ]),
                      @symcore.pow(params[0], @symcore.int(2)),
                    ]),
                  )
                ContinuousTag::LogNormal if params.length() == 2 => {
                  let mu = params[0]
                  let sigma = params[1]
                  eval_arith(
                    @symcore.mul([
                      eval_arith(
                        @symcore.add([
                          @symcore.function("exp", [
                            @symcore.pow(sigma, @symcore.int(2)),
                          ]),
                          @symcore.int(-1),
                        ]),
                      ),
                      @symcore.function("exp", [
                        eval_arith(
                          @symcore.add([
                            @symcore.mul([@symcore.int(2), mu]),
                            @symcore.pow(sigma, @symcore.int(2)),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                }
                ContinuousTag::Weibull if params.length() == 2 => {
                  let lam = params[0]
                  let k = params[1]
                  let g1 = @symcore.function("gamma", [
                    eval_arith(
                      @symcore.add([
                        @symcore.int(1),
                        @symcore.pow(k, @symcore.int(-1)),
                      ]),
                    ),
                  ])
                  let g2 = @symcore.function("gamma", [
                    eval_arith(
                      @symcore.add([
                        @symcore.int(1),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(2),
                            @symcore.pow(k, @symcore.int(-1)),
                          ]),
                        ),
                      ]),
                    ),
                  ])
                  eval_arith(
                    @symcore.mul([
                      @symcore.pow(lam, @symcore.int(2)),
                      eval_arith(
                        @symcore.add([
                          g2,
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(g1, @symcore.int(2)),
                          ]),
                        ]),
                      ),
                    ]),
                  )
                }
                ContinuousTag::StudentT if params.length() == 1 =>
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.pow(
                        @symcore.add([params[0], @symcore.int(-2)]),
                        @symcore.int(-1),
                      ),
                    ]),
                  )
                ContinuousTag::PowerFunction if params.length() == 3 =>
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[2],
                            @symcore.mul([@symcore.int(-1), params[1]]),
                          ]),
                        ),
                        @symcore.int(2),
                      ),
                      @symcore.pow(
                        eval_arith(@symcore.add([params[0], @symcore.int(2)])),
                        @symcore.int(-1),
                      ),
                      @symcore.pow(
                        eval_arith(@symcore.add([params[0], @symcore.int(1)])),
                        @symcore.int(-2),
                      ),
                    ]),
                  )
                ContinuousTag::Trapezoidal if params.length() == 4 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let d = params[3]
                  let abcd = eval_arith(
                    @symcore.add([
                      a,
                      b,
                      @symcore.mul([@symcore.int(-1), c]),
                      @symcore.mul([@symcore.int(-1), d]),
                    ]),
                  )
                  let m_num = eval_arith(
                    @symcore.add([
                      @symcore.pow(a, @symcore.int(2)),
                      @symcore.mul([a, b]),
                      @symcore.pow(b, @symcore.int(2)),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(c, @symcore.int(2)),
                      ]),
                      @symcore.mul([@symcore.int(-1), c, d]),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(d, @symcore.int(2)),
                      ]),
                    ]),
                  )
                  let e1 = eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 3),
                      @symcore.pow(abcd, @symcore.int(-1)),
                      m_num,
                    ]),
                  )
                  let e2 = eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 6),
                      @symcore.pow(abcd, @symcore.int(-1)),
                      eval_arith(
                        @symcore.add([
                          @symcore.pow(a, @symcore.int(3)),
                          @symcore.mul([@symcore.pow(a, @symcore.int(2)), b]),
                          @symcore.mul([a, @symcore.pow(b, @symcore.int(2))]),
                          @symcore.pow(b, @symcore.int(3)),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(c, @symcore.int(3)),
                          ]),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(c, @symcore.int(2)),
                            d,
                          ]),
                          @symcore.mul([
                            @symcore.int(-1),
                            c,
                            @symcore.pow(d, @symcore.int(2)),
                          ]),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(d, @symcore.int(3)),
                          ]),
                        ]),
                      ),
                    ]),
                  )
                  eval_arith(
                    @symcore.add([
                      e2,
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(e1, @symcore.int(2)),
                      ]),
                    ]),
                  )
                }
                _ =>
                  match
                    symbolic_continuous_variance_via_integral(name, params) {
                    Some(v) => v
                    None => symbolic_stat_expr(name, "Variance", params)
                  }
              }
              Some(cont_guard_params(name, params, raw))
            }
          }
        }
        _ => None
      }
    _ => None
  }
}
