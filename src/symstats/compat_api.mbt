///|
/// Compatibility API for broader SymPy stats coverage.

///|
fn symbolic_rv(
  name : String,
  dist : String,
  params : Array[@symcore.Expr],
) -> RandomVar {
  let kind = symbolic_kind_from_name(dist)
  random_var(name, Symbolic(kind~, params~))
}

///|
pub fn p(event : Event, rv? : RandomVar) -> @symcore.Expr {
  match rv {
    Some(v) => probability(event, rv=v)
    None => probability(event)
  }
}

///|
pub fn e(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  expectation(expr, rvs~)
}

///|
pub fn h(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  entropy(expr, rvs~)
}

///|
pub fn given(expr : @symcore.Expr, condition : Event) -> @symcore.Expr {
  match condition {
    Bool(true) => expr
    Bool(false) => @symcore.function("given", [expr, event_to_expr(condition)])
    Rel(op~, lhs~, rhs~) =>
      match (op, lhs, rhs) {
        (Eq, Symbol(name), value) => substitute_symbol(expr, name, value)
        (Eq, value, Symbol(name)) => substitute_symbol(expr, name, value)
        _ => {
          let expr_names = random_symbols(expr)
          let cond_names = event_symbols(condition)
          let mut overlaps = false
          for left in expr_names {
            for right in cond_names {
              if left == right {
                overlaps = true
                break
              }
            }
            if overlaps {
              break
            }
          }
          if overlaps {
            @symcore.function("given", [expr, event_to_expr(condition)])
          } else {
            expr
          }
        }
      }
    _ => {
      let expr_names = random_symbols(expr)
      let cond_names = event_symbols(condition)
      let mut overlaps = false
      for left in expr_names {
        for right in cond_names {
          if left == right {
            overlaps = true
            break
          }
        }
        if overlaps {
          break
        }
      }
      if overlaps {
        @symcore.function("given", [expr, event_to_expr(condition)])
      } else {
        expr
      }
    }
  }
}

///|
pub fn where_(condition : Event) -> @symcore.Expr {
  @symcore.function("where", [event_to_expr(condition)])
}

///|
fn stats_positive_infinity() -> @symcore.Expr {
  NumberSymbol(Infinity)
}

///|
fn stats_int_range_set(lo : Int, hi : Int) -> @symsets.Set {
  if hi < lo {
    return @symsets.finite_set([])
  }
  let values : Array[@symcore.Expr] = []
  for i in lo..<=hi {
    values.push(@symcore.int(i))
  }
  @symsets.finite_set(values)
}

///|
fn stats_symbolic_support(
  kind : SymbolicKind,
  params : Array[@symcore.Expr],
) -> @symsets.Set {
  match kind {
    Continuous(tag) =>
      match tag {
        Arcsin | Beta | Kumaraswamy =>
          @symsets.interval(@symcore.int(0), @symcore.int(1))
        BetaPrime
        | Chi
        | ChiSquared
        | Erlang
        | Exponential
        | FDistribution
        | Frechet
        | GammaInverse
        | GaussianInverse
        | LogLogistic
        | LogNormal
        | Lomax
        | Maxwell
        | Nakagami
        | Rayleigh
        | Weibull =>
          @symsets.interval(@symcore.int(0), stats_positive_infinity())
        Pareto if params.length() == 2 =>
          @symsets.interval(params[0], stats_positive_infinity())
        PowerFunction if params.length() == 3 =>
          @symsets.interval(params[1], params[2])
        Reciprocal if params.length() == 2 =>
          @symsets.interval(params[0], params[1])
        Triangular if params.length() == 3 =>
          @symsets.interval(params[0], params[1])
        Trapezoidal if params.length() == 4 =>
          @symsets.interval(params[0], params[3])
        Uniform if params.length() == 2 =>
          @symsets.interval(params[0], params[1])
        WignerSemicircle if params.length() == 1 =>
          @symsets.interval(
            @symcore.mul([@symcore.int(-1), params[0]]),
            params[0],
          )
        _ => @symsets.reals()
      }
    Discrete(tag) =>
      match tag {
        BetaBinomial if params.length() == 3 =>
          match expr_as_int(params[0]) {
            Some(n) => stats_int_range_set(0, n)
            None =>
              @symsets.intersection([
                @symsets.naturals0(),
                @symsets.interval(@symcore.int(0), params[0]),
              ])
          }
        FiniteDistributionHandmade =>
          match symbolic_finite_handmade_pairs(params) {
            Some(pairs) => @symsets.finite_set(pairs.map(pair => pair.0))
            None => @symsets.reals()
          }
        FlorySchulz
        | IdealSoliton
        | Logarithmic
        | RobustSoliton
        | YuleSimon
        | Zeta => @symsets.naturals()
        Hermite | Multinomial | NegativeMultinomial => @symsets.naturals0()
        Hypergeometric if params.length() == 3 =>
          match
            (
              expr_as_int(params[0]),
              expr_as_int(params[1]),
              expr_as_int(params[2]),
            ) {
            (Some(population), Some(successes), Some(draws)) => {
              let lo = if 0 > draws + successes - population {
                0
              } else {
                draws + successes - population
              }
              let hi = if draws < successes { draws } else { successes }
              stats_int_range_set(lo, hi)
            }
            _ => @symsets.naturals0()
          }
        Skellam => @symsets.integers()
        _ => @symsets.reals()
      }
    Joint(_) | Process(_) | Matrix(_) => @symsets.reals()
  }
}

///|
fn stats_random_var_support(rv : RandomVar) -> @symsets.Set {
  match rv.kind {
    Finite(items) => @symsets.finite_set(items.map(item => item.0))
    Binomial(n~, ..) => @symsets.interval(@symcore.int(0), n)
    Poisson(_) | NegativeBinomial(_) => @symsets.naturals0()
    Geometric(_) => @symsets.naturals()
    Normal(_) => @symsets.reals()
    Exponential(_) | Gamma(_) =>
      @symsets.interval(@symcore.int(0), stats_positive_infinity())
    JointIndependent(_) | Compound(_) | StochasticProcess(_) | Matrix(_) =>
      @symsets.reals()
    Symbolic(kind~, params~) => stats_symbolic_support(kind, params)
  }
}

///|
pub fn where_set(
  condition : Event,
  rv : RandomVar,
) -> @symsets.Set? raise @symsolvers.SolverError {
  match rv.kind {
    Finite(items) => {
      let values : Array[@symcore.Expr] = []
      let env : Map[String, @symcore.Expr] = Map([])
      for item in items {
        let (value, _) = item
        env[rv.name] = value
        match evaluate_event(condition, env) {
          True => values.push(value)
          False => ()
          Unknown => return None
        }
      }
      Some(@symsets.finite_set(values))
    }
    _ => {
      let solved = reduce_rational_inequalities_wrap(condition, Symbol(rv.name))
      let support = stats_random_var_support(rv)
      if support is Reals {
        Some(solved)
      } else {
        Some(@symsets.intersection([support, solved]))
      }
    }
  }
}

///|
pub fn sample(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
  seed? : Int? = None,
) -> @symcore.Expr {
  match sample_expr(expr, rvs~, seed~) {
    Some(value) => value
    None => @symcore.function("sample", [expr])
  }
}

///|
pub fn sample_iter(
  expr : @symcore.Expr,
  n? : Int = 1,
  rvs? : Array[RandomVar] = [],
  seed? : Int? = None,
) -> Array[@symcore.Expr] {
  if n <= 0 {
    return []
  }
  let rng = stats_rng(seed~)
  let out : Array[@symcore.Expr] = []
  match direct_finite_symbol_items(expr, rvs) {
    Some(items) =>
      match stats_prepare_finite_sampler(items) {
        Some(prepared) => {
          for _ in 0..<n {
            match stats_sample_finite_prepared(prepared, rng) {
              Some(value) => out.push(eval_arith(value))
              None => out.push(@symcore.function("sample", [expr]))
            }
          }
          return out
        }
        None => {
          for _ in 0..<n {
            out.push(@symcore.function("sample", [expr]))
          }
          return out
        }
      }
    None => ()
  }
  for _ in 0..<n {
    match sample_expr_with_rng(expr, rvs, rng) {
      Some(value) => out.push(value)
      None => out.push(@symcore.function("sample", [expr]))
    }
  }
  out
}

///|
pub fn sample_iter_lambdify(
  expr : @symcore.Expr,
  n? : Int = 1,
  rvs? : Array[RandomVar] = [],
  seed? : Int? = None,
) -> Array[@symcore.Expr] {
  sample_iter(expr, n~, rvs~, seed~)
}

///|
pub fn sample_iter_subs(
  expr : @symcore.Expr,
  n? : Int = 1,
  rvs? : Array[RandomVar] = [],
  seed? : Int? = None,
) -> Array[@symcore.Expr] {
  sample_iter(expr, n~, rvs~, seed~)
}

///|
pub fn rv(
  name : String,
  distribution : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  match distribution {
    "Binomial" if params.length() == 2 => binomial(name, params[0], params[1])
    "Poisson" if params.length() == 1 => poisson(name, params[0])
    "Geometric" if params.length() == 1 => geometric(name, params[0])
    "NegativeBinomial" if params.length() == 2 =>
      negative_binomial(name, params[0], params[1])
    "Normal" if params.length() == 2 => normal(name, params[0], params[1])
    "Exponential" if params.length() == 1 => exponential(name, params[0])
    "Gamma" if params.length() == 2 => gamma_dist(name, params[0], params[1])
    "Bernoulli" if params.length() == 1 =>
      match expr_as_number(params[0]) {
        Some(p) => bernoulli(name, p)
        None =>
          finite_distribution_handmade(name, params=[
            Tuple([
              Tuple([@symcore.int(1), params[0]]),
              Tuple([
                @symcore.int(0),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), params[0]]),
                  ]),
                ),
              ]),
            ]),
          ])
      }
    "Coin" =>
      if params.is_empty() {
        coin(name)
      } else {
        match expr_as_number(params[0]) {
          Some(p) => coin(name, p_head=p)
          None =>
            finite_distribution_handmade(name, params=[
              Tuple([
                Tuple([@symcore.int(1), params[0]]),
                Tuple([
                  @symcore.int(0),
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([@symcore.int(-1), params[0]]),
                    ]),
                  ),
                ]),
              ]),
            ])
        }
      }
    "Die" =>
      if params.is_empty() {
        die(name)
      } else {
        match expr_as_int(params[0]) {
          Some(sides) => die(name, sides~)
          None => symbolic_rv(name, distribution, params)
        }
      }
    _ => symbolic_rv(name, distribution, params)
  }
}

///|
pub fn sample_stochastic_process(
  proc : RandomVar,
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
  n? : Int = 2,
) -> @symcore.Expr {
  match sample_stochastic_process_path(proc, t0, t1, n) {
    Some(path) => return path
    None => ()
  }
  @symcore.function("sample_stochastic_process", [
    Symbol(proc.name),
    t0,
    t1,
    @symcore.int(n),
  ])
}

