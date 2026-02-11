///|
/// Unified query interface (`P/E/variance/covariance/density/cdf` style).

///|
fn query_expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.add([a, @symcore.mul([@symcore.int(-1), b])])
}

///|
fn rv_map(rvs : Array[RandomVar]) -> Map[String, RandomVar] {
  let out : Map[String, RandomVar] = {}
  for rv in rvs {
    out[rv.name] = rv
  }
  out
}

///|
fn symbolic_query_expr(
  name : String,
  suffix : String,
  head : @symcore.Expr,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = [head]
  for p in params {
    args.push(p)
  }
  @symcore.function("\{name}\{suffix}", args)
}

///|
fn tuple_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function("Tuple", items)
}

///|
fn tuple_matrix(rows : Array[Array[@symcore.Expr]]) -> @symcore.Expr {
  tuple_expr(rows.map(row => tuple_expr(row)))
}

///|
fn scale_tuple_matrix(
  mat : @symcore.Expr,
  scale : @symcore.Expr,
) -> @symcore.Expr {
  match mat {
    @symcore.Expr::Function("Tuple", rows) =>
      tuple_expr(
        rows.map(row => {
          match row {
            @symcore.Expr::Function("Tuple", cols) =>
              tuple_expr(
                cols.map(col => eval_arith(@symcore.mul([scale, col]))),
              )
            _ => eval_arith(@symcore.mul([scale, row]))
          }
        }),
      )
    _ => eval_arith(@symcore.mul([scale, mat]))
  }
}

///|
fn symbolic_joint_mean(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match name {
    "Dirichlet" | "MultivariateBeta" if params.length() >= 2 => {
      let total = eval_arith(@symcore.add(params))
      let means = params.map(a => {
        eval_arith(@symcore.mul([a, @symcore.pow(total, @symcore.int(-1))]))
      })
      Some(tuple_expr(means))
    }
    "Multinomial" if params.length() >= 2 => {
      let n = params[0]
      let ps : Array[@symcore.Expr] = Array::new()
      for i in 1..<params.length() {
        ps.push(params[i])
      }
      Some(tuple_expr(ps.map(p => eval_arith(@symcore.mul([n, p])))))
    }
    "MultivariateT" if params.length() == 3 => Some(params[0])
    "MultivariateLaplace" if params.length() >= 2 => Some(params[0])
    "MultivariateNormal" if params.length() >= 1 => Some(params[0])
    "NormalGamma" if params.length() == 4 =>
      Some(
        tuple_expr([
          params[0],
          eval_arith(
            @symcore.mul([params[2], @symcore.pow(params[3], @symcore.int(-1))]),
          ),
        ]),
      )
    _ => None
  }
}

///|
fn symbolic_joint_variance(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match name {
    "Dirichlet" | "MultivariateBeta" if params.length() >= 2 => {
      let total = eval_arith(@symcore.add(params))
      let denom = eval_arith(
        @symcore.mul([
          @symcore.pow(total, @symcore.int(2)),
          @symcore.add([total, @symcore.int(1)]),
        ]),
      )
      let rows : Array[Array[@symcore.Expr]] = Array::new()
      for i in 0..<params.length() {
        let ai = params[i]
        let row : Array[@symcore.Expr] = Array::new()
        for j in 0..<params.length() {
          let aj = params[j]
          if i == j {
            row.push(
              eval_arith(
                @symcore.mul([
                  ai,
                  @symcore.add([total, @symcore.mul([@symcore.int(-1), ai])]),
                  @symcore.pow(denom, @symcore.int(-1)),
                ]),
              ),
            )
          } else {
            row.push(
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  ai,
                  aj,
                  @symcore.pow(denom, @symcore.int(-1)),
                ]),
              ),
            )
          }
        }
        rows.push(row)
      }
      Some(tuple_matrix(rows))
    }
    "Multinomial" if params.length() >= 2 => {
      let n = params[0]
      let ps : Array[@symcore.Expr] = Array::new()
      for i in 1..<params.length() {
        ps.push(params[i])
      }
      let rows : Array[Array[@symcore.Expr]] = Array::new()
      for i in 0..<ps.length() {
        let pi = ps[i]
        let row : Array[@symcore.Expr] = Array::new()
        for j in 0..<ps.length() {
          let pj = ps[j]
          if i == j {
            row.push(
              eval_arith(
                @symcore.mul([
                  n,
                  pi,
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), pi]),
                  ]),
                ]),
              ),
            )
          } else {
            row.push(eval_arith(@symcore.mul([@symcore.int(-1), n, pi, pj])))
          }
        }
        rows.push(row)
      }
      Some(tuple_matrix(rows))
    }
    "MultivariateT" if params.length() == 3 => {
      let sigma = params[1]
      let nu = params[2]
      let scale = eval_arith(
        @symcore.mul([
          nu,
          @symcore.pow(@symcore.add([nu, @symcore.int(-2)]), @symcore.int(-1)),
        ]),
      )
      Some(scale_tuple_matrix(sigma, scale))
    }
    "MultivariateLaplace" if params.length() >= 2 => Some(params[1])
    "MultivariateNormal" if params.length() >= 2 => Some(params[1])
    "NormalGamma" if params.length() == 4 => {
      let lamda = params[1]
      let alpha = params[2]
      let beta = params[3]
      let var_x = eval_arith(
        @symcore.mul([
          beta,
          @symcore.pow(lamda, @symcore.int(-1)),
          @symcore.pow(
            @symcore.add([alpha, @symcore.int(-1)]),
            @symcore.int(-1),
          ),
        ]),
      )
      let var_tau = eval_arith(
        @symcore.mul([alpha, @symcore.pow(beta, @symcore.int(-2))]),
      )
      Some(tuple_matrix([[var_x, @symcore.int(0)], [@symcore.int(0), var_tau]]))
    }
    _ => None
  }
}

///|
fn query_tuple_items(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function("Tuple", items) => Some(items)
    _ => None
  }
}

///|
fn query_tuple2(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr)? {
  match query_tuple_items(expr) {
    Some(items) if items.length() == 2 => Some((items[0], items[1]))
    _ => None
  }
}

///|
fn query_matrix2x2(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr, @symcore.Expr)? {
  match query_tuple_items(expr) {
    Some(rows) if rows.length() == 2 =>
      match (query_tuple_items(rows[0]), query_tuple_items(rows[1])) {
        (Some(r0), Some(r1)) if r0.length() == 2 && r1.length() == 2 =>
          Some((r0[0], r0[1], r1[0], r1[1]))
        _ => None
      }
    _ => None
  }
}

///|
fn query_lambda_apply(
  template : @symcore.Expr,
  args : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match template {
    @symcore.Expr::Function("Lambda", lambda_args) if lambda_args.length() == 2 => {
      let vars = lambda_args[0]
      let body = lambda_args[1]
      match vars {
        @symcore.Expr::Symbol(v) =>
          if args.length() == 1 {
            let env : Map[String, @symcore.Expr] = {}
            env[v] = args[0]
            Some(eval_arith(@symcore.subst(body, env)))
          } else {
            None
          }
        @symcore.Expr::Function("Tuple", vs) =>
          if vs.length() == args.length() {
            let env : Map[String, @symcore.Expr] = {}
            for i in 0..<vs.length() {
              match vs[i] {
                @symcore.Expr::Symbol(v) => env[v] = args[i]
                _ => return None
              }
            }
            Some(eval_arith(@symcore.subst(body, env)))
          } else {
            None
          }
        _ => None
      }
    }
    @symcore.Expr::Symbol(name) => Some(@symcore.function(name, args))
    _ => None
  }
}

///|
fn query_tuple_pairs(
  expr : @symcore.Expr,
) -> Array[(@symcore.Expr, @symcore.Expr)]? {
  match query_tuple_items(expr) {
    Some(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = Array::new()
      for item in items {
        match query_tuple_items(item) {
          Some(pair) if pair.length() == 2 => out.push((pair[0], pair[1]))
          _ => return None
        }
      }
      Some(out)
    }
    None => None
  }
}

///|
fn query_product_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  if items.is_empty() {
    @symcore.int(1)
  } else {
    eval_arith(@symcore.mul(items))
  }
}

