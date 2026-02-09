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
fn cont_tuple_expr(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Tuple", [a, b])
}

///|
fn cont_piecewise(pairs : Array[(@symcore.Expr, @symcore.Expr)]) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = Array::new()
  for pair in pairs {
    let (value, cond) = pair
    args.push(cont_tuple_expr(value, cond))
  }
  @symcore.function("Piecewise", args)
}

///|
fn cont_rel(name : String, lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  @symcore.function(name, [lhs, rhs])
}

///|
fn cont_and(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("And", [a, b])
}

///|
fn cont_param_condition(name : String, params : Array[@symcore.Expr]) -> @symcore.Expr? {
  match name {
    "Arcsin" if params.length() == 2 => Some(cont_rel("Lt", params[0], params[1]))
    "Uniform" if params.length() == 2 => Some(cont_rel("Lt", params[0], params[1]))
    "Beta" if params.length() == 2 =>
      Some(cont_and(cont_rel("Gt", params[0], @symcore.int(0)), cont_rel("Gt", params[1], @symcore.int(0))))
    "Laplace" if params.length() == 2 => Some(cont_rel("Gt", params[1], @symcore.int(0)))
    "Cauchy" if params.length() == 2 => Some(cont_rel("Gt", params[1], @symcore.int(0)))
    "Pareto" if params.length() == 2 =>
      Some(cont_and(cont_rel("Gt", params[0], @symcore.int(0)), cont_rel("Gt", params[1], @symcore.int(0))))
    "BoundedPareto" if params.length() == 3 =>
      Some(cont_and(
        cont_rel("Gt", params[0], @symcore.int(0)),
        cont_and(cont_rel("Gt", params[1], @symcore.int(0)), cont_rel("Lt", params[1], params[2])),
      ))
    "Kumaraswamy" if params.length() == 2 =>
      Some(cont_and(cont_rel("Gt", params[0], @symcore.int(0)), cont_rel("Gt", params[1], @symcore.int(0))))
    "Rayleigh" if params.length() == 1 => Some(cont_rel("Gt", params[0], @symcore.int(0)))
    "LogNormal" if params.length() == 2 => Some(cont_rel("Gt", params[1], @symcore.int(0)))
    "Weibull" if params.length() == 2 =>
      Some(cont_and(cont_rel("Gt", params[0], @symcore.int(0)), cont_rel("Gt", params[1], @symcore.int(0))))
    "PowerFunction" if params.length() == 3 =>
      Some(cont_and(cont_rel("Gt", params[0], @symcore.int(0)), cont_rel("Lt", params[1], params[2])))
    "StudentT" if params.length() == 1 => Some(cont_rel("Gt", params[0], @symcore.int(0)))
    "Moyal" if params.length() == 2 => Some(cont_rel("Gt", params[1], @symcore.int(0)))
    "WignerSemicircle" if params.length() == 1 => Some(cont_rel("Gt", params[0], @symcore.int(0)))
    "Trapezoidal" if params.length() == 4 =>
      Some(cont_and(
        cont_and(cont_rel("Lt", params[0], params[1]), cont_rel("Le", params[1], params[2])),
        cont_rel("Lt", params[2], params[3]),
      ))
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
  match name {
    "Arcsin" if params.length() == 2 => cont_numeric_lt(params[0], params[1])
    "Uniform" if params.length() == 2 => cont_numeric_lt(params[0], params[1])
    "Beta" if params.length() == 2 =>
      cont_bool_and(cont_numeric_gt_zero(params[0]), cont_numeric_gt_zero(params[1]))
    "Laplace" if params.length() == 2 => cont_numeric_gt_zero(params[1])
    "Cauchy" if params.length() == 2 => cont_numeric_gt_zero(params[1])
    "Pareto" if params.length() == 2 =>
      cont_bool_and(cont_numeric_gt_zero(params[0]), cont_numeric_gt_zero(params[1]))
    "BoundedPareto" if params.length() == 3 =>
      cont_bool_and(
        cont_numeric_gt_zero(params[0]),
        cont_bool_and(cont_numeric_gt_zero(params[1]), cont_numeric_lt(params[1], params[2])),
      )
    "Kumaraswamy" if params.length() == 2 =>
      cont_bool_and(cont_numeric_gt_zero(params[0]), cont_numeric_gt_zero(params[1]))
    "Rayleigh" if params.length() == 1 => cont_numeric_gt_zero(params[0])
    "LogNormal" if params.length() == 2 => cont_numeric_gt_zero(params[1])
    "Weibull" if params.length() == 2 =>
      cont_bool_and(cont_numeric_gt_zero(params[0]), cont_numeric_gt_zero(params[1]))
    "PowerFunction" if params.length() == 3 =>
      cont_bool_and(cont_numeric_gt_zero(params[0]), cont_numeric_lt(params[1], params[2]))
    "StudentT" if params.length() == 1 => cont_numeric_gt_zero(params[0])
    "Moyal" if params.length() == 2 => cont_numeric_gt_zero(params[1])
    "WignerSemicircle" if params.length() == 1 => cont_numeric_gt_zero(params[0])
    "Trapezoidal" if params.length() == 4 =>
      cont_bool_and(
        cont_bool_and(cont_numeric_lt(params[0], params[1]), match cont_numeric_cmp(params[1], params[2]) {
          Some(v) => Some(v <= 0)
          None => None
        }),
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
    Some(false) => @symcore.symbol("nan")
    None =>
      match cont_param_condition(name, params) {
        Some(valid_cond) =>
          cont_piecewise([
            (expr, valid_cond),
            (@symcore.symbol("nan"), @symcore.symbol("True")),
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
      let denom = eval_arith(@symcore.mul([
        @symcore.symbol("pi"),
        @symcore.function("sqrt", [eval_arith(@symcore.mul([
          @symcore.int(-1),
          cont_expr_sub(x, b),
          cont_expr_sub(x, a),
        ]))]),
      ]))
      let body = eval_arith(@symcore.mul([
        @symcore.pow(denom, @symcore.int(-1)),
      ]))
      Some(
        cont_piecewise([
          (
            body,
            cont_and(cont_rel("Le", a, x), cont_rel("Le", x, b)),
          ),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "Uniform" if params.length() == 2 => {
      let a = params[0]
      let b = params[1]
      let body = eval_arith(@symcore.pow(eval_arith(cont_expr_sub(b, a)), @symcore.int(-1)))
      Some(
        cont_piecewise([
          (
            body,
            cont_and(cont_rel("Le", a, x), cont_rel("Le", x, b)),
          ),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "Beta" if params.length() == 2 => {
      let alpha = params[0]
      let beta = params[1]
      let body = eval_arith(@symcore.mul([
        @symcore.pow(x, cont_expr_sub(alpha, @symcore.int(1))),
        @symcore.pow(cont_expr_sub(@symcore.int(1), x), cont_expr_sub(beta, @symcore.int(1))),
        @symcore.pow(@symcore.function("beta", [alpha, beta]), @symcore.int(-1)),
      ]))
      Some(
        cont_piecewise([
          (
            body,
            cont_and(cont_rel("Le", @symcore.int(0), x), cont_rel("Le", x, @symcore.int(1))),
          ),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "Laplace" if params.length() == 2 => {
      let mu = params[0]
      let b = params[1]
      Some(
        eval_arith(@symcore.mul([
          @symcore.pow(eval_arith(@symcore.mul([@symcore.int(2), b])), @symcore.int(-1)),
          @symcore.function("exp", [
            eval_arith(@symcore.mul([
              @symcore.int(-1),
              @symcore.function("Abs", [cont_expr_sub(x, mu)]),
              @symcore.pow(b, @symcore.int(-1)),
            ])),
          ]),
        ])),
      )
    }
    "Cauchy" if params.length() == 2 => {
      let x0 = params[0]
      let gamma = params[1]
      let ratio = eval_arith(@symcore.mul([cont_expr_sub(x, x0), @symcore.pow(gamma, @symcore.int(-1))]))
      let denom = eval_arith(@symcore.mul([
        @symcore.symbol("pi"),
        gamma,
        eval_arith(@symcore.add([@symcore.int(1), @symcore.pow(ratio, @symcore.int(2))])),
      ]))
      Some(eval_arith(@symcore.pow(denom, @symcore.int(-1))))
    }
    "Pareto" if params.length() == 2 => {
      let xm = params[0]
      let alpha = params[1]
      let body = eval_arith(@symcore.mul([
        alpha,
        @symcore.pow(xm, alpha),
        @symcore.pow(x, eval_arith(@symcore.mul([@symcore.int(-1), @symcore.add([alpha, @symcore.int(1)])]))),
      ]))
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, xm)),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "Rayleigh" if params.length() == 1 => {
      let sigma = params[0]
      let body = eval_arith(@symcore.mul([
        x,
        @symcore.pow(sigma, @symcore.int(-2)),
        @symcore.function("exp", [
          eval_arith(@symcore.mul([
            @symcore.int(-1),
            @symcore.pow(x, @symcore.int(2)),
            @symcore.pow(eval_arith(@symcore.mul([@symcore.int(2), @symcore.pow(sigma, @symcore.int(2))])), @symcore.int(-1)),
          ])),
        ]),
      ]))
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, @symcore.int(0))),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "LogNormal" if params.length() == 2 => {
      let mu = params[0]
      let sigma = params[1]
      let logterm = cont_expr_sub(@symcore.function("log", [x]), mu)
      let body = eval_arith(@symcore.mul([
        @symcore.pow(eval_arith(@symcore.mul([
          x,
          sigma,
          @symcore.function("sqrt", [eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi")]))]),
        ])), @symcore.int(-1)),
        @symcore.function("exp", [
          eval_arith(@symcore.mul([
            @symcore.int(-1),
            @symcore.pow(logterm, @symcore.int(2)),
            @symcore.pow(eval_arith(@symcore.mul([@symcore.int(2), @symcore.pow(sigma, @symcore.int(2))])), @symcore.int(-1)),
          ])),
        ]),
      ]))
      Some(
        cont_piecewise([
          (body, cont_rel("Gt", x, @symcore.int(0))),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "Weibull" if params.length() == 2 => {
      let lam = params[0]
      let k = params[1]
      let ratio = eval_arith(@symcore.mul([x, @symcore.pow(lam, @symcore.int(-1))]))
      let body = eval_arith(@symcore.mul([
        k,
        @symcore.pow(lam, @symcore.int(-1)),
        @symcore.pow(ratio, cont_expr_sub(k, @symcore.int(1))),
        @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.int(-1), @symcore.pow(ratio, k)]))]),
      ]))
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, @symcore.int(0))),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "StudentT" if params.length() == 1 => {
      let nu = params[0]
      let coeff = eval_arith(@symcore.mul([
        @symcore.function("gamma", [eval_arith(@symcore.mul([try! @symcore.rational_from_ints(1, 2), @symcore.add([nu, @symcore.int(1)])]))]),
        @symcore.pow(eval_arith(@symcore.mul([
          @symcore.function("sqrt", [eval_arith(@symcore.mul([nu, @symcore.symbol("pi")]))]),
          @symcore.function("gamma", [eval_arith(@symcore.mul([try! @symcore.rational_from_ints(1, 2), nu]))]),
        ])), @symcore.int(-1)),
      ]))
      let body = eval_arith(@symcore.mul([
        coeff,
        @symcore.pow(
          eval_arith(@symcore.add([
            @symcore.int(1),
            eval_arith(@symcore.mul([@symcore.pow(x, @symcore.int(2)), @symcore.pow(nu, @symcore.int(-1))])),
          ])),
          eval_arith(@symcore.mul([try! @symcore.rational_from_ints(-1, 2), @symcore.add([nu, @symcore.int(1)])])),
        ),
      ]))
      Some(body)
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
fn symbolic_continuous_cdf(
  tag : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match tag {
    "Arcsin" if params.length() == 2 => {
      let a = params[0]
      let b = params[1]
      let ratio = eval_arith(@symcore.mul([
        cont_expr_sub(x, a),
        @symcore.pow(cont_expr_sub(b, a), @symcore.int(-1)),
      ]))
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, a)),
          (
            eval_arith(@symcore.mul([
              try! @symcore.rational_from_ints(2, 1),
              @symcore.pow(@symcore.symbol("pi"), @symcore.int(-1)),
              @symcore.function("asin", [@symcore.function("sqrt", [ratio])]),
            ])),
            cont_rel("Le", x, b),
          ),
          (@symcore.int(1), @symcore.symbol("True")),
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
          (@symcore.int(1), @symcore.symbol("True")),
        ]),
      )
    }
    "Laplace" if params.length() == 2 => {
      let mu = params[0]
      let b = params[1]
      let left = eval_arith(@symcore.mul([
        try! @symcore.rational_from_ints(1, 2),
        @symcore.function("exp", [eval_arith(@symcore.mul([cont_expr_sub(x, mu), @symcore.pow(b, @symcore.int(-1))]))]),
      ]))
      let right = eval_arith(@symcore.add([
        @symcore.int(1),
        @symcore.mul([
          try! @symcore.rational_from_ints(-1, 2),
          @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.int(-1), cont_expr_sub(x, mu), @symcore.pow(b, @symcore.int(-1))]))]),
        ]),
      ]))
      Some(
        cont_piecewise([
          (left, cont_rel("Lt", x, mu)),
          (right, @symcore.symbol("True")),
        ]),
      )
    }
    "Cauchy" if params.length() == 2 => {
      let x0 = params[0]
      let gamma = params[1]
      Some(
        eval_arith(@symcore.add([
          try! @symcore.rational_from_ints(1, 2),
          eval_arith(@symcore.mul([
            @symcore.pow(@symcore.symbol("pi"), @symcore.int(-1)),
            @symcore.function("atan", [eval_arith(@symcore.mul([cont_expr_sub(x, x0), @symcore.pow(gamma, @symcore.int(-1))]))]),
          ])),
        ])),
      )
    }
    "Pareto" if params.length() == 2 => {
      let xm = params[0]
      let alpha = params[1]
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, xm)),
          (
            eval_arith(@symcore.add([
              @symcore.int(1),
              @symcore.mul([
                @symcore.int(-1),
                @symcore.pow(eval_arith(@symcore.mul([xm, @symcore.pow(x, @symcore.int(-1))])), alpha),
              ]),
            ])),
            @symcore.symbol("True"),
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
            eval_arith(@symcore.add([
              @symcore.int(1),
              @symcore.mul([
                @symcore.int(-1),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([
                    @symcore.int(-1),
                    @symcore.pow(x, @symcore.int(2)),
                    @symcore.pow(eval_arith(@symcore.mul([@symcore.int(2), @symcore.pow(sigma, @symcore.int(2))])), @symcore.int(-1)),
                  ])),
                ]),
              ]),
            ])),
            @symcore.symbol("True"),
          ),
        ]),
      )
    }
    "WignerSemicircle" if params.length() == 1 => {
      let r = params[0]
      let r2 = eval_arith(@symcore.pow(r, @symcore.int(2)))
      let term1 = eval_arith(@symcore.mul([
        x,
        @symcore.function("sqrt", [eval_arith(cont_expr_sub(r2, @symcore.pow(x, @symcore.int(2))))]),
        @symcore.pow(eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi"), r2])), @symcore.int(-1)),
      ]))
      let term2 = eval_arith(@symcore.mul([
        @symcore.function("asin", [eval_arith(@symcore.mul([x, @symcore.pow(r, @symcore.int(-1))]))]),
        @symcore.pow(@symcore.symbol("pi"), @symcore.int(-1)),
      ]))
      let body = eval_arith(@symcore.add([
        try! @symcore.rational_from_ints(1, 2),
        term1,
        term2,
      ]))
      Some(
        cont_piecewise([
          (body, cont_rel("Ge", x, eval_arith(@symcore.mul([@symcore.int(-1), r])))),
          (@symcore.int(0), @symcore.symbol("True")),
        ]),
      )
    }
    "Chi" if params.length() == 1 => {
      let k = params[0]
      let half = try! @symcore.rational_from_ints(1, 2)
      let shape = eval_arith(@symcore.mul([half, k]))
      let z = eval_arith(@symcore.mul([half, @symcore.pow(x, @symcore.int(2))]))
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, @symcore.int(0))),
          (
            eval_arith(@symcore.mul([
              @symcore.function("lowergamma", [shape, z]),
              @symcore.pow(@symcore.function("gamma", [shape]), @symcore.int(-1)),
            ])),
            @symcore.symbol("True"),
          ),
        ]),
      )
    }
    "LogNormal" if params.length() == 2 => {
      let mu = params[0]
      let sigma = params[1]
      let arg = eval_arith(@symcore.mul([
        cont_expr_sub(@symcore.function("log", [x]), mu),
        @symcore.pow(eval_arith(@symcore.mul([sigma, @symcore.function("sqrt", [@symcore.int(2)])])), @symcore.int(-1)),
      ]))
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Le", x, @symcore.int(0))),
          (eval_arith(@symcore.add([try! @symcore.rational_from_ints(1, 2), eval_arith(@symcore.mul([try! @symcore.rational_from_ints(1, 2), @symcore.function("erf", [arg])]))])), @symcore.symbol("True")),
        ]),
      )
    }
    "Weibull" if params.length() == 2 => {
      let lam = params[0]
      let k = params[1]
      let ratio_pow = @symcore.pow(eval_arith(@symcore.mul([x, @symcore.pow(lam, @symcore.int(-1))])), k)
      Some(
        cont_piecewise([
          (@symcore.int(0), cont_rel("Lt", x, @symcore.int(0))),
          (
            eval_arith(@symcore.add([
              @symcore.int(1),
              @symcore.mul([@symcore.int(-1), @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.int(-1), ratio_pow]))])]),
            ])),
            @symcore.symbol("True"),
          ),
        ]),
      )
    }
    "Moyal" if params.length() == 2 => {
      let mu = params[0]
      let sigma = params[1]
      let arg = eval_arith(@symcore.mul([
        @symcore.function("exp", [eval_arith(@symcore.mul([
          @symcore.int(-1),
          cont_expr_sub(x, mu),
          @symcore.pow(eval_arith(@symcore.mul([@symcore.int(2), sigma])), @symcore.int(-1)),
        ]))]),
        @symcore.pow(@symcore.function("sqrt", [@symcore.int(2)]), @symcore.int(-1)),
      ]))
      Some(@symcore.function("erfc", [arg]))
    }
    "Trapezoidal" if params.length() == 4 => {
      let a = params[0]
      let b = params[1]
      let c = params[2]
      let d = params[3]
      let span = eval_arith(@symcore.add([
        d,
        c,
        @symcore.mul([@symcore.int(-1), b]),
        @symcore.mul([@symcore.int(-1), a]),
      ]))
      let left = eval_arith(@symcore.mul([
        @symcore.pow(cont_expr_sub(x, a), @symcore.int(2)),
        @symcore.pow(eval_arith(@symcore.mul([span, cont_expr_sub(b, a)])), @symcore.int(-1)),
      ]))
      let mid = eval_arith(@symcore.mul([
        eval_arith(@symcore.add([
          eval_arith(@symcore.mul([@symcore.int(2), x])),
          @symcore.mul([@symcore.int(-1), a]),
          @symcore.mul([@symcore.int(-1), b]),
        ])),
        @symcore.pow(span, @symcore.int(-1)),
      ]))
      let right = eval_arith(@symcore.add([
        @symcore.int(1),
        @symcore.mul([
          @symcore.int(-1),
          @symcore.pow(cont_expr_sub(d, x), @symcore.int(2)),
          @symcore.pow(eval_arith(@symcore.mul([span, cont_expr_sub(d, c)])), @symcore.int(-1)),
        ]),
      ]))
      Some(cont_piecewise([
        (@symcore.int(0), cont_rel("Lt", x, a)),
        (left, cont_rel("Le", x, b)),
        (mid, cont_rel("Le", x, c)),
        (right, cont_rel("Le", x, d)),
        (@symcore.int(1), @symcore.symbol("True")),
      ]))
    }
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
fn symbolic_stat_expr(
  name : String,
  suffix : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  @symcore.function("\{name}\{suffix}", params)
}