///|
fn sample_time_grid(
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
  n : Int,
) -> Array[(@symcore.Expr, Double)]? {
  if n <= 0 {
    return None
  }
  match (stats_expr_to_double(t0), stats_expr_to_double(t1)) {
    (Some(start), Some(stop)) if stop >= start && start >= 0.0 => {
      let out : Array[(@symcore.Expr, Double)] = []
      if n == 1 {
        out.push((t0, start))
        return Some(out)
      }
      let step = (stop - start) / (n - 1).to_double()
      for i in 0..<n {
        let time = start + step * i.to_double()
        out.push((stats_expr_from_double(time), time))
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn sample_path_expr(
  times : Array[(@symcore.Expr, Double)],
  values : Array[@symcore.Expr],
) -> @symcore.Expr {
  let pairs : Array[@symcore.Expr] = []
  for i in 0..<values.length() {
    pairs.push(Tuple([times[i].0, values[i]]))
  }
  Tuple(pairs)
}

///|
fn sample_poisson_process_path(
  rate : @symcore.Expr,
  times : Array[(@symcore.Expr, Double)],
  rng : @random.Rand,
) -> @symcore.Expr? {
  let rate_d = match stats_expr_to_double(rate) {
    Some(value) if value >= 0.0 => value
    _ => return None
  }
  let values : Array[@symcore.Expr] = []
  let mut current = 0
  let mut previous = 0.0
  for i in 0..<times.length() {
    let time = times[i].1
    let delta = if i == 0 { time } else { time - previous }
    previous = time
    match stats_sample_poisson(stats_expr_from_double(rate_d * delta), rng) {
      Some(sampled) =>
        match expr_as_int(sampled) {
          Some(k) => {
            current += k
            values.push(@symcore.int(current))
          }
          None => return None
        }
      None => return None
    }
  }
  Some(sample_path_expr(times, values))
}

///|
fn sample_wiener_process_path(
  times : Array[(@symcore.Expr, Double)],
  rng : @random.Rand,
) -> @symcore.Expr? {
  let values : Array[@symcore.Expr] = []
  let mut current = 0.0
  let mut previous = 0.0
  for i in 0..<times.length() {
    let time = times[i].1
    let delta = if i == 0 { time } else { time - previous }
    previous = time
    if delta < 0.0 {
      return None
    }
    if delta > 0.0 {
      current += delta.sqrt() * stats_sample_standard_normal(rng)
    }
    values.push(stats_expr_from_double(current))
  }
  Some(sample_path_expr(times, values))
}

///|
fn sample_gamma_process_path(
  lamda : @symcore.Expr,
  gamma : @symcore.Expr,
  times : Array[(@symcore.Expr, Double)],
  rng : @random.Rand,
) -> @symcore.Expr? {
  let lamda_d = match stats_expr_to_double(lamda) {
    Some(value) if value > 0.0 => value
    _ => return None
  }
  let gamma_d = match stats_expr_to_double(gamma) {
    Some(value) if value > 0.0 => value
    _ => return None
  }
  let values : Array[@symcore.Expr] = []
  let mut current = 0.0
  let mut previous = 0.0
  for i in 0..<times.length() {
    let time = times[i].1
    let delta = if i == 0 { time } else { time - previous }
    previous = time
    if delta < 0.0 {
      return None
    }
    if delta > 0.0 {
      match stats_sample_gamma_double(gamma_d * delta, 1.0 / lamda_d, rng) {
        Some(increment) => current += increment
        None => return None
      }
    }
    values.push(stats_expr_from_double(current))
  }
  Some(sample_path_expr(times, values))
}

///|
fn sample_bernoulli_process_path(
  params : Array[@symcore.Expr],
  times : Array[(@symcore.Expr, Double)],
  rng : @random.Rand,
) -> @symcore.Expr? {
  if params.length() < 1 {
    return None
  }
  let p = match expr_as_number(params[0]) {
    Some(value) => value
    None => return None
  }
  let success = if params.length() >= 2 { params[1] } else { @symcore.int(1) }
  let failure = if params.length() >= 3 { params[2] } else { @symcore.int(0) }
  let one_minus_p = @symnum.BigRational::one().add_r(p.neg_r())
  let values : Array[@symcore.Expr] = []
  for _ in times {
    match stats_sample_finite([(success, p), (failure, one_minus_p)], rng) {
      Some(value) => values.push(value)
      None => return None
    }
  }
  Some(sample_path_expr(times, values))
}

///|
fn sample_stochastic_process_path(
  proc : RandomVar,
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
  n : Int,
) -> @symcore.Expr? {
  let times = match sample_time_grid(t0, t1, n) {
    Some(value) => value
    None => return None
  }
  let rng = stats_rng()
  match proc.kind {
    StochasticProcess(PoissonProcess(rate~, ..)) =>
      sample_poisson_process_path(rate, times, rng)
    StochasticProcess(WienerProcess(..)) =>
      sample_wiener_process_path(times, rng)
    Symbolic(kind~, params~) =>
      match kind {
        Process(BernoulliProcess) =>
          sample_bernoulli_process_path(params, times, rng)
        Process(GammaProcess) if params.length() >= 2 =>
          sample_gamma_process_path(params[0], params[1], times, rng)
        _ => None
      }
    _ => None
  }
}

///|
pub fn median(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  quantile(expr, stats_exact_rational(1, 2), rvs~)
}

///|
fn resolve_rv(expr : @symcore.Expr, rvs : Array[RandomVar]) -> RandomVar? {
  if rvs.length() == 1 {
    return Some(rvs[0])
  }
  match expr {
    Symbol(name) => {
      for rv in rvs {
        if rv.name == name {
          return Some(rv)
        }
      }
      None
    }
    _ => None
  }
}

///|
fn symbolic_metric_with_head(
  name : String,
  suffix : String,
  head : @symcore.Expr,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  let dist = symbolic_distribution_expr(name, params)
  match suffix {
    "MGF" =>
      @symcore.function("Expectation", [
        @symcore.function("exp", [eval_arith(@symcore.mul([head, dist]))]),
      ])
    "CF" =>
      @symcore.function("Expectation", [
        @symcore.function("exp", [
          eval_arith(@symcore.mul([NumberSymbol(ImaginaryUnit), head, dist])),
        ]),
      ])
    _ => @symcore.function(suffix, [dist, head])
  }
}

///|
fn symbolic_metric_no_head(
  name : String,
  suffix : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  let dist = symbolic_distribution_expr(name, params)
  match suffix {
    "Entropy" => @symcore.function("Entropy", [dist])
    _ => @symcore.function(suffix, [dist])
  }
}

///|

///|

///|
fn compat_tuple2(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr)? {
  match @symcore.tuple_items(expr) {
    Some(items) if items.length() == 2 => Some((items[0], items[1]))
    _ => None
  }
}

///|
fn compat_matrix2x2(
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
fn compat_dot2(
  a1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b1 : @symcore.Expr,
  b2 : @symcore.Expr,
) -> @symcore.Expr {
  eval_arith(
    @symcore.add([
      eval_arith(@symcore.mul([a1, b1])),
      eval_arith(@symcore.mul([a2, b2])),
    ]),
  )
}

///|
fn compat_quad2(
  s00 : @symcore.Expr,
  s01 : @symcore.Expr,
  s10 : @symcore.Expr,
  s11 : @symcore.Expr,
  t1 : @symcore.Expr,
  t2 : @symcore.Expr,
) -> @symcore.Expr {
  eval_arith(
    @symcore.add([
      eval_arith(@symcore.mul([s00, @symcore.pow(t1, @symcore.int(2))])),
      eval_arith(@symcore.mul([eval_arith(@symcore.add([s01, s10])), t1, t2])),
      eval_arith(@symcore.mul([s11, @symcore.pow(t2, @symcore.int(2))])),
    ]),
  )
}

///|
fn compat_piecewise2(
  v1 : @symcore.Expr,
  c1 : @symcore.Expr,
  v2 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Piecewise", [Tuple([v1, c1]), Tuple([v2, Boolean(true)])])
}

///|
fn compat_piecewise3(
  v1 : @symcore.Expr,
  c1 : @symcore.Expr,
  v2 : @symcore.Expr,
  c2 : @symcore.Expr,
  v3 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Piecewise", [
    Tuple([v1, c1]),
    Tuple([v2, c2]),
    Tuple([v3, Boolean(true)]),
  ])
}

///|
fn compat_use_generic_unevaluated(name : String) -> Bool {
  symbolic_name_is_opaque(name)
}

///|
fn symbolic_opaque_mgf(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_kind_from_name(name) {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) =>
      if params.length() >= 1 {
        let rv = symbolic_rv(rv_name, name, params)
        let x = @symcore.Expr::Symbol("_x")
        let pdf = density(rv, x)
        Some(
          eval_arith(
            @symcore.function("Integral", [
              eval_arith(
                @symcore.mul([
                  @symcore.function("exp", [eval_arith(@symcore.mul([t, x]))]),
                  pdf,
                ]),
              ),
              @symcore.function("Tuple", [
                x,
                eval_arith(
                  @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
                ),
                NumberSymbol(Infinity),
              ]),
            ]),
          ),
        )
      } else {
        None
      }
    Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      if params.length() >= 1 {
        let rv = symbolic_rv(rv_name, name, params)
        let k = @symcore.Expr::Symbol("_k")
        let pmf = density(rv, k)
        Some(
          eval_arith(
            @symcore.function("Sum", [
              eval_arith(
                @symcore.mul([
                  @symcore.function("exp", [eval_arith(@symcore.mul([t, k]))]),
                  pmf,
                ]),
              ),
              @symcore.function("Tuple", [
                k,
                eval_arith(
                  @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
                ),
                NumberSymbol(Infinity),
              ]),
            ]),
          ),
        )
      } else {
        None
      }
    Discrete(FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for pair in pairs {
            let (value, prob) = pair
            terms.push(
              eval_arith(
                @symcore.mul([
                  prob,
                  @symcore.function("exp", [
                    eval_arith(@symcore.mul([t, value])),
                  ]),
                ]),
              ),
            )
          }
          Some(eval_arith(@symcore.add(terms)))
        }
        None => None
      }
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_mgf_via_integral(name, params, t)
    Joint(MultivariateEwens) =>
      if params.length() != 2 {
        None
      } else {
        match (expr_as_int(params[0]), @symcore.tuple_items(t)) {
          (Some(n), Some(ts)) if params.length() == 2 && ts.length() == n => {
            let vars : Array[@symcore.Expr] = Array::new()
            for i in 0..<n {
              vars.push(Symbol("_k\{i + 1}"))
            }
            let rv = symbolic_rv(rv_name, name, params)
            let point = @symcore.function("Tuple", vars)
            let pmf = density(rv, point)
            let linear_terms : Array[@symcore.Expr] = Array::new()
            for i in 0..<n {
              linear_terms.push(eval_arith(@symcore.mul([ts[i], vars[i]])))
            }
            let lin = if linear_terms.is_empty() {
              @symcore.int(0)
            } else {
              eval_arith(@symcore.add(linear_terms))
            }
            let mut expr = eval_arith(
              @symcore.mul([@symcore.function("exp", [lin]), pmf]),
            )
            for i in 0..<n {
              expr = eval_arith(
                @symcore.function("Sum", [
                  expr,
                  @symcore.function("Tuple", [
                    vars[i],
                    @symcore.int(0),
                    @symcore.int(n / (i + 1)),
                  ]),
                ]),
              )
            }
            Some(expr)
          }
          _ => None
        }
      }
    Process(BernoulliProcess) if params.length() >= 1 => {
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
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                p,
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([t, success])),
                ]),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), p]),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([t, failure])),
                ]),
              ]),
            ),
          ]),
        ),
      )
    }
    Process(GammaProcess) if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let inner = eval_arith(
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([
            @symcore.int(-1),
            t,
            @symcore.pow(lamda, @symcore.int(-1)),
          ]),
        ]),
      )
      Some(
        eval_arith(
          @symcore.pow(
            inner,
            eval_arith(@symcore.mul([@symcore.int(-1), gamma])),
          ),
        ),
      )
    }
    Matrix(
      GaussianOrthogonalEnsemble
      | GaussianEnsemble
      | GaussianUnitaryEnsemble
      | GaussianSymplecticEnsemble
      | CircularEnsemble
      | CircularUnitaryEnsemble
      | CircularOrthogonalEnsemble
      | CircularSymplecticEnsemble
      | MatrixGamma
      | MatrixStudentT
    ) =>
      Some(
        @symcore.function("Expectation", [
          @symcore.function("exp", [
            eval_arith(@symcore.mul([t, Symbol(rv_name)])),
          ]),
        ]),
      )
    _ => None
  }
}

///|
fn symbolic_opaque_cf(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
  t : @symcore.Expr,
) -> @symcore.Expr? {
  symbolic_opaque_mgf(
    name,
    params,
    rv_name,
    eval_arith(@symcore.mul([NumberSymbol(ImaginaryUnit), t])),
  )
}

///|
fn symbolic_continuous_mgf_via_integral(
  name : String,
  params : Array[@symcore.Expr],
  t : @symcore.Expr,
) -> @symcore.Expr? {
  let kind = symbolic_kind_from_name(name)
  let rv = random_var("_X", Symbolic(kind~, params~))
  let x = @symcore.Expr::Symbol("_x")
  match continuous_density(rv, x) {
    Some(pdf) => {
      let lower = eval_arith(
        @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
      )
      let upper = @symcore.Expr::NumberSymbol(Infinity)
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(
              @symcore.mul([
                @symcore.function("exp", [eval_arith(@symcore.mul([t, x]))]),
                pdf,
              ]),
            ),
            @symcore.function("Tuple", [x, lower, upper]),
          ]),
        ),
      )
    }
    None => None
  }
}

///|
fn symbolic_discrete_mgf_via_sum(
  name : String,
  params : Array[@symcore.Expr],
  t : @symcore.Expr,
) -> @symcore.Expr? {
  let bounds = match discrete_tag_from_name(name) {
    BetaBinomial if params.length() == 3 => Some((@symcore.int(0), params[0]))
    Hypergeometric if params.length() == 3 => Some((@symcore.int(0), params[2]))
    IdealSoliton if params.length() == 1 => Some((@symcore.int(1), params[0]))
    RobustSoliton if params.length() == 3 => Some((@symcore.int(1), params[0]))
    YuleSimon if params.length() == 1 =>
      Some((@symcore.int(1), NumberSymbol(Infinity)))
    _ => None
  }
  match bounds {
    Some((lower, upper)) => {
      let k = @symcore.Expr::Symbol("_k")
      let kind = symbolic_kind_from_name(name)
      let rv = random_var("_X", Symbolic(kind~, params~))
      match discrete_pmf(rv, k) {
        Some(pmf) =>
          Some(
            eval_arith(
              @symcore.function("Sum", [
                eval_arith(
                  @symcore.mul([
                    @symcore.function("exp", [eval_arith(@symcore.mul([t, k]))]),
                    pmf,
                  ]),
                ),
                @symcore.function("Tuple", [k, lower, upper]),
              ]),
            ),
          )
        None => None
      }
    }
    None => None
  }
}

///|
fn symbolic_joint_mgf_via_integral(
  name : String,
  params : Array[@symcore.Expr],
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match @symcore.tuple_items(t) {
    Some(ts) if !ts.is_empty() => {
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<ts.length() {
        vars.push(Symbol("_x\{i + 1}"))
      }
      let kind = symbolic_kind_from_name(name)
      let rv = random_var("_X", Symbolic(kind~, params~))
      let point = @symcore.function("Tuple", vars)
      let dens = density(rv, point)
      let linear_terms : Array[@symcore.Expr] = Array::new()
      for i in 0..<ts.length() {
        linear_terms.push(eval_arith(@symcore.mul([ts[i], vars[i]])))
      }
      let lin = if linear_terms.is_empty() {
        @symcore.int(0)
      } else {
        eval_arith(@symcore.add(linear_terms))
      }
      let lower = eval_arith(
        @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
      )
      let upper = @symcore.Expr::NumberSymbol(Infinity)
      let mut expr = eval_arith(
        @symcore.mul([@symcore.function("exp", [lin]), dens]),
      )
      for v in vars {
        expr = eval_arith(
          @symcore.function("Integral", [
            expr,
            @symcore.function("Tuple", [v, lower, upper]),
          ]),
        )
      }
      Some(expr)
    }
    _ => None
  }
}

///|
fn symbolic_joint_mgf_special(
  name : String,
  params : Array[@symcore.Expr],
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_kind_from_name(name) {
    Discrete(Multinomial) if params.length() >= 2 =>
      match @symcore.tuple_items(t) {
        Some(ts) if ts.length() == params.length() - 1 => {
          let n = params[0]
          let terms : Array[@symcore.Expr] = Array::new()
          for i in 0..<ts.length() {
            terms.push(
              eval_arith(
                @symcore.mul([params[i + 1], @symcore.function("exp", [ts[i]])]),
              ),
            )
          }
          Some(eval_arith(@symcore.pow(eval_arith(@symcore.add(terms)), n)))
        }
        _ => None
      }
    Discrete(NegativeMultinomial) if params.length() >= 2 =>
      match @symcore.tuple_items(t) {
        Some(ts) if ts.length() == params.length() - 1 => {
          let k0 = params[0]
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
          let denom_terms : Array[@symcore.Expr] = Array::new()
          for i in 0..<ts.length() {
            denom_terms.push(
              eval_arith(
                @symcore.mul([params[i + 1], @symcore.function("exp", [ts[i]])]),
              ),
            )
          }
          let denom = eval_arith(
            @symcore.add([
              @symcore.int(1),
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(@symcore.add(denom_terms)),
              ]),
            ]),
          )
          Some(
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([q, @symcore.pow(denom, @symcore.int(-1))]),
                ),
                k0,
              ),
            ),
          )
        }
        _ => None
      }
    Joint(NormalGamma) if params.length() == 4 =>
      match compat_tuple2(t) {
        Some((t1, t2)) => {
          let mu = params[0]
          let lamda = params[1]
          let alpha = params[2]
          let beta = params[3]
          let inner = eval_arith(
            @symcore.add([
              beta,
              @symcore.mul([@symcore.int(-1), t2]),
              @symcore.mul([
                stats_exact_rational(-1, 2),
                @symcore.pow(lamda, @symcore.int(-1)),
                @symcore.pow(t1, @symcore.int(2)),
              ]),
            ]),
          )
          Some(
            eval_arith(
              @symcore.mul([
                @symcore.function("exp", [eval_arith(@symcore.mul([mu, t1]))]),
                @symcore.pow(
                  eval_arith(
                    @symcore.mul([beta, @symcore.pow(inner, @symcore.int(-1))]),
                  ),
                  alpha,
                ),
              ]),
            ),
          )
        }
        _ => None
      }
    Joint(Dirichlet | MultivariateBeta | MultivariateT) =>
      symbolic_joint_mgf_via_integral(name, params, t)
    _ => None
  }
}