///|
fn symbolic_finite_handmade_pairs(
  params : Array[@symcore.Expr],
) -> Array[(@symcore.Expr, @symcore.Expr)]? {
  if params.length() < 1 {
    return None
  }
  query_tuple_pairs(params[0])
}

///|
fn symbolic_finite_handmade_mean(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_finite_handmade_pairs(params) {
    Some(pairs) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for pair in pairs {
        let (value, prob) = pair
        terms.push(eval_arith(@symcore.mul([value, prob])))
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    None => None
  }
}

///|
fn symbolic_finite_handmade_variance(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match
    (
      symbolic_finite_handmade_pairs(params),
      symbolic_finite_handmade_mean(params),
    ) {
    (Some(pairs), Some(mean)) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for pair in pairs {
        let (value, prob) = pair
        let delta = eval_arith(
          @symcore.add([value, @symcore.mul([@symcore.int(-1), mean])]),
        )
        terms.push(
          eval_arith(@symcore.mul([prob, @symcore.pow(delta, @symcore.int(2))])),
        )
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    _ => None
  }
}

///|
fn symbolic_opaque_mean(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match name {
    "GaussianOrthogonalEnsemble"
    | "GaussianUnitaryEnsemble"
    | "GaussianSymplecticEnsemble" if params.length() == 1 =>
      Some(@symcore.function("ZeroMatrix", [params[0], params[0]]))
    "MatrixGamma" if params.length() == 3 =>
      Some(eval_arith(@symcore.mul([params[0], params[1], params[2]])))
    "MatrixStudentT" if params.length() == 4 => Some(params[1])
    _ => None
  }
}

///|
fn symbolic_special_variance(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
) -> @symcore.Expr? {
  match name {
    "GaussianOrthogonalEnsemble"
    | "GaussianUnitaryEnsemble"
    | "GaussianSymplecticEnsemble" if params.length() == 1 => {
      let x = @symcore.symbol(rv_name)
      let mean = @symcore.function("ZeroMatrix", [params[0], params[0]])
      Some(
        @symcore.function("Expectation", [
          eval_arith(@symcore.pow(query_expr_sub(x, mean), @symcore.int(2))),
        ]),
      )
    }
    "MatrixGamma" if params.length() == 3 =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            @symcore.pow(params[2], @symcore.int(2)),
          ]),
        ),
      )
    "MatrixStudentT" if params.length() == 4 =>
      Some(
        @symcore.function("Expectation", [
          eval_arith(
            @symcore.pow(
              query_expr_sub(@symcore.symbol(rv_name), params[1]),
              @symcore.int(2),
            ),
          ),
        ]),
      )
    _ => None
  }
}

///|
fn symbolic_multivariate_ewens_density(
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  if params.length() != 2 {
    return None
  }
  match query_tuple_items(x) {
    Some(xs) if !xs.is_empty() => {
      let n = params[0]
      let theta = params[1]
      let term2_items : Array[@symcore.Expr] = Array::new()
      let cond_terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<xs.length() {
        let xi = xs[i]
        let j = @symcore.int(i + 1)
        term2_items.push(
          eval_arith(
            @symcore.mul([
              @symcore.pow(theta, xi),
              @symcore.pow(j, eval_arith(@symcore.mul([@symcore.int(-1), xi]))),
              @symcore.pow(
                @symcore.function("factorial", [xi]),
                @symcore.int(-1),
              ),
            ]),
          ),
        )
        cond_terms.push(eval_arith(@symcore.mul([j, xi])))
      }
      let term1 = eval_arith(
        @symcore.mul([
          @symcore.function("factorial", [n]),
          @symcore.function("gamma", [theta]),
          @symcore.pow(
            @symcore.function("gamma", [eval_arith(@symcore.add([theta, n]))]),
            @symcore.int(-1),
          ),
        ]),
      )
      let cond_sum = if cond_terms.is_empty() {
        @symcore.int(0)
      } else {
        eval_arith(@symcore.add(cond_terms))
      }
      let body = eval_arith(
        @symcore.mul([term1, query_product_expr(term2_items)]),
      )
      Some(
        @symcore.function("Piecewise", [
          tuple_expr([body, @symcore.function("Eq", [cond_sum, n])]),
          tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
        ]),
      )
    }
    _ => None
  }
}

///|
fn symbolic_generalized_multivariate_log_gamma_density(
  delta : @symcore.Expr,
  v : @symcore.Expr,
  lamda_expr : @symcore.Expr,
  mu_expr : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match
    (
      query_tuple_items(lamda_expr),
      query_tuple_items(mu_expr),
      query_tuple_items(x),
    ) {
    (Some(lamdas), Some(mus), Some(xs)) if lamdas.length() == mus.length() &&
      mus.length() == xs.length() &&
      xs.length() > 1 => {
      let k = lamdas.length()
      let n_var = @symcore.symbol("_k")
      let v_plus_n = eval_arith(@symcore.add([v, n_var]))
      let one_minus_delta = eval_arith(
        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), delta])]),
      )
      let gamma_vn = @symcore.function("gamma", [v_plus_n])
      let gamma_pow = if k == 1 {
        @symcore.int(1)
      } else {
        @symcore.pow(gamma_vn, @symcore.int(-(k - 1)))
      }
      let sum_term1 = eval_arith(
        @symcore.mul([
          @symcore.pow(one_minus_delta, n_var),
          gamma_pow,
          @symcore.pow(@symcore.function("gamma", [v]), @symcore.int(-1)),
          @symcore.pow(
            @symcore.function("gamma", [
              eval_arith(@symcore.add([n_var, @symcore.int(1)])),
            ]),
            @symcore.int(-1),
          ),
        ]),
      )

      let lamda_mu_terms : Array[@symcore.Expr] = Array::new()
      let mu_y_terms : Array[@symcore.Expr] = Array::new()
      let exp_terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<k {
        let lam = lamdas[i]
        let mu = mus[i]
        let y = xs[i]
        lamda_mu_terms.push(
          eval_arith(
            @symcore.mul([
              mu,
              @symcore.pow(
                lam,
                eval_arith(@symcore.mul([@symcore.int(-1), v_plus_n])),
              ),
            ]),
          ),
        )
        mu_y_terms.push(eval_arith(@symcore.mul([mu, y])))
        exp_terms.push(
          eval_arith(
            @symcore.mul([
              @symcore.function("exp", [eval_arith(@symcore.mul([mu, y]))]),
              @symcore.pow(lam, @symcore.int(-1)),
            ]),
          ),
        )
      }
      let term2 = @symcore.function("exp", [
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([v_plus_n, eval_arith(@symcore.add(mu_y_terms))]),
            ),
            @symcore.mul([@symcore.int(-1), eval_arith(@symcore.add(exp_terms))]),
          ]),
        ),
      ])
      let summand = eval_arith(
        @symcore.mul([sum_term1, query_product_expr(lamda_mu_terms), term2]),
      )
      let sum_expr = @symcore.function("Sum", [
        summand,
        tuple_expr([n_var, @symcore.int(0), @symcore.symbol("oo")]),
      ])
      Some(eval_arith(@symcore.mul([@symcore.pow(delta, v), sum_expr])))
    }
    _ => None
  }
}

