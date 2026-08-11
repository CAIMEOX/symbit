///|
/// Unified query interface (`P/E/variance/covariance/density/cdf` style).

///|
fn query_expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.add([a, @symcore.mul([@symcore.int(-1), b])])
}

///|
fn rv_map(rvs : Array[RandomVar]) -> Map[String, RandomVar] {
  let out : Map[String, RandomVar] = Map([])
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
  let dist = @symcore.function(name, params)
  match suffix {
    "Probability" => @symcore.function("Probability", [head])
    "Mean" => @symcore.function("Expectation", [head])
    "Variance" => @symcore.function("Variance", [head])
    "Density" => @symcore.function("density", [dist, head])
    "CDF" => @symcore.function("cdf", [dist, head])
    _ => {
      let args : Array[@symcore.Expr] = [head]
      for p in params {
        args.push(p)
      }
      @symcore.function("\{name}\{suffix}", args)
    }
  }
}

///|

///|
fn tuple_matrix(rows : Array[Array[@symcore.Expr]]) -> @symcore.Expr {
  Tuple(rows.map(row => Tuple(row)))
}

///|
fn scale_tuple_matrix(
  mat : @symcore.Expr,
  scale : @symcore.Expr,
) -> @symcore.Expr {
  match @symcore.tuple_items(mat) {
    Some(rows) =>
      Tuple(
        rows.map(row => {
          match @symcore.tuple_items(row) {
            Some(cols) =>
              Tuple(cols.map(col => eval_arith(@symcore.mul([scale, col]))))
            None => eval_arith(@symcore.mul([scale, row]))
          }
        }),
      )
    None => eval_arith(@symcore.mul([scale, mat]))
  }
}