///|
fn symbolic_discrete_entropy_bounds(
  name : String,
  params : Array[@symcore.Expr],
) -> (@symcore.Expr, @symcore.Expr) {
  match discrete_tag_from_name(name) {
    BetaBinomial if params.length() == 3 => (@symcore.int(0), params[0])
    Hypergeometric if params.length() == 3 => (@symcore.int(0), params[2])
    IdealSoliton if params.length() == 1 => (@symcore.int(1), params[0])
    RobustSoliton if params.length() == 3 => (@symcore.int(1), params[0])
    Logarithmic | YuleSimon | Zeta => (@symcore.int(1), NumberSymbol(Infinity))
    Skellam =>
      (
        eval_arith(@symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)])),
        NumberSymbol(Infinity),
      )
    _ =>
      (
        eval_arith(@symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)])),
        NumberSymbol(Infinity),
      )
  }
}

///|
fn symbolic_discrete_entropy_via_sum(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  let k = @symcore.Expr::Symbol("_k")
  let rv = symbolic_rv("_X", name, params)
  match discrete_pmf(rv, k) {
    Some(pmf) => {
      let (lower, upper) = symbolic_discrete_entropy_bounds(name, params)
      Some(
        eval_arith(
          @symcore.function("Sum", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                pmf,
                @symcore.function("log", [pmf]),
              ]),
            ),
            @symcore.function("Tuple", [k, lower, upper]),
          ]),
        ),
      )
    }
    None => None
  }
}

///|
fn symbolic_continuous_entropy_via_integral(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  let x = @symcore.Expr::Symbol("_x")
  let rv = symbolic_rv("_X", name, params)
  match continuous_density(rv, x) {
    Some(pdf) => {
      let lower = eval_arith(
        @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
      )
      let upper = @symcore.Expr::NumberSymbol(Infinity)
      Some(
        eval_arith(
          @symcore.function("Integral", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                pdf,
                @symcore.function("log", [pdf]),
              ]),
            ),
            @symcore.function("Tuple", [x, lower, upper]),
          ]),
        ),
      )
    }
    None => None
  }
}

///|
fn symbolic_joint_entropy_arity(
  name : String,
  params : Array[@symcore.Expr],
) -> Int? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) if !vars.is_empty() => return Some(vars.length())
    _ => ()
  }
  match symbolic_kind_from_name(name) {
    Joint(Dirichlet | MultivariateBeta) if params.length() >= 2 =>
      Some(params.length())
    Discrete(Multinomial | NegativeMultinomial) if params.length() >= 2 =>
      Some(params.length() - 1)
    Joint(NormalGamma) if params.length() == 4 => Some(2)
    Joint(MultivariateNormal | MultivariateLaplace | MultivariateT) if params.length() >=
      1 =>
      match @symcore.tuple_items(params[0]) {
        Some(xs) if !xs.is_empty() => Some(xs.length())
        _ => None
      }
    _ => None
  }
}

///|
fn symbolic_joint_entropy_via_sum(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_joint_entropy_arity(name, params) {
    Some(arity) if arity > 0 => {
      match symbolic_kind_from_name(name) {
        Discrete(Multinomial | NegativeMultinomial) => ()
        _ => return None
      }
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<arity {
        vars.push(Symbol("_k\{i + 1}"))
      }
      let point = @symcore.function("Tuple", vars)
      let rv = symbolic_rv("_X", name, params)
      let pmf = density(rv, point)
      let mut expr = eval_arith(
        @symcore.mul([@symcore.int(-1), pmf, @symcore.function("log", [pmf])]),
      )
      let upper = match symbolic_kind_from_name(name) {
        Discrete(Multinomial) => params[0]
        _ => NumberSymbol(Infinity)
      }
      for v in vars {
        expr = eval_arith(
          @symcore.function("Sum", [
            expr,
            @symcore.function("Tuple", [v, @symcore.int(0), upper]),
          ]),
        )
      }
      Some(expr)
    }
    _ => None
  }
}

///|
fn symbolic_joint_entropy_via_integral(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match symbolic_joint_entropy_arity(name, params) {
    Some(arity) if arity > 0 => {
      match symbolic_kind_from_name(name) {
        Discrete(Multinomial | NegativeMultinomial) => return None
        _ => ()
      }
      let vars : Array[@symcore.Expr] = Array::new()
      for i in 0..<arity {
        vars.push(Symbol("_x\{i + 1}"))
      }
      let point = @symcore.function("Tuple", vars)
      let rv = symbolic_rv("_X", name, params)
      let dens = density(rv, point)
      let lower = eval_arith(
        @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
      )
      let upper = @symcore.Expr::NumberSymbol(Infinity)
      let mut expr = eval_arith(
        @symcore.mul([@symcore.int(-1), dens, @symcore.function("log", [dens])]),
      )
      for v in vars {
        expr = eval_arith(
          @symcore.function("Integral", [
            expr,
            @symcore.function("Tuple", [v, lower, upper]),
          ]),
        )
      }
      Some(expr)
    }
    _ => None
  }
}

///|
fn symbolic_process_entropy(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match process_tag_from_name(name) {
    BernoulliProcess if params.length() >= 1 => {
      let p = params[0]
      let one_minus_p = eval_arith(
        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])]),
      )
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([@symcore.int(-1), p, @symcore.function("log", [p])]),
            ),
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                one_minus_p,
                @symcore.function("log", [one_minus_p]),
              ]),
            ),
          ]),
        ),
      )
    }
    GammaProcess if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.Expr::Symbol("t")
      let shape = eval_arith(@symcore.mul([gamma, t]))
      Some(
        eval_arith(
          @symcore.add([
            shape,
            @symcore.function("log", [
              eval_arith(
                @symcore.mul([
                  @symcore.function("gamma", [shape]),
                  @symcore.pow(lamda, @symcore.int(-1)),
                ]),
              ),
            ]),
            @symcore.mul([
              @symcore.add([
                @symcore.int(1),
                @symcore.mul([@symcore.int(-1), shape]),
              ]),
              @symcore.function("digamma", [shape]),
            ]),
          ]),
        ),
      )
    }
    _ => None
  }
}

///|
fn symbolic_matrix_entropy_expectation(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
) -> @symcore.Expr? {
  let rv = symbolic_rv(rv_name, name, params)
  let x = @symcore.Expr::Symbol(rv_name)
  match matrix_density(rv, x) {
    Some(pdf) =>
      Some(
        @symcore.function("Expectation", [
          eval_arith(
            @symcore.mul([@symcore.int(-1), @symcore.function("log", [pdf])]),
          ),
        ]),
      )
    None => None
  }
}

///|
fn symbolic_opaque_entropy(
  name : String,
  params : Array[@symcore.Expr],
  rv_name : String,
) -> @symcore.Expr? {
  match symbolic_kind_from_name(name) {
    Continuous(ContinuousRV | ContinuousDistributionHandmade) =>
      if params.length() >= 1 {
        let rv = symbolic_rv(rv_name, name, params)
        let x = @symcore.Expr::Symbol("_x")
        let pdf = density(rv, x)
        Some(
          eval_arith(
            @symcore.function("Integral", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  pdf,
                  @symcore.function("log", [pdf]),
                ]),
              ),
              @symcore.function("Tuple", [
                x,
                eval_arith(
                  @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
                ),
                NumberSymbol(Infinity),
              ]),
            ]),
          ),
        )
      } else {
        None
      }
    Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      if params.length() >= 1 {
        let rv = symbolic_rv(rv_name, name, params)
        let k = @symcore.Expr::Symbol("_k")
        let pmf = density(rv, k)
        Some(
          eval_arith(
            @symcore.function("Sum", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  pmf,
                  @symcore.function("log", [pmf]),
                ]),
              ),
              @symcore.function("Tuple", [
                k,
                eval_arith(
                  @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
                ),
                NumberSymbol(Infinity),
              ]),
            ]),
          ),
        )
      } else {
        None
      }
    Discrete(FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for pair in pairs {
            let (_, prob) = pair
            if @symcore.compare_expr(prob, @symcore.int(0)) != 0 {
              terms.push(
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    prob,
                    @symcore.function("log", [prob]),
                  ]),
                ),
              )
            }
          }
          Some(eval_arith(@symcore.add(terms)))
        }
        None => None
      }
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
    ) => symbolic_joint_entropy_via_integral(name, params)
    Joint(MultivariateEwens) =>
      if params.length() != 2 {
        None
      } else {
        match expr_as_int(params[0]) {
          Some(n) if params.length() == 2 => {
            let vars : Array[@symcore.Expr] = Array::new()
            for i in 0..<n {
              vars.push(Symbol("_k\{i + 1}"))
            }
            let rv = symbolic_rv(rv_name, name, params)
            let point = @symcore.function("Tuple", vars)
            let pmf = density(rv, point)
            let mut expr = eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                pmf,
                @symcore.function("log", [pmf]),
              ]),
            )
            for i in 0..<n {
              expr = eval_arith(
                @symcore.function("Sum", [
                  expr,
                  @symcore.function("Tuple", [
                    vars[i],
                    @symcore.int(0),
                    @symcore.int(n / (i + 1)),
                  ]),
                ]),
              )
            }
            Some(expr)
          }
          _ => None
        }
      }
    Matrix(
      GaussianEnsemble
      | GaussianOrthogonalEnsemble
      | GaussianUnitaryEnsemble
      | GaussianSymplecticEnsemble
      | CircularEnsemble
      | CircularUnitaryEnsemble
      | CircularOrthogonalEnsemble
      | CircularSymplecticEnsemble
      | MatrixGamma
      | MatrixStudentT
    ) => symbolic_matrix_entropy_expectation(name, params, rv_name)
    _ => None
  }
}

///|
fn quantile_unit_interval_guard(
  q : @symcore.Expr,
  value : @symcore.Expr,
) -> @symcore.Expr {
  compat_piecewise2(
    value,
    @symcore.function("And", [
      @symcore.function("Ge", [q, @symcore.int(0)]),
      @symcore.function("Le", [q, @symcore.int(1)]),
    ]),
    NumberSymbol(NaN),
  )
}

///|
fn symbolic_quantile_via_conditionset(
  name : String,
  params : Array[@symcore.Expr],
  q : @symcore.Expr,
) -> @symcore.Expr {
  let x = @symcore.Expr::Symbol("_x")
  let rv = symbolic_rv("_Q", name, params)
  let c = cdf(rv, x)
  let domain = match symbolic_kind_from_name(name) {
    Discrete(_) => @symcore.Expr::Symbol("Integers")
    _ =>
      @symcore.function("Interval", [
        eval_arith(@symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)])),
        NumberSymbol(Infinity),
      ])
  }
  quantile_unit_interval_guard(
    q,
    @symcore.function("ConditionSet", [
      x,
      @symcore.function("Eq", [c, q]),
      domain,
    ]),
  )
}

///|
fn symbolic_joint_quantile_via_conditionset(
  name : String,
  params : Array[@symcore.Expr],
  q : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_joint_integration_vars(name, params) {
    Some(vars) if !vars.is_empty() => {
      let rv = symbolic_rv("_Q", name, params)
      let point = @symcore.function("Tuple", vars)
      let c = cdf(rv, point)
      let base_domain = match symbolic_kind_from_name(name) {
        Joint(MultivariateEwens) => @symcore.Expr::Symbol("Integers")
        _ =>
          @symcore.function("Interval", [
            eval_arith(@symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)])),
            NumberSymbol(Infinity),
          ])
      }
      let domain_args : Array[@symcore.Expr] = Array::new()
      for _ in 0..<vars.length() {
        domain_args.push(base_domain)
      }
      let domain = if domain_args.length() == 1 {
        domain_args[0]
      } else {
        @symcore.function("ProductSet", domain_args)
      }
      Some(
        quantile_unit_interval_guard(
          q,
          @symcore.function("ConditionSet", [
            point,
            @symcore.function("Eq", [c, q]),
            domain,
          ]),
        ),
      )
    }
    _ => None
  }
}