///|
fn symbolic_joint_gmlg_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "GeneralizedMultivariateLogGamma" if params.length() == 4 =>
      symbolic_generalized_multivariate_log_gamma_density(
        params[0],
        params[1],
        params[2],
        params[3],
        x,
      )
    "GeneralizedMultivariateLogGammaOmega" if params.length() == 4 =>
      match query_tuple_items(params[2]) {
        Some(lamdas) if lamdas.length() > 1 => {
          let delta = match query_matrix2x2(params[0]) {
            Some((a00, a01, a10, a11)) if lamdas.length() == 2 =>
              eval_arith(
                @symcore.add([
                  eval_arith(@symcore.mul([a00, a11])),
                  @symcore.mul([@symcore.int(-1), a01, a10]),
                ]),
              )
            _ => params[0]
          }
          symbolic_generalized_multivariate_log_gamma_density(
            delta,
            params[1],
            params[2],
            params[3],
            x,
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn symbolic_joint_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "JointRV" if params.length() >= 1 =>
      match query_tuple_items(x) {
        Some(xs) => query_lambda_apply(params[0], xs)
        None => query_lambda_apply(params[0], [x])
      }
    "MultivariateEwens" if params.length() == 2 =>
      symbolic_multivariate_ewens_density(params, x)
    "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega" =>
      symbolic_joint_gmlg_density(name, params, x)
    "Dirichlet" | "MultivariateBeta" if params.length() >= 2 =>
      match query_tuple_items(x) {
        Some(xs) if xs.length() == params.length() => {
          let alpha_sum = eval_arith(@symcore.add(params))
          let denom = query_product_expr(
            params.map(a => @symcore.function("gamma", [a])),
          )
          let power_terms : Array[@symcore.Expr] = Array::new()
          for i in 0..<params.length() {
            power_terms.push(
              eval_arith(
                @symcore.pow(
                  xs[i],
                  eval_arith(@symcore.add([params[i], @symcore.int(-1)])),
                ),
              ),
            )
          }
          Some(
            eval_arith(
              @symcore.mul([
                @symcore.function("gamma", [alpha_sum]),
                @symcore.pow(denom, @symcore.int(-1)),
                query_product_expr(power_terms),
              ]),
            ),
          )
        }
        _ => None
      }
    "NormalGamma" if params.length() == 4 =>
      match query_tuple2(x) {
        Some((xv, tau)) => {
          let mu = params[0]
          let lamda = params[1]
          let alpha = params[2]
          let beta = params[3]
          let half = try! @symcore.rational_from_ints(1, 2)
          let tau_power = eval_arith(
            @symcore.pow(
              tau,
              eval_arith(
                @symcore.add([alpha, @symcore.mul([@symcore.int(-1), half])]),
              ),
            ),
          )
          let norm = eval_arith(
            @symcore.mul([
              @symcore.function("sqrt", [
                eval_arith(
                  @symcore.mul([@symcore.int(2), @symcore.symbol("pi")]),
                ),
              ]),
              @symcore.function("gamma", [alpha]),
            ]),
          )
          let quad = eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              half,
              lamda,
              tau,
              @symcore.pow(eval_arith(query_expr_sub(xv, mu)), @symcore.int(2)),
            ]),
          )
          Some(
            eval_arith(
              @symcore.mul([
                @symcore.pow(beta, alpha),
                @symcore.function("sqrt", [lamda]),
                @symcore.pow(norm, @symcore.int(-1)),
                tau_power,
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([@symcore.int(-1), beta, tau])),
                ]),
                @symcore.function("exp", [quad]),
              ]),
            ),
          )
        }
        _ => None
      }
    "MultivariateNormal" if params.length() >= 2 =>
      match
        (query_tuple2(params[0]), query_matrix2x2(params[1]), query_tuple2(x)) {
        (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((x1, x2))) => {
          let det = eval_arith(
            @symcore.add([
              eval_arith(@symcore.mul([s00, s11])),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
            ]),
          )
          let dx1 = eval_arith(query_expr_sub(x1, mu1))
          let dx2 = eval_arith(query_expr_sub(x2, mu2))
          let quad_num = eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([s11, @symcore.pow(dx1, @symcore.int(2))]),
              ),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, dx1, dx2])),
              eval_arith(@symcore.mul([@symcore.int(-1), s10, dx1, dx2])),
              eval_arith(
                @symcore.mul([s00, @symcore.pow(dx2, @symcore.int(2))]),
              ),
            ]),
          )
          let half = try! @symcore.rational_from_ints(1, 2)
          let quad = eval_arith(
            @symcore.mul([quad_num, @symcore.pow(det, @symcore.int(-1))]),
          )
          let norm = eval_arith(
            @symcore.mul([
              @symcore.int(2),
              @symcore.symbol("pi"),
              @symcore.function("sqrt", [det]),
            ]),
          )
          Some(
            eval_arith(
              @symcore.mul([
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([@symcore.int(-1), half, quad])),
                ]),
                @symcore.pow(norm, @symcore.int(-1)),
              ]),
            ),
          )
        }
        _ => None
      }
    "MultivariateLaplace" if params.length() >= 2 =>
      match
        (query_tuple2(params[0]), query_matrix2x2(params[1]), query_tuple2(x)) {
        (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((x1, x2))) => {
          let det = eval_arith(
            @symcore.add([
              eval_arith(@symcore.mul([s00, s11])),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
            ]),
          )
          let x_quad_num = eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([s11, @symcore.pow(mu1, @symcore.int(2))]),
              ),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, mu1, mu2])),
              eval_arith(@symcore.mul([@symcore.int(-1), s10, mu1, mu2])),
              eval_arith(
                @symcore.mul([s00, @symcore.pow(mu2, @symcore.int(2))]),
              ),
            ]),
          )
          let y_quad_num = eval_arith(
            @symcore.add([
              eval_arith(@symcore.mul([s11, @symcore.pow(x1, @symcore.int(2))])),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, x1, x2])),
              eval_arith(@symcore.mul([@symcore.int(-1), s10, x1, x2])),
              eval_arith(@symcore.mul([s00, @symcore.pow(x2, @symcore.int(2))])),
            ]),
          )
          let linear_num = eval_arith(
            @symcore.add([
              eval_arith(@symcore.mul([s11, x1, mu1])),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, x1, mu2])),
              eval_arith(@symcore.mul([@symcore.int(-1), s10, x2, mu1])),
              eval_arith(@symcore.mul([s00, x2, mu2])),
            ]),
          )
          let x_quad = eval_arith(
            @symcore.mul([x_quad_num, @symcore.pow(det, @symcore.int(-1))]),
          )
          let y_quad = eval_arith(
            @symcore.mul([y_quad_num, @symcore.pow(det, @symcore.int(-1))]),
          )
          let linear = eval_arith(
            @symcore.mul([linear_num, @symcore.pow(det, @symcore.int(-1))]),
          )
          let denom = eval_arith(
            @symcore.mul([
              @symcore.symbol("pi"),
              @symcore.function("sqrt", [det]),
            ]),
          )
          Some(
            eval_arith(
              @symcore.mul([
                @symcore.function("exp", [linear]),
                @symcore.function("besselk", [
                  @symcore.int(0),
                  @symcore.function("sqrt", [
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.add([@symcore.int(2), x_quad])),
                        y_quad,
                      ]),
                    ),
                  ]),
                ]),
                @symcore.pow(denom, @symcore.int(-1)),
              ]),
            ),
          )
        }
        _ => None
      }
    "MultivariateT" if params.length() == 3 =>
      match
        (query_tuple2(params[0]), query_matrix2x2(params[1]), query_tuple2(x)) {
        (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((x1, x2))) => {
          let nu = params[2]
          let det = eval_arith(
            @symcore.add([
              eval_arith(@symcore.mul([s00, s11])),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
            ]),
          )
          let dx1 = eval_arith(query_expr_sub(x1, mu1))
          let dx2 = eval_arith(query_expr_sub(x2, mu2))
          let quad_num = eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([s11, @symcore.pow(dx1, @symcore.int(2))]),
              ),
              eval_arith(@symcore.mul([@symcore.int(-1), s01, dx1, dx2])),
              eval_arith(@symcore.mul([@symcore.int(-1), s10, dx1, dx2])),
              eval_arith(
                @symcore.mul([s00, @symcore.pow(dx2, @symcore.int(2))]),
              ),
            ]),
          )
          let half = try! @symcore.rational_from_ints(1, 2)
          let nu_half = eval_arith(@symcore.mul([half, nu]))
          let shape = eval_arith(@symcore.add([nu_half, @symcore.int(1)]))
          let quad = eval_arith(
            @symcore.mul([quad_num, @symcore.pow(det, @symcore.int(-1))]),
          )
          let coeff = eval_arith(
            @symcore.mul([
              @symcore.function("gamma", [shape]),
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    @symcore.function("gamma", [nu_half]),
                    nu,
                    @symcore.symbol("pi"),
                    @symcore.function("sqrt", [det]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ]),
          )
          Some(
            eval_arith(
              @symcore.mul([
                coeff,
                @symcore.pow(
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(
                        @symcore.mul([quad, @symcore.pow(nu, @symcore.int(-1))]),
                      ),
                    ]),
                  ),
                  eval_arith(@symcore.mul([@symcore.int(-1), shape])),
                ),
              ]),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn probability_joint_independent(
  vars : Array[RandomVar],
  event : Event,
) -> @symcore.Expr? {
  let factors : Array[Event] = match event {
    Event::And(items) => items
    _ => [event]
  }
  let used : Array[Bool] = Array::make(factors.length(), false)
  let probs : Array[@symcore.Expr] = Array::new()
  for rv in vars {
    let grouped : Array[Event] = Array::new()
    for i in 0..<factors.length() {
      let factor = factors[i]
      if event_depends_only_on(factor, rv.name) {
        used[i] = true
        grouped.push(factor)
      }
    }
    if !grouped.is_empty() {
      match probability_of_rv(rv, and_event(grouped)) {
        Some(p) => probs.push(p)
        None => return None
      }
    }
  }
  for flag in used {
    if !flag {
      return None
    }
  }
  if probs.is_empty() {
    Some(@symcore.int(1))
  } else {
    Some(eval_arith(@symcore.mul(probs)))
  }
}