///|
fn symbolic_joint_mean(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match joint_tag_from_name(name) {
    Dirichlet | MultivariateBeta if params.length() >= 2 => {
      let total = eval_arith(@symcore.add(params))
      let means = params.map(a => {
        eval_arith(@symcore.mul([a, @symcore.pow(total, @symcore.int(-1))]))
      })
      Some(Tuple(means))
    }
    MultivariateT if params.length() == 3 => Some(params[0])
    MultivariateLaplace if params.length() >= 2 => Some(params[0])
    MultivariateNormal if params.length() >= 1 => Some(params[0])
    NormalGamma if params.length() == 4 =>
      Some(
        Tuple([
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
  match joint_tag_from_name(name) {
    Dirichlet | MultivariateBeta if params.length() >= 2 => {
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
    MultivariateT if params.length() == 3 => {
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
    MultivariateLaplace if params.length() >= 2 => Some(params[1])
    MultivariateNormal if params.length() >= 2 => Some(params[1])
    NormalGamma if params.length() == 4 => {
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

///|
fn query_tuple2(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr)? {
  match @symcore.tuple_items(expr) {
    Some(items) if items.length() == 2 => Some((items[0], items[1]))
    _ => None
  }
}

///|
fn query_replace_expr(
  expr : @symcore.Expr,
  target : @symcore.Expr,
  replacement : @symcore.Expr,
) -> @symcore.Expr {
  if expr == target {
    return replacement
  }
  match expr {
    Number(_)
    | Float(_)
    | ComplexFloat(_)
    | NumberSymbol(_)
    | Boolean(_)
    | Symbol(_)
    | Dummy(_, _)
    | Wild(_, _, _)
    | FunctionHead(_)
    | UndefinedFunction(_) => expr
    Apply(head, args) =>
      @symcore.raw_apply(
        head,
        args.map(arg => query_replace_expr(arg, target, replacement)),
      ).unwrap_or(
        Apply(
          head,
          args.map(arg => query_replace_expr(arg, target, replacement)),
        ),
      )
    Add(args) =>
      eval_arith(
        @symcore.add(
          args.map(arg => query_replace_expr(arg, target, replacement)),
        ),
      )
    Mul(args) =>
      eval_arith(
        @symcore.mul(
          args.map(arg => query_replace_expr(arg, target, replacement)),
        ),
      )
    Mod(lhs, rhs) =>
      @symcore.mod_expr(
        query_replace_expr(lhs, target, replacement),
        query_replace_expr(rhs, target, replacement),
      )
    Pow(base, exp) =>
      eval_arith(
        @symcore.pow(
          query_replace_expr(base, target, replacement),
          query_replace_expr(exp, target, replacement),
        ),
      )
    Tuple(args) =>
      Tuple(args.map(arg => query_replace_expr(arg, target, replacement)))
    Dict(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (
            query_replace_expr(key, target, replacement),
            query_replace_expr(value, target, replacement),
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
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        Ne =>
          Relational(
            Ne,
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        Lt =>
          Relational(
            Lt,
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        Le =>
          Relational(
            Le,
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        Gt =>
          Relational(
            Gt,
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        Ge =>
          Relational(
            Ge,
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
      }
    Derivative(inner, deriv_args) => {
      let out : Array[@symcore.Expr] = []
      out.push(query_replace_expr(inner, target, replacement))
      for arg in deriv_args {
        out.push(query_replace_expr(arg, target, replacement))
      }
      @symcore.raw_function("Derivative", out)
    }
    Subs(inner, variable, value) =>
      @symcore.subs_expr(
        query_replace_expr(inner, target, replacement),
        query_replace_expr(variable, target, replacement),
        query_replace_expr(value, target, replacement),
      )
    Lambda(vars, body) =>
      @symcore.lambda_expr(
        query_replace_expr(vars, target, replacement),
        query_replace_expr(body, target, replacement),
      )
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          @symcore.raw_apply(
            head,
            args.map(arg => query_replace_expr(arg, target, replacement)),
          ).unwrap_or(expr)
        None => expr
      }
  }
}

///|
fn query_matrix2x2(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr, @symcore.Expr)? {
  match @symcore.tuple_items(expr) {
    Some(rows) if rows.length() == 2 =>
      match (@symcore.tuple_items(rows[0]), @symcore.tuple_items(rows[1])) {
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
    Symbol(name) => Some(@symcore.function(name, args))
    _ =>
      match @symcore.lambda_parts(template) {
        Some((vars, body)) =>
          match vars {
            Symbol(v) =>
              if args.length() == 1 {
                let env : Map[String, @symcore.Expr] = Map([])
                env[v] = args[0]
                Some(eval_arith(@symcore.subst(body, env)))
              } else {
                None
              }
            _ =>
              match @symcore.tuple_items(vars) {
                Some(vs) =>
                  if vs.length() == args.length() {
                    let mut out = body
                    for i in 0..<vs.length() {
                      out = query_replace_expr(out, vs[i], args[i])
                    }
                    Some(eval_arith(out))
                  } else {
                    None
                  }
                None => None
              }
          }
        None => None
      }
  }
}

///|
fn query_tuple_pairs(
  expr : @symcore.Expr,
) -> Array[(@symcore.Expr, @symcore.Expr)]? {
  match @symcore.tuple_items(expr) {
    Some(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = Array::new()
      for item in items {
        match @symcore.tuple_items(item) {
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
  match symbolic_kind_from_name(name) {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) =>
      symbolic_continuous_handmade_mean(params)
    Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      symbolic_discrete_handmade_mean(params)
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_mean_via_integral(name, params)
    Joint(MultivariateEwens) => symbolic_multivariate_ewens_mean(params)
    Matrix(
      GaussianEnsemble
      | GaussianOrthogonalEnsemble
      | GaussianUnitaryEnsemble
      | GaussianSymplecticEnsemble
      | CircularEnsemble
      | CircularUnitaryEnsemble
      | CircularOrthogonalEnsemble
      | CircularSymplecticEnsemble
    ) if params.length() == 1 =>
      Some(@symcore.function("ZeroMatrix", [params[0], params[0]]))
    Matrix(MatrixGamma) if params.length() == 3 =>
      Some(eval_arith(@symcore.mul([params[0], params[1], params[2]])))
    Matrix(MatrixStudentT) if params.length() == 4 => Some(params[1])
    _ => None
  }
}

///|
fn symbolic_special_variance(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
) -> @symcore.Expr? {
  match symbolic_kind_from_name(name) {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) =>
      symbolic_continuous_handmade_variance(params)
    Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      symbolic_discrete_handmade_variance(params)
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_variance_via_integral(name, params)
    Joint(MultivariateEwens) => symbolic_multivariate_ewens_variance(params)
    Matrix(
      GaussianEnsemble
      | GaussianOrthogonalEnsemble
      | GaussianUnitaryEnsemble
      | GaussianSymplecticEnsemble
      | CircularEnsemble
      | CircularUnitaryEnsemble
      | CircularOrthogonalEnsemble
      | CircularSymplecticEnsemble
    ) if params.length() == 1 => {
      let x = @symcore.Expr::Symbol(rv_name)
      let mean = @symcore.function("ZeroMatrix", [params[0], params[0]])
      Some(
        @symcore.function("Expectation", [
          eval_arith(@symcore.pow(query_expr_sub(x, mean), @symcore.int(2))),
        ]),
      )
    }
    Matrix(MatrixGamma) if params.length() == 3 =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            @symcore.pow(params[2], @symcore.int(2)),
          ]),
        ),
      )
    Matrix(MatrixStudentT) if params.length() == 4 =>
      Some(
        @symcore.function("Expectation", [
          eval_arith(
            @symcore.pow(
              query_expr_sub(Symbol(rv_name), params[1]),
              @symcore.int(2),
            ),
          ),
        ]),
      )
    _ => None
  }
}

///|
fn symbolic_continuous_handmade_mean(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  if params.length() < 1 {
    return None
  }
  let x = @symcore.Expr::Symbol("_x")
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
  )
  match query_lambda_apply(params[0], [x]) {
    Some(pdf) =>
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(@symcore.mul([x, pdf])),
            Tuple([x, neg_oo, NumberSymbol(Infinity)]),
          ]),
        ),
      )
    None => None
  }
}

///|
fn symbolic_continuous_handmade_variance(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  if params.length() < 1 {
    return None
  }
  let x = @symcore.Expr::Symbol("_x")
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
  )
  match
    (
      query_lambda_apply(params[0], [x]),
      symbolic_continuous_handmade_mean(params),
    ) {
    (Some(pdf), Some(mean_expr)) =>
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(
              @symcore.mul([
                @symcore.pow(
                  eval_arith(query_expr_sub(x, mean_expr)),
                  @symcore.int(2),
                ),
                pdf,
              ]),
            ),
            Tuple([x, neg_oo, NumberSymbol(Infinity)]),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn symbolic_discrete_handmade_mean(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  if params.length() < 1 {
    return None
  }
  let k = @symcore.Expr::Symbol("_k")
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
  )
  match query_lambda_apply(params[0], [k]) {
    Some(pmf) =>
      Some(
        eval_arith(
          @symcore.function("Sum", [
            eval_arith(@symcore.mul([k, pmf])),
            Tuple([k, neg_oo, NumberSymbol(Infinity)]),
          ]),
        ),
      )
    None => None
  }
}

///|
fn symbolic_discrete_handmade_variance(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  if params.length() < 1 {
    return None
  }
  let k = @symcore.Expr::Symbol("_k")
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
  )
  match
    (
      query_lambda_apply(params[0], [k]),
      symbolic_discrete_handmade_mean(params),
    ) {
    (Some(pmf), Some(mean_expr)) =>
      Some(
        eval_arith(
          @symcore.function("Sum", [
            eval_arith(
              @symcore.mul([
                @symcore.pow(
                  eval_arith(query_expr_sub(k, mean_expr)),
                  @symcore.int(2),
                ),
                pmf,
              ]),
            ),
            Tuple([k, neg_oo, NumberSymbol(Infinity)]),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn symbolic_joint_integral_bounds(
  name : String,
  vars : Array[@symcore.Expr],
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) {
  let lowers = symbolic_joint_cdf_lowers(name, vars)
  let uppers : Array[@symcore.Expr] = Array::new()
  for _ in 0..<vars.length() {
    uppers.push(NumberSymbol(Infinity))
  }
  (lowers, uppers)
}

///|
fn symbolic_joint_nested_integral(
  integrand : @symcore.Expr,
  vars : Array[@symcore.Expr],
  lowers : Array[@symcore.Expr],
  uppers : Array[@symcore.Expr],
) -> @symcore.Expr {
  let mut expr = integrand
  for i in 0..<vars.length() {
    expr = eval_arith(
      @symcore.function("Integral", [
        expr,
        Tuple([vars[i], lowers[i], uppers[i]]),
      ]),
    )
  }
  expr
}

///|
fn symbolic_joint_mean_via_integral(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) if !vars.is_empty() =>
      match symbolic_joint_integrand(name, params, vars) {
        Some(dens) => {
          let (lowers, uppers) = symbolic_joint_integral_bounds(name, vars)
          let means : Array[@symcore.Expr] = Array::new()
          for v in vars {
            means.push(
              symbolic_joint_nested_integral(
                eval_arith(@symcore.mul([v, dens])),
                vars,
                lowers,
                uppers,
              ),
            )
          }
          Some(Tuple(means))
        }
        None => None
      }
    _ => None
  }
}

///|
fn symbolic_joint_variance_via_integral(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match
    (
      symbolic_joint_integration_vars(name, params),
      symbolic_joint_mean_via_integral(name, params),
    ) {
    (Some(vars), Some(mean_expr)) if !vars.is_empty() =>
      match
        (
          symbolic_joint_integrand(name, params, vars),
          @symcore.tuple_items(mean_expr),
        ) {
        (Some(dens), Some(means)) if means.length() == vars.length() => {
          let (lowers, uppers) = symbolic_joint_integral_bounds(name, vars)
          let rows : Array[Array[@symcore.Expr]] = Array::new()
          for i in 0..<vars.length() {
            let row : Array[@symcore.Expr] = Array::new()
            for j in 0..<vars.length() {
              let centered_i = eval_arith(query_expr_sub(vars[i], means[i]))
              let centered_j = eval_arith(query_expr_sub(vars[j], means[j]))
              row.push(
                symbolic_joint_nested_integral(
                  eval_arith(@symcore.mul([centered_i, centered_j, dens])),
                  vars,
                  lowers,
                  uppers,
                ),
              )
            }
            rows.push(row)
          }
          Some(tuple_matrix(rows))
        }
        _ => None
      }
    _ => None
  }
}

///|
fn symbolic_multivariate_ewens_arity(params : Array[@symcore.Expr]) -> Int? {
  if params.length() != 2 {
    return None
  }
  match expr_as_int(params[0]) {
    Some(n) if n > 0 => Some(n)
    _ => None
  }
}

///|
fn symbolic_multivariate_ewens_nested_sum(
  integrand : @symcore.Expr,
  vars : Array[@symcore.Expr],
  n : Int,
) -> @symcore.Expr {
  let mut expr = integrand
  for i in 0..<vars.length() {
    expr = eval_arith(
      @symcore.function("Sum", [
        expr,
        Tuple([vars[i], @symcore.int(0), @symcore.int(n / (i + 1))]),
      ]),
    )
  }
  expr
}

///|
fn symbolic_multivariate_ewens_mean(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_multivariate_ewens_arity(params) {
    Some(n) => {
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<n {
        vars.push(Symbol("_k\{i + 1}"))
      }
      match symbolic_multivariate_ewens_density(params, Tuple(vars)) {
        Some(pmf) => {
          let means : Array[@symcore.Expr] = Array::new()
          for v in vars {
            means.push(
              symbolic_multivariate_ewens_nested_sum(
                eval_arith(@symcore.mul([v, pmf])),
                vars,
                n,
              ),
            )
          }
          Some(Tuple(means))
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn symbolic_multivariate_ewens_variance(
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match
    (
      symbolic_multivariate_ewens_arity(params),
      symbolic_multivariate_ewens_mean(params),
    ) {
    (Some(n), Some(mean_expr)) =>
      match @symcore.tuple_items(mean_expr) {
        Some(means) if means.length() == n => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<n {
            vars.push(Symbol("_k\{i + 1}"))
          }
          match symbolic_multivariate_ewens_density(params, Tuple(vars)) {
            Some(pmf) => {
              let rows : Array[Array[@symcore.Expr]] = Array::new()
              for i in 0..<n {
                let row : Array[@symcore.Expr] = Array::new()
                for j in 0..<n {
                  let centered_i = eval_arith(query_expr_sub(vars[i], means[i]))
                  let centered_j = eval_arith(query_expr_sub(vars[j], means[j]))
                  row.push(
                    symbolic_multivariate_ewens_nested_sum(
                      eval_arith(@symcore.mul([centered_i, centered_j, pmf])),
                      vars,
                      n,
                    ),
                  )
                }
                rows.push(row)
              }
              Some(tuple_matrix(rows))
            }
            None => None
          }
        }
        _ => None
      }
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
  match @symcore.tuple_items(x) {
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
          Tuple([body, @symcore.function("Eq", [cond_sum, n])]),
          Tuple([@symcore.int(0), Boolean(true)]),
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
      @symcore.tuple_items(lamda_expr),
      @symcore.tuple_items(mu_expr),
      @symcore.tuple_items(x),
    ) {
    (Some(lamdas), Some(mus), Some(xs)) if lamdas.length() == mus.length() &&
      mus.length() == xs.length() &&
      xs.length() > 1 => {
      let k = lamdas.length()
      let n_var = @symcore.Expr::Symbol("_k")
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
        Tuple([n_var, @symcore.int(0), NumberSymbol(Infinity)]),
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
  match joint_tag_from_name(name) {
    GeneralizedMultivariateLogGamma if params.length() == 4 =>
      symbolic_generalized_multivariate_log_gamma_density(
        params[0],
        params[1],
        params[2],
        params[3],
        x,
      )
    GeneralizedMultivariateLogGammaOmega if params.length() == 4 =>
      match @symcore.tuple_items(params[2]) {
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
  match joint_tag_from_name(name) {
    JointRV if params.length() >= 1 =>
      match @symcore.tuple_items(x) {
        Some(xs) => query_lambda_apply(params[0], xs)
        None => query_lambda_apply(params[0], [x])
      }
    MultivariateEwens if params.length() == 2 =>
      symbolic_multivariate_ewens_density(params, x)
    GeneralizedMultivariateLogGamma | GeneralizedMultivariateLogGammaOmega =>
      symbolic_joint_gmlg_density(name, params, x)
    Dirichlet | MultivariateBeta if params.length() >= 2 =>
      match @symcore.tuple_items(x) {
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
    NormalGamma if params.length() == 4 =>
      match query_tuple2(x) {
        Some((xv, tau)) => {
          let mu = params[0]
          let lamda = params[1]
          let alpha = params[2]
          let beta = params[3]
          let half = stats_exact_rational(1, 2)
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
                eval_arith(@symcore.mul([@symcore.int(2), NumberSymbol(Pi)])),
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
    MultivariateNormal if params.length() >= 2 =>
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
          let half = stats_exact_rational(1, 2)
          let quad = eval_arith(
            @symcore.mul([quad_num, @symcore.pow(det, @symcore.int(-1))]),
          )
          let norm = eval_arith(
            @symcore.mul([
              @symcore.int(2),
              NumberSymbol(Pi),
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
    MultivariateLaplace if params.length() >= 2 =>
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
            @symcore.mul([NumberSymbol(Pi), @symcore.function("sqrt", [det])]),
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
    MultivariateT if params.length() == 3 =>
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
          let half = stats_exact_rational(1, 2)
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
                    NumberSymbol(Pi),
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
    And(items) => items
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
    Finite(_) => finite_probability(rv, event)
    StochasticProcess(_) => process_probability_event(rv, event)
    Binomial(..) | Poisson(..) | Geometric(..) | NegativeBinomial(..) =>
      discrete_probability(rv, event)
    Normal(..) | Exponential(..) | Gamma(..) =>
      continuous_probability(rv, event)
    Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      match kind {
        Process(_) =>
          match process_probability_event(rv, event) {
            Some(v) => return Some(v)
            None => ()
          }
        _ => ()
      }
      if symbolic_kind_is_opaque(kind) {
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
    JointIndependent(items) => probability_joint_independent(items, event)
    Compound(items) => probability_compound(items, rv.name, event)
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
    Finite(_) => finite_expectation(rv, expr~)
    StochasticProcess(_) =>
      match expr {
        Symbol(name) if name == rv.name => Some(Symbol(rv.name))
        _ if @symcore.application_has_name(expr, rv.name, arity=1) =>
          process_mean_at(rv, @symcore.application_args(expr).unwrap()[0])
        _ => None
      }
    Binomial(..) | Poisson(..) | Geometric(..) | NegativeBinomial(..) =>
      if @symcore.compare_expr(expr, Symbol(rv.name)) == 0 {
        discrete_mean(rv)
      } else {
        None
      }
    Normal(..) | Exponential(..) | Gamma(..) =>
      if @symcore.compare_expr(expr, Symbol(rv.name)) == 0 {
        continuous_mean(rv)
      } else {
        None
      }
    Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      if symbolic_kind_is_opaque(kind) {
        match expr {
          Symbol(sym) if sym == rv.name =>
            match kind {
              Discrete(FiniteDistributionHandmade) =>
                match symbolic_finite_handmade_mean(params) {
                  Some(v) => Some(v)
                  None => Some(Symbol(rv.name))
                }
              _ =>
                match symbolic_opaque_mean(name, params) {
                  Some(v) => Some(v)
                  None => Some(Symbol(rv.name))
                }
            }
          _ if @symcore.application_has_name(expr, rv.name, arity=1) =>
            match kind {
              Process(_) =>
                process_mean_at(rv, @symcore.application_args(expr).unwrap()[0])
              _ => None
            }
          _ => None
        }
      } else if @symcore.compare_expr(expr, Symbol(rv.name)) == 0 {
        match kind {
          Joint(_) =>
            match symbolic_joint_mean(name, params) {
              Some(v) => Some(v)
              None =>
                Some(symbolic_query_expr(name, "Mean", Symbol(rv.name), params))
            }
          _ =>
            match symbolic_opaque_mean(name, params) {
              Some(v) => Some(v)
              None =>
                match (discrete_mean(rv), continuous_mean(rv)) {
                  (Some(v), _) => Some(v)
                  (_, Some(v)) => Some(v)
                  _ =>
                    Some(
                      symbolic_query_expr(name, "Mean", Symbol(rv.name), params),
                    )
                }
            }
        }
      } else {
        None
      }
    }
    Compound(items) => {
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
    Number(_) | Float(_) | ComplexFloat(_) => Some(expr)
    Symbol(name) =>
      match map.get(name) {
        Some(rv) => expectation_of_rv(rv, Symbol(name))
        None => Some(expr)
      }
    Add(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for item in items {
        match expectation_eval_independent(item, map) {
          Some(v) => terms.push(v)
          None => return None
        }
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    Mul(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      let seen_rv : Map[String, Bool] = Map([])
      for item in items {
        match item {
          Symbol(name) =>
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
    Finite(_) => finite_variance(rv)
    StochasticProcess(_) => Some(variance_expr(Symbol(rv.name)))
    Binomial(..) | Poisson(..) | Geometric(..) | NegativeBinomial(..) =>
      discrete_variance(rv)
    Normal(..) | Exponential(..) | Gamma(..) => continuous_variance(rv)
    Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      if symbolic_kind_is_opaque(kind) {
        return match kind {
          Discrete(FiniteDistributionHandmade) =>
            match symbolic_finite_handmade_variance(params) {
              Some(v) => Some(v)
              None => Some(variance_expr(Symbol(rv.name)))
            }
          _ =>
            match symbolic_special_variance(name, params, rv.name) {
              Some(v) => Some(v)
              None => Some(variance_expr(Symbol(rv.name)))
            }
        }
      }
      match kind {
        Joint(_) =>
          match symbolic_joint_variance(name, params) {
            Some(v) => Some(v)
            None =>
              Some(
                symbolic_query_expr(name, "Variance", Symbol(rv.name), params),
              )
          }
        _ =>
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
                      Symbol(rv.name),
                      params,
                    ),
                  )
              }
          }
      }
    }
    Compound(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      let means : Array[@symcore.Expr] = Array::new()
      let weights : Array[@symnum.BigRational] = Array::new()
      for pair in items {
        let (w, item) = pair
        let renamed = rename_random_var(item, rv.name)
        match
          (expectation_of_rv(renamed, Symbol(rv.name)), variance_of_rv(renamed)) {
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
      _ if @symcore.application_has_name(expr, rvs[0].name, arity=1) =>
        match
          process_variance_at(
            rvs[0],
            @symcore.application_args(expr).unwrap()[0],
          ) {
          Some(v) => return v
          None => ()
        }
      _ => ()
    }
    if @symcore.compare_expr(expr, Symbol(rvs[0].name)) == 0 {
      match variance_of_rv(rvs[0]) {
        Some(v) => return v
        None => ()
      }
    }
  }
  if !rvs.is_empty() {
    let vars_map : Map[String, @symcore.Expr] = Map([])
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
      (Symbol(sa), Symbol(sb)) if sa != sb => {
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
  match symbolic_kind_from_name(name) {
    Matrix(JointEigenDistribution) =>
      match symbolic_matrix_derived_distribution(name, params) {
        Some(lam) =>
          match @symcore.tuple_items(x) {
            Some(xs) => query_lambda_apply(lam, xs)
            None => query_lambda_apply(lam, [x])
          }
        None => None
      }
    Matrix(LevelSpacingDistribution) =>
      match symbolic_matrix_derived_distribution(name, params) {
        Some(lam) => query_lambda_apply(lam, [x])
        None => None
      }
    Continuous(ContinuousRV | ContinuousDistributionHandmade)
    | Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      if params.length() >= 1 {
        query_lambda_apply(params[0], [x])
      } else {
        None
      }
    Discrete(FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          for pair in pairs {
            let (value, prob) = pair
            piecewise_args.push(
              Tuple([prob, @symcore.function("Eq", [x, value])]),
            )
          }
          piecewise_args.push(Tuple([@symcore.int(0), Boolean(true)]))
          Some(@symcore.function("Piecewise", piecewise_args))
        }
        None =>
          if params.length() >= 1 {
            query_lambda_apply(params[0], [x])
          } else {
            None
          }
      }
    Joint(
      JointRV
      | MultivariateEwens
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_density(name, params, x)
    _ => None
  }
}

///|
fn symbolic_matrix_ensemble_from_expr(spec : @symcore.Expr) -> RandomVar? {
  match (@symcore.application_name(spec), @symcore.application_args(spec)) {
    (Some(name), Some(args)) if args.length() == 1 =>
      match matrix_tag_from_name(name) {
        GaussianUnitaryEnsemble
        | GaussianOrthogonalEnsemble
        | GaussianSymplecticEnsemble
        | CircularUnitaryEnsemble
        | CircularOrthogonalEnsemble
        | CircularSymplecticEnsemble => Some(symbolic_rv("_M", name, args))
        _ => None
      }
    _ => None
  }
}

///|
fn symbolic_matrix_derived_distribution(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  if params.length() != 1 {
    return None
  }
  match symbolic_matrix_ensemble_from_expr(params[0]) {
    Some(rv) =>
      match matrix_tag_from_name(name) {
        JointEigenDistribution => joint_eigen_distribution_of(rv)
        LevelSpacingDistribution => level_spacing_distribution_of(rv)
        _ => None
      }
    None => None
  }
}

///|
fn expr_known_compare(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Int? {
  let l = eval_arith(lhs)
  let r = eval_arith(rhs)
  match (expr_as_number(l), expr_as_number(r)) {
    (Some(ln), Some(rn)) => Some(ln.compare(rn))
    _ => if @symcore.compare_expr(l, r) == 0 { Some(0) } else { None }
  }
}

///|
fn expr_known_equal(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  match expr_known_compare(lhs, rhs) {
    Some(0) => true
    _ => false
  }
}

///|
fn bernoulli_process_cdf_exact_point(
  x : @symcore.Expr,
  p : @symcore.Expr,
  success : @symcore.Expr,
  failure : @symcore.Expr,
  one_minus_p : @symcore.Expr,
) -> @symcore.Expr? {
  let support_order = expr_known_compare(success, failure)
  if expr_known_equal(x, failure) {
    match support_order {
      Some(cmp) =>
        if cmp <= 0 {
          return Some(@symcore.int(1))
        } else {
          return Some(one_minus_p)
        }
      None => ()
    }
  }
  if expr_known_equal(x, success) {
    match support_order {
      Some(cmp) =>
        if cmp < 0 {
          return Some(p)
        } else {
          return Some(@symcore.int(1))
        }
      None => ()
    }
  }
  None
}

///|
fn symbolic_process_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match process_tag_from_name(name) {
    BernoulliProcess if params.length() >= 1 => {
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
      if expr_known_equal(success, failure) && expr_known_equal(x, success) {
        return Some(@symcore.int(1))
      } else if expr_known_equal(x, success) {
        return Some(p)
      } else if expr_known_equal(x, failure) {
        return Some(one_minus_p)
      }
      Some(
        @symcore.function("Piecewise", [
          Tuple([p, @symcore.function("Eq", [x, success])]),
          Tuple([one_minus_p, @symcore.function("Eq", [x, failure])]),
          Tuple([@symcore.int(0), Boolean(true)]),
        ]),
      )
    }
    GammaProcess if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.Expr::Symbol("t")
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
          Tuple([body, @symcore.function("Ge", [x, @symcore.int(0)])]),
          Tuple([@symcore.int(0), Boolean(true)]),
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
  match process_tag_from_name(name) {
    BernoulliProcess if params.length() >= 1 => {
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
      match
        bernoulli_process_cdf_exact_point(x, p, success, failure, one_minus_p) {
        Some(value) => return Some(value)
        None => ()
      }
      let between_value = @symcore.function("Piecewise", [
        Tuple([p, @symcore.function("Lt", [success, failure])]),
        Tuple([one_minus_p, Boolean(true)]),
      ])
      Some(
        @symcore.function("Piecewise", [
          Tuple([
            @symcore.int(0),
            @symcore.function("Lt", [
              x,
              @symcore.function("Min", [success, failure]),
            ]),
          ]),
          Tuple([
            between_value,
            @symcore.function("Lt", [
              x,
              @symcore.function("Max", [success, failure]),
            ]),
          ]),
          Tuple([@symcore.int(1), Boolean(true)]),
        ]),
      )
    }
    GammaProcess if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.Expr::Symbol("t")
      let shape = eval_arith(@symcore.mul([gamma, t]))
      Some(
        @symcore.function("Piecewise", [
          Tuple([@symcore.int(0), @symcore.function("Lt", [x, @symcore.int(0)])]),
          Tuple([
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
            Boolean(true),
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
  let kind = symbolic_kind_from_name(name)
  let rv = random_var("_M", Symbolic(kind~, params~))
  let dummy = @symcore.Expr::Symbol("_x")
  match matrix_density(rv, dummy) {
    Some(pdf) =>
      Some(
        eval_arith(
          @symcore.function("Integral", [
            pdf,
            Tuple([
              dummy,
              eval_arith(
                @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
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
  match @symcore.lambda_parts(template) {
    Some((vars_expr, body)) =>
      match @symcore.tuple_items(vars_expr) {
        Some(vars) => {
          for v in vars {
            match v {
              Symbol(_) => ()
              _ => return None
            }
          }
          Some((vars, body))
        }
        None => None
      }
    _ => None
  }
}

///|
fn symbolic_joint_integration_vars(
  name : String,
  params : Array[@symcore.Expr],
) -> Array[@symcore.Expr]? {
  match joint_tag_from_name(name) {
    JointRV =>
      if params.length() >= 1 {
        match query_lambda_tuple_signature(params[0]) {
          Some((vars, _)) => Some(vars)
          None => None
        }
      } else {
        None
      }
    GeneralizedMultivariateLogGamma | GeneralizedMultivariateLogGammaOmega =>
      if params.length() == 4 {
        match @symcore.tuple_items(params[2]) {
          Some(lamdas) if !lamdas.is_empty() => {
            let vars : Array[@symcore.Expr] = Array::new()
            for i in 0..<lamdas.length() {
              vars.push(Symbol("_y\{i + 1}"))
            }
            Some(vars)
          }
          _ => None
        }
      } else {
        None
      }
    MultivariateEwens if params.length() == 2 =>
      match expr_as_int(params[0]) {
        Some(n) if n > 0 => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<n {
            vars.push(Symbol("_k\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    Dirichlet | MultivariateBeta if params.length() >= 2 => {
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<params.length() {
        vars.push(Symbol("_x\{i + 1}"))
      }
      Some(vars)
    }
    MultivariateNormal | MultivariateLaplace if params.length() >= 1 =>
      match @symcore.tuple_items(params[0]) {
        Some(mu) if !mu.is_empty() => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<mu.length() {
            vars.push(Symbol("_x\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    MultivariateT if params.length() == 3 =>
      match @symcore.tuple_items(params[0]) {
        Some(mu) if !mu.is_empty() => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<mu.length() {
            vars.push(Symbol("_x\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    NormalGamma if params.length() == 4 => Some([Symbol("_x"), Symbol("_tau")])
    _ => None
  }
}

///|
fn symbolic_joint_integrand(
  name : String,
  params : Array[@symcore.Expr],
  vars : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match joint_tag_from_name(name) {
    JointRV =>
      if params.length() >= 1 {
        query_lambda_apply(params[0], vars)
      } else {
        None
      }
    GeneralizedMultivariateLogGamma | GeneralizedMultivariateLogGammaOmega =>
      symbolic_joint_gmlg_density(name, params, Tuple(vars))
    Dirichlet
    | MultivariateBeta
    | MultivariateNormal
    | MultivariateLaplace
    | MultivariateT
    | NormalGamma => symbolic_joint_density(name, params, Tuple(vars))
    _ => None
  }
}

///|
fn symbolic_joint_cdf_lowers(
  name : String,
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
  )
  match joint_tag_from_name(name) {
    Dirichlet | MultivariateBeta => {
      let lowers : Array[@symcore.Expr] = Array::new()
      for _ in 0..<vars.length() {
        lowers.push(@symcore.int(0))
      }
      lowers
    }
    NormalGamma =>
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
            args.push(Tuple([vars[i], lowers[i], uppers[i]]))
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
      match @symcore.tuple_items(x) {
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
      match @symcore.tuple_items(x) {
        Some(bounds) if bounds.length() == vars.length() => {
          let uppers : Array[@symcore.Expr] = Array::new()
          for _ in 0..<vars.length() {
            uppers.push(NumberSymbol(Infinity))
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
      match (@symcore.tuple_items(lower), @symcore.tuple_items(upper)) {
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
    Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Not(inner) =>
      match
        symbolic_joint_probability_continuous(name, params, rv_name, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Rel(..) =>
      match query_extract_rel_to_var(event, rv_name) {
        Some((op, bound)) =>
          match op {
            Eq => Some(@symcore.int(0))
            Ne => Some(@symcore.int(1))
            Le | Lt => symbolic_joint_cdf(name, params, bound)
            Ge | Gt => symbolic_joint_survival(name, params, bound)
          }
        None => None
      }
    And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_var(items[0], rv_name)
        let r2 = query_extract_rel_to_var(items[1], rv_name)
        match (r1, r2) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower1 : @symcore.Expr? = match op1 {
              Gt | Ge => Some(b1)
              _ => None
            }
            let lower2 : @symcore.Expr? = match op2 {
              Gt | Ge => Some(b2)
              _ => None
            }
            let upper1 : @symcore.Expr? = match op1 {
              Lt | Le => Some(b1)
              _ => None
            }
            let upper2 : @symcore.Expr? = match op2 {
              Lt | Le => Some(b2)
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
    Or(items) =>
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
  match symbolic_kind_from_name(name) {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) =>
      if params.length() >= 1 {
        let dummy = @symcore.Expr::Symbol("_x")
        let neg_oo = eval_arith(
          @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
        )
        match query_lambda_apply(params[0], [dummy]) {
          Some(pdf) =>
            Some(
              eval_arith(
                @symcore.function("Integral", [pdf, Tuple([dummy, neg_oo, x])]),
              ),
            )
          None => None
        }
      } else {
        None
      }
    Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      if params.length() >= 1 {
        let dummy = @symcore.Expr::Symbol("_k")
        let neg_oo = eval_arith(
          @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
        )
        let upper = @symcore.function("floor", [x])
        match query_lambda_apply(params[0], [dummy]) {
          Some(pmf) =>
            Some(
              eval_arith(
                @symcore.function("Sum", [pmf, Tuple([dummy, neg_oo, upper])]),
              ),
            )
          None => None
        }
      } else {
        None
      }
    Discrete(FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let sorted_pairs = pairs
          sorted_pairs.sort_by((a, b) => @symcore.compare_expr(a.0, b.0))
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          let mut acc = @symcore.int(0)
          for pair in sorted_pairs {
            let (value, prob) = pair
            piecewise_args.push(
              Tuple([acc, @symcore.function("Lt", [x, value])]),
            )
            acc = eval_arith(@symcore.add([acc, prob]))
          }
          piecewise_args.push(Tuple([acc, Boolean(true)]))
          Some(@symcore.function("Piecewise", piecewise_args))
        }
        None => None
      }
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_cdf(name, params, x)
    Matrix(JointEigenDistribution) =>
      match
        (
          symbolic_matrix_derived_distribution(name, params),
          @symcore.tuple_items(x),
        ) {
        (Some(lam), Some(bounds)) =>
          match query_lambda_tuple_signature(lam) {
            Some((vars, body)) if vars.length() == bounds.length() => {
              let derived_rv = match
                symbolic_matrix_ensemble_from_expr(params[0]) {
                Some(rv) => rv
                None => return None
              }
              let lowers = match matrix_ensemble_spec(derived_rv) {
                Some((_, _, true)) => {
                  let xs : Array[@symcore.Expr] = Array::new()
                  for _ in 0..<vars.length() {
                    xs.push(@symcore.int(0))
                  }
                  xs
                }
                _ => {
                  let xs : Array[@symcore.Expr] = Array::new()
                  let neg_oo = eval_arith(
                    @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
                  )
                  for _ in 0..<vars.length() {
                    xs.push(neg_oo)
                  }
                  xs
                }
              }
              Some(symbolic_joint_nested_integral(body, vars, lowers, bounds))
            }
            _ => None
          }
        _ => None
      }
    Matrix(LevelSpacingDistribution) =>
      match symbolic_matrix_derived_distribution(name, params) {
        Some(lam) =>
          match query_lambda_tuple_signature(lam) {
            Some((vars, body)) if vars.length() == 1 =>
              Some(
                eval_arith(
                  @symcore.function("Integral", [
                    body,
                    Tuple([vars[0], @symcore.int(0), x]),
                  ]),
                ),
              )
            _ => None
          }
        None => None
      }
    Joint(MultivariateEwens) =>
      match
        (symbolic_multivariate_ewens_arity(params), @symcore.tuple_items(x)) {
        (Some(n), Some(bounds)) if bounds.length() == n => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<n {
            vars.push(Symbol("_k\{i + 1}"))
          }
          match symbolic_multivariate_ewens_density(params, Tuple(vars)) {
            Some(pmf) => {
              let mut expr = pmf
              for i in 0..<n {
                expr = eval_arith(
                  @symcore.function("Sum", [
                    expr,
                    Tuple([
                      vars[i],
                      @symcore.int(0),
                      @symcore.function("floor", [bounds[i]]),
                    ]),
                  ]),
                )
              }
              Some(expr)
            }
            None => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn query_extract_rel_to_var(
  event : Event,
  rv_name : String,
) -> (RelOp, @symcore.Expr)? {
  match event {
    Rel(op~, lhs~, rhs~) =>
      match lhs {
        Symbol(name) if name == rv_name => Some((op, rhs))
        _ =>
          match rhs {
            Symbol(name) if name == rv_name => Some((invert_relop(op), lhs))
            _ => None
          }
      }
    _ => None
  }
}

///|
fn query_extract_rel_to_process_value(
  event : Event,
  rv_name : String,
) -> (RelOp, @symcore.Expr, @symcore.Expr)? {
  match event {
    Rel(op~, lhs~, rhs~) =>
      match lhs {
        _ if @symcore.application_has_name(lhs, rv_name, arity=1) =>
          Some((op, @symcore.application_args(lhs).unwrap()[0], rhs))
        _ =>
          match rhs {
            _ if @symcore.application_has_name(rhs, rv_name, arity=1) =>
              Some(
                (
                  invert_relop(op),
                  @symcore.application_args(rhs).unwrap()[0],
                  lhs,
                ),
              )
            _ => None
          }
      }
    _ => None
  }
}

///|
fn process_interval_probability(
  rv : RandomVar,
  time : @symcore.Expr,
  lower : (@symcore.Expr, Bool)?,
  upper : (@symcore.Expr, Bool)?,
) -> @symcore.Expr? {
  let discrete = process_is_discrete(rv)
  match (lower, upper) {
    (None, Some((hi, hi_strict))) => {
      let hi_arg = if discrete && hi_strict {
        eval_arith(query_expr_sub(hi, @symcore.int(1)))
      } else {
        hi
      }
      process_cdf_at(rv, time, hi_arg)
    }
    (Some((lo, lo_strict)), None) => {
      let lo_arg = if discrete && !lo_strict {
        eval_arith(query_expr_sub(lo, @symcore.int(1)))
      } else {
        lo
      }
      match process_cdf_at(rv, time, lo_arg) {
        Some(cdf_expr) =>
          Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
        None => None
      }
    }
    (Some((lo, lo_strict)), Some((hi, hi_strict))) => {
      let lo_arg = if discrete && !lo_strict {
        eval_arith(query_expr_sub(lo, @symcore.int(1)))
      } else {
        lo
      }
      let hi_arg = if discrete && hi_strict {
        eval_arith(query_expr_sub(hi, @symcore.int(1)))
      } else {
        hi
      }
      match
        (process_cdf_at(rv, time, lo_arg), process_cdf_at(rv, time, hi_arg)) {
        (Some(cl), Some(cu)) => Some(eval_arith(query_expr_sub(cu, cl)))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn process_probability_event(rv : RandomVar, event : Event) -> @symcore.Expr? {
  match event {
    Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Not(inner) =>
      match process_probability_event(rv, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Rel(..) =>
      match query_extract_rel_to_process_value(event, rv.name) {
        Some((op, time, bound)) =>
          match op {
            Eq => process_probability_at(rv, time, bound)
            Ne =>
              match process_probability_at(rv, time, bound) {
                Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
                None => None
              }
            Le => process_cdf_at(rv, time, bound)
            Lt =>
              process_interval_probability(rv, time, None, Some((bound, true)))
            Ge =>
              process_interval_probability(rv, time, Some((bound, false)), None)
            Gt =>
              process_interval_probability(rv, time, Some((bound, true)), None)
          }
        None => None
      }
    And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_process_value(items[0], rv.name)
        let r2 = query_extract_rel_to_process_value(items[1], rv.name)
        match (r1, r2) {
          (Some((Eq, t0, x0)), Some((Eq, t1, x1))) =>
            if @symcore.compare_expr(t0, t1) == 0 {
              if @symcore.compare_expr(x0, x1) == 0 {
                process_probability_at(rv, t0, x0)
              } else {
                Some(@symcore.int(0))
              }
            } else {
              match
                (
                  process_probability_at(rv, t0, x0),
                  process_transition_probability(rv, x0, x1, t0, t1),
                ) {
                (Some(p0), Some(tp)) => Some(eval_arith(@symcore.mul([p0, tp])))
                _ => None
              }
            }
          (Some((op1, t0, b1)), Some((op2, t1, b2))) if @symcore.compare_expr(
              t0, t1,
            ) ==
            0 => {
            let lower1 : (@symcore.Expr, Bool)? = match op1 {
              Gt => Some((b1, true))
              Ge => Some((b1, false))
              _ => None
            }
            let lower2 : (@symcore.Expr, Bool)? = match op2 {
              Gt => Some((b2, true))
              Ge => Some((b2, false))
              _ => None
            }
            let upper1 : (@symcore.Expr, Bool)? = match op1 {
              Lt => Some((b1, true))
              Le => Some((b1, false))
              _ => None
            }
            let upper2 : (@symcore.Expr, Bool)? = match op2 {
              Lt => Some((b2, true))
              Le => Some((b2, false))
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
            process_interval_probability(rv, t0, lower, upper)
          }
          _ => None
        }
      } else {
        None
      }
    Or(items) =>
      if items.length() == 2 {
        let a = items[0]
        let b = items[1]
        match
          (
            process_probability_event(rv, a),
            process_probability_event(rv, b),
            process_probability_event(rv, and_event([a, b])),
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
    Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Not(inner) =>
      match
        symbolic_opaque_probability_continuous(name, params, rv_name, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Rel(..) =>
      match query_extract_rel_to_var(event, rv_name) {
        Some((op, bound)) =>
          match op {
            Eq => Some(@symcore.int(0))
            Ne => Some(@symcore.int(1))
            Le | Lt => symbolic_opaque_cdf(name, params, rv_name, bound)
            Ge | Gt =>
              match symbolic_opaque_cdf(name, params, rv_name, bound) {
                Some(cdf_expr) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                None => None
              }
          }
        None => None
      }
    And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_var(items[0], rv_name)
        let r2 = query_extract_rel_to_var(items[1], rv_name)
        match (r1, r2) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower1 : @symcore.Expr? = match op1 {
              Gt | Ge => Some(b1)
              _ => None
            }
            let lower2 : @symcore.Expr? = match op2 {
              Gt | Ge => Some(b2)
              _ => None
            }
            let upper1 : @symcore.Expr? = match op1 {
              Lt | Le => Some(b1)
              _ => None
            }
            let upper2 : @symcore.Expr? = match op2 {
              Lt | Le => Some(b2)
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
    Or(items) =>
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
    Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Not(inner) =>
      match symbolic_opaque_probability_discrete(name, params, rv_name, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Rel(..) =>
      match query_extract_rel_to_var(event, rv_name) {
        Some((op, bound)) =>
          match op {
            Eq => symbolic_opaque_density(name, params, bound)
            Ne =>
              match symbolic_opaque_density(name, params, bound) {
                Some(pmf) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), pmf)))
                None => None
              }
            Le => symbolic_opaque_cdf(name, params, rv_name, bound)
            Lt =>
              symbolic_opaque_cdf(
                name,
                params,
                rv_name,
                eval_arith(query_expr_sub(bound, @symcore.int(1))),
              )
            Ge =>
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
            Gt =>
              match symbolic_opaque_cdf(name, params, rv_name, bound) {
                Some(cdf_expr) =>
                  Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                None => None
              }
          }
        None => None
      }
    And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_var(items[0], rv_name)
        let r2 = query_extract_rel_to_var(items[1], rv_name)
        match (r1, r2) {
          (Some((op1, b1)), Some((op2, b2))) => {
            let lower1 : (@symcore.Expr, Bool)? = match op1 {
              Gt => Some((b1, true))
              Ge => Some((b1, false))
              _ => None
            }
            let lower2 : (@symcore.Expr, Bool)? = match op2 {
              Gt => Some((b2, true))
              Ge => Some((b2, false))
              _ => None
            }
            let upper1 : (@symcore.Expr, Bool)? = match op1 {
              Lt => Some((b1, true))
              Le => Some((b1, false))
              _ => None
            }
            let upper2 : (@symcore.Expr, Bool)? = match op2 {
              Lt => Some((b2, true))
              Le => Some((b2, false))
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
    Or(items) =>
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
  match symbolic_kind_from_name(name) {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) =>
      symbolic_opaque_probability_continuous(name, params, rv_name, event)
    Discrete(
      DiscreteRV
      | DiscreteDistributionHandmade
      | FiniteDistributionHandmade
    ) => symbolic_opaque_probability_discrete(name, params, rv_name, event)
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_probability_continuous(name, params, rv_name, event)
    Joint(MultivariateEwens) =>
      if !event_depends_only_on(event, rv_name) {
        None
      } else {
        match event {
          Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
          Not(inner) =>
            match symbolic_opaque_probability(name, params, rv_name, inner) {
              Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
              None => None
            }
          Rel(..) =>
            match query_extract_rel_to_var(event, rv_name) {
              Some((Eq, point)) => symbolic_opaque_density(name, params, point)
              Some((Ne, point)) =>
                match symbolic_opaque_density(name, params, point) {
                  Some(d) =>
                    Some(eval_arith(query_expr_sub(@symcore.int(1), d)))
                  None => None
                }
              Some((Le, point)) | Some((Lt, point)) =>
                symbolic_opaque_cdf(name, params, rv_name, point)
              Some((Ge, point)) | Some((Gt, point)) =>
                match symbolic_opaque_cdf(name, params, rv_name, point) {
                  Some(cdf_expr) =>
                    Some(eval_arith(query_expr_sub(@symcore.int(1), cdf_expr)))
                  None => None
                }
              None => None
            }
          Or(items) =>
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
          match matrix_density(rv, x) {
            Some(v) => v
            None =>
              match rv.kind {
                Symbolic(kind~, params~) => {
                  let name = symbolic_kind_name(kind)
                  if symbolic_kind_is_opaque(kind) {
                    match symbolic_opaque_density(name, params, x) {
                      Some(v) => v
                      None => @symcore.function("density", [Symbol(rv.name), x])
                    }
                  } else {
                    match kind {
                      Process(_) =>
                        match symbolic_process_density(name, params, x) {
                          Some(v) => v
                          None =>
                            symbolic_query_expr(name, "Density", x, params)
                        }
                      Joint(_) =>
                        match symbolic_joint_density(name, params, x) {
                          Some(v) => v
                          None =>
                            symbolic_query_expr(name, "Density", x, params)
                        }
                      _ => symbolic_query_expr(name, "Density", x, params)
                    }
                  }
                }
                _ => @symcore.function("density", [Symbol(rv.name), x])
              }
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
            Symbolic(kind~, params~) => {
              let name = symbolic_kind_name(kind)
              if symbolic_kind_is_opaque(kind) {
                match symbolic_opaque_cdf(name, params, rv.name, x) {
                  Some(v) => v
                  None =>
                    match kind {
                      Process(_) =>
                        match symbolic_process_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      Joint(_) =>
                        match symbolic_joint_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      Matrix(_) =>
                        match symbolic_matrix_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      _ => symbolic_query_expr(name, "CDF", x, params)
                    }
                }
              } else {
                match kind {
                  Process(_) =>
                    match symbolic_process_cdf(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "CDF", x, params)
                    }
                  Joint(_) =>
                    match symbolic_joint_cdf(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "CDF", x, params)
                    }
                  Matrix(_) =>
                    match symbolic_matrix_cdf(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "CDF", x, params)
                    }
                  _ => symbolic_query_expr(name, "CDF", x, params)
                }
              }
            }
            _ => @symcore.function("cdf", [Symbol(rv.name), x])
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
  let x = @symcore.Expr::Symbol(rv.name)
  expectation(@symcore.pow(x, @symcore.int(n)), rvs=[rv])
}