///|
fn symbolic_opaque_quantile(
  name : String,
  params : Array[@symcore.Expr],
  q : @symcore.Expr,
) -> @symcore.Expr? {
  match symbolic_kind_from_name(name) {
    Joint(
      JointRV
      | GeneralizedMultivariateLogGamma
      | GeneralizedMultivariateLogGammaOmega
      | MultivariateEwens
    ) => symbolic_joint_quantile_via_conditionset(name, params, q)
    Continuous(ContinuousRV | ContinuousDistributionHandmade)
    | Discrete(DiscreteRV | DiscreteDistributionHandmade) =>
      Some(symbolic_quantile_via_conditionset(name, params, q))
    Discrete(FiniteDistributionHandmade) =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) if !pairs.is_empty() => {
          let sorted_pairs = pairs
          sorted_pairs.sort_by((a, b) => @symcore.compare_expr(a.0, b.0))
          let piecewise_args : Array[@symcore.Expr] = Array::new()
          let mut acc = @symcore.int(0)
          let mut last_value = sorted_pairs[0].0
          for pair in sorted_pairs {
            let (value, prob) = pair
            last_value = value
            acc = eval_arith(@symcore.add([acc, prob]))
            piecewise_args.push(
              Tuple([value, @symcore.function("Le", [q, acc])]),
            )
          }
          piecewise_args.push(Tuple([last_value, Boolean(true)]))
          Some(
            quantile_unit_interval_guard(
              q,
              @symcore.function("Piecewise", piecewise_args),
            ),
          )
        }
        _ => None
      }
    Process(BernoulliProcess) if params.length() >= 1 => {
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
      let lower = @symcore.function("Min", [success, failure])
      let upper = @symcore.function("Max", [success, failure])
      let p_low = @symcore.function("Piecewise", [
        Tuple([p, @symcore.function("Lt", [success, failure])]),
        Tuple([
          eval_arith(
            @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])]),
          ),
          Boolean(true),
        ]),
      ])
      Some(
        @symcore.function("Piecewise", [
          Tuple([
            NumberSymbol(NaN),
            @symcore.function("Or", [
              @symcore.function("Lt", [q, @symcore.int(0)]),
              @symcore.function("Gt", [q, @symcore.int(1)]),
            ]),
          ]),
          Tuple([lower, @symcore.function("Le", [q, p_low])]),
          Tuple([upper, Boolean(true)]),
        ]),
      )
    }
    Process(GammaProcess) if params.length() >= 2 => {
      let lamda = params[0]
      let gamma = params[1]
      let t = @symcore.Expr::Symbol("t")
      let shape = eval_arith(@symcore.mul([gamma, t]))
      Some(
        quantile_unit_interval_guard(
          q,
          eval_arith(
            @symcore.mul([
              @symcore.function("gammaincinv", [shape, q]),
              @symcore.pow(lamda, @symcore.int(-1)),
            ]),
          ),
        ),
      )
    }
    Matrix(
      GaussianEnsemble
      | GaussianOrthogonalEnsemble
      | GaussianUnitaryEnsemble
      | GaussianSymplecticEnsemble
      | CircularEnsemble
      | CircularUnitaryEnsemble
      | CircularOrthogonalEnsemble
      | CircularSymplecticEnsemble
      | MatrixGamma
      | MatrixStudentT
    ) => Some(symbolic_quantile_via_conditionset(name, params, q))
    _ => None
  }
}

///|
fn mgf_of_rv(rv : RandomVar, t : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    Finite(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for item in items {
        let (value, p) = item
        terms.push(
          eval_arith(
            @symcore.mul([
              expr_from_big_rational(p),
              @symcore.function("exp", [eval_arith(@symcore.mul([t, value]))]),
            ]),
          ),
        )
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    Binomial(n~, p~) => {
      let inside = eval_arith(
        @symcore.add([
          @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])]),
          @symcore.mul([p, @symcore.function("exp", [t])]),
        ]),
      )
      Some(eval_arith(@symcore.pow(inside, n)))
    }
    Poisson(rate~) => {
      let inner = eval_arith(
        @symcore.add([@symcore.function("exp", [t]), @symcore.int(-1)]),
      )
      Some(
        eval_arith(
          @symcore.function("exp", [eval_arith(@symcore.mul([rate, inner]))]),
        ),
      )
    }
    Geometric(p~) => {
      let et = @symcore.function("exp", [t])
      let numer = eval_arith(@symcore.mul([p, et]))
      let denom = eval_arith(
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([
            @symcore.int(-1),
            @symcore.mul([
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), p]),
                ]),
              ),
              et,
            ]),
          ]),
        ]),
      )
      Some(
        eval_arith(@symcore.mul([numer, @symcore.pow(denom, @symcore.int(-1))])),
      )
    }
    NegativeBinomial(r~, p~) => {
      let et = @symcore.function("exp", [t])
      let denom = eval_arith(
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([
            @symcore.int(-1),
            @symcore.mul([
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), p]),
                ]),
              ),
              et,
            ]),
          ]),
        ]),
      )
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(@symcore.mul([p, @symcore.pow(denom, @symcore.int(-1))])),
            r,
          ),
        ),
      )
    }
    Normal(mu~, sigma~) => {
      let t2 = @symcore.pow(t, @symcore.int(2))
      let quad = eval_arith(
        @symcore.mul([
          @symcore.int(1),
          @symcore.pow(@symcore.int(2), @symcore.int(-1)),
          @symcore.pow(sigma, @symcore.int(2)),
          t2,
        ]),
      )
      Some(
        eval_arith(
          @symcore.function("exp", [
            eval_arith(@symcore.add([eval_arith(@symcore.mul([mu, t])), quad])),
          ]),
        ),
      )
    }
    Exponential(rate~) => {
      let denom = eval_arith(
        @symcore.add([rate, @symcore.mul([@symcore.int(-1), t])]),
      )
      Some(
        eval_arith(@symcore.mul([rate, @symcore.pow(denom, @symcore.int(-1))])),
      )
    }
    Gamma(shape~, scale~) => {
      let inner = eval_arith(
        @symcore.add([
          @symcore.int(1),
          @symcore.mul([@symcore.int(-1), @symcore.mul([scale, t])]),
        ]),
      )
      Some(
        eval_arith(@symcore.pow(inner, @symcore.mul([@symcore.int(-1), shape]))),
      )
    }
    StochasticProcess(PoissonProcess(rate~, ..)) => {
      let inner = eval_arith(
        @symcore.add([@symcore.function("exp", [t]), @symcore.int(-1)]),
      )
      Some(
        eval_arith(
          @symcore.function("exp", [eval_arith(@symcore.mul([rate, inner]))]),
        ),
      )
    }
    StochasticProcess(WienerProcess(..)) =>
      Some(
        eval_arith(
          @symcore.function("exp", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                @symcore.pow(t, @symcore.int(2)),
              ]),
            ),
          ]),
        ),
      )
    Symbolic(kind~, params~) => {
      let name = symbolic_kind_name(kind)
      if compat_use_generic_unevaluated(name) {
        return match symbolic_opaque_mgf(name, params, rv.name, t) {
          Some(v) => Some(v)
          None =>
            Some(
              @symcore.function("moment_generating_function", [
                Symbol(rv.name),
                t,
              ]),
            )
        }
      }
      match generated_mgf(name, params, t) {
        Some(v) => Some(v)
        None =>
          match kind {
            Joint(MultivariateNormal) if params.length() >= 2 =>
              match
                (
                  compat_tuple2(params[0]),
                  compat_matrix2x2(params[1]),
                  compat_tuple2(t),
                ) {
                (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                  let half = stats_exact_rational(1, 2)
                  let lin = compat_dot2(t1, t2, mu1, mu2)
                  let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                  Some(
                    eval_arith(
                      @symcore.function("exp", [
                        eval_arith(
                          @symcore.add([
                            lin,
                            eval_arith(@symcore.mul([half, quad])),
                          ]),
                        ),
                      ]),
                    ),
                  )
                }
                _ => Some(symbolic_metric_with_head(name, "MGF", t, params))
              }
            Joint(MultivariateLaplace) if params.length() >= 2 =>
              match
                (
                  compat_tuple2(params[0]),
                  compat_matrix2x2(params[1]),
                  compat_tuple2(t),
                ) {
                (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                  let half = stats_exact_rational(1, 2)
                  let lin = compat_dot2(t1, t2, mu1, mu2)
                  let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                  let denom = eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(@symcore.mul([half, quad])),
                      ]),
                    ]),
                  )
                  Some(
                    eval_arith(
                      @symcore.mul([
                        @symcore.function("exp", [lin]),
                        @symcore.pow(denom, @symcore.int(-1)),
                      ]),
                    ),
                  )
                }
                _ => Some(symbolic_metric_with_head(name, "MGF", t, params))
              }
            Continuous(Uniform) if params.length() == 2 => {
              let a = params[0]
              let b = params[1]
              let numer = eval_arith(
                @symcore.add([
                  @symcore.function("exp", [eval_arith(@symcore.mul([t, b]))]),
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("exp", [eval_arith(@symcore.mul([t, a]))]),
                  ]),
                ]),
              )
              let denom = eval_arith(
                @symcore.mul([
                  t,
                  eval_arith(
                    @symcore.add([b, @symcore.mul([@symcore.int(-1), a])]),
                  ),
                ]),
              )
              Some(
                eval_arith(
                  @symcore.mul([numer, @symcore.pow(denom, @symcore.int(-1))]),
                ),
              )
            }
            Continuous(Laplace) if params.length() == 2 => {
              let mu = params[0]
              let b = params[1]
              let num = @symcore.function("exp", [
                eval_arith(@symcore.mul([mu, t])),
              ])
              let den = eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.mul([
                      @symcore.pow(b, @symcore.int(2)),
                      @symcore.pow(t, @symcore.int(2)),
                    ]),
                  ]),
                ]),
              )
              Some(
                eval_arith(
                  @symcore.mul([num, @symcore.pow(den, @symcore.int(-1))]),
                ),
              )
            }
            Continuous(LogNormal) if params.length() == 2 =>
              // LogNormal has no elementary closed form MGF.
              Some(symbolic_metric_with_head(name, "MGF", t, params))
            _ =>
              match symbolic_opaque_mgf(name, params, rv.name, t) {
                Some(v) => Some(v)
                None =>
                  match symbolic_joint_mgf_special(name, params, t) {
                    Some(v) => Some(v)
                    None =>
                      match symbolic_discrete_mgf_via_sum(name, params, t) {
                        Some(v) => Some(v)
                        None =>
                          match
                            symbolic_continuous_mgf_via_integral(
                              name, params, t,
                            ) {
                            Some(v) => Some(v)
                            None =>
                              Some(
                                symbolic_metric_with_head(
                                  name, "MGF", t, params,
                                ),
                              )
                          }
                      }
                  }
              }
          }
      }
    }
    _ => None
  }
}

///|
pub fn characteristic_function(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.length() == 1 {
    match resolve_process_time(expr, rvs[0]) {
      Some(time) =>
        match process_cf_at(rvs[0], time, t) {
          Some(v) => return v
          None => ()
        }
      None => ()
    }
  }
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match rv.kind {
        Symbolic(kind~, params~) => {
          let name = symbolic_kind_name(kind)
          if compat_use_generic_unevaluated(name) {
            return match symbolic_opaque_cf(name, params, rv.name, t) {
              Some(v) => v
              None =>
                @symcore.function("characteristic_function", [
                  Symbol(rv.name),
                  t,
                ])
            }
          }
          let special = match kind {
            Continuous(Cauchy) if params.length() == 2 =>
              Some(
                eval_arith(
                  @symcore.function("exp", [
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            NumberSymbol(ImaginaryUnit),
                            params[0],
                            t,
                          ]),
                        ),
                        @symcore.mul([
                          @symcore.int(-1),
                          params[1],
                          @symcore.function("Abs", [t]),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              )
            Continuous(StudentT) if params.length() == 1 => {
              let nu = params[0]
              let half = stats_exact_rational(1, 2)
              let nu_half = eval_arith(@symcore.mul([half, nu]))
              let arg = eval_arith(
                @symcore.mul([
                  @symcore.function("sqrt", [nu]),
                  @symcore.function("Abs", [t]),
                ]),
              )
              let core = eval_arith(
                @symcore.mul([
                  @symcore.pow(
                    @symcore.int(2),
                    eval_arith(
                      @symcore.add([
                        @symcore.int(1),
                        @symcore.mul([@symcore.int(-1), nu_half]),
                      ]),
                    ),
                  ),
                  @symcore.pow(arg, nu_half),
                  @symcore.function("besselk", [nu_half, arg]),
                  @symcore.pow(
                    @symcore.function("gamma", [nu_half]),
                    @symcore.int(-1),
                  ),
                ]),
              )
              Some(
                @symcore.function("Piecewise", [
                  Tuple([
                    @symcore.int(1),
                    @symcore.function("Eq", [t, @symcore.int(0)]),
                  ]),
                  Tuple([core, Boolean(true)]),
                ]),
              )
            }
            Joint(MultivariateNormal) if params.length() >= 2 =>
              match
                (
                  compat_tuple2(params[0]),
                  compat_matrix2x2(params[1]),
                  compat_tuple2(t),
                ) {
                (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                  let half = stats_exact_rational(1, 2)
                  let lin = compat_dot2(t1, t2, mu1, mu2)
                  let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                  Some(
                    eval_arith(
                      @symcore.function("exp", [
                        eval_arith(
                          @symcore.add([
                            eval_arith(
                              @symcore.mul([NumberSymbol(ImaginaryUnit), lin]),
                            ),
                            @symcore.mul([@symcore.int(-1), half, quad]),
                          ]),
                        ),
                      ]),
                    ),
                  )
                }
                _ => None
              }
            Joint(MultivariateLaplace) if params.length() >= 2 =>
              match
                (
                  compat_tuple2(params[0]),
                  compat_matrix2x2(params[1]),
                  compat_tuple2(t),
                ) {
                (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                  let half = stats_exact_rational(1, 2)
                  let lin = compat_dot2(t1, t2, mu1, mu2)
                  let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                  let denom = eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([half, quad])),
                    ]),
                  )
                  Some(
                    eval_arith(
                      @symcore.mul([
                        @symcore.function("exp", [
                          eval_arith(
                            @symcore.mul([NumberSymbol(ImaginaryUnit), lin]),
                          ),
                        ]),
                        @symcore.pow(denom, @symcore.int(-1)),
                      ]),
                    ),
                  )
                }
                _ => None
              }
            _ => None
          }
          match special {
            Some(v) => v
            None =>
              match generated_cf(name, params, t) {
                Some(v) => v
                None =>
                  match
                    mgf_of_rv(
                      rv,
                      eval_arith(@symcore.mul([NumberSymbol(ImaginaryUnit), t])),
                    ) {
                    Some(v) => v
                    None => symbolic_metric_with_head(name, "CF", t, params)
                  }
              }
          }
        }
        _ =>
          match
            mgf_of_rv(
              rv,
              eval_arith(@symcore.mul([NumberSymbol(ImaginaryUnit), t])),
            ) {
            Some(v) => v
            None => @symcore.function("characteristic_function", [expr, t])
          }
      }
    None => @symcore.function("characteristic_function", [expr, t])
  }
}

///|
fn resolve_process_time(expr : @symcore.Expr, rv : RandomVar) -> @symcore.Expr? {
  match @symcore.application_args(expr) {
    Some([arg]) if @symcore.application_has_name(expr, rv.name, arity=1) =>
      Some(arg)
    _ => None
  }
}