///|
pub fn continuous_density(
  rv : RandomVar,
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Normal(mu~, sigma~) => {
      let two = @symcore.int(2)
      let pi = @symcore.symbol("pi")
      let diff = cont_expr_sub(x, mu)
      let numer = @symcore.function(
        "exp",
        [@symcore.mul([
          @symcore.int(-1),
          @symcore.pow(diff, two),
          @symcore.pow(@symcore.mul([two, @symcore.pow(sigma, two)]), @symcore.int(-1)),
        ])],
      )
      let denom = @symcore.mul([@symcore.function("sqrt", [@symcore.mul([two, pi])]), sigma])
      Some(eval_arith(@symcore.mul([numer, @symcore.pow(denom, @symcore.int(-1))])))
    }
    RVKind::Exponential(rate~) => {
      let raw = eval_arith(@symcore.mul([
        rate,
        @symcore.function("exp", [@symcore.mul([@symcore.int(-1), rate, x])]),
      ]))
      Some(cont_piecewise([
        (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
        (raw, @symcore.symbol("True")),
      ]))
    }
    RVKind::Gamma(shape~, scale~) => {
      let base = eval_arith(@symcore.mul([
        @symcore.pow(x, cont_expr_sub(shape, @symcore.int(1))),
        @symcore.function(
          "exp",
          [@symcore.mul([@symcore.int(-1), x, @symcore.pow(scale, @symcore.int(-1))])],
        ),
        @symcore.pow(@symcore.function("gamma", [shape]), @symcore.int(-1)),
        @symcore.pow(scale, @symcore.mul([@symcore.int(-1), shape])),
      ]))
      Some(cont_piecewise([
        (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
        (base, @symcore.symbol("True")),
      ]))
    }
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "C" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        if name == "ContinuousRV" || name == "ContinuousDistributionHandmade" {
          return None
        }
        // Prefer curated formulas that already encode support as Piecewise.
        match symbolic_continuous_density(name, params, x) {
          Some(v) => Some(cont_guard_params(name, params, v))
          None =>
            match generated_density(name, params, x) {
              Some(v) => Some(cont_guard_params(name, params, v))
              None => Some(cont_guard_params(name, params, symbolic_density_expr(name, params, x)))
            }
        }
      }
    }
    _ => None
  }
}

