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
///|
fn tuple_matrix(rows : Array[Array[@symcore.Expr]]) -> @symcore.Expr {
  @symcore.Expr::Tuple(rows.map(row => @symcore.Expr::Tuple(row)))
}

///|
fn scale_tuple_matrix(
  mat : @symcore.Expr,
  scale : @symcore.Expr,
) -> @symcore.Expr {
  match @symcore.tuple_items(mat) {
    Some(rows) =>
      @symcore.Expr::Tuple(
        rows.map(row => {
          match @symcore.tuple_items(row) {
            Some(cols) =>
              @symcore.Expr::Tuple(
                cols.map(col => eval_arith(@symcore.mul([scale, col]))),
              )
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
    JointTag::Dirichlet | JointTag::MultivariateBeta if params.length() >= 2 => {
      let total = eval_arith(@symcore.add(params))
      let means = params.map(a => {
        eval_arith(@symcore.mul([a, @symcore.pow(total, @symcore.int(-1))]))
      })
      Some(@symcore.Expr::Tuple(means))
    }
    JointTag::MultivariateT if params.length() == 3 => Some(params[0])
    JointTag::MultivariateLaplace if params.length() >= 2 => Some(params[0])
    JointTag::MultivariateNormal if params.length() >= 1 => Some(params[0])
    JointTag::NormalGamma if params.length() == 4 =>
      Some(
        @symcore.Expr::Tuple([
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
    JointTag::Dirichlet | JointTag::MultivariateBeta if params.length() >= 2 => {
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
    JointTag::MultivariateT if params.length() == 3 => {
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
    JointTag::MultivariateLaplace if params.length() >= 2 => Some(params[1])
    JointTag::MultivariateNormal if params.length() >= 2 => Some(params[1])
    JointTag::NormalGamma if params.length() == 4 => {
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
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::ComplexFloat(_)
    | @symcore.Expr::NumberSymbol(_)
    | @symcore.Expr::Boolean(_)
    | @symcore.Expr::Symbol(_)
    | @symcore.Expr::Dummy(_, _)
    | @symcore.Expr::Wild(_)
    | @symcore.Expr::FunctionHead(_)
    | @symcore.Expr::UndefinedFunction(_) => expr
    @symcore.Expr::Apply(head, args) =>
      @symcore.raw_apply(
        head,
        args.map(arg => query_replace_expr(arg, target, replacement)),
      ).unwrap_or(
        @symcore.Expr::Apply(
          head,
          args.map(arg => query_replace_expr(arg, target, replacement)),
        ),
      )
    @symcore.Expr::Add(args) =>
      eval_arith(
        @symcore.add(
          args.map(arg => query_replace_expr(arg, target, replacement)),
        ),
      )
    @symcore.Expr::Mul(args) =>
      eval_arith(
        @symcore.mul(
          args.map(arg => query_replace_expr(arg, target, replacement)),
        ),
      )
    @symcore.Expr::Mod(lhs, rhs) =>
      @symcore.mod_expr(
        query_replace_expr(lhs, target, replacement),
        query_replace_expr(rhs, target, replacement),
      )
    @symcore.Expr::Pow(base, exp) =>
      eval_arith(
        @symcore.pow(
          query_replace_expr(base, target, replacement),
          query_replace_expr(exp, target, replacement),
        ),
      )
    @symcore.Expr::Tuple(args) =>
      @symcore.Expr::Tuple(
        args.map(arg => query_replace_expr(arg, target, replacement)),
      )
    @symcore.Expr::Dict(items) => {
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
      @symcore.Expr::Dict(out)
    }
    @symcore.Expr::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          @symcore.Expr::Relational(@symcore.RelOp::Eq, 
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        @symcore.RelOp::Ne =>
          @symcore.Expr::Relational(@symcore.RelOp::Ne, 
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        @symcore.RelOp::Lt =>
          @symcore.Expr::Relational(@symcore.RelOp::Lt, 
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        @symcore.RelOp::Le =>
          @symcore.Expr::Relational(@symcore.RelOp::Le, 
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        @symcore.RelOp::Gt =>
          @symcore.Expr::Relational(@symcore.RelOp::Gt, 
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
        @symcore.RelOp::Ge =>
          @symcore.Expr::Relational(@symcore.RelOp::Ge, 
            query_replace_expr(lhs, target, replacement),
            query_replace_expr(rhs, target, replacement),
          )
      }
    @symcore.Expr::Derivative(inner, deriv_args) => {
      let out : Array[@symcore.Expr] = []
      out.push(query_replace_expr(inner, target, replacement))
      for arg in deriv_args {
        out.push(query_replace_expr(arg, target, replacement))
      }
      @symcore.raw_function("Derivative", out)
    }
    @symcore.Expr::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        query_replace_expr(inner, target, replacement),
        query_replace_expr(variable, target, replacement),
        query_replace_expr(value, target, replacement),
      )
    @symcore.Expr::Lambda(vars, body) =>
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
    @symcore.Expr::Symbol(name) => Some(@symcore.function(name, args))
    _ =>
      match @symcore.lambda_parts(template) {
        Some((vars, body)) =>
          match vars {
            @symcore.Expr::Symbol(v) =>
              if args.length() == 1 {
                let env : Map[String, @symcore.Expr] = {}
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
    SymbolicKind::Continuous(
      ContinuousTag::ContinuousRV
      | ContinuousTag::ContinuousDistributionHandmade
    ) => symbolic_continuous_handmade_mean(params)
    SymbolicKind::Discrete(
      DiscreteTag::DiscreteRV
      | DiscreteTag::DiscreteDistributionHandmade
    ) => symbolic_discrete_handmade_mean(params)
    SymbolicKind::Joint(
      JointTag::JointRV
      | JointTag::GeneralizedMultivariateLogGamma
      | JointTag::GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_mean_via_integral(name, params)
    SymbolicKind::Joint(JointTag::MultivariateEwens) =>
      symbolic_multivariate_ewens_mean(params)
    SymbolicKind::Matrix(
      MatrixTag::GaussianEnsemble
      | MatrixTag::GaussianOrthogonalEnsemble
      | MatrixTag::GaussianUnitaryEnsemble
      | MatrixTag::GaussianSymplecticEnsemble
      | MatrixTag::CircularEnsemble
      | MatrixTag::CircularUnitaryEnsemble
      | MatrixTag::CircularOrthogonalEnsemble
      | MatrixTag::CircularSymplecticEnsemble
    ) if params.length() == 1 =>
      Some(@symcore.function("ZeroMatrix", [params[0], params[0]]))
    SymbolicKind::Matrix(MatrixTag::MatrixGamma) if params.length() == 3 =>
      Some(eval_arith(@symcore.mul([params[0], params[1], params[2]])))
    SymbolicKind::Matrix(MatrixTag::MatrixStudentT) if params.length() == 4 =>
      Some(params[1])
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
    SymbolicKind::Continuous(
      ContinuousTag::ContinuousRV
      | ContinuousTag::ContinuousDistributionHandmade
    ) => symbolic_continuous_handmade_variance(params)
    SymbolicKind::Discrete(
      DiscreteTag::DiscreteRV
      | DiscreteTag::DiscreteDistributionHandmade
    ) => symbolic_discrete_handmade_variance(params)
    SymbolicKind::Joint(
      JointTag::JointRV
      | JointTag::GeneralizedMultivariateLogGamma
      | JointTag::GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_variance_via_integral(name, params)
    SymbolicKind::Joint(JointTag::MultivariateEwens) =>
      symbolic_multivariate_ewens_variance(params)
    SymbolicKind::Matrix(
      MatrixTag::GaussianEnsemble
      | MatrixTag::GaussianOrthogonalEnsemble
      | MatrixTag::GaussianUnitaryEnsemble
      | MatrixTag::GaussianSymplecticEnsemble
      | MatrixTag::CircularEnsemble
      | MatrixTag::CircularUnitaryEnsemble
      | MatrixTag::CircularOrthogonalEnsemble
      | MatrixTag::CircularSymplecticEnsemble
    ) if params.length() == 1 => {
      let x = @symcore.Expr::Symbol(rv_name)
      let mean = @symcore.function("ZeroMatrix", [params[0], params[0]])
      Some(
        @symcore.function("Expectation", [
          eval_arith(@symcore.pow(query_expr_sub(x, mean), @symcore.int(2))),
        ]),
      )
    }
    SymbolicKind::Matrix(MatrixTag::MatrixGamma) if params.length() == 3 =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            @symcore.pow(params[2], @symcore.int(2)),
          ]),
        ),
      )
    SymbolicKind::Matrix(MatrixTag::MatrixStudentT) if params.length() == 4 =>
      Some(
        @symcore.function("Expectation", [
          eval_arith(
            @symcore.pow(
              query_expr_sub(@symcore.Expr::Symbol(rv_name), params[1]),
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
    @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
  )
  match query_lambda_apply(params[0], [x]) {
    Some(pdf) =>
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(@symcore.mul([x, pdf])),
            @symcore.Expr::Tuple([x, neg_oo, @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
    @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
            @symcore.Expr::Tuple([x, neg_oo, @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
    @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
  )
  match query_lambda_apply(params[0], [k]) {
    Some(pmf) =>
      Some(
        eval_arith(
          @symcore.function("Sum", [
            eval_arith(@symcore.mul([k, pmf])),
            @symcore.Expr::Tuple([k, neg_oo, @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
    @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
            @symcore.Expr::Tuple([k, neg_oo, @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
    uppers.push(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity))
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
        @symcore.Expr::Tuple([vars[i], lowers[i], uppers[i]]),
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
          Some(@symcore.Expr::Tuple(means))
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
        @symcore.Expr::Tuple([vars[i], @symcore.int(0), @symcore.int(n / (i + 1))]),
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
        vars.push(@symcore.Expr::Symbol("_k\{i + 1}"))
      }
      match symbolic_multivariate_ewens_density(params, @symcore.Expr::Tuple(vars)) {
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
          Some(@symcore.Expr::Tuple(means))
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
            vars.push(@symcore.Expr::Symbol("_k\{i + 1}"))
          }
          match symbolic_multivariate_ewens_density(params, @symcore.Expr::Tuple(vars)) {
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
          @symcore.Expr::Tuple([body, @symcore.function("Eq", [cond_sum, n])]),
          @symcore.Expr::Tuple([@symcore.int(0), @symcore.Expr::Boolean(true)]),
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
        @symcore.Expr::Tuple([n_var, @symcore.int(0), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
    JointTag::GeneralizedMultivariateLogGamma if params.length() == 4 =>
      symbolic_generalized_multivariate_log_gamma_density(
        params[0],
        params[1],
        params[2],
        params[3],
        x,
      )
    JointTag::GeneralizedMultivariateLogGammaOmega if params.length() == 4 =>
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
    JointTag::JointRV if params.length() >= 1 =>
      match @symcore.tuple_items(x) {
        Some(xs) => query_lambda_apply(params[0], xs)
        None => query_lambda_apply(params[0], [x])
      }
    JointTag::MultivariateEwens if params.length() == 2 =>
      symbolic_multivariate_ewens_density(params, x)
    JointTag::GeneralizedMultivariateLogGamma
    | JointTag::GeneralizedMultivariateLogGammaOmega =>
      symbolic_joint_gmlg_density(name, params, x)
    JointTag::Dirichlet | JointTag::MultivariateBeta if params.length() >= 2 =>
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
    JointTag::NormalGamma if params.length() == 4 =>
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
                eval_arith(
                  @symcore.mul([@symcore.int(2), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)]),
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
    JointTag::MultivariateNormal if params.length() >= 2 =>
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
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
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
    JointTag::MultivariateLaplace if params.length() >= 2 =>
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
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
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
    JointTag::MultivariateT if params.length() == 3 =>
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
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
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
    RVKind::StochasticProcess(_) => process_probability_event(rv, event)
    RVKind::Binomial(..)
    | RVKind::Poisson(..)
    | RVKind::Geometric(..)
    | RVKind::NegativeBinomial(..) => discrete_probability(rv, event)
    RVKind::Normal(..) | RVKind::Exponential(..) | RVKind::Gamma(..) =>
      continuous_probability(rv, event)
    RVKind::Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      match kind {
        SymbolicKind::Process(_) =>
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
          Some(@symcore.Expr::Symbol(rv.name))
        _ if @symcore.application_has_name(expr, rv.name, arity=1) =>
          process_mean_at(rv, @symcore.application_args(expr).unwrap()[0])
        _ => None
      }
    RVKind::Binomial(..)
    | RVKind::Poisson(..)
    | RVKind::Geometric(..)
    | RVKind::NegativeBinomial(..) =>
      if @symcore.compare_expr(expr, @symcore.Expr::Symbol(rv.name)) == 0 {
        discrete_mean(rv)
      } else {
        None
      }
    RVKind::Normal(..) | RVKind::Exponential(..) | RVKind::Gamma(..) =>
      if @symcore.compare_expr(expr, @symcore.Expr::Symbol(rv.name)) == 0 {
        continuous_mean(rv)
      } else {
        None
      }
    RVKind::Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      if symbolic_kind_is_opaque(kind) {
        match expr {
          @symcore.Expr::Symbol(sym) if sym == rv.name =>
            match kind {
              SymbolicKind::Discrete(DiscreteTag::FiniteDistributionHandmade) =>
                match symbolic_finite_handmade_mean(params) {
                  Some(v) => Some(v)
                  None => Some(@symcore.Expr::Symbol(rv.name))
                }
              _ =>
                match symbolic_opaque_mean(name, params) {
                  Some(v) => Some(v)
                  None => Some(@symcore.Expr::Symbol(rv.name))
                }
            }
          _ if @symcore.application_has_name(expr, rv.name, arity=1) =>
            match kind {
              SymbolicKind::Process(_) =>
                process_mean_at(rv, @symcore.application_args(expr).unwrap()[0])
              _ => None
            }
          _ => None
        }
      } else if @symcore.compare_expr(expr, @symcore.Expr::Symbol(rv.name)) == 0 {
        match kind {
          SymbolicKind::Joint(_) =>
            match symbolic_joint_mean(name, params) {
              Some(v) => Some(v)
              None =>
                Some(
                  symbolic_query_expr(
                    name,
                    "Mean",
                    @symcore.Expr::Symbol(rv.name),
                    params,
                  ),
                )
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
                      symbolic_query_expr(
                        name,
                        "Mean",
                        @symcore.Expr::Symbol(rv.name),
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
    @symcore.Expr::Number(_)
    | @symcore.Expr::Float(_)
    | @symcore.Expr::ComplexFloat(_) => Some(expr)
    @symcore.Expr::Symbol(name) =>
      match map.get(name) {
        Some(rv) => expectation_of_rv(rv, @symcore.Expr::Symbol(name))
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
      Some(variance_expr(@symcore.Expr::Symbol(rv.name)))
    RVKind::Binomial(..)
    | RVKind::Poisson(..)
    | RVKind::Geometric(..)
    | RVKind::NegativeBinomial(..) => discrete_variance(rv)
    RVKind::Normal(..) | RVKind::Exponential(..) | RVKind::Gamma(..) =>
      continuous_variance(rv)
    RVKind::Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      if symbolic_kind_is_opaque(kind) {
        return match kind {
          SymbolicKind::Discrete(DiscreteTag::FiniteDistributionHandmade) =>
            match symbolic_finite_handmade_variance(params) {
              Some(v) => Some(v)
              None => Some(variance_expr(@symcore.Expr::Symbol(rv.name)))
            }
          _ =>
            match symbolic_special_variance(name, params, rv.name) {
              Some(v) => Some(v)
              None => Some(variance_expr(@symcore.Expr::Symbol(rv.name)))
            }
        }
      }
      match kind {
        SymbolicKind::Joint(_) =>
          match symbolic_joint_variance(name, params) {
            Some(v) => Some(v)
            None =>
              Some(
                symbolic_query_expr(
                  name,
                  "Variance",
                  @symcore.Expr::Symbol(rv.name),
                  params,
                ),
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
                      @symcore.Expr::Symbol(rv.name),
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
            expectation_of_rv(renamed, @symcore.Expr::Symbol(rv.name)),
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
      _ if @symcore.application_has_name(expr, rvs[0].name, arity=1) =>
        match process_variance_at(
          rvs[0],
          @symcore.application_args(expr).unwrap()[0],
        ) {
          Some(v) => return v
          None => ()
        }
      _ => ()
    }
    if @symcore.compare_expr(expr, @symcore.Expr::Symbol(rvs[0].name)) == 0 {
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
  match symbolic_kind_from_name(name) {
    SymbolicKind::Matrix(MatrixTag::JointEigenDistribution) =>
      match symbolic_matrix_derived_distribution(name, params) {
        Some(lam) =>
          match @symcore.tuple_items(x) {
            Some(xs) => query_lambda_apply(lam, xs)
            None => query_lambda_apply(lam, [x])
          }
        None => None
      }
    SymbolicKind::Matrix(MatrixTag::LevelSpacingDistribution) =>
      match symbolic_matrix_derived_distribution(name, params) {
        Some(lam) => query_lambda_apply(lam, [x])
        None => None
      }
    SymbolicKind::Continuous(
      ContinuousTag::ContinuousRV
      | ContinuousTag::ContinuousDistributionHandmade
    )
    | SymbolicKind::Discrete(
      DiscreteTag::DiscreteRV
      | DiscreteTag::DiscreteDistributionHandmade
    ) =>
      if params.length() >= 1 {
        query_lambda_apply(params[0], [x])
      } else {
        None
      }
    SymbolicKind::Discrete(DiscreteTag::FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          for pair in pairs {
            let (value, prob) = pair
            piecewise_args.push(
              @symcore.Expr::Tuple([prob, @symcore.function("Eq", [x, value])]),
            )
          }
          piecewise_args.push(
            @symcore.Expr::Tuple([@symcore.int(0), @symcore.Expr::Boolean(true)]),
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
    SymbolicKind::Joint(
      JointTag::JointRV
      | JointTag::MultivariateEwens
      | JointTag::GeneralizedMultivariateLogGamma
      | JointTag::GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_density(name, params, x)
    _ => None
  }
}

///|
fn symbolic_matrix_ensemble_from_expr(spec : @symcore.Expr) -> RandomVar? {
  match (@symcore.application_name(spec), @symcore.application_args(spec)) {
    (Some(name), Some(args)) if args.length() == 1 =>
      match matrix_tag_from_name(name) {
        MatrixTag::GaussianUnitaryEnsemble
        | MatrixTag::GaussianOrthogonalEnsemble
        | MatrixTag::GaussianSymplecticEnsemble
        | MatrixTag::CircularUnitaryEnsemble
        | MatrixTag::CircularOrthogonalEnsemble
        | MatrixTag::CircularSymplecticEnsemble =>
          Some(symbolic_rv("_M", name, args))
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
        MatrixTag::JointEigenDistribution => joint_eigen_distribution_of(rv)
        MatrixTag::LevelSpacingDistribution => level_spacing_distribution_of(rv)
        _ => None
      }
    None => None
  }
}

///|
fn symbolic_process_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match process_tag_from_name(name) {
    ProcessTag::BernoulliProcess if params.length() >= 1 => {
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
          @symcore.Expr::Tuple([p, @symcore.function("Eq", [x, success])]),
          @symcore.Expr::Tuple([
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                @symcore.mul([@symcore.int(-1), p]),
              ]),
            ),
            @symcore.function("Eq", [x, failure]),
          ]),
          @symcore.Expr::Tuple([@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    }
    ProcessTag::GammaProcess if params.length() >= 2 => {
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
          @symcore.Expr::Tuple([body, @symcore.function("Ge", [x, @symcore.int(0)])]),
          @symcore.Expr::Tuple([@symcore.int(0), @symcore.Expr::Boolean(true)]),
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
    ProcessTag::BernoulliProcess if params.length() >= 1 => {
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
        @symcore.Expr::Tuple([p, @symcore.function("Lt", [success, failure])]),
        @symcore.Expr::Tuple([one_minus_p, @symcore.Expr::Boolean(true)]),
      ])
      Some(
        @symcore.function("Piecewise", [
          @symcore.Expr::Tuple([
            @symcore.int(0),
            @symcore.function("Lt", [
              x,
              @symcore.function("Min", [success, failure]),
            ]),
          ]),
          @symcore.Expr::Tuple([
            between_value,
            @symcore.function("Lt", [
              x,
              @symcore.function("Max", [success, failure]),
            ]),
          ]),
          @symcore.Expr::Tuple([@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    }
    ProcessTag::GammaProcess if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.Expr::Symbol("t")
      let shape = eval_arith(@symcore.mul([gamma, t]))
      Some(
        @symcore.function("Piecewise", [
          @symcore.Expr::Tuple([
            @symcore.int(0),
            @symcore.function("Lt", [x, @symcore.int(0)]),
          ]),
          @symcore.Expr::Tuple([
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
            @symcore.Expr::Boolean(true),
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
  let rv = random_var("_M", RVKind::Symbolic(kind~, params~))
  let dummy = @symcore.Expr::Symbol("_x")
  match matrix_density(rv, dummy) {
    Some(pdf) =>
      Some(
        eval_arith(
          @symcore.function("Integral", [
            pdf,
            @symcore.Expr::Tuple([
              dummy,
              eval_arith(
                @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
              @symcore.Expr::Symbol(_) => ()
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
    JointTag::JointRV =>
      if params.length() >= 1 {
        match query_lambda_tuple_signature(params[0]) {
          Some((vars, _)) => Some(vars)
          None => None
        }
      } else {
        None
      }
    JointTag::GeneralizedMultivariateLogGamma
    | JointTag::GeneralizedMultivariateLogGammaOmega =>
      if params.length() == 4 {
        match @symcore.tuple_items(params[2]) {
          Some(lamdas) if !lamdas.is_empty() => {
            let vars : Array[@symcore.Expr] = Array::new()
            for i in 0..<lamdas.length() {
              vars.push(@symcore.Expr::Symbol("_y\{i + 1}"))
            }
            Some(vars)
          }
          _ => None
        }
      } else {
        None
      }
    JointTag::MultivariateEwens if params.length() == 2 =>
      match expr_as_int(params[0]) {
        Some(n) if n > 0 => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<n {
            vars.push(@symcore.Expr::Symbol("_k\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    JointTag::Dirichlet | JointTag::MultivariateBeta if params.length() >= 2 => {
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<params.length() {
        vars.push(@symcore.Expr::Symbol("_x\{i + 1}"))
      }
      Some(vars)
    }
    JointTag::MultivariateNormal | JointTag::MultivariateLaplace if params.length() >=
      1 =>
      match @symcore.tuple_items(params[0]) {
        Some(mu) if !mu.is_empty() => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<mu.length() {
            vars.push(@symcore.Expr::Symbol("_x\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    JointTag::MultivariateT if params.length() == 3 =>
      match @symcore.tuple_items(params[0]) {
        Some(mu) if !mu.is_empty() => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<mu.length() {
            vars.push(@symcore.Expr::Symbol("_x\{i + 1}"))
          }
          Some(vars)
        }
        _ => None
      }
    JointTag::NormalGamma if params.length() == 4 =>
      Some([@symcore.Expr::Symbol("_x"), @symcore.Expr::Symbol("_tau")])
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
    JointTag::JointRV =>
      if params.length() >= 1 {
        query_lambda_apply(params[0], vars)
      } else {
        None
      }
    JointTag::GeneralizedMultivariateLogGamma
    | JointTag::GeneralizedMultivariateLogGammaOmega =>
      symbolic_joint_gmlg_density(name, params, @symcore.Expr::Tuple(vars))
    JointTag::Dirichlet
    | JointTag::MultivariateBeta
    | JointTag::MultivariateNormal
    | JointTag::MultivariateLaplace
    | JointTag::MultivariateT
    | JointTag::NormalGamma =>
      symbolic_joint_density(name, params, @symcore.Expr::Tuple(vars))
    _ => None
  }
}

///|
fn symbolic_joint_cdf_lowers(
  name : String,
  vars : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let neg_oo = eval_arith(
    @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
  )
  match joint_tag_from_name(name) {
    JointTag::Dirichlet | JointTag::MultivariateBeta => {
      let lowers : Array[@symcore.Expr] = Array::new()
      for _ in 0..<vars.length() {
        lowers.push(@symcore.int(0))
      }
      lowers
    }
    JointTag::NormalGamma =>
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
            args.push(@symcore.Expr::Tuple([vars[i], lowers[i], uppers[i]]))
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
            uppers.push(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity))
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
  match symbolic_kind_from_name(name) {
    SymbolicKind::Continuous(
      ContinuousTag::ContinuousRV
      | ContinuousTag::ContinuousDistributionHandmade
    ) =>
      if params.length() >= 1 {
        let dummy = @symcore.Expr::Symbol("_x")
        let neg_oo = eval_arith(
          @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
        )
        match query_lambda_apply(params[0], [dummy]) {
          Some(pdf) =>
            Some(
              eval_arith(
                @symcore.function("Integral", [
                  pdf,
                  @symcore.Expr::Tuple([dummy, neg_oo, x]),
                ]),
              ),
            )
          None => None
        }
      } else {
        None
      }
    SymbolicKind::Discrete(
      DiscreteTag::DiscreteRV
      | DiscreteTag::DiscreteDistributionHandmade
    ) =>
      if params.length() >= 1 {
        let dummy = @symcore.Expr::Symbol("_k")
        let neg_oo = eval_arith(
          @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
        )
        let upper = @symcore.function("floor", [x])
        match query_lambda_apply(params[0], [dummy]) {
          Some(pmf) =>
            Some(
              eval_arith(
                @symcore.function("Sum", [
                  pmf,
                  @symcore.Expr::Tuple([dummy, neg_oo, upper]),
                ]),
              ),
            )
          None => None
        }
      } else {
        None
      }
    SymbolicKind::Discrete(DiscreteTag::FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let sorted_pairs = pairs
          sorted_pairs.sort_by((a, b) => @symcore.compare_expr(a.0, b.0))
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          let mut acc = @symcore.int(0)
          for pair in sorted_pairs {
            let (value, prob) = pair
            piecewise_args.push(
              @symcore.Expr::Tuple([acc, @symcore.function("Lt", [x, value])]),
            )
            acc = eval_arith(@symcore.add([acc, prob]))
          }
          piecewise_args.push(@symcore.Expr::Tuple([acc, @symcore.Expr::Boolean(true)]))
          Some(@symcore.function("Piecewise", piecewise_args))
        }
        None => None
      }
    SymbolicKind::Joint(
      JointTag::JointRV
      | JointTag::GeneralizedMultivariateLogGamma
      | JointTag::GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_cdf(name, params, x)
    SymbolicKind::Matrix(MatrixTag::JointEigenDistribution) =>
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
                    @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
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
    SymbolicKind::Matrix(MatrixTag::LevelSpacingDistribution) =>
      match symbolic_matrix_derived_distribution(name, params) {
        Some(lam) =>
          match query_lambda_tuple_signature(lam) {
            Some((vars, body)) if vars.length() == 1 =>
              Some(
                eval_arith(
                  @symcore.function("Integral", [
                    body,
                    @symcore.Expr::Tuple([vars[0], @symcore.int(0), x]),
                  ]),
                ),
              )
            _ => None
          }
        None => None
      }
    SymbolicKind::Joint(JointTag::MultivariateEwens) =>
      match (symbolic_multivariate_ewens_arity(params), @symcore.tuple_items(x)) {
        (Some(n), Some(bounds)) if bounds.length() == n => {
          let vars : Array[@symcore.Expr] = Array::new()
          for i in 0..<n {
            vars.push(@symcore.Expr::Symbol("_k\{i + 1}"))
          }
          match symbolic_multivariate_ewens_density(params, @symcore.Expr::Tuple(vars)) {
            Some(pmf) => {
              let mut expr = pmf
              for i in 0..<n {
                expr = eval_arith(
                  @symcore.function("Sum", [
                    expr,
                    @symcore.Expr::Tuple([
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
fn query_extract_rel_to_process_value(
  event : Event,
  rv_name : String,
) -> (RelOp, @symcore.Expr, @symcore.Expr)? {
  match event {
    Event::Rel(op~, lhs~, rhs~) =>
      match lhs {
        _ if @symcore.application_has_name(lhs, rv_name, arity=1) =>
          Some((op, @symcore.application_args(lhs).unwrap()[0], rhs))
        _ =>
          match rhs {
            _ if @symcore.application_has_name(rhs, rv_name, arity=1) =>
              Some((invert_relop(op), @symcore.application_args(rhs).unwrap()[0], lhs))
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
    Event::Bool(v) => Some(if v { @symcore.int(1) } else { @symcore.int(0) })
    Event::Not(inner) =>
      match process_probability_event(rv, inner) {
        Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
        None => None
      }
    Event::Rel(..) =>
      match query_extract_rel_to_process_value(event, rv.name) {
        Some((op, time, bound)) =>
          match op {
            RelOp::Eq => process_probability_at(rv, time, bound)
            RelOp::Ne =>
              match process_probability_at(rv, time, bound) {
                Some(p) => Some(eval_arith(query_expr_sub(@symcore.int(1), p)))
                None => None
              }
            RelOp::Le => process_cdf_at(rv, time, bound)
            RelOp::Lt =>
              process_interval_probability(rv, time, None, Some((bound, true)))
            RelOp::Ge =>
              process_interval_probability(rv, time, Some((bound, false)), None)
            RelOp::Gt =>
              process_interval_probability(rv, time, Some((bound, true)), None)
          }
        None => None
      }
    Event::And(items) =>
      if items.length() == 2 {
        let r1 = query_extract_rel_to_process_value(items[0], rv.name)
        let r2 = query_extract_rel_to_process_value(items[1], rv.name)
        match (r1, r2) {
          (Some((RelOp::Eq, t0, x0)), Some((RelOp::Eq, t1, x1))) =>
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
            process_interval_probability(rv, t0, lower, upper)
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
  match symbolic_kind_from_name(name) {
    SymbolicKind::Continuous(
      ContinuousTag::ContinuousRV
      | ContinuousTag::ContinuousDistributionHandmade
    ) => symbolic_opaque_probability_continuous(name, params, rv_name, event)
    SymbolicKind::Discrete(
      DiscreteTag::DiscreteRV
      | DiscreteTag::DiscreteDistributionHandmade
      | DiscreteTag::FiniteDistributionHandmade
    ) => symbolic_opaque_probability_discrete(name, params, rv_name, event)
    SymbolicKind::Joint(
      JointTag::JointRV
      | JointTag::GeneralizedMultivariateLogGamma
      | JointTag::GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_probability_continuous(name, params, rv_name, event)
    SymbolicKind::Joint(JointTag::MultivariateEwens) =>
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
            RVKind::Symbolic(kind~, params~) => {
              let name = symbolic_kind_name(kind)
              if symbolic_kind_is_opaque(kind) {
                match symbolic_opaque_density(name, params, x) {
                  Some(v) => v
                  None =>
                    @symcore.function("density", [@symcore.Expr::Symbol(rv.name), x])
                }
              } else {
                match kind {
                  SymbolicKind::Process(_) =>
                    match symbolic_process_density(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "Density", x, params)
                    }
                  SymbolicKind::Joint(_) =>
                    match symbolic_joint_density(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "Density", x, params)
                    }
                  _ => symbolic_query_expr(name, "Density", x, params)
                }
              }
            }
            _ => @symcore.function("density", [@symcore.Expr::Symbol(rv.name), x])
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
            RVKind::Symbolic(kind~, params~) => {
              let name = symbolic_kind_name(kind)
              if symbolic_kind_is_opaque(kind) {
                match symbolic_opaque_cdf(name, params, rv.name, x) {
                  Some(v) => v
                  None =>
                    match kind {
                      SymbolicKind::Process(_) =>
                        match symbolic_process_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      SymbolicKind::Joint(_) =>
                        match symbolic_joint_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      SymbolicKind::Matrix(_) =>
                        match symbolic_matrix_cdf(name, params, x) {
                          Some(v) => v
                          None => symbolic_query_expr(name, "CDF", x, params)
                        }
                      _ => symbolic_query_expr(name, "CDF", x, params)
                    }
                }
              } else {
                match kind {
                  SymbolicKind::Process(_) =>
                    match symbolic_process_cdf(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "CDF", x, params)
                    }
                  SymbolicKind::Joint(_) =>
                    match symbolic_joint_cdf(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "CDF", x, params)
                    }
                  SymbolicKind::Matrix(_) =>
                    match symbolic_matrix_cdf(name, params, x) {
                      Some(v) => v
                      None => symbolic_query_expr(name, "CDF", x, params)
                    }
                  _ => symbolic_query_expr(name, "CDF", x, params)
                }
              }
            }
            _ => @symcore.function("cdf", [@symcore.Expr::Symbol(rv.name), x])
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