///|
fn process_metric_head(
  name : String,
  suffix : String,
  time : @symcore.Expr,
  extras : Array[@symcore.Expr],
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  let value = process_symbolic_value(name, time, params)
  match suffix {
    "MGF" =>
      match extras {
        [t] =>
          @symcore.function("Expectation", [
            @symcore.function("exp", [eval_arith(@symcore.mul([t, value]))]),
          ])
        _ => @symcore.function("Expectation", [value])
      }
    "CF" =>
      match extras {
        [t] =>
          @symcore.function("Expectation", [
            @symcore.function("exp", [
              eval_arith(@symcore.mul([NumberSymbol(ImaginaryUnit), t, value])),
            ]),
          ])
        _ => @symcore.function("Expectation", [value])
      }
    "Entropy" => @symcore.function("Entropy", [value])
    "Quantile" =>
      match extras {
        [q] => {
          let x = @symcore.Expr::Symbol("_x")
          @symcore.function("ConditionSet", [
            x,
            @symcore.function("Eq", [
              @symcore.function("Probability", [
                @symcore.function("Le", [value, x]),
              ]),
              q,
            ]),
            @symcore.function("Interval", [
              eval_arith(
                @symcore.mul([@symcore.int(-1), NumberSymbol(Infinity)]),
              ),
              NumberSymbol(Infinity),
            ]),
          ])
        }
        _ => @symcore.function("ConditionSet", [value])
      }
    _ => {
      ignore(params)
      let args : Array[@symcore.Expr] = [value]
      for extra in extras {
        args.push(extra)
      }
      @symcore.function(suffix, args)
    }
  }
}

///|
fn process_mgf_at(
  rv : RandomVar,
  time : @symcore.Expr,
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match rv.kind {
    StochasticProcess(PoissonProcess(rate~, ..)) => {
      let inner = eval_arith(
        @symcore.add([@symcore.function("exp", [t]), @symcore.int(-1)]),
      )
      Some(
        eval_arith(
          @symcore.function("exp", [
            eval_arith(@symcore.mul([rate, time, inner])),
          ]),
        ),
      )
    }
    StochasticProcess(WienerProcess(..)) =>
      Some(
        eval_arith(
          @symcore.function("exp", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                time,
                @symcore.pow(t, @symcore.int(2)),
              ]),
            ),
          ]),
        ),
      )
    Symbolic(kind~, params~) =>
      match kind {
        Process(tag) => {
          let name = process_tag_name(tag)
          match tag {
            BernoulliProcess if params.length() >= 1 => {
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
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        p,
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([t, success])),
                        ]),
                      ]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), p]),
                          ]),
                        ),
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([t, failure])),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              )
            }
            GammaProcess if params.length() >= 2 => {
              let lamda = params[0]
              let gamma = params[1]
              let inner = eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([
                    @symcore.int(-1),
                    t,
                    @symcore.pow(lamda, @symcore.int(-1)),
                  ]),
                ]),
              )
              Some(
                eval_arith(
                  @symcore.pow(
                    inner,
                    eval_arith(@symcore.mul([@symcore.int(-1), gamma, time])),
                  ),
                ),
              )
            }
            _ => Some(process_metric_head(name, "MGF", time, [t], params))
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn process_cf_at(
  rv : RandomVar,
  time : @symcore.Expr,
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match rv.kind {
    Symbolic(kind~, params~) =>
      match kind {
        Process(tag) =>
          match tag {
            BernoulliProcess | GammaProcess => ()
            _ =>
              return Some(
                process_metric_head(
                  process_tag_name(tag),
                  "CF",
                  time,
                  [t],
                  params,
                ),
              )
          }
        _ => ()
      }
    _ => ()
  }
  match
    process_mgf_at(
      rv,
      time,
      eval_arith(@symcore.mul([NumberSymbol(ImaginaryUnit), t])),
    ) {
    Some(v) =>
      match rv.kind {
        StochasticProcess(WienerProcess(..)) =>
          Some(
            eval_arith(
              @symcore.function("exp", [
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(-1, 2),
                    time,
                    @symcore.pow(t, @symcore.int(2)),
                  ]),
                ),
              ]),
            ),
          )
        _ => Some(v)
      }
    None => None
  }
}