///|
fn probability_compound(
  items : Array[(@symnum.BigRational, RandomVar)],
  name : String,
  event : Event,
) -> @symcore.Expr? {
  let terms : Array[@symcore.Expr] = Array::new()
  for pair in items {
    let (w, item) = pair
    let renamed = rename_random_var(item, name)
    match probability_of_rv(renamed, event) {
      Some(p) =>
        terms.push(eval_arith(@symcore.mul([expr_from_big_rational(w), p])))
      None => return None
    }
  }
  if terms.is_empty() {
    Some(@symcore.int(0))
  } else {
    Some(eval_arith(@symcore.add(terms)))
  }
}

///|
fn probability_of_rv(rv : RandomVar, event : Event) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_probability(rv, event)
    RVKind::Binomial(..)
    | RVKind::Poisson(..)
    | RVKind::Geometric(..)
    | RVKind::NegativeBinomial(..) => discrete_probability(rv, event)
    RVKind::Normal(..) | RVKind::Exponential(..) | RVKind::Gamma(..) =>
      continuous_probability(rv, event)
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      if symbolic_opaque_stats_name(name) {
        match symbolic_opaque_probability(name, params, rv.name, event) {
          Some(v) => Some(v)
          None =>
            Some(
              symbolic_query_expr(
                name,
                "Probability",
                event_to_expr(event),
                params,
              ),
            )
        }
      } else {
        match
          (discrete_probability(rv, event), continuous_probability(rv, event)) {
          (Some(v), _) => Some(v)
          (_, Some(v)) => Some(v)
          _ =>
            Some(
              symbolic_query_expr(
                name,
                "Probability",
                event_to_expr(event),
                params,
              ),
            )
        }
      }
    }
    RVKind::JointIndependent(items) =>
      probability_joint_independent(items, event)
    RVKind::Compound(items) => probability_compound(items, rv.name, event)
    _ => None
  }
}

///|
pub fn probability(event : Event, rv? : RandomVar) -> @symcore.Expr {
  match rv {
    Some(v) =>
      match probability_of_rv(v, event) {
        Some(value) => value
        None => probability_expr(event)
      }
    None => probability_expr(event)
  }
}

///|
fn expectation_symbolic_or_value(
  expr : @symcore.Expr,
  rv : RandomVar?,
) -> @symcore.Expr {
  expectation_expr(expr, rv)
}

///|
fn expectation_of_rv(rv : RandomVar, expr : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_expectation(rv, expr~)
    RVKind::StochasticProcess(_) =>
      match expr {
        @symcore.Expr::Symbol(name) if name == rv.name =>
          Some(@symcore.symbol(rv.name))
        @symcore.Expr::Function(name, args) if name == rv.name &&
          args.length() == 1 => process_mean_at(rv, args[0])
        _ => None
      }
    RVKind::Binomial(..)
    | RVKind::Poisson(..)
    | RVKind::Geometric(..)
    | RVKind::NegativeBinomial(..) =>
      if @symcore.compare_expr(expr, @symcore.symbol(rv.name)) == 0 {
        discrete_mean(rv)
      } else {
        None
      }
    RVKind::Normal(..) | RVKind::Exponential(..) | RVKind::Gamma(..) =>
      if @symcore.compare_expr(expr, @symcore.symbol(rv.name)) == 0 {
        continuous_mean(rv)
      } else {
        None
      }
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      if symbolic_opaque_stats_name(name) {
        match expr {
          @symcore.Expr::Symbol(sym) if sym == rv.name =>
            match name {
              "FiniteDistributionHandmade" =>
                match symbolic_finite_handmade_mean(params) {
                  Some(v) => Some(v)
                  None => Some(@symcore.symbol(rv.name))
                }
              _ =>
                match symbolic_opaque_mean(name, params) {
                  Some(v) => Some(v)
                  None => Some(@symcore.symbol(rv.name))
                }
            }
          @symcore.Expr::Function(fname, args) if fname == rv.name &&
            args.length() == 1 &&
            symbolic_tag_family(tag) == "P" => process_mean_at(rv, args[0])
          _ => None
        }
      } else if @symcore.compare_expr(expr, @symcore.symbol(rv.name)) == 0 {
        if symbolic_tag_family(tag) == "J" {
          match symbolic_joint_mean(name, params) {
            Some(v) => Some(v)
            None =>
              Some(
                symbolic_query_expr(
                  name,
                  "Mean",
                  @symcore.symbol(rv.name),
                  params,
                ),
              )
          }
        } else {
          match symbolic_opaque_mean(name, params) {
            Some(v) => Some(v)
            None =>
              match (discrete_mean(rv), continuous_mean(rv)) {
                (Some(v), _) => Some(v)
                (_, Some(v)) => Some(v)
                _ =>
                  Some(
                    symbolic_query_expr(
                      name,
                      "Mean",
                      @symcore.symbol(rv.name),
                      params,
                    ),
                  )
              }
          }
        }
      } else {
        None
      }
    }
    RVKind::Compound(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for pair in items {
        let (w, item) = pair
        let renamed = rename_random_var(item, rv.name)
        match expectation_of_rv(renamed, expr) {
          Some(val) =>
            terms.push(
              eval_arith(@symcore.mul([expr_from_big_rational(w), val])),
            )
          None => return None
        }
      }
      if terms.is_empty() {
        Some(@symcore.int(0))
      } else {
        Some(eval_arith(@symcore.add(terms)))
      }
    }
    _ => None
  }
}

///|
fn expectation_eval_independent(
  expr : @symcore.Expr,
  map : Map[String, RandomVar],
) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Number(_) => Some(expr)
    @symcore.Expr::Symbol(name) =>
      match map.get(name) {
        Some(rv) => expectation_of_rv(rv, @symcore.symbol(name))
        None => Some(expr)
      }
    @symcore.Expr::Add(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for item in items {
        match expectation_eval_independent(item, map) {
          Some(v) => terms.push(v)
          None => return None
        }
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    @symcore.Expr::Mul(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      let seen_rv : Map[String, Bool] = {}
      for item in items {
        match item {
          @symcore.Expr::Symbol(name) =>
            match map.get(name) {
              Some(_) =>
                if seen_rv.contains(name) {
                  return None
                } else {
                  seen_rv[name] = true
                }
              None => ()
            }
          _ => ()
        }
        match expectation_eval_independent(item, map) {
          Some(v) => terms.push(v)
          None => return None
        }
      }
      Some(eval_arith(@symcore.mul(terms)))
    }
    _ => None
  }
}

///|
pub fn expectation(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.is_empty() {
    return expectation_symbolic_or_value(expr, None)
  }
  if rvs.length() == 1 {
    match expectation_of_rv(rvs[0], expr) {
      Some(value) => return value
      None => ()
    }
  }
  let map = rv_map(rvs)
  match expectation_eval_independent(expr, map) {
    Some(value) => value
    None =>
      if rvs.length() == 1 {
        expectation_symbolic_or_value(expr, Some(rvs[0]))
      } else {
        expectation_symbolic_or_value(expr, None)
      }
  }
}

