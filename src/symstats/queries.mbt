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
        match (discrete_mean(rv), continuous_mean(rv)) {
          (Some(v), _) => Some(v)
          (_, Some(v)) => Some(v)
          _ => Some(symbolic_query_expr(symbolic_tag_name(tag), "Mean", @symcore.symbol(rv.name), params))
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
      match (discrete_variance(rv), continuous_variance(rv)) {
        (Some(v), _) => Some(v)
        (_, Some(v)) => Some(v)
        _ => Some(symbolic_query_expr(symbolic_tag_name(tag), "Variance", @symcore.symbol(rv.name), params))
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
            RVKind::Symbolic(tag~, params~) =>
              symbolic_query_expr(symbolic_tag_name(tag), "Density", x, params)
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