///|
fn process_entropy_at(rv : RandomVar, time : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    StochasticProcess(PoissonProcess(rate~, ..)) => {
      let k = @symcore.Expr::Symbol("_k")
      let mean = eval_arith(@symcore.mul([rate, time]))
      let pmf = poisson_pmf_expr(mean, k)
      Some(
        eval_arith(
          @symcore.function("Sum", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                pmf,
                @symcore.function("log", [pmf]),
              ]),
            ),
            @symcore.function("Tuple", [
              k,
              @symcore.int(0),
              NumberSymbol(Infinity),
            ]),
          ]),
        ),
      )
    }
    StochasticProcess(WienerProcess(..)) =>
      Some(
        eval_arith(
          @symcore.function("log", [
            eval_arith(
              @symcore.function("sqrt", [
                eval_arith(
                  @symcore.mul([
                    @symcore.int(2),
                    NumberSymbol(Pi),
                    NumberSymbol(Exp1),
                    time,
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    Symbolic(kind~, params~) =>
      match kind {
        Process(tag) => {
          let name = process_tag_name(tag)
          match tag {
            BernoulliProcess if params.length() >= 1 => {
              let p = params[0]
              let one_minus_p = eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), p]),
                ]),
              )
              Some(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        p,
                        @symcore.function("log", [p]),
                      ]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        one_minus_p,
                        @symcore.function("log", [one_minus_p]),
                      ]),
                    ),
                  ]),
                ),
              )
            }
            GammaProcess if params.length() >= 2 => {
              let lamda = params[0]
              let gamma = params[1]
              let shape = eval_arith(@symcore.mul([gamma, time]))
              Some(
                eval_arith(
                  @symcore.add([
                    shape,
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.function("gamma", [shape]),
                          @symcore.pow(lamda, @symcore.int(-1)),
                        ]),
                      ),
                    ]),
                    @symcore.mul([
                      @symcore.add([
                        @symcore.int(1),
                        @symcore.mul([@symcore.int(-1), shape]),
                      ]),
                      @symcore.function("digamma", [shape]),
                    ]),
                  ]),
                ),
              )
            }
            _ => Some(process_metric_head(name, "Entropy", time, [], params))
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn process_quantile_at(
  rv : RandomVar,
  time : @symcore.Expr,
  q : @symcore.Expr,
) -> @symcore.Expr? {
  match rv.kind {
    StochasticProcess(PoissonProcess(rate~, ..)) =>
      Some(process_metric_head("PoissonProcess", "Quantile", time, [q], [rate]))
    StochasticProcess(WienerProcess(..)) =>
      Some(
        quantile_unit_interval_guard(
          q,
          eval_arith(
            @symcore.mul([
              @symcore.function("sqrt", [
                eval_arith(@symcore.mul([@symcore.int(2), time])),
              ]),
              @symcore.function("erfinv", [
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.mul([@symcore.int(2), q])),
                    @symcore.int(-1),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      )
    Symbolic(kind~, params~) =>
      match kind {
        Process(tag) => {
          let name = process_tag_name(tag)
          match tag {
            BernoulliProcess if params.length() >= 1 =>
              symbolic_opaque_quantile(name, params, q)
            GammaProcess if params.length() >= 2 => {
              let lamda = params[0]
              let gamma = params[1]
              let shape = eval_arith(@symcore.mul([gamma, time]))
              Some(
                quantile_unit_interval_guard(
                  q,
                  eval_arith(
                    @symcore.mul([
                      @symcore.function("gammaincinv", [shape, q]),
                      @symcore.pow(lamda, @symcore.int(-1)),
                    ]),
                  ),
                ),
              )
            }
            _ => Some(process_metric_head(name, "Quantile", time, [q], params))
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
pub fn pspace(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("pspace", [expr])
}

///|
pub fn skewness(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  let c3 = central_moment(expr, 3, rvs~)
  let s = std(expr, rvs~)
  eval_arith(@symcore.mul([c3, @symcore.pow(s, @symcore.int(-3))]))
}

///|
pub fn kurtosis(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  let c4 = central_moment(expr, 4, rvs~)
  let v = variance(expr, rvs~)
  eval_arith(@symcore.mul([c4, @symcore.pow(v, @symcore.int(-2))]))
}

///|
pub fn entropy(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.length() == 1 {
    match resolve_process_time(expr, rvs[0]) {
      Some(time) =>
        match process_entropy_at(rvs[0], time) {
          Some(v) => return v
          None => ()
        }
      None => ()
    }
  }
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match rv.kind {
        Finite(items) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for item in items {
            let (_, p) = item
            let pe = expr_from_big_rational(p)
            if @symcore.compare_expr(pe, @symcore.int(0)) != 0 {
              terms.push(
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    pe,
                    @symcore.function("log", [pe]),
                  ]),
                ),
              )
            }
          }
          eval_arith(@symcore.add(terms))
        }
        Normal(mu~, sigma~) => {
          ignore(mu)
          eval_arith(
            @symcore.function("log", [
              eval_arith(
                @symcore.mul([
                  sigma,
                  @symcore.function("sqrt", [
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(2),
                        NumberSymbol(Pi),
                        NumberSymbol(Exp1),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          )
        }
        Exponential(rate~) =>
          eval_arith(
            @symcore.add([
              @symcore.int(1),
              @symcore.mul([@symcore.int(-1), @symcore.function("log", [rate])]),
            ]),
          )
        Gamma(shape~, scale~) =>
          eval_arith(
            @symcore.add([
              shape,
              @symcore.function("log", [
                eval_arith(
                  @symcore.mul([scale, @symcore.function("gamma", [shape])]),
                ),
              ]),
              @symcore.mul([
                @symcore.add([
                  @symcore.int(1),
                  @symcore.mul([@symcore.int(-1), shape]),
                ]),
                @symcore.function("digamma", [shape]),
              ]),
            ]),
          )
        Symbolic(kind~, params~) => {
          let name = symbolic_kind_name(kind)
          if compat_use_generic_unevaluated(name) {
            return match symbolic_opaque_entropy(name, params, rv.name) {
              Some(v) => v
              None => @symcore.function("entropy", [Symbol(rv.name)])
            }
          }
          match generated_entropy(name, params) {
            Some(v) => v
            None =>
              match kind {
                Joint(Dirichlet | MultivariateBeta) if params.length() >= 2 => {
                  let alpha_sum = eval_arith(@symcore.add(params))
                  let log_beta_terms : Array[@symcore.Expr] = Array::new()
                  let sum_terms : Array[@symcore.Expr] = Array::new()
                  for a in params {
                    log_beta_terms.push(
                      @symcore.function("log", [@symcore.function("gamma", [a])]),
                    )
                    sum_terms.push(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.add([a, @symcore.int(-1)])),
                          @symcore.function("digamma", [a]),
                        ]),
                      ),
                    )
                  }
                  let log_beta = eval_arith(
                    @symcore.add([
                      eval_arith(@symcore.add(log_beta_terms)),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [
                          @symcore.function("gamma", [alpha_sum]),
                        ]),
                      ]),
                    ]),
                  )
                  let dim = @symcore.int(params.length())
                  eval_arith(
                    @symcore.add([
                      log_beta,
                      eval_arith(
                        @symcore.mul([
                          eval_arith(
                            @symcore.add([
                              alpha_sum,
                              @symcore.mul([@symcore.int(-1), dim]),
                            ]),
                          ),
                          @symcore.function("digamma", [alpha_sum]),
                        ]),
                      ),
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(@symcore.add(sum_terms)),
                      ]),
                    ]),
                  )
                }
                Joint(MultivariateNormal) if params.length() >= 2 =>
                  match compat_matrix2x2(params[1]) {
                    Some((s00, s01, s10, s11)) => {
                      let half = stats_exact_rational(1, 2)
                      let det = eval_arith(
                        @symcore.add([
                          eval_arith(@symcore.mul([s00, s11])),
                          eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
                        ]),
                      )
                      let base = eval_arith(
                        @symcore.pow(
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(2),
                              NumberSymbol(Pi),
                              NumberSymbol(Exp1),
                            ]),
                          ),
                          @symcore.int(2),
                        ),
                      )
                      eval_arith(
                        @symcore.mul([
                          half,
                          @symcore.function("log", [
                            eval_arith(@symcore.mul([base, det])),
                          ]),
                        ]),
                      )
                    }
                    None =>
                      match symbolic_joint_entropy_via_integral(name, params) {
                        Some(v) => v
                        None => symbolic_metric_no_head(name, "Entropy", params)
                      }
                  }
                Continuous(Uniform) if params.length() == 2 =>
                  eval_arith(
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.add([
                          params[1],
                          @symcore.mul([@symcore.int(-1), params[0]]),
                        ]),
                      ),
                    ]),
                  )
                Continuous(Exponential) if params.length() == 1 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[0]]),
                      ]),
                    ]),
                  )
                Continuous(ChiSquared) if params.length() == 1 => {
                  let half = stats_exact_rational(1, 2)
                  let shape = eval_arith(@symcore.mul([half, params[0]]))
                  eval_arith(
                    @symcore.add([
                      shape,
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(2),
                            @symcore.function("gamma", [shape]),
                          ]),
                        ),
                      ]),
                      @symcore.mul([
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), shape]),
                          ]),
                        ),
                        @symcore.function("digamma", [shape]),
                      ]),
                    ]),
                  )
                }
                Continuous(Chi) if params.length() == 1 => {
                  let half = stats_exact_rational(1, 2)
                  let shape = eval_arith(@symcore.mul([half, params[0]]))
                  eval_arith(
                    @symcore.add([
                      @symcore.function("log", [
                        @symcore.function("gamma", [shape]),
                      ]),
                      shape,
                      @symcore.mul([
                        @symcore.int(-1),
                        half,
                        eval_arith(@symcore.add([params[0], @symcore.int(-1)])),
                        @symcore.function("digamma", [shape]),
                      ]),
                      @symcore.mul([
                        stats_exact_rational(-1, 2),
                        @symcore.function("log", [@symcore.int(2)]),
                      ]),
                    ]),
                  )
                }
                Continuous(Erlang) if params.length() == 2 => {
                  let k = params[0]
                  let lamda = params[1]
                  eval_arith(
                    @symcore.add([
                      k,
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.function("gamma", [k]),
                            @symcore.pow(lamda, @symcore.int(-1)),
                          ]),
                        ),
                      ]),
                      @symcore.mul([
                        @symcore.add([
                          @symcore.int(1),
                          @symcore.mul([@symcore.int(-1), k]),
                        ]),
                        @symcore.function("digamma", [k]),
                      ]),
                    ]),
                  )
                }
                Continuous(Laplace) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.function("log", [
                        eval_arith(@symcore.mul([@symcore.int(2), params[1]])),
                      ]),
                    ]),
                  )
                Continuous(Beta) if params.length() == 2 => {
                  let a = params[0]
                  let b = params[1]
                  eval_arith(
                    @symcore.add([
                      @symcore.function("log", [
                        @symcore.function("beta", [a, b]),
                      ]),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.add([a, @symcore.int(-1)]),
                        @symcore.function("digamma", [a]),
                      ]),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.add([b, @symcore.int(-1)]),
                        @symcore.function("digamma", [b]),
                      ]),
                      @symcore.mul([
                        @symcore.add([a, b, @symcore.int(-2)]),
                        @symcore.function("digamma", [@symcore.add([a, b])]),
                      ]),
                    ]),
                  )
                }
                Continuous(Cauchy) if params.length() == 2 =>
                  eval_arith(
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(4),
                          NumberSymbol(Pi),
                          params[1],
                        ]),
                      ),
                    ]),
                  )
                Continuous(Logistic) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(2),
                      @symcore.function("log", [params[1]]),
                    ]),
                  )
                Continuous(Rayleigh) if params.length() == 1 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([
                        stats_exact_rational(1, 2),
                        NumberSymbol(EulerGamma),
                      ]),
                      @symcore.function("log", [params[0]]),
                      @symcore.mul([
                        stats_exact_rational(-1, 2),
                        @symcore.function("log", [@symcore.int(2)]),
                      ]),
                    ]),
                  )
                Continuous(Weibull) if params.length() == 2 => {
                  let lam = params[0]
                  let k = params[1]
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([lam, @symcore.pow(k, @symcore.int(-1))]),
                        ),
                      ]),
                      @symcore.mul([
                        NumberSymbol(EulerGamma),
                        @symcore.add([
                          @symcore.int(1),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(k, @symcore.int(-1)),
                          ]),
                        ]),
                      ]),
                    ]),
                  )
                }
                Continuous(Gumbel) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      NumberSymbol(EulerGamma),
                      @symcore.function("log", [params[0]]),
                    ]),
                  )
                Continuous(LogNormal) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      params[0],
                      stats_exact_rational(1, 2),
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            params[1],
                            @symcore.function("sqrt", [
                              eval_arith(
                                @symcore.mul([@symcore.int(2), NumberSymbol(Pi)]),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                Continuous(Pareto) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.pow(params[1], @symcore.int(-1)),
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            params[0],
                            @symcore.pow(params[1], @symcore.int(-1)),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                Continuous(Levy) if params.length() == 2 => {
                  let c = params[1]
                  eval_arith(
                    @symcore.add([
                      stats_exact_rational(1, 2),
                      @symcore.mul([
                        stats_exact_rational(3, 2),
                        NumberSymbol(EulerGamma),
                      ]),
                      @symcore.mul([
                        stats_exact_rational(1, 2),
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(16),
                              NumberSymbol(Pi),
                              @symcore.pow(c, @symcore.int(2)),
                            ]),
                          ),
                        ]),
                      ]),
                    ]),
                  )
                }
                Continuous(Gompertz) if params.length() == 2 => {
                  let b = params[0]
                  let eta = params[1]
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [
                          eval_arith(@symcore.mul([b, eta])),
                        ]),
                      ]),
                      @symcore.mul([
                        @symcore.function("exp", [eta]),
                        @symcore.function("Ei", [
                          eval_arith(@symcore.mul([@symcore.int(-1), eta])),
                        ]),
                      ]),
                    ]),
                  )
                }
                Continuous(Lomax) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.pow(params[0], @symcore.int(-1)),
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            params[1],
                            @symcore.pow(params[0], @symcore.int(-1)),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                Continuous(Triangular) if params.length() == 3 =>
                  eval_arith(
                    @symcore.add([
                      stats_exact_rational(1, 2),
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            stats_exact_rational(1, 2),
                            eval_arith(
                              @symcore.add([
                                params[1],
                                @symcore.mul([@symcore.int(-1), params[0]]),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                Continuous(PowerFunction) if params.length() == 3 =>
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.pow(params[0], @symcore.int(-1)),
                      ]),
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            eval_arith(
                              @symcore.add([
                                params[2],
                                @symcore.mul([@symcore.int(-1), params[1]]),
                              ]),
                            ),
                            @symcore.pow(params[0], @symcore.int(-1)),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                Continuous(Arcsin) if params.length() == 0 =>
                  @symcore.function("log", [
                    eval_arith(
                      @symcore.mul([
                        NumberSymbol(Pi),
                        stats_exact_rational(1, 4),
                      ]),
                    ),
                  ])
                Continuous(Arcsin) if params.length() == 2 =>
                  @symcore.function("log", [
                    eval_arith(
                      @symcore.mul([
                        NumberSymbol(Pi),
                        stats_exact_rational(1, 4),
                        eval_arith(
                          @symcore.add([
                            params[1],
                            @symcore.mul([@symcore.int(-1), params[0]]),
                          ]),
                        ),
                      ]),
                    ),
                  ])
                Continuous(StudentT) if params.length() == 1 => {
                  let nu = params[0]
                  let half = stats_exact_rational(1, 2)
                  let nu_half = eval_arith(@symcore.mul([half, nu]))
                  let nu1_half = eval_arith(
                    @symcore.mul([half, @symcore.add([nu, @symcore.int(1)])]),
                  )
                  eval_arith(
                    @symcore.add([
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.function("sqrt", [nu]),
                            @symcore.function("beta", [nu_half, half]),
                          ]),
                        ),
                      ]),
                      @symcore.mul([
                        nu1_half,
                        eval_arith(
                          @symcore.add([
                            @symcore.function("digamma", [nu1_half]),
                            @symcore.mul([
                              @symcore.int(-1),
                              @symcore.function("digamma", [nu_half]),
                            ]),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                }
                Continuous(VonMises) if params.length() == 2 => {
                  let kappa = params[1]
                  let i0 = @symcore.function("besseli", [@symcore.int(0), kappa])
                  let i1 = @symcore.function("besseli", [@symcore.int(1), kappa])
                  eval_arith(
                    @symcore.add([
                      @symcore.function("log", [
                        eval_arith(
                          @symcore.mul([@symcore.int(2), NumberSymbol(Pi), i0]),
                        ),
                      ]),
                      @symcore.mul([
                        @symcore.int(-1),
                        kappa,
                        i1,
                        @symcore.pow(i0, @symcore.int(-1)),
                      ]),
                    ]),
                  )
                }
                Continuous(Trapezoidal) if params.length() == 4 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let d = params[3]
                  let half = stats_exact_rational(1, 2)
                  let span = eval_arith(
                    @symcore.add([
                      d,
                      c,
                      @symcore.mul([@symcore.int(-1), b]),
                      @symcore.mul([@symcore.int(-1), a]),
                    ]),
                  )
                  let edge = eval_arith(
                    @symcore.add([
                      eval_arith(
                        @symcore.add([b, @symcore.mul([@symcore.int(-1), a])]),
                      ),
                      eval_arith(
                        @symcore.add([d, @symcore.mul([@symcore.int(-1), c])]),
                      ),
                    ]),
                  )
                  eval_arith(
                    @symcore.add([
                      @symcore.function("log", [
                        eval_arith(@symcore.mul([half, span])),
                      ]),
                      eval_arith(
                        @symcore.mul([
                          half,
                          edge,
                          @symcore.pow(span, @symcore.int(-1)),
                        ]),
                      ),
                    ]),
                  )
                }
                Continuous(Moyal) if params.length() == 2 =>
                  NumberSymbol(Infinity)
                _ =>
                  match symbolic_process_entropy(name, params) {
                    Some(v) => v
                    None =>
                      match symbolic_joint_entropy_via_sum(name, params) {
                        Some(v) => v
                        None =>
                          match
                            symbolic_discrete_entropy_via_sum(name, params) {
                            Some(v) => v
                            None =>
                              match
                                symbolic_joint_entropy_via_integral(
                                  name, params,
                                ) {
                                Some(v) => v
                                None =>
                                  match
                                    symbolic_continuous_entropy_via_integral(
                                      name, params,
                                    ) {
                                    Some(v) => v
                                    None =>
                                      match
                                        symbolic_matrix_entropy_expectation(
                                          name,
                                          params,
                                          rv.name,
                                        ) {
                                        Some(v) => v
                                        None =>
                                          symbolic_metric_no_head(
                                            name, "Entropy", params,
                                          )
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
        }
        _ => @symcore.function("entropy", [expr])
      }
    None => @symcore.function("entropy", [expr])
  }
}

///|
pub fn dependent(a : RandomVar, b : RandomVar) -> Bool {
  !assume_independent(a, b)
}

///|
pub fn independent(a : RandomVar, b : RandomVar) -> Bool {
  assume_independent(a, b)
}

///|
pub fn probability_space_independent(a : RandomVar, b : RandomVar) -> TriBool {
  if a.name == b.name {
    False
  } else if assume_independent(a, b) {
    True
  } else {
    Unknown
  }
}

///|
pub fn pspace_independent(a : RandomVar, b : RandomVar) -> TriBool {
  probability_space_independent(a, b)
}

///|
fn collect_symbols(expr : @symcore.Expr, out : Map[String, Bool]) -> Unit {
  match expr {
    Symbol(name) => out[name] = true
    _ =>
      for child in @symcore.children(expr) {
        collect_symbols(child, out)
      }
  }
}

///|
pub fn random_symbols(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  collect_symbols(expr, seen)
  let out : Array[String] = Array::new()
  if rvs.is_empty() {
    for key, _ in seen {
      out.push(key)
    }
  } else {
    for rv in rvs {
      if seen.contains(rv.name) {
        out.push(rv.name)
      }
    }
  }
  out.sort()
  out
}

///|
fn expr_mentions_random_var(expr : @symcore.Expr, rv : RandomVar) -> Bool {
  match expr {
    Symbol(name) if name == rv.name => true
    _ if @symcore.application_has_name(expr, rv.name) => true
    _ => {
      for child in @symcore.children(expr) {
        if expr_mentions_random_var(child, rv) {
          return true
        }
      }
      false
    }
  }
}

///|
pub fn is_random(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> Bool {
  for rv in rvs {
    if expr_mentions_random_var(expr, rv) {
      return true
    }
  }
  false
}

///|
pub fn rv_subs(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.length() == 0 {
    return expr
  }
  let env : Map[String, @symcore.Expr] = Map([])
  for rv in rvs {
    env[rv.name] = Symbol(rv.name)
  }
  @symcore.subst(expr, env)
}

///|
pub fn sumsets(sets : Array[Array[@symcore.Expr]]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = []
  for set in sets {
    for item in set {
      let mut seen = false
      for prev in out {
        if prev == item {
          seen = true
          break
        }
      }
      if !seen {
        out.push(item)
      }
    }
  }
  @symcore.sort_exprs_in_place(out)
  out
}

///|
pub fn random_var_symbol_swap(
  lhs : Array[RandomVar],
  rhs : Array[RandomVar],
) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for left in lhs {
    for right in rhs {
      if left.name == right.name {
        out[left.name] = right.name
        break
      }
    }
  }
  out
}

///|
pub fn rs_swap(
  lhs : Array[RandomVar],
  rhs : Array[RandomVar],
) -> Map[String, String] {
  random_var_symbol_swap(lhs, rhs)
}

///|
fn stats_relop_to_core(op : RelOp) -> @symcore.RelOp {
  match op {
    Eq => Eq
    Ne => Ne
    Lt => Lt
    Le => Le
    Gt => Gt
    Ge => Ge
  }
}

///|
fn event_relational_expr(event : Event) -> @symcore.Expr {
  match event {
    Rel(op~, lhs~, rhs~) => Relational(stats_relop_to_core(op), lhs, rhs)
    _ => event_to_expr(event)
  }
}

///|
pub fn reduce_rational_inequalities_wrap(
  condition : Event,
  symbol : @symcore.Expr,
) -> @symsets.Set raise @symsolvers.SolverError {
  match condition {
    Bool(true) => @symsets.reals()
    Bool(false) => @symsets.empty_set()
    Rel(..) =>
      match
        @symsolvers.solve_univariate_inequality(
          event_relational_expr(condition),
          symbol,
          relational=false,
        ) {
        Set(set) => set
        Relational(_) => @symsets.empty_set()
      }
    Or(items) => {
      let parts : Array[@symsets.Set] = []
      for item in items {
        parts.push(reduce_rational_inequalities_wrap(item, symbol))
      }
      @symsets.union(parts)
    }
    And(items) => {
      if items.is_empty() {
        return @symsets.reals()
      }
      let parts : Array[@symsets.Set] = []
      for item in items {
        parts.push(reduce_rational_inequalities_wrap(item, symbol))
      }
      @symsets.intersection(parts)
    }
    Not(inner) =>
      @symsets.complement(
        @symsets.reals(),
        reduce_rational_inequalities_wrap(inner, symbol),
      )
  }
}

///|
pub fn correlation(
  a : @symcore.Expr,
  b : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  let cov = covariance(a, b, rvs~)
  let sa = std(a, rvs~)
  let sb = std(b, rvs~)
  eval_arith(
    @symcore.mul([
      cov,
      @symcore.pow(sa, @symcore.int(-1)),
      @symcore.pow(sb, @symcore.int(-1)),
    ]),
  )
}

///|
pub fn factorial_moment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  let factors : Array[@symcore.Expr] = Array::new()
  for i in 0..<n {
    factors.push(eval_arith(@symcore.add([expr, @symcore.int(-i)])))
  }
  let falling = if factors.is_empty() {
    @symcore.int(1)
  } else {
    eval_arith(@symcore.mul(factors))
  }
  if !rvs.is_empty() {
    expectation(falling, rvs~)
  } else {
    @symcore.function("factorial_moment", [expr, @symcore.int(n)])
  }
}

///|
pub fn cmoment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  central_moment(expr, n, rvs~)
}

///|
pub fn sampling_p(
  condition : Event,
  rvs? : Array[RandomVar] = [],
  numsamples? : Int = 1,
  seed? : Int? = None,
) -> @symcore.Expr {
  if numsamples <= 0 {
    return NumberSymbol(NaN)
  }
  let rng = stats_rng(seed~)
  let mut count_true = 0
  for _ in 0..<numsamples {
    let env = sample_env_with_rng(rvs, rng)
    match env {
      Some(values) =>
        match evaluate_event(condition, values) {
          True => count_true += 1
          False | Unknown => ()
        }
      None => ()
    }
  }
  match stats_exact_big_rational(count_true, numsamples) {
    Some(value) => expr_from_big_rational(value)
    None => NumberSymbol(NaN)
  }
}

///|
pub fn sampling_e(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
  numsamples? : Int = 1,
  seed? : Int? = None,
) -> @symcore.Expr {
  if numsamples <= 0 {
    return NumberSymbol(NaN)
  }
  let samples = sample_iter(expr, n=numsamples, rvs~, seed~)
  if samples.is_empty() {
    return NumberSymbol(NaN)
  }
  let scale = match stats_exact_big_rational(1, samples.length()) {
    Some(value) => expr_from_big_rational(value)
    None => @symcore.int(1)
  }
  eval_arith(@symcore.mul([@symcore.add(samples), scale]))
}

///|
pub fn sampling_density(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
  numsamples? : Int = 1,
  seed? : Int? = None,
) -> @symcore.Expr {
  if numsamples <= 0 {
    return Dict([])
  }
  let samples = sample_iter(expr, n=numsamples, rvs~, seed~)
  let keys : Array[@symcore.Expr] = []
  let counts : Array[Int] = []
  for sample_value in samples {
    let mut found = false
    for i in 0..<keys.length() {
      if @symcore.compare_expr(keys[i], sample_value) == 0 {
        counts[i] = counts[i] + 1
        found = true
        break
      }
    }
    if !found {
      keys.push(sample_value)
      counts.push(1)
    }
  }
  let entries : Array[(@symcore.Expr, @symcore.Expr)] = []
  for i in 0..<keys.length() {
    entries.push((keys[i], @symcore.int(counts[i])))
  }
  Dict(entries)
}

///|
pub fn moment_generating_function(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.length() == 1 {
    match resolve_process_time(expr, rvs[0]) {
      Some(time) =>
        match process_mgf_at(rvs[0], time, t) {
          Some(v) => return v
          None => ()
        }
      None => ()
    }
  }
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match mgf_of_rv(rv, t) {
        Some(v) => v
        None => @symcore.function("moment_generating_function", [expr, t])
      }
    None => @symcore.function("moment_generating_function", [expr, t])
  }
}

///|
pub fn smoment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if !rvs.is_empty() {
    let c = central_moment(expr, n, rvs~)
    let s = std(expr, rvs~)
    eval_arith(@symcore.mul([c, @symcore.pow(s, @symcore.int(-n))]))
  } else {
    @symcore.function("smoment", [expr, @symcore.int(n)])
  }
}

///|
pub fn quantile(
  expr : @symcore.Expr,
  q : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if rvs.length() == 1 {
    match resolve_process_time(expr, rvs[0]) {
      Some(time) =>
        match process_quantile_at(rvs[0], time, q) {
          Some(v) => return v
          None => ()
        }
      None => ()
    }
  }
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match rv.kind {
        Exponential(rate~) =>
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.function("log", [
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), q]),
                  ]),
                ),
              ]),
              @symcore.pow(rate, @symcore.int(-1)),
            ]),
          )
        Normal(mu~, sigma~) =>
          eval_arith(
            @symcore.add([
              mu,
              eval_arith(
                @symcore.mul([
                  sigma,
                  @symcore.function("sqrt", [@symcore.int(2)]),
                  @symcore.function("erfinv", [
                    eval_arith(
                      @symcore.add([
                        eval_arith(@symcore.mul([@symcore.int(2), q])),
                        @symcore.int(-1),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          )
        Symbolic(kind~, params~) => {
          let name = symbolic_kind_name(kind)
          if compat_use_generic_unevaluated(name) {
            return match symbolic_opaque_quantile(name, params, q) {
              Some(v) => v
              None => @symcore.function("quantile", [Symbol(rv.name), q])
            }
          }
          match generated_quantile(name, params, q) {
            Some(v) => v
            None =>
              match kind {
                Continuous(Arcsin) if params.length() == 0 =>
                  compat_piecewise2(
                    @symcore.pow(
                      @symcore.function("sin", [
                        eval_arith(
                          @symcore.mul([
                            NumberSymbol(Pi),
                            q,
                            stats_exact_rational(1, 2),
                          ]),
                        ),
                      ]),
                      @symcore.int(2),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Arcsin) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        @symcore.mul([
                          eval_arith(
                            @symcore.add([
                              params[1],
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ]),
                          ),
                          @symcore.pow(
                            @symcore.function("sin", [
                              eval_arith(
                                @symcore.mul([
                                  NumberSymbol(Pi),
                                  q,
                                  stats_exact_rational(1, 2),
                                ]),
                              ),
                            ]),
                            @symcore.int(2),
                          ),
                        ]),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Beta) if params.length() == 2 =>
                  compat_piecewise2(
                    @symcore.function("betaincinv", [params[0], params[1], q]),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Kumaraswamy) if params.length() == 2 =>
                  compat_piecewise2(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          @symcore.int(1),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(1),
                                  @symcore.mul([@symcore.int(-1), q]),
                                ]),
                              ),
                              @symcore.pow(params[1], @symcore.int(-1)),
                            ),
                          ]),
                        ]),
                      ),
                      @symcore.pow(params[0], @symcore.int(-1)),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Chi) if params.length() == 1 =>
                  compat_piecewise2(
                    @symcore.function("sqrt", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(2),
                          @symcore.function("gammaincinv", [
                            eval_arith(
                              @symcore.mul([
                                stats_exact_rational(1, 2),
                                params[0],
                              ]),
                            ),
                            q,
                          ]),
                        ]),
                      ),
                    ]),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(ChiSquared) if params.length() == 1 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(2),
                        @symcore.function("gammaincinv", [
                          eval_arith(
                            @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                          ),
                          q,
                        ]),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Erlang) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.mul([
                        @symcore.function("gammaincinv", [params[0], q]),
                        @symcore.pow(params[1], @symcore.int(-1)),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Uniform) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      params[0],
                      eval_arith(
                        @symcore.mul([
                          q,
                          eval_arith(
                            @symcore.add([
                              params[1],
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  )
                Continuous(Cauchy) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        @symcore.mul([
                          params[1],
                          @symcore.function("tan", [
                            eval_arith(
                              @symcore.mul([
                                NumberSymbol(Pi),
                                eval_arith(
                                  @symcore.add([q, stats_exact_rational(-1, 2)]),
                                ),
                              ]),
                            ),
                          ]),
                        ]),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Rayleigh) if params.length() == 1 =>
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.function("sqrt", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-2),
                            @symcore.function("log", [
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(1),
                                  @symcore.mul([@symcore.int(-1), q]),
                                ]),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                Continuous(Laplace) if params.length() == 2 => {
                  let mu = params[0]
                  let b = params[1]
                  let left = eval_arith(
                    @symcore.add([
                      mu,
                      @symcore.mul([
                        b,
                        @symcore.function("log", [
                          eval_arith(@symcore.mul([@symcore.int(2), q])),
                        ]),
                      ]),
                    ]),
                  )
                  let right = eval_arith(
                    @symcore.add([
                      mu,
                      @symcore.mul([
                        @symcore.int(-1),
                        b,
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(2),
                              @symcore.add([
                                @symcore.int(1),
                                @symcore.mul([@symcore.int(-1), q]),
                              ]),
                            ]),
                          ),
                        ]),
                      ]),
                    ]),
                  )
                  compat_piecewise3(
                    left,
                    @symcore.function("Le", [q, stats_exact_rational(1, 2)]),
                    right,
                    @symcore.function("Le", [q, @symcore.int(1)]),
                    NumberSymbol(NaN),
                  )
                }
                Continuous(Weibull) if params.length() == 2 =>
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.function("log", [
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(1),
                                  @symcore.mul([@symcore.int(-1), q]),
                                ]),
                              ),
                            ]),
                          ]),
                        ),
                        @symcore.pow(params[1], @symcore.int(-1)),
                      ),
                    ]),
                  )
                Continuous(Gumbel) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      params[1],
                      @symcore.mul([
                        @symcore.int(-1),
                        params[0],
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              @symcore.function("log", [q]),
                            ]),
                          ),
                        ]),
                      ]),
                    ]),
                  )
                Continuous(Moyal) if params.length() == 2 =>
                  eval_arith(
                    @symcore.add([
                      params[0],
                      @symcore.mul([
                        @symcore.int(-2),
                        params[1],
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.function("sqrt", [@symcore.int(2)]),
                              @symcore.function("erfcinv", [q]),
                            ]),
                          ),
                        ]),
                      ]),
                    ]),
                  )
                Continuous(PowerFunction) if params.length() == 3 =>
                  eval_arith(
                    @symcore.add([
                      params[1],
                      @symcore.mul([
                        @symcore.add([
                          params[2],
                          @symcore.mul([@symcore.int(-1), params[1]]),
                        ]),
                        @symcore.pow(
                          q,
                          @symcore.pow(params[0], @symcore.int(-1)),
                        ),
                      ]),
                    ]),
                  )
                Continuous(Triangular) if params.length() == 3 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let span = eval_arith(
                    @symcore.add([b, @symcore.mul([@symcore.int(-1), a])]),
                  )
                  let left = eval_arith(
                    @symcore.add([
                      a,
                      @symcore.function("sqrt", [
                        eval_arith(
                          @symcore.mul([
                            q,
                            span,
                            eval_arith(
                              @symcore.add([
                                c,
                                @symcore.mul([@symcore.int(-1), a]),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                  let right = eval_arith(
                    @symcore.add([
                      b,
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("sqrt", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.add([
                                @symcore.int(1),
                                @symcore.mul([@symcore.int(-1), q]),
                              ]),
                              span,
                              eval_arith(
                                @symcore.add([
                                  b,
                                  @symcore.mul([@symcore.int(-1), c]),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ]),
                    ]),
                  )
                  let pivot = eval_arith(
                    @symcore.mul([
                      eval_arith(
                        @symcore.add([c, @symcore.mul([@symcore.int(-1), a])]),
                      ),
                      @symcore.pow(span, @symcore.int(-1)),
                    ]),
                  )
                  compat_piecewise3(
                    left,
                    @symcore.function("Le", [q, pivot]),
                    right,
                    @symcore.function("Le", [q, @symcore.int(1)]),
                    NumberSymbol(NaN),
                  )
                }
                Continuous(Trapezoidal) if params.length() == 4 => {
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
                  let ql = eval_arith(
                    @symcore.mul([
                      eval_arith(
                        @symcore.add([b, @symcore.mul([@symcore.int(-1), a])]),
                      ),
                      @symcore.pow(span, @symcore.int(-1)),
                    ]),
                  )
                  let qr = eval_arith(
                    @symcore.mul([
                      eval_arith(
                        @symcore.add([
                          @symcore.mul([@symcore.int(2), c]),
                          @symcore.mul([@symcore.int(-1), a]),
                          @symcore.mul([@symcore.int(-1), b]),
                        ]),
                      ),
                      @symcore.pow(span, @symcore.int(-1)),
                    ]),
                  )
                  let left = eval_arith(
                    @symcore.add([
                      a,
                      @symcore.function("sqrt", [
                        eval_arith(
                          @symcore.mul([
                            q,
                            eval_arith(
                              @symcore.add([
                                b,
                                @symcore.mul([@symcore.int(-1), a]),
                              ]),
                            ),
                            span,
                          ]),
                        ),
                      ]),
                    ]),
                  )
                  let mid = eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.add([eval_arith(@symcore.mul([q, span])), a, b]),
                      ),
                    ]),
                  )
                  let right = eval_arith(
                    @symcore.add([
                      d,
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("sqrt", [
                          eval_arith(
                            @symcore.mul([
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(1),
                                  @symcore.mul([@symcore.int(-1), q]),
                                ]),
                              ),
                              eval_arith(
                                @symcore.add([
                                  d,
                                  @symcore.mul([@symcore.int(-1), c]),
                                ]),
                              ),
                              span,
                            ]),
                          ),
                        ]),
                      ]),
                    ]),
                  )
                  @symcore.function("Piecewise", [
                    Tuple([left, @symcore.function("Le", [q, ql])]),
                    Tuple([mid, @symcore.function("Le", [q, qr])]),
                    Tuple([right, @symcore.function("Le", [q, @symcore.int(1)])]),
                    Tuple([NumberSymbol(NaN), Boolean(true)]),
                  ])
                }
                Continuous(VonMises) if params.length() == 2 => {
                  let mu = params[0]
                  let kappa = params[1]
                  let x_var = @symcore.Expr::Symbol("_x")
                  let integral_term = @symcore.function("Integral", [
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([
                          kappa,
                          @symcore.function("cos", [
                            eval_arith(
                              @symcore.add([
                                x_var,
                                @symcore.mul([@symcore.int(-1), mu]),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                    @symcore.function("Tuple", [x_var, @symcore.int(0), x_var]),
                  ])
                  let target = eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      NumberSymbol(Pi),
                      q,
                      @symcore.function("besseli", [@symcore.int(0), kappa]),
                    ]),
                  )
                  let condset = @symcore.function("ConditionSet", [
                    x_var,
                    @symcore.function("Eq", [
                      eval_arith(
                        @symcore.add([
                          integral_term,
                          @symcore.mul([@symcore.int(-1), target]),
                        ]),
                      ),
                      @symcore.int(0),
                    ]),
                    @symcore.function("Interval", [
                      @symcore.int(0),
                      eval_arith(
                        @symcore.mul([@symcore.int(2), NumberSymbol(Pi)]),
                      ),
                    ]),
                  ])
                  compat_piecewise2(
                    condset,
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                }
                Continuous(StudentT) if params.length() == 1 => {
                  let nu = params[0]
                  let half = stats_exact_rational(1, 2)
                  let a = eval_arith(@symcore.mul([half, nu]))
                  let left_beta = @symcore.function("betaincinv", [
                    a,
                    half,
                    eval_arith(@symcore.mul([@symcore.int(2), q])),
                  ])
                  let right_beta = @symcore.function("betaincinv", [
                    a,
                    half,
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(2),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), q]),
                          ]),
                        ),
                      ]),
                    ),
                  ])
                  let left = eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.function("sqrt", [
                        eval_arith(
                          @symcore.mul([
                            nu,
                            eval_arith(
                              @symcore.add([
                                @symcore.pow(left_beta, @symcore.int(-1)),
                                @symcore.int(-1),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ]),
                  )
                  let right = eval_arith(
                    @symcore.function("sqrt", [
                      eval_arith(
                        @symcore.mul([
                          nu,
                          eval_arith(
                            @symcore.add([
                              @symcore.pow(right_beta, @symcore.int(-1)),
                              @symcore.int(-1),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  )
                  @symcore.function("Piecewise", [
                    Tuple([left, @symcore.function("Lt", [q, half])]),
                    Tuple([@symcore.int(0), @symcore.function("Eq", [q, half])]),
                    Tuple([right, @symcore.function("Le", [q, @symcore.int(1)])]),
                    Tuple([NumberSymbol(NaN), Boolean(true)]),
                  ])
                }
                Continuous(BoundedPareto) if params.length() == 3 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.mul([
                        params[1],
                        @symcore.pow(
                          eval_arith(
                            @symcore.add([
                              @symcore.int(1),
                              @symcore.mul([
                                @symcore.int(-1),
                                q,
                                eval_arith(
                                  @symcore.add([
                                    @symcore.int(1),
                                    @symcore.mul([
                                      @symcore.int(-1),
                                      @symcore.pow(
                                        eval_arith(
                                          @symcore.mul([
                                            params[1],
                                            @symcore.pow(
                                              params[2],
                                              @symcore.int(-1),
                                            ),
                                          ]),
                                        ),
                                        params[0],
                                      ),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              @symcore.pow(params[0], @symcore.int(-1)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Pareto) if params.length() == 2 =>
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), q]),
                          ]),
                        ),
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.pow(params[1], @symcore.int(-1)),
                        ]),
                      ),
                    ]),
                  )
                Continuous(Lomax) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.mul([
                        params[1],
                        eval_arith(
                          @symcore.add([
                            @symcore.pow(
                              eval_arith(
                                @symcore.add([
                                  @symcore.int(1),
                                  @symcore.mul([@symcore.int(-1), q]),
                                ]),
                              ),
                              @symcore.mul([
                                @symcore.int(-1),
                                @symcore.pow(params[0], @symcore.int(-1)),
                              ]),
                            ),
                            @symcore.int(-1),
                          ]),
                        ),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Reciprocal) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.mul([
                        params[0],
                        @symcore.pow(
                          eval_arith(
                            @symcore.mul([
                              params[1],
                              @symcore.pow(params[0], @symcore.int(-1)),
                            ]),
                          ),
                          q,
                        ),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Gompertz) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.mul([
                        @symcore.pow(params[0], @symcore.int(-1)),
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.add([
                              @symcore.int(1),
                              @symcore.mul([
                                @symcore.int(-1),
                                @symcore.function("log", [
                                  eval_arith(
                                    @symcore.add([
                                      @symcore.int(1),
                                      @symcore.mul([@symcore.int(-1), q]),
                                    ]),
                                  ),
                                ]),
                                @symcore.pow(params[1], @symcore.int(-1)),
                              ]),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(Levy) if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        @symcore.mul([
                          params[1],
                          @symcore.pow(
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(2),
                                @symcore.pow(
                                  @symcore.function("erfcinv", [q]),
                                  @symcore.int(2),
                                ),
                              ]),
                            ),
                            @symcore.int(-1),
                          ),
                        ]),
                      ]),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    NumberSymbol(NaN),
                  )
                Continuous(LogNormal) if params.length() == 2 =>
                  eval_arith(
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(
                            @symcore.mul([
                              params[1],
                              @symcore.function("sqrt", [@symcore.int(2)]),
                              @symcore.function("erfinv", [
                                eval_arith(
                                  @symcore.add([
                                    eval_arith(
                                      @symcore.mul([@symcore.int(2), q]),
                                    ),
                                    @symcore.int(-1),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  )
                _ => symbolic_quantile_via_conditionset(name, params, q)
              }
          }
        }
        _ => @symcore.function("quantile", [expr, q])
      }
    None => @symcore.function("quantile", [expr, q])
  }
}

///|
pub fn coskewness(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("coskewness", [a, b, c])
}

///|
pub fn marginal_distribution(
  expr : @symcore.Expr,
  vars : Array[@symcore.Expr],
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = [expr]
  for v in vars {
    args.push(v)
  }
  @symcore.function("marginal_distribution", args)
}

///|
pub fn generator_matrix_of(obj : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("GeneratorMatrixOf", [obj])
}

///|
pub fn transition_matrix_of(obj : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("TransitionMatrixOf", [obj])
}

///|
pub fn stochastic_state_space_of(obj : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("StochasticStateSpaceOf", [obj])
}

///|
fn finite_central_moment(rv : RandomVar, n : Int) -> @symcore.Expr? {
  match rv.kind {
    Finite(items) =>
      match finite_expectation(rv) {
        Some(mu) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for item in items {
            let (value, p) = item
            let centered = eval_arith(
              @symcore.add([value, @symcore.mul([@symcore.int(-1), mu])]),
            )
            terms.push(
              eval_arith(
                @symcore.mul([
                  expr_from_big_rational(p),
                  @symcore.pow(centered, @symcore.int(n)),
                ]),
              ),
            )
          }
          Some(eval_arith(@symcore.add(terms)))
        }
        None => None
      }
    _ => None
  }
}

///|
pub fn central_moment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match finite_central_moment(rv, n) {
        Some(v) => return v
        None => ()
      }
    None => ()
  }
  let mu = expectation(expr, rvs~)
  let centered = eval_arith(
    @symcore.add([expr, @symcore.mul([@symcore.int(-1), mu])]),
  )
  expectation(@symcore.pow(centered, @symcore.int(n)), rvs~)
}

///|
pub fn expectation_matrix(
  exprs : Array[@symcore.Expr],
  rvs? : Array[RandomVar] = [],
) -> Array[@symcore.Expr] {
  exprs.map(e0 => expectation(e0, rvs~))
}

///|
pub fn variance_matrix(
  exprs : Array[@symcore.Expr],
  rvs? : Array[RandomVar] = [],
) -> Array[Array[@symcore.Expr]] {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<exprs.length() {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<exprs.length() {
      row.push(covariance(exprs[i], exprs[j], rvs~))
    }
    out.push(row)
  }
  out
}

///|
pub fn cross_covariance_matrix(
  xs : Array[@symcore.Expr],
  ys : Array[@symcore.Expr],
  rvs? : Array[RandomVar] = [],
) -> Array[Array[@symcore.Expr]] {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<xs.length() {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<ys.length() {
      row.push(covariance(xs[i], ys[j], rvs~))
    }
    out.push(row)
  }
  out
}

///|
pub fn joint_eigen_distribution(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "JointEigenDistribution", params)
}

///|
pub fn level_spacing_distribution(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "level_spacing_distribution", params)
}

///|
pub fn matrix_gamma(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MatrixGamma", params)
}

///|
pub fn matrix_student_t(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MatrixStudentT", params)
}

///|
pub fn gamma(
  name : String,
  shape : @symcore.Expr,
  scale : @symcore.Expr,
) -> RandomVar {
  gamma_dist(name, shape, scale)
}

///|
pub fn wishart(
  name : String,
  df : @symcore.Expr,
  scale : @symcore.Expr,
) -> RandomVar {
  wishart_rv(name, df, scale)
}

///|
pub fn matrix_normal(
  name : String,
  mean : @symcore.Expr,
  rowcov : @symcore.Expr,
  colcov : @symcore.Expr,
) -> RandomVar {
  matrix_normal_rv(name, mean, rowcov, colcov)
}

///|
pub fn beta_binomial(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "BetaBinomial", params)
}

///|
pub fn hypergeometric(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Hypergeometric", params)
}

///|
pub fn rademacher(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  match stats_exact_big_rational(1, 2) {
    Some(half) =>
      finite_rv(name, [(@symcore.int(-1), half), (@symcore.int(1), half)])
    None => symbolic_rv(name, "Rademacher", params)
  }
}

///|
pub fn ideal_soliton(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "IdealSoliton", params)
}

///|
pub fn robust_soliton(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "RobustSoliton", params)
}

///|
pub fn finite_distribution_handmade(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "FiniteDistributionHandmade", params)
}

///|
pub fn continuous_rv(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ContinuousRV", params)
}

///|
pub fn arcsin(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Arcsin", params)
}

///|
pub fn benini(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Benini", params)
}

///|
pub fn beta(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Beta", params)
}

///|
pub fn beta_noncentral(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "BetaNoncentral", params)
}

///|
pub fn beta_prime(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "BetaPrime", params)
}

///|
pub fn bounded_pareto(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "BoundedPareto", params)
}

///|
pub fn cauchy(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Cauchy", params)
}

///|
pub fn chi(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Chi", params)
}

///|
pub fn chi_noncentral(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ChiNoncentral", params)
}

///|
pub fn chi_squared(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ChiSquared", params)
}

///|
pub fn dagum(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Dagum", params)
}

///|
pub fn davis(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Davis", params)
}

///|
pub fn erlang(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Erlang", params)
}

///|
pub fn ex_gaussian(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ExGaussian", params)
}

///|
pub fn exponential_power(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ExponentialPower", params)
}

///|
pub fn f_distribution(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "FDistribution", params)
}

///|
pub fn fisher_z(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "FisherZ", params)
}

///|
pub fn frechet(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Frechet", params)
}

///|
pub fn gamma_inverse(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GammaInverse", params)
}

///|
pub fn gompertz(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Gompertz", params)
}

///|
pub fn gumbel(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Gumbel", params)
}

///|
pub fn kumaraswamy(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Kumaraswamy", params)
}

///|
pub fn laplace(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Laplace", params)
}

///|
pub fn levy(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Levy", params)
}

///|
pub fn logistic(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Logistic", params)
}

///|
pub fn log_cauchy(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "LogCauchy", params)
}