///|
fn variance_of_rv(rv : RandomVar) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(_) => finite_variance(rv)
    RVKind::StochasticProcess(_) =>
      Some(variance_expr(@symcore.symbol(rv.name)))
    RVKind::Binomial(..)
    | RVKind::Poisson(..)
    | RVKind::Geometric(..)
    | RVKind::NegativeBinomial(..) => discrete_variance(rv)
    RVKind::Normal(..) | RVKind::Exponential(..) | RVKind::Gamma(..) =>
      continuous_variance(rv)
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      if symbolic_opaque_stats_name(name) {
        return match name {
          "FiniteDistributionHandmade" =>
            match symbolic_finite_handmade_variance(params) {
              Some(v) => Some(v)
              None => Some(variance_expr(@symcore.symbol(rv.name)))
            }
          _ =>
            match symbolic_special_variance(name, params, rv.name) {
              Some(v) => Some(v)
              None => Some(variance_expr(@symcore.symbol(rv.name)))
            }
        }
      }
      if symbolic_tag_family(tag) == "J" {
        match symbolic_joint_variance(name, params) {
          Some(v) => Some(v)
          None =>
            Some(
              symbolic_query_expr(
                name,
                "Variance",
                @symcore.symbol(rv.name),
                params,
              ),
            )
        }
      } else {
        match symbolic_special_variance(name, params, rv.name) {
          Some(v) => Some(v)
          None =>
            match (discrete_variance(rv), continuous_variance(rv)) {
              (Some(v), _) => Some(v)
              (_, Some(v)) => Some(v)
              _ =>
                Some(
                  symbolic_query_expr(
                    name,
                    "Variance",
                    @symcore.symbol(rv.name),
                    params,
                  ),
                )
            }
        }
      }
    }
    RVKind::Compound(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      let means : Array[@symcore.Expr] = Array::new()
      let weights : Array[@symnum.BigRational] = Array::new()
      for pair in items {
        let (w, item) = pair
        let renamed = rename_random_var(item, rv.name)
        match
          (
            expectation_of_rv(renamed, @symcore.symbol(rv.name)),
            variance_of_rv(renamed),
          ) {
          (Some(m), Some(v)) => {
            weights.push(w)
            means.push(m)
            terms.push(eval_arith(@symcore.mul([expr_from_big_rational(w), v])))
          }
          _ => return None
        }
      }
      let mean_terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<weights.length() {
        mean_terms.push(
          eval_arith(
            @symcore.mul([expr_from_big_rational(weights[i]), means[i]]),
          ),
        )
      }
      let total_mean = eval_arith(@symcore.add(mean_terms))
      for i in 0..<weights.length() {
        let diff = eval_arith(query_expr_sub(means[i], total_mean))
        let sq = eval_arith(@symcore.pow(diff, @symcore.int(2)))
        terms.push(
          eval_arith(@symcore.mul([expr_from_big_rational(weights[i]), sq])),
        )
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    _ => None
  }
}

///|
pub fn variance(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.length() == 1 {
    match expr {
      @symcore.Expr::Function(name, args) if name == rvs[0].name &&
        args.length() == 1 =>
        match process_variance_at(rvs[0], args[0]) {
          Some(v) => return v
          None => ()
        }
      _ => ()
    }
    if @symcore.compare_expr(expr, @symcore.symbol(rvs[0].name)) == 0 {
      match variance_of_rv(rvs[0]) {
        Some(v) => return v
        None => ()
      }
    }
  }
  if !rvs.is_empty() {
    let vars_map : Map[String, @symcore.Expr] = {}
    for rv in rvs {
      match variance_of_rv(rv) {
        Some(v) => vars_map[rv.name] = v
        None => ()
      }
    }
    let approx = variance_prop(expr, vars_map)
    if @symcore.compare_expr(approx, @symcore.function("variance_prop", [expr])) !=
      0 {
      return approx
    }
  }
  variance_expr(expr)
}

///|
pub fn covariance(
  a : @symcore.Expr,
  b : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if @symcore.compare_expr(a, b) == 0 {
    return variance(a, rvs~)
  }
  if rvs.length() >= 2 {
    match (a, b) {
      (@symcore.Expr::Symbol(sa), @symcore.Expr::Symbol(sb)) if sa != sb => {
        let map = rv_map(rvs)
        match (map.get(sa), map.get(sb)) {
          (Some(ra), Some(rb)) if assume_independent(ra, rb) =>
            return @symcore.int(0)
          _ => ()
        }
      }
      _ => ()
    }
    let ea = expectation(a, rvs~)
    let eb = expectation(b, rvs~)
    let eab = expectation(eval_arith(@symcore.mul([a, b])), rvs~)
    return eval_arith(query_expr_sub(eab, eval_arith(@symcore.mul([ea, eb]))))
  }
  covariance_expr(a, b)
}

///|
fn symbolic_opaque_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "ContinuousRV"
    | "ContinuousDistributionHandmade"
    | "DiscreteRV"
    | "DiscreteDistributionHandmade" =>
      if params.length() >= 1 {
        query_lambda_apply(params[0], [x])
      } else {
        None
      }
    "FiniteDistributionHandmade" =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          for pair in pairs {
            let (value, prob) = pair
            piecewise_args.push(
              tuple_expr([prob, @symcore.function("Eq", [x, value])]),
            )
          }
          piecewise_args.push(
            tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
          )
          Some(@symcore.function("Piecewise", piecewise_args))
        }
        None =>
          if params.length() >= 1 {
            query_lambda_apply(params[0], [x])
          } else {
            None
          }
      }
    "JointRV"
    | "MultivariateEwens"
    | "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega" =>
      symbolic_joint_density(name, params, x)
    _ => None
  }
}

///|
fn symbolic_process_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "BernoulliProcess" if params.length() >= 1 => {
      let p = params[0]
      let success = if params.length() >= 2 {
        params[1]
      } else {
        @symcore.int(1)
      }
      let failure = if params.length() >= 3 {
        params[2]
      } else {
        @symcore.int(0)
      }
      Some(
        @symcore.function("Piecewise", [
          tuple_expr([p, @symcore.function("Eq", [x, success])]),
          tuple_expr([
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                @symcore.mul([@symcore.int(-1), p]),
              ]),
            ),
            @symcore.function("Eq", [x, failure]),
          ]),
          tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
        ]),
      )
    }
    "GammaProcess" if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.symbol("t")
      let shape = eval_arith(@symcore.mul([gamma, t]))
      let body = eval_arith(
        @symcore.mul([
          @symcore.pow(lamda, shape),
          @symcore.pow(x, eval_arith(query_expr_sub(shape, @symcore.int(1)))),
          @symcore.function("exp", [
            eval_arith(@symcore.mul([@symcore.int(-1), lamda, x])),
          ]),
          @symcore.pow(@symcore.function("gamma", [shape]), @symcore.int(-1)),
        ]),
      )
      Some(
        @symcore.function("Piecewise", [
          tuple_expr([body, @symcore.function("Ge", [x, @symcore.int(0)])]),
          tuple_expr([@symcore.int(0), @symcore.symbol("True")]),
        ]),
      )
    }
    _ => None
  }
}