///|
pub fn continuous_cdf(
  rv : RandomVar,
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Normal(mu~, sigma~) => {
      let two = @symcore.int(2)
      let arg = eval_arith(@symcore.mul([
        cont_expr_sub(x, mu),
        @symcore.pow(@symcore.mul([@symcore.function("sqrt", [two]), sigma]), @symcore.int(-1)),
      ]))
      Some(eval_arith(@symcore.mul([
        @symcore.int(1),
        @symcore.pow(two, @symcore.int(-1)),
        @symcore.add([@symcore.int(1), @symcore.function("erf", [arg])]),
      ])))
    }
    RVKind::Exponential(rate~) =>
      Some(cont_piecewise([
        (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
        (
          cont_one_minus(
            @symcore.function("exp", [@symcore.mul([@symcore.int(-1), rate, x])]),
          ),
          @symcore.symbol("True"),
        ),
      ]))
    RVKind::Gamma(shape~, scale~) =>
      Some(cont_piecewise([
        (@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])),
        (
          eval_arith(@symcore.mul([
            @symcore.function("lowergamma", [shape, eval_arith(@symcore.mul([x, @symcore.pow(scale, @symcore.int(-1))]))]),
            @symcore.pow(@symcore.function("gamma", [shape]), @symcore.int(-1)),
          ])),
          @symcore.symbol("True"),
        ),
      ]))
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "C" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        if name == "ContinuousRV" || name == "ContinuousDistributionHandmade" {
          return None
        }
        // Prefer curated formulas that preserve expected branch structure.
        match symbolic_continuous_cdf(name, params, x) {
          Some(v) => Some(cont_guard_params(name, params, v))
          None =>
            match generated_cdf(name, params, x) {
              Some(v) => Some(cont_guard_params(name, params, v))
              None => Some(cont_guard_params(name, params, symbolic_cdf_expr(name, params, x)))
            }
        }
      }
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
                Some(cdf) => Some(eval_arith(cont_expr_sub(@symcore.int(1), cdf)))
                None => None
              }
          }
        None => None
      }
    Event::And(items) => {
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
                  (Some(cl), Some(cu)) => Some(eval_arith(cont_expr_sub(cu, cl)))
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
    RVKind::Exponential(rate~) => Some(eval_arith(@symcore.pow(rate, @symcore.int(-1))))
    RVKind::Gamma(shape~, scale~) => Some(eval_arith(@symcore.mul([shape, scale])))
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "C" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_mean(name, params) {
          Some(v) => Some(cont_guard_params(name, params, v))
          None => {
            let raw =
              match name {
                "Arcsin" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 2),
                    @symcore.add([params[0], params[1]]),
                  ]))
                "Uniform" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 2),
                    @symcore.add([params[0], params[1]]),
                  ]))
                "Beta" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.pow(@symcore.add([params[0], params[1]]), @symcore.int(-1)),
                  ]))
                "Kumaraswamy" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    params[1],
                    @symcore.function("beta", [
                      eval_arith(@symcore.add([
                        @symcore.int(1),
                        @symcore.pow(params[0], @symcore.int(-1)),
                      ])),
                      params[1],
                    ]),
                  ]))
                "Laplace" if params.length() == 2 => params[0]
                "Cauchy" if params.length() == 2 => @symcore.symbol("nan")
                "Pareto" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    params[1],
                    params[0],
                    @symcore.pow(@symcore.add([params[1], @symcore.int(-1)]), @symcore.int(-1)),
                  ]))
                "Rayleigh" if params.length() == 1 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.function("sqrt", [@symcore.mul([@symcore.symbol("pi"), try! @symcore.rational_from_ints(1, 2)])]),
                  ]))
                "LogNormal" if params.length() == 2 =>
                  eval_arith(@symcore.function("exp", [
                    eval_arith(@symcore.add([
                      params[0],
                      @symcore.mul([try! @symcore.rational_from_ints(1, 2), @symcore.pow(params[1], @symcore.int(2))]),
                    ])),
                  ]))
                "Weibull" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.function("gamma", [
                      eval_arith(@symcore.add([
                        @symcore.int(1),
                        @symcore.pow(params[1], @symcore.int(-1)),
                      ])),
                    ]),
                  ]))
                "StudentT" if params.length() == 1 => @symcore.int(0)
                "Trapezoidal" if params.length() == 4 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let d = params[3]
                  eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 3),
                    eval_arith(@symcore.add([
                      @symcore.pow(eval_arith(@symcore.add([a, b, @symcore.mul([@symcore.int(-1), c]), @symcore.mul([@symcore.int(-1), d])])), @symcore.int(-1)),
                    ])),
                    eval_arith(@symcore.add([
                      @symcore.pow(a, @symcore.int(2)),
                      @symcore.mul([a, b]),
                      @symcore.pow(b, @symcore.int(2)),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(c, @symcore.int(2))]),
                      @symcore.mul([@symcore.int(-1), c, d]),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(d, @symcore.int(2))]),
                    ])),
                  ]))
                }
                _ => symbolic_stat_expr(name, "Mean", params)
              }
            Some(cont_guard_params(name, params, raw))
          }
        }
      }
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
      Some(eval_arith(@symcore.mul([shape, @symcore.pow(scale, @symcore.int(2))])))
    RVKind::Symbolic(tag~, params~) => {
      if symbolic_tag_family(tag) != "C" {
        None
      } else {
        let name = symbolic_tag_name(tag)
        match generated_variance(name, params) {
          Some(v) => Some(cont_guard_params(name, params, v))
          None => {
            let raw =
              match name {
                "Arcsin" if params.length() == 0 => try! @symcore.rational_from_ints(1, 8)
                "Arcsin" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 8),
                    @symcore.pow(cont_expr_sub(params[1], params[0]), @symcore.int(2)),
                  ]))
                "Uniform" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 12),
                    @symcore.pow(cont_expr_sub(params[1], params[0]), @symcore.int(2)),
                  ]))
                "Beta" if params.length() == 2 => {
                  let a = params[0]
                  let b = params[1]
                  eval_arith(@symcore.mul([
                    a,
                    b,
                    @symcore.pow(@symcore.add([a, b]), @symcore.int(-2)),
                    @symcore.pow(@symcore.add([a, b, @symcore.int(1)]), @symcore.int(-1)),
                  ]))
                }
                "Kumaraswamy" if params.length() == 2 => {
                  let a = params[0]
                  let b = params[1]
                  let m1 = eval_arith(@symcore.mul([
                    b,
                    @symcore.function("beta", [
                      eval_arith(@symcore.add([
                        @symcore.int(1),
                        @symcore.pow(a, @symcore.int(-1)),
                      ])),
                      b,
                    ]),
                  ]))
                  let m2 = eval_arith(@symcore.mul([
                    b,
                    @symcore.function("beta", [
                      eval_arith(@symcore.add([
                        @symcore.int(1),
                        eval_arith(@symcore.mul([@symcore.int(2), @symcore.pow(a, @symcore.int(-1))])),
                      ])),
                      b,
                    ]),
                  ]))
                  eval_arith(@symcore.add([
                    m2,
                    @symcore.mul([@symcore.int(-1), @symcore.pow(m1, @symcore.int(2))]),
                  ]))
                }
                "Laplace" if params.length() == 2 =>
                  eval_arith(@symcore.mul([@symcore.int(2), @symcore.pow(params[1], @symcore.int(2))]))
                "Cauchy" if params.length() == 2 => @symcore.symbol("nan")
                "Pareto" if params.length() == 2 => {
                  let xm = params[0]
                  let a = params[1]
                  eval_arith(@symcore.mul([
                    @symcore.pow(xm, @symcore.int(2)),
                    a,
                    @symcore.pow(@symcore.add([a, @symcore.int(-2)]), @symcore.int(-1)),
                    @symcore.pow(@symcore.add([a, @symcore.int(-1)]), @symcore.int(-2)),
                  ]))
                }
                "BoundedPareto" if params.length() == 3 => {
                  let a = params[0]
                  let l = params[1]
                  let h = params[2]
                  let one_minus = eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.pow(eval_arith(@symcore.mul([l, @symcore.pow(h, @symcore.int(-1))])), a),
                    ]),
                  ]))
                  let common = eval_arith(@symcore.mul([
                    a,
                    @symcore.pow(l, a),
                    @symcore.pow(one_minus, @symcore.int(-1)),
                  ]))
                  let e1 = eval_arith(@symcore.mul([
                    common,
                    eval_arith(@symcore.add([
                      @symcore.pow(h, eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), a])]))),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(l, eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), a])])))]),
                    ])),
                    @symcore.pow(eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), a])])), @symcore.int(-1)),
                  ]))
                  let e2 = eval_arith(@symcore.mul([
                    common,
                    eval_arith(@symcore.add([
                      @symcore.pow(h, eval_arith(@symcore.add([@symcore.int(2), @symcore.mul([@symcore.int(-1), a])]))),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(l, eval_arith(@symcore.add([@symcore.int(2), @symcore.mul([@symcore.int(-1), a])])))]),
                    ])),
                    @symcore.pow(eval_arith(@symcore.add([@symcore.int(2), @symcore.mul([@symcore.int(-1), a])])), @symcore.int(-1)),
                  ]))
                  eval_arith(@symcore.add([
                    e2,
                    @symcore.mul([@symcore.int(-1), @symcore.pow(e1, @symcore.int(2))]),
                  ]))
                }
                "Rayleigh" if params.length() == 1 =>
                  eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 2),
                    @symcore.add([@symcore.int(4), @symcore.mul([@symcore.int(-1), @symcore.symbol("pi")])]),
                    @symcore.pow(params[0], @symcore.int(2)),
                  ]))
                "LogNormal" if params.length() == 2 => {
                  let mu = params[0]
                  let sigma = params[1]
                  eval_arith(@symcore.mul([
                    eval_arith(@symcore.add([
                      @symcore.function("exp", [@symcore.pow(sigma, @symcore.int(2))]),
                      @symcore.int(-1),
                    ])),
                    @symcore.function("exp", [
                      eval_arith(@symcore.add([
                        @symcore.mul([@symcore.int(2), mu]),
                        @symcore.pow(sigma, @symcore.int(2)),
                      ])),
                    ]),
                  ]))
                }
                "Weibull" if params.length() == 2 => {
                  let lam = params[0]
                  let k = params[1]
                  let g1 = @symcore.function("gamma", [eval_arith(@symcore.add([@symcore.int(1), @symcore.pow(k, @symcore.int(-1))]))])
                  let g2 = @symcore.function("gamma", [eval_arith(@symcore.add([@symcore.int(1), eval_arith(@symcore.mul([@symcore.int(2), @symcore.pow(k, @symcore.int(-1))]))]))])
                  eval_arith(@symcore.mul([
                    @symcore.pow(lam, @symcore.int(2)),
                    eval_arith(@symcore.add([g2, @symcore.mul([@symcore.int(-1), @symcore.pow(g1, @symcore.int(2))])])),
                  ]))
                }
                "StudentT" if params.length() == 1 =>
                  eval_arith(@symcore.mul([params[0], @symcore.pow(@symcore.add([params[0], @symcore.int(-2)]), @symcore.int(-1))]))
                "PowerFunction" if params.length() == 3 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.pow(eval_arith(@symcore.add([params[2], @symcore.mul([@symcore.int(-1), params[1]])])), @symcore.int(2)),
                    @symcore.pow(eval_arith(@symcore.add([params[0], @symcore.int(2)])), @symcore.int(-1)),
                    @symcore.pow(eval_arith(@symcore.add([params[0], @symcore.int(1)])), @symcore.int(-2)),
                  ]))
                "Trapezoidal" if params.length() == 4 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let d = params[3]
                  let abcd = eval_arith(@symcore.add([a, b, @symcore.mul([@symcore.int(-1), c]), @symcore.mul([@symcore.int(-1), d])]))
                  let m_num = eval_arith(@symcore.add([
                    @symcore.pow(a, @symcore.int(2)),
                    @symcore.mul([a, b]),
                    @symcore.pow(b, @symcore.int(2)),
                    @symcore.mul([@symcore.int(-1), @symcore.pow(c, @symcore.int(2))]),
                    @symcore.mul([@symcore.int(-1), c, d]),
                    @symcore.mul([@symcore.int(-1), @symcore.pow(d, @symcore.int(2))]),
                  ]))
                  let e1 = eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 3),
                    @symcore.pow(abcd, @symcore.int(-1)),
                    m_num,
                  ]))
                  let e2 = eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 6),
                    @symcore.pow(abcd, @symcore.int(-1)),
                    eval_arith(@symcore.add([
                      @symcore.pow(a, @symcore.int(3)),
                      @symcore.mul([@symcore.pow(a, @symcore.int(2)), b]),
                      @symcore.mul([a, @symcore.pow(b, @symcore.int(2))]),
                      @symcore.pow(b, @symcore.int(3)),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(c, @symcore.int(3))]),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(c, @symcore.int(2)), d]),
                      @symcore.mul([@symcore.int(-1), c, @symcore.pow(d, @symcore.int(2))]),
                      @symcore.mul([@symcore.int(-1), @symcore.pow(d, @symcore.int(3))]),
                    ])),
                  ]))
                  eval_arith(@symcore.add([
                    e2,
                    @symcore.mul([@symcore.int(-1), @symcore.pow(e1, @symcore.int(2))]),
                  ]))
                }
                _ => symbolic_stat_expr(name, "Variance", params)
              }
            Some(cont_guard_params(name, params, raw))
          }
        }
      }
    }
    _ => None
  }
}