///|
pub fn log_logistic(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "LogLogistic", params)
}

///|
pub fn logit_normal(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "LogitNormal", params)
}

///|
pub fn log_normal(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "LogNormal", params)
}

///|
pub fn lomax(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Lomax", params)
}

///|
pub fn moyal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Moyal", params)
}

///|
pub fn maxwell(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Maxwell", params)
}

///|
pub fn nakagami(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Nakagami", params)
}

///|
pub fn gaussian_inverse(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GaussianInverse", params)
}

///|
pub fn pareto(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Pareto", params)
}

///|
pub fn power_function(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "PowerFunction", params)
}

///|
pub fn quadratic_u(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "QuadraticU", params)
}

///|
pub fn raised_cosine(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "RaisedCosine", params)
}

///|
pub fn rayleigh(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Rayleigh", params)
}

///|
pub fn reciprocal(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Reciprocal", params)
}

///|
pub fn student_t(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "StudentT", params)
}

///|
pub fn shifted_gompertz(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ShiftedGompertz", params)
}

///|
pub fn trapezoidal(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Trapezoidal", params)
}

///|
pub fn triangular(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Triangular", params)
}

///|
pub fn uniform(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Uniform", params)
}

///|
pub fn uniform_sum(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "UniformSum", params)
}

///|
pub fn von_mises(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "VonMises", params)
}