///|
fn symbolic_process_cdf(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "BernoulliProcess" if params.length() >= 1 => {
      let p = params[0]
      let one_minus_p = eval_arith(
        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])]),
      )
      let success = if params.length() >= 2 {
        params[1]
      } else {
        @symcore.int(1)
      }
      let failure = if params.length() >= 3 {
        params[2]
      } else {
        @symcore.int(0)
      }
      let between_value = @symcore.function("Piecewise", [
        tuple_expr([p, @symcore.function("Lt", [success, failure])]),
        tuple_expr([one_minus_p, @symcore.symbol("True")]),
      ])
      Some(
        @symcore.function("Piecewise", [
          tuple_expr([
            @symcore.int(0),
            @symcore.function("Lt", [
              x,
              @symcore.function("Min", [success, failure]),
            ]),
          ]),
          tuple_expr([
            between_value,
            @symcore.function("Lt", [
              x,
              @symcore.function("Max", [success, failure]),
            ]),
          ]),
          tuple_expr([@symcore.int(1), @symcore.symbol("True")]),
        ]),
      )
    }
    "GammaProcess" if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.symbol("t")
      let shape = eval_arith(@symcore.mul([gamma, t]))
      Some(
        @symcore.function("Piecewise", [
          tuple_expr([
            @symcore.int(0),
            @symcore.function("Lt", [x, @symcore.int(0)]),
          ]),
          tuple_expr([
            eval_arith(
              @symcore.mul([
                @symcore.function("lowergamma", [
                  shape,
                  eval_arith(@symcore.mul([lamda, x])),
                ]),
                @symcore.pow(
                  @symcore.function("gamma", [shape]),
                  @symcore.int(-1),
                ),
              ]),
            ),
            @symcore.symbol("True"),
          ]),
        ]),
      )
    }
    _ => None
  }
}

///|
fn symbolic_matrix_cdf(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  let tag = "M:\{name}"
  let rv = random_var("_M", RVKind::Symbolic(tag~, params~))
  let dummy = @symcore.symbol("_x")
  match matrix_density(rv, dummy) {
    Some(pdf) =>
      Some(
        eval_arith(
          @symcore.function("Integral", [
            pdf,
            tuple_expr([
              dummy,
              eval_arith(
                @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")]),
              ),
              x,
            ]),
          ]),
        ),
      )
    None => None
  }
}

///|
fn query_lambda_tuple_signature(
  template : @symcore.Expr,
) -> (Array[@symcore.Expr], @symcore.Expr)? {
  match template {
    @symcore.Expr::Function("Lambda", lambda_args) if lambda_args.length() == 2 =>
      match lambda_args[0] {
        @symcore.Expr::Function("Tuple", vars) => {
          for v in vars {
            match v {
              @symcore.Expr::Symbol(_) => ()
              _ => return None
            }
          }
          Some((vars, lambda_args[1]))
        }
        _ => None
      }
    _ => None
  }
}

///|
fn symbolic_joint_integration_vars(
  name : String,
  params : Array[@symcore.Expr],
) -> Array[@symcore.Expr]? {
  match name {
    "JointRV" =>
      if params.length() >= 1 {
        match query_lambda_tuple_signature(params[0]) {
          Some((vars, _)) => Some(vars)
          None => None
        }
      } else {
        None
      }
    "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega" =>
      if params.length() == 4 {
        match query_tuple_items(params[2]) {
          Some(lamdas) if !lamdas.is_empty() => {
            let vars : Array[@symcore.Expr] = Array::new()
            for i in 0..<lamdas.length() {
              vars.push(@symcore.symbol("_y\{i + 1}"))
            }
            Some(vars)
          }
          _ => None
        }
      } else {
        None
      }
    "Dirichlet" | "MultivariateBeta" if params.length() >= 2 => {
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<params.length() {
        vars.push(@symcore.symbol("_x\{i + 1}"))
      }
      Some(vars)
    }
    "MultivariateNormal" | "MultivariateLaplace" if params.length() >= 1 =>
      match query_tuple_items(params[0]) {
        Some(mu) if !mu.is_empty() => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<mu.length() {
            vars.push(@symcore.symbol("_x\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    "MultivariateT" if params.length() == 3 =>
      match query_tuple_items(params[0]) {
        Some(mu) if !mu.is_empty() => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<mu.length() {
            vars.push(@symcore.symbol("_x\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    "NormalGamma" if params.length() == 4 =>
      Some([@symcore.symbol("_x"), @symcore.symbol("_tau")])
    _ => None
  }
}

///|
fn symbolic_joint_integrand(
  name : String,
  params : Array[@symcore.Expr],
  vars : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match name {
    "JointRV" =>
      if params.length() >= 1 {
        query_lambda_apply(params[0], vars)
      } else {
        None
      }
    "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega" =>
      symbolic_joint_gmlg_density(name, params, tuple_expr(vars))
    "Dirichlet"
    | "MultivariateBeta"
    | "MultivariateNormal"
    | "MultivariateLaplace"
    | "MultivariateT"
    | "NormalGamma" => symbolic_joint_density(name, params, tuple_expr(vars))
    _ => None
  }
}

///|
fn symbolic_joint_cdf_lowers(
  name : String,
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")]),
  )
  match name {
    "Dirichlet" | "MultivariateBeta" => {
      let lowers : Array[@symcore.Expr] = Array::new()
      for _ in 0..<vars.length() {
        lowers.push(@symcore.int(0))
      }
      lowers
    }
    "NormalGamma" =>
      if vars.length() == 2 {
        [neg_oo, @symcore.int(0)]
      } else {
        let lowers : Array[@symcore.Expr] = Array::new()
        for _ in 0..<vars.length() {
          lowers.push(neg_oo)
        }
        lowers
      }
    _ => {
      let lowers : Array[@symcore.Expr] = Array::new()
      for _ in 0..<vars.length() {
        lowers.push(neg_oo)
      }
      lowers
    }
  }
}

///|
fn symbolic_joint_box_integral(
  name : String,
  params : Array[@symcore.Expr],
  lowers : Array[@symcore.Expr],
  uppers : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) if vars.length() == lowers.length() &&
      vars.length() == uppers.length() =>
      match symbolic_joint_integrand(name, params, vars) {
        Some(integrand) => {
          let args : Array[@symcore.Expr] = [integrand]
          for i in 0..<vars.length() {
            args.push(tuple_expr([vars[i], lowers[i], uppers[i]]))
          }
          Some(eval_arith(@symcore.function("Integral", args)))
        }
        None => None
      }
    _ => None
  }
}

///|
fn symbolic_joint_cdf(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) =>
      match query_tuple_items(x) {
        Some(bounds) if bounds.length() == vars.length() => {
          let lowers = symbolic_joint_cdf_lowers(name, vars)
          symbolic_joint_box_integral(name, params, lowers, bounds)
        }
        _ => None
      }
    None => None
  }
}

///|
fn symbolic_joint_survival(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) =>
      match query_tuple_items(x) {
        Some(bounds) if bounds.length() == vars.length() => {
          let uppers : Array[@symcore.Expr] = Array::new()
          for _ in 0..<vars.length() {
            uppers.push(@symcore.symbol("oo"))
          }
          symbolic_joint_box_integral(name, params, bounds, uppers)
        }
        _ => None
      }
    None => None
  }
}

///|
fn symbolic_joint_interval_probability(
  name : String,
  params : Array[@symcore.Expr],
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) =>
      match (query_tuple_items(lower), query_tuple_items(upper)) {
        (Some(low), Some(up)) if low.length() == vars.length() &&
          up.length() == vars.length() =>
          symbolic_joint_box_integral(name, params, low, up)
        _ => None
      }
    None => None
  }
}

