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
      tuple_expr(rows.map(row =>
        match row {
          @symcore.Expr::Function("Tuple", cols) =>
            tuple_expr(cols.map(col => eval_arith(@symcore.mul([scale, col]))))
          _ => eval_arith(@symcore.mul([scale, row]))
        }
      ))
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
      let means = params.map(a =>
        eval_arith(@symcore.mul([a, @symcore.pow(total, @symcore.int(-1))]))
      )
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
      Some(tuple_expr([
        params[0],
        eval_arith(@symcore.mul([
          params[2],
          @symcore.pow(params[3], @symcore.int(-1)),
        ])),
      ]))
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
      let denom = eval_arith(@symcore.mul([
        @symcore.pow(total, @symcore.int(2)),
        @symcore.add([total, @symcore.int(1)]),
      ]))
      let rows : Array[Array[@symcore.Expr]] = Array::new()
      for i in 0..<params.length() {
        let ai = params[i]
        let row : Array[@symcore.Expr] = Array::new()
        for j in 0..<params.length() {
          let aj = params[j]
          if i == j {
            row.push(eval_arith(@symcore.mul([
              ai,
              @symcore.add([total, @symcore.mul([@symcore.int(-1), ai])]),
              @symcore.pow(denom, @symcore.int(-1)),
            ])))
          } else {
            row.push(eval_arith(@symcore.mul([
              @symcore.int(-1),
              ai,
              aj,
              @symcore.pow(denom, @symcore.int(-1)),
            ])))
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
            row.push(eval_arith(@symcore.mul([
              n,
              pi,
              @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), pi])]),
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
      Some(tuple_matrix(rows))
    }
    "MultivariateT" if params.length() == 3 => {
      let sigma = params[1]
      let nu = params[2]
      let scale = eval_arith(@symcore.mul([
        nu,
        @symcore.pow(@symcore.add([nu, @symcore.int(-2)]), @symcore.int(-1)),
      ]))
      Some(scale_tuple_matrix(sigma, scale))
    }
    "MultivariateLaplace" if params.length() >= 2 => Some(params[1])
    "MultivariateNormal" if params.length() >= 2 => Some(params[1])
    "NormalGamma" if params.length() == 4 => {
      let lamda = params[1]
      let alpha = params[2]
      let beta = params[3]
      let var_x = eval_arith(@symcore.mul([
        beta,
        @symcore.pow(lamda, @symcore.int(-1)),
        @symcore.pow(@symcore.add([alpha, @symcore.int(-1)]), @symcore.int(-1)),
      ]))
      let var_tau = eval_arith(@symcore.mul([
        alpha,
        @symcore.pow(beta, @symcore.int(-2)),
      ]))
      Some(tuple_matrix([
        [var_x, @symcore.int(0)],
        [@symcore.int(0), var_tau],
      ]))
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
fn query_product_expr(items : Array[@symcore.Expr]) -> @symcore.Expr {
  if items.is_empty() {
    @symcore.int(1)
  } else {
    eval_arith(@symcore.mul(items))
  }
}

///|
fn symbolic_joint_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "Dirichlet" | "MultivariateBeta" if params.length() >= 2 =>
      match query_tuple_items(x) {
        Some(xs) if xs.length() == params.length() => {
          let alpha_sum = eval_arith(@symcore.add(params))
          let denom = query_product_expr(params.map(a => @symcore.function("gamma", [a])))
          let power_terms : Array[@symcore.Expr] = Array::new()
          for i in 0..<params.length() {
            power_terms.push(eval_arith(@symcore.pow(
              xs[i],
              eval_arith(@symcore.add([params[i], @symcore.int(-1)])),
            )))
          }
          Some(eval_arith(@symcore.mul([
            @symcore.function("gamma", [alpha_sum]),
            @symcore.pow(denom, @symcore.int(-1)),
            query_product_expr(power_terms),
          ])))
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
          let tau_power = eval_arith(@symcore.pow(
            tau,
            eval_arith(@symcore.add([alpha, @symcore.mul([@symcore.int(-1), half])])),
          ))
          let norm = eval_arith(@symcore.mul([
            @symcore.function("sqrt", [eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi")]))]),
            @symcore.function("gamma", [alpha]),
          ]))
          let quad = eval_arith(@symcore.mul([
            @symcore.int(-1),
            half,
            lamda,
            tau,
            @symcore.pow(eval_arith(query_expr_sub(xv, mu)), @symcore.int(2)),
          ]))
          Some(eval_arith(@symcore.mul([
            @symcore.pow(beta, alpha),
            @symcore.function("sqrt", [lamda]),
            @symcore.pow(norm, @symcore.int(-1)),
            tau_power,
            @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.int(-1), beta, tau]))]),
            @symcore.function("exp", [quad]),
          ])))
        }
        _ => None
      }
    "MultivariateNormal" if params.length() >= 2 =>
      match (query_tuple2(params[0]), query_matrix2x2(params[1]), query_tuple2(x)) {
        (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((x1, x2))) => {
          let det = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s00, s11])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
          ]))
          let dx1 = eval_arith(query_expr_sub(x1, mu1))
          let dx2 = eval_arith(query_expr_sub(x2, mu2))
          let quad_num = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s11, @symcore.pow(dx1, @symcore.int(2))])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, dx1, dx2])),
            eval_arith(@symcore.mul([@symcore.int(-1), s10, dx1, dx2])),
            eval_arith(@symcore.mul([s00, @symcore.pow(dx2, @symcore.int(2))])),
          ]))
          let half = try! @symcore.rational_from_ints(1, 2)
          let quad = eval_arith(@symcore.mul([quad_num, @symcore.pow(det, @symcore.int(-1))]))
          let norm = eval_arith(@symcore.mul([
            @symcore.int(2),
            @symcore.symbol("pi"),
            @symcore.function("sqrt", [det]),
          ]))
          Some(eval_arith(@symcore.mul([
            @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.int(-1), half, quad]))]),
            @symcore.pow(norm, @symcore.int(-1)),
          ])))
        }
        _ => None
      }
    "MultivariateLaplace" if params.length() >= 2 =>
      match (query_tuple2(params[0]), query_matrix2x2(params[1]), query_tuple2(x)) {
        (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((x1, x2))) => {
          let det = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s00, s11])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
          ]))
          let x_quad_num = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s11, @symcore.pow(mu1, @symcore.int(2))])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, mu1, mu2])),
            eval_arith(@symcore.mul([@symcore.int(-1), s10, mu1, mu2])),
            eval_arith(@symcore.mul([s00, @symcore.pow(mu2, @symcore.int(2))])),
          ]))
          let y_quad_num = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s11, @symcore.pow(x1, @symcore.int(2))])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, x1, x2])),
            eval_arith(@symcore.mul([@symcore.int(-1), s10, x1, x2])),
            eval_arith(@symcore.mul([s00, @symcore.pow(x2, @symcore.int(2))])),
          ]))
          let linear_num = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s11, x1, mu1])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, x1, mu2])),
            eval_arith(@symcore.mul([@symcore.int(-1), s10, x2, mu1])),
            eval_arith(@symcore.mul([s00, x2, mu2])),
          ]))
          let x_quad = eval_arith(@symcore.mul([x_quad_num, @symcore.pow(det, @symcore.int(-1))]))
          let y_quad = eval_arith(@symcore.mul([y_quad_num, @symcore.pow(det, @symcore.int(-1))]))
          let linear = eval_arith(@symcore.mul([linear_num, @symcore.pow(det, @symcore.int(-1))]))
          let denom = eval_arith(@symcore.mul([
            @symcore.symbol("pi"),
            @symcore.function("sqrt", [det]),
          ]))
          Some(eval_arith(@symcore.mul([
            @symcore.function("exp", [linear]),
            @symcore.function("besselk", [
              @symcore.int(0),
              @symcore.function("sqrt", [eval_arith(@symcore.mul([
                eval_arith(@symcore.add([@symcore.int(2), x_quad])),
                y_quad,
              ]))]),
            ]),
            @symcore.pow(denom, @symcore.int(-1)),
          ])))
        }
        _ => None
      }
    "MultivariateT" if params.length() == 3 =>
      match (query_tuple2(params[0]), query_matrix2x2(params[1]), query_tuple2(x)) {
        (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((x1, x2))) => {
          let nu = params[2]
          let det = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s00, s11])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
          ]))
          let dx1 = eval_arith(query_expr_sub(x1, mu1))
          let dx2 = eval_arith(query_expr_sub(x2, mu2))
          let quad_num = eval_arith(@symcore.add([
            eval_arith(@symcore.mul([s11, @symcore.pow(dx1, @symcore.int(2))])),
            eval_arith(@symcore.mul([@symcore.int(-1), s01, dx1, dx2])),
            eval_arith(@symcore.mul([@symcore.int(-1), s10, dx1, dx2])),
            eval_arith(@symcore.mul([s00, @symcore.pow(dx2, @symcore.int(2))])),
          ]))
          let half = try! @symcore.rational_from_ints(1, 2)
          let nu_half = eval_arith(@symcore.mul([half, nu]))
          let shape = eval_arith(@symcore.add([nu_half, @symcore.int(1)]))
          let quad = eval_arith(@symcore.mul([quad_num, @symcore.pow(det, @symcore.int(-1))]))
          let coeff = eval_arith(@symcore.mul([
            @symcore.function("gamma", [shape]),
            @symcore.pow(
              eval_arith(@symcore.mul([
                @symcore.function("gamma", [nu_half]),
                nu,
                @symcore.symbol("pi"),
                @symcore.function("sqrt", [det]),
              ])),
              @symcore.int(-1),
            ),
          ]))
          Some(eval_arith(@symcore.mul([
            coeff,
            @symcore.pow(
              eval_arith(@symcore.add([
                @symcore.int(1),
                eval_arith(@symcore.mul([quad, @symcore.pow(nu, @symcore.int(-1))])),
              ])),
              eval_arith(@symcore.mul([@symcore.int(-1), shape])),
            ),
          ])))
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
      Some(p) => terms.push(eval_arith(@symcore.mul([expr_from_big_rational(w), p])))
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
    RVKind::Binomial(..) |
    RVKind::Poisson(..) |
    RVKind::Geometric(..) |
    RVKind::NegativeBinomial(..) => discrete_probability(rv, event)
    RVKind::Normal(..) |
    RVKind::Exponential(..) |
    RVKind::Gamma(..) => continuous_probability(rv, event)
    RVKind::Symbolic(tag~, params~) =>
      match (discrete_probability(rv, event), continuous_probability(rv, event)) {
        (Some(v), _) => Some(v)
        (_, Some(v)) => Some(v)
        _ => Some(symbolic_query_expr(symbolic_tag_name(tag), "Probability", event_to_expr(event), params))
      }
    RVKind::JointIndependent(items) => probability_joint_independent(items, event)
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
    RVKind::Finite(_) => finite_expectation(rv, expr=expr)
    RVKind::Binomial(..) |
    RVKind::Poisson(..) |
    RVKind::Geometric(..) |
    RVKind::NegativeBinomial(..) =>
      if @symcore.compare_expr(expr, @symcore.symbol(rv.name)) == 0 {
        discrete_mean(rv)
      } else {
        None
      }
    RVKind::Normal(..) |
    RVKind::Exponential(..) |
    RVKind::Gamma(..) =>
      if @symcore.compare_expr(expr, @symcore.symbol(rv.name)) == 0 {
        continuous_mean(rv)
      } else {
        None
      }
    RVKind::Symbolic(tag~, params~) =>
      if @symcore.compare_expr(expr, @symcore.symbol(rv.name)) == 0 {
        let name = symbolic_tag_name(tag)
        if symbolic_tag_family(tag) == "J" {
          match symbolic_joint_mean(name, params) {
            Some(v) => Some(v)
            None =>
              Some(symbolic_query_expr(name, "Mean", @symcore.symbol(rv.name), params))
          }
        } else {
          match (discrete_mean(rv), continuous_mean(rv)) {
            (Some(v), _) => Some(v)
            (_, Some(v)) => Some(v)
            _ => Some(symbolic_query_expr(name, "Mean", @symcore.symbol(rv.name), params))
          }
        }
      } else {
        None
      }
    RVKind::Compound(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for pair in items {
        let (w, item) = pair
        let renamed = rename_random_var(item, rv.name)
        match expectation_of_rv(renamed, expr) {
          Some(val) => terms.push(eval_arith(@symcore.mul([expr_from_big_rational(w), val])))
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
    RVKind::Binomial(..) |
    RVKind::Poisson(..) |
    RVKind::Geometric(..) |
    RVKind::NegativeBinomial(..) => discrete_variance(rv)
    RVKind::Normal(..) |
    RVKind::Exponential(..) |
    RVKind::Gamma(..) => continuous_variance(rv)
    RVKind::Symbolic(tag~, params~) =>
      {
        let name = symbolic_tag_name(tag)
        if symbolic_tag_family(tag) == "J" {
          match symbolic_joint_variance(name, params) {
            Some(v) => Some(v)
            None =>
              Some(symbolic_query_expr(name, "Variance", @symcore.symbol(rv.name), params))
          }
        } else {
          match (discrete_variance(rv), continuous_variance(rv)) {
            (Some(v), _) => Some(v)
            (_, Some(v)) => Some(v)
            _ => Some(symbolic_query_expr(name, "Variance", @symcore.symbol(rv.name), params))
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
        match (expectation_of_rv(renamed, @symcore.symbol(rv.name)), variance_of_rv(renamed)) {
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
        mean_terms.push(eval_arith(@symcore.mul([expr_from_big_rational(weights[i]), means[i]])))
      }
      let total_mean = eval_arith(@symcore.add(mean_terms))
      for i in 0..<weights.length() {
        let diff = eval_arith(query_expr_sub(means[i], total_mean))
        let sq = eval_arith(@symcore.pow(diff, @symcore.int(2)))
        terms.push(eval_arith(@symcore.mul([expr_from_big_rational(weights[i]), sq])))
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
  if rvs.length() == 1 && @symcore.compare_expr(expr, @symcore.symbol(rvs[0].name)) == 0 {
    match variance_of_rv(rvs[0]) {
      Some(v) => return v
      None => ()
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
    if @symcore.compare_expr(approx, @symcore.function("variance_prop", [expr])) != 0 {
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
          (Some(ra), Some(rb)) if assume_independent(ra, rb) => return @symcore.int(0)
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
              if symbolic_tag_family(tag) == "J" {
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
            RVKind::Symbolic(tag~, params~) =>
              symbolic_query_expr(symbolic_tag_name(tag), "CDF", x, params)
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