///|
pub fn wald(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Wald", params)
}

///|
pub fn weibull(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Weibull", params)
}

///|
pub fn wigner_semicircle(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "WignerSemicircle", params)
}

///|
pub fn continuous_distribution_handmade(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ContinuousDistributionHandmade", params)
}

///|
pub fn flory_schulz(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "FlorySchulz", params)
}

///|
pub fn hermite(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Hermite", params)
}

///|
pub fn logarithmic(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Logarithmic", params)
}

///|
pub fn skellam(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Skellam", params)
}

///|
pub fn yule_simon(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "YuleSimon", params)
}

///|
pub fn zeta(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Zeta", params)
}

///|
pub fn discrete_rv(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "DiscreteRV", params)
}

///|
pub fn discrete_distribution_handmade(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "DiscreteDistributionHandmade", params)
}

///|
pub fn joint_rv(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "JointRV", params)
}

///|
pub fn dirichlet(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Dirichlet", params)
}

///|
pub fn generalized_multivariate_log_gamma(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GeneralizedMultivariateLogGamma", params)
}

///|
pub fn generalized_multivariate_log_gamma_omega(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GeneralizedMultivariateLogGammaOmega", params)
}

///|
pub fn multinomial(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "Multinomial", params)
}

///|
pub fn multivariate_beta(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MultivariateBeta", params)
}

///|
pub fn multivariate_ewens(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MultivariateEwens", params)
}

///|
pub fn multivariate_t(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MultivariateT", params)
}

///|
pub fn negative_multinomial(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "NegativeMultinomial", params)
}

///|
pub fn normal_gamma(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "NormalGamma", params)
}

///|
pub fn multivariate_normal(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MultivariateNormal", params)
}

///|
pub fn multivariate_laplace(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "MultivariateLaplace", params)
}

///|
pub fn stochastic_process(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "StochasticProcess", params)
}

///|
pub fn discrete_time_stochastic_process(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "DiscreteTimeStochasticProcess", params)
}

///|
pub fn discrete_markov_chain(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "DiscreteMarkovChain", params)
}

///|
pub fn continuous_markov_chain(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "ContinuousMarkovChain", params)
}

///|
pub fn bernoulli_process(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "BernoulliProcess", params)
}

///|
pub fn gamma_process(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GammaProcess", params)
}

///|
pub fn circular_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "CircularEnsemble", params)
}

///|
pub fn circular_unitary_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "CircularUnitaryEnsemble", params)
}

///|
pub fn circular_orthogonal_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "CircularOrthogonalEnsemble", params)
}

///|
pub fn circular_symplectic_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "CircularSymplecticEnsemble", params)
}

///|
pub fn gaussian_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GaussianEnsemble", params)
}

///|
pub fn gaussian_unitary_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GaussianUnitaryEnsemble", params)
}

///|
pub fn gaussian_orthogonal_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GaussianOrthogonalEnsemble", params)
}

///|
pub fn gaussian_symplectic_ensemble(
  name : String,
  params? : Array[@symcore.Expr] = [],
) -> RandomVar {
  symbolic_rv(name, "GaussianSymplecticEnsemble", params)
}