///|
fn symbolic_joint_probability_continuous(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  event : Event,
) -> @symcore.Expr? {
  if !event_depends_only_on(event, rv_name) {
    return None
  }
  match event {
    Event::Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Event::Not(inner) =>
      match
        symbolic_joint_probability_continuous(name, params, rv_name, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Event::Rel(..) =>
      match query_extract_rel_to_var(event, rv_name) {
        Some((op, bound)) =>
          match op {
            RelOp::Eq => Some(@symcore.int(0))
            RelOp::Ne => Some(@symcore.int(1))
            RelOp::Le | RelOp::Lt => symbolic_joint_cdf(name, params, bound)
            RelOp::Ge | RelOp::Gt =>
              symbolic_joint_survival(name, params, bound)
          }
        None => None
      }
    Event::And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_var(items[0], rv_name)
        let r2 = query_extract_rel_to_var(items[1], rv_name)
        match (r1, r2) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower1 : @symcore.Expr? = match op1 {
              RelOp::Gt | RelOp::Ge => Some(b1)
              _ => None
            }
            let lower2 : @symcore.Expr? = match op2 {
              RelOp::Gt | RelOp::Ge => Some(b2)
              _ => None
            }
            let upper1 : @symcore.Expr? = match op1 {
              RelOp::Lt | RelOp::Le => Some(b1)
              _ => None
            }
            let upper2 : @symcore.Expr? = match op2 {
              RelOp::Lt | RelOp::Le => Some(b2)
              _ => None
            }
            let lower = match lower1 {
              Some(v) => Some(v)
              None => lower2
            }
            let upper = match upper1 {
              Some(v) => Some(v)
              None => upper2
            }
            match (lower, upper) {
              (Some(lo), Some(hi)) =>
                symbolic_joint_interval_probability(name, params, lo, hi)
              _ => None
            }
          }
          _ => None
        }
      } else {
        None
      }
    Event::Or(items) =>
      if items.length() == 2 {
        let a = items[0]
        let b = items[1]
        match
          (
            symbolic_joint_probability_continuous(name, params, rv_name, a),
            symbolic_joint_probability_continuous(name, params, rv_name, b),
            symbolic_joint_probability_continuous(
              name,
              params,
              rv_name,
              and_event([a, b]),
            ),
          ) {
          (Some(pa), Some(pb), Some(pab)) =>
            Some(
              eval_arith(
                @symcore.add([pa, pb, @symcore.mul([@symcore.int(-1), pab])]),
              ),
            )
          _ => None
        }
      } else {
        None
      }
  }
}

///|
fn symbolic_opaque_cdf(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  x : @symcore.Expr,
) -> @symcore.Expr? {
  ignore(rv_name)
  match name {
    "ContinuousRV" | "ContinuousDistributionHandmade" =>
      if params.length() >= 1 {
        let dummy = @symcore.symbol("_x")
        let neg_oo = eval_arith(
          @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")]),
        )
        match query_lambda_apply(params[0], [dummy]) {
          Some(pdf) =>
            Some(
              eval_arith(
                @symcore.function("Integral", [
                  pdf,
                  tuple_expr([dummy, neg_oo, x]),
                ]),
              ),
            )
          None => None
        }
      } else {
        None
      }
    "DiscreteRV" | "DiscreteDistributionHandmade" =>
      if params.length() >= 1 {
        let dummy = @symcore.symbol("_k")
        let neg_oo = eval_arith(
          @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")]),
        )
        let upper = @symcore.function("floor", [x])
        match query_lambda_apply(params[0], [dummy]) {
          Some(pmf) =>
            Some(
              eval_arith(
                @symcore.function("Sum", [
                  pmf,
                  tuple_expr([dummy, neg_oo, upper]),
                ]),
              ),
            )
          None => None
        }
      } else {
        None
      }
    "FiniteDistributionHandmade" =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let sorted_pairs = pairs
          sorted_pairs.sort_by((a, b) => @symcore.compare_expr(a.0, b.0))
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          let mut acc = @symcore.int(0)
          for pair in sorted_pairs {
            let (value, prob) = pair
            piecewise_args.push(
              tuple_expr([acc, @symcore.function("Lt", [x, value])]),
            )
            acc = eval_arith(@symcore.add([acc, prob]))
          }
          piecewise_args.push(tuple_expr([acc, @symcore.symbol("True")]))
          Some(@symcore.function("Piecewise", piecewise_args))
        }
        None => None
      }
    "JointRV"
    | "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega" =>
      symbolic_joint_cdf(name, params, x)
    "MultivariateEwens" => Some(symbolic_query_expr(name, "CDF", x, params))
    _ => None
  }
}

///|
fn query_extract_rel_to_var(
  event : Event,
  rv_name : String,
) -> (RelOp, @symcore.Expr)? {
  match event {
    Event::Rel(op~, lhs~, rhs~) =>
      match lhs {
        @symcore.Expr::Symbol(name) if name == rv_name => Some((op, rhs))
        _ =>
          match rhs {
            @symcore.Expr::Symbol(name) if name == rv_name =>
              Some((invert_relop(op), lhs))
            _ => None
          }
      }
    _ => None
  }
}

///|
fn symbolic_opaque_probability_continuous(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  event : Event,
) -> @symcore.Expr? {
  if !event_depends_only_on(event, rv_name) {
    return None
  }
  match event {
    Event::Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Event::Not(inner) =>
      match
        symbolic_opaque_probability_continuous(name, params, rv_name, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Event::Rel(..) =>
      match query_extract_rel_to_var(event, rv_name) {
        Some((op, bound)) =>
          match op {
            RelOp::Eq => Some(@symcore.int(0))
            RelOp::Ne => Some(@symcore.int(1))
            RelOp::Le | RelOp::Lt =>
              symbolic_opaque_cdf(name, params, rv_name, bound)
            RelOp::Ge | RelOp::Gt =>
              match symbolic_opaque_cdf(name, params, rv_name, bound) {
                Some(cdf_expr) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                None => None
              }
          }
        None => None
      }
    Event::And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_var(items[0], rv_name)
        let r2 = query_extract_rel_to_var(items[1], rv_name)
        match (r1, r2) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower1 : @symcore.Expr? = match op1 {
              RelOp::Gt | RelOp::Ge => Some(b1)
              _ => None
            }
            let lower2 : @symcore.Expr? = match op2 {
              RelOp::Gt | RelOp::Ge => Some(b2)
              _ => None
            }
            let upper1 : @symcore.Expr? = match op1 {
              RelOp::Lt | RelOp::Le => Some(b1)
              _ => None
            }
            let upper2 : @symcore.Expr? = match op2 {
              RelOp::Lt | RelOp::Le => Some(b2)
              _ => None
            }
            let lower = match lower1 {
              Some(v) => Some(v)
              None => lower2
            }
            let upper = match upper1 {
              Some(v) => Some(v)
              None => upper2
            }
            match (lower, upper) {
              (Some(lo), Some(hi)) =>
                match
                  (
                    symbolic_opaque_cdf(name, params, rv_name, lo),
                    symbolic_opaque_cdf(name, params, rv_name, hi),
                  ) {
                  (Some(cl), Some(cu)) =>
                    Some(eval_arith(query_expr_sub(cu, cl)))
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
    Event::Or(items) =>
      if items.length() == 2 {
        let a = items[0]
        let b = items[1]
        match
          (
            symbolic_opaque_probability_continuous(name, params, rv_name, a),
            symbolic_opaque_probability_continuous(name, params, rv_name, b),
            symbolic_opaque_probability_continuous(
              name,
              params,
              rv_name,
              and_event([a, b]),
            ),
          ) {
          (Some(pa), Some(pb), Some(pab)) =>
            Some(
              eval_arith(
                @symcore.add([pa, pb, @symcore.mul([@symcore.int(-1), pab])]),
              ),
            )
          _ => None
        }
      } else {
        None
      }
  }
}

///|
fn symbolic_opaque_probability_discrete(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  event : Event,
) -> @symcore.Expr? {
  if !event_depends_only_on(event, rv_name) {
    return None
  }
  match event {
    Event::Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Event::Not(inner) =>
      match symbolic_opaque_probability_discrete(name, params, rv_name, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Event::Rel(..) =>
      match query_extract_rel_to_var(event, rv_name) {
        Some((op, bound)) =>
          match op {
            RelOp::Eq => symbolic_opaque_density(name, params, bound)
            RelOp::Ne =>
              match symbolic_opaque_density(name, params, bound) {
                Some(pmf) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), pmf)))
                None => None
              }
            RelOp::Le => symbolic_opaque_cdf(name, params, rv_name, bound)
            RelOp::Lt =>
              symbolic_opaque_cdf(
                name,
                params,
                rv_name,
                eval_arith(query_expr_sub(bound, @symcore.int(1))),
              )
            RelOp::Ge =>
              match
                symbolic_opaque_cdf(
                  name,
                  params,
                  rv_name,
                  eval_arith(query_expr_sub(bound, @symcore.int(1))),
                ) {
                Some(cdf_expr) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                None => None
              }
            RelOp::Gt =>
              match symbolic_opaque_cdf(name, params, rv_name, bound) {
                Some(cdf_expr) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                None => None
              }
          }
        None => None
      }
    Event::And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_var(items[0], rv_name)
        let r2 = query_extract_rel_to_var(items[1], rv_name)
        match (r1, r2) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower1 : (@symcore.Expr, Bool)? = match op1 {
              RelOp::Gt => Some((b1, true))
              RelOp::Ge => Some((b1, false))
              _ => None
            }
            let lower2 : (@symcore.Expr, Bool)? = match op2 {
              RelOp::Gt => Some((b2, true))
              RelOp::Ge => Some((b2, false))
              _ => None
            }
            let upper1 : (@symcore.Expr, Bool)? = match op1 {
              RelOp::Lt => Some((b1, true))
              RelOp::Le => Some((b1, false))
              _ => None
            }
            let upper2 : (@symcore.Expr, Bool)? = match op2 {
              RelOp::Lt => Some((b2, true))
              RelOp::Le => Some((b2, false))
              _ => None
            }
            let lower = match lower1 {
              Some(v) => Some(v)
              None => lower2
            }
            let upper = match upper1 {
              Some(v) => Some(v)
              None => upper2
            }
            match (lower, upper) {
              (Some((lo, lo_strict)), Some((hi, hi_strict))) => {
                let lo_arg = if lo_strict {
                  lo
                } else {
                  eval_arith(query_expr_sub(lo, @symcore.int(1)))
                }
                let hi_arg = if hi_strict {
                  eval_arith(query_expr_sub(hi, @symcore.int(1)))
                } else {
                  hi
                }
                match
                  (
                    symbolic_opaque_cdf(name, params, rv_name, lo_arg),
                    symbolic_opaque_cdf(name, params, rv_name, hi_arg),
                  ) {
                  (Some(cl), Some(cu)) =>
                    Some(eval_arith(query_expr_sub(cu, cl)))
                  _ => None
                }
              }
              _ => None
            }
          }
          _ => None
        }
      } else {
        None
      }
    Event::Or(items) =>
      if items.length() == 2 {
        let a = items[0]
        let b = items[1]
        match
          (
            symbolic_opaque_probability_discrete(name, params, rv_name, a),
            symbolic_opaque_probability_discrete(name, params, rv_name, b),
            symbolic_opaque_probability_discrete(
              name,
              params,
              rv_name,
              and_event([a, b]),
            ),
          ) {
          (Some(pa), Some(pb), Some(pab)) =>
            Some(
              eval_arith(
                @symcore.add([pa, pb, @symcore.mul([@symcore.int(-1), pab])]),
              ),
            )
          _ => None
        }
      } else {
        None
      }
  }
}

///|
fn symbolic_opaque_probability(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  event : Event,
) -> @symcore.Expr? {
  match name {
    "ContinuousRV" | "ContinuousDistributionHandmade" =>
      symbolic_opaque_probability_continuous(name, params, rv_name, event)
    "DiscreteRV"
    | "DiscreteDistributionHandmade"
    | "FiniteDistributionHandmade" =>
      symbolic_opaque_probability_discrete(name, params, rv_name, event)
    "JointRV"
    | "GeneralizedMultivariateLogGamma"
    | "GeneralizedMultivariateLogGammaOmega" =>
      symbolic_joint_probability_continuous(name, params, rv_name, event)
    "MultivariateEwens" =>
      if !event_depends_only_on(event, rv_name) {
        None
      } else {
        match event {
          Event::Bool(v) =>
            Some(if v { @symcore.int(1) } else { @symcore.int(0) })
          Event::Not(inner) =>
            match symbolic_opaque_probability(name, params, rv_name, inner) {
              Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
              None => None
            }
          Event::Rel(..) =>
            match query_extract_rel_to_var(event, rv_name) {
              Some((RelOp::Eq, point)) =>
                symbolic_opaque_density(name, params, point)
              Some((RelOp::Ne, point)) =>
                match symbolic_opaque_density(name, params, point) {
                  Some(d) =>
                    Some(eval_arith(query_expr_sub(@symcore.int(1), d)))
                  None => None
                }
              Some((RelOp::Le, point)) | Some((RelOp::Lt, point)) =>
                symbolic_opaque_cdf(name, params, rv_name, point)
              Some((RelOp::Ge, point)) | Some((RelOp::Gt, point)) =>
                match symbolic_opaque_cdf(name, params, rv_name, point) {
                  Some(cdf_expr) =>
                    Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                  None => None
                }
              None => None
            }
          Event::Or(items) =>
            if items.length() == 2 {
              let a = items[0]
              let b = items[1]
              match
                (
                  symbolic_opaque_probability(name, params, rv_name, a),
                  symbolic_opaque_probability(name, params, rv_name, b),
                  symbolic_opaque_probability(
                    name,
                    params,
                    rv_name,
                    and_event([a, b]),
                  ),
                ) {
                (Some(pa), Some(pb), Some(pab)) =>
                  Some(
                    eval_arith(
                      @symcore.add([
                        pa,
                        pb,
                        @symcore.mul([@symcore.int(-1), pab]),
                      ]),
                    ),
                  )
                _ => None
              }
            } else {
              None
            }
          _ => None
        }
      }
    _ => None
  }
}

///|
pub fn density(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr {
  match discrete_pmf(rv, x) {
    Some(v) => v
    None =>
      match continuous_density(rv, x) {
        Some(v) => v
        None =>
          match rv.kind {
            RVKind::Symbolic(tag~, params~) => {
              let name = symbolic_tag_name(tag)
              if symbolic_opaque_stats_name(name) {
                match symbolic_opaque_density(name, params, x) {
                  Some(v) => v
                  None =>
                    @symcore.function("density", [@symcore.symbol(rv.name), x])
                }
              } else if symbolic_tag_family(tag) == "P" {
                match symbolic_process_density(name, params, x) {
                  Some(v) => v
                  None => symbolic_query_expr(name, "Density", x, params)
                }
              } else if symbolic_tag_family(tag) == "J" {
                match symbolic_joint_density(name, params, x) {
                  Some(v) => v
                  None => symbolic_query_expr(name, "Density", x, params)
                }
              } else {
                symbolic_query_expr(name, "Density", x, params)
              }
            }
            _ => @symcore.function("density", [@symcore.symbol(rv.name), x])
          }
      }
  }
}

///|
pub fn cdf(rv : RandomVar, x : @symcore.Expr) -> @symcore.Expr {
  match discrete_cdf(rv, x) {
    Some(v) => v
    None =>
      match continuous_cdf(rv, x) {
        Some(v) => v
        None =>
          match rv.kind {
            RVKind::Symbolic(tag~, params~) => {
              let name = symbolic_tag_name(tag)
              let family = symbolic_tag_family(tag)
              if symbolic_opaque_stats_name(name) {
                match symbolic_opaque_cdf(name, params, rv.name, x) {
                  Some(v) => v
                  None =>
                    match family {
                      "P" =>
                        match symbolic_process_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      "J" =>
                        match symbolic_joint_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      "M" =>
                        match symbolic_matrix_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      _ => symbolic_query_expr(name, "CDF", x, params)
                    }
                }
              } else if family == "P" {
                match symbolic_process_cdf(name, params, x) {
                  Some(v) => v
                  None => symbolic_query_expr(name, "CDF", x, params)
                }
              } else if family == "J" {
                match symbolic_joint_cdf(name, params, x) {
                  Some(v) => v
                  None => symbolic_query_expr(name, "CDF", x, params)
                }
              } else if family == "M" {
                match symbolic_matrix_cdf(name, params, x) {
                  Some(v) => v
                  None => symbolic_query_expr(name, "CDF", x, params)
                }
              } else {
                symbolic_query_expr(name, "CDF", x, params)
              }
            }
            _ => @symcore.function("cdf", [@symcore.symbol(rv.name), x])
          }
      }
  }
}

///|
pub fn std(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  @symcore.function("sqrt", [variance(expr, rvs~)])
}

///|
pub fn moment(rv : RandomVar, n : Int) -> @symcore.Expr {
  let x = @symcore.symbol(rv.name)
  expectation(@symcore.pow(x, @symcore.int(n)), rvs=[rv])
}
