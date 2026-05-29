///|
fn stats_seed_bytes(seed : Int) -> Bytes {
  Bytes::makei(32, i => ((seed + i * 73) & 255).to_byte())
}

///|
fn stats_rng(seed? : Int? = None) -> @random.Rand {
  match seed {
    Some(value) => @random.Rand::chacha8(seed=stats_seed_bytes(value))
    None => @random.Rand::new()
  }
}

///|
fn stats_expr_from_double(value : Double) -> @symcore.Expr {
  @symcore.Expr::Float(@symcore.Float::from_double(value))
}

///|
fn stats_rational_to_double(value : @symnum.BigRational) -> Double? {
  let float_value = @symcore.Float::from_exact(value, prec=53) catch {
    _ => return None
  }
  Some(float_value.to_double() catch { _ => return None })
}

///|
fn stats_expr_to_double(expr : @symcore.Expr) -> Double? {
  match expr {
    @symcore.Expr::Number(value) => stats_rational_to_double(value)
    @symcore.Expr::Float(value) =>
      Some(value.to_double() catch { _ => return None })
    _ =>
      match @symcore.evalf(expr, prec=80) {
        @symcore.Expr::Number(value) => stats_rational_to_double(value)
        @symcore.Expr::Float(value) =>
          Some(value.to_double() catch { _ => return None })
        _ => None
      }
  }
}

///|
fn stats_uniform01(rng : @random.Rand) -> Double {
  let value = rng.double()
  if value <= 0.0 {
    0.5e-16
  } else if value >= 1.0 {
    1.0 - 0.5e-16
  } else {
    value
  }
}

///|
fn stats_sample_standard_normal(rng : @random.Rand) -> Double {
  let u1 = stats_uniform01(rng)
  let u2 = stats_uniform01(rng)
  let radius = (-2.0 * @math.ln(u1)).sqrt()
  let theta = 6.2831853071795864769 * u2
  radius * @math.cos(theta)
}

///|
fn stats_sample_gamma_double(
  shape : Double,
  scale : Double,
  rng : @random.Rand,
) -> Double? {
  if shape <= 0.0 || scale <= 0.0 {
    return None
  }
  if shape < 1.0 {
    match stats_sample_gamma_double(shape + 1.0, scale, rng) {
      Some(base) => Some(base * @math.pow(stats_uniform01(rng), 1.0 / shape))
      None => None
    }
  } else {
    let d = shape - 1.0 / 3.0
    let c = 1.0 / (9.0 * d).sqrt()
    while true {
      let x = stats_sample_standard_normal(rng)
      let v0 = 1.0 + c * x
      if v0 <= 0.0 {
        continue
      }
      let v = v0 * v0 * v0
      let u = stats_uniform01(rng)
      if u < 1.0 - 0.0331 * x * x * x * x {
        return Some(scale * d * v)
      }
      if @math.ln(u) < 0.5 * x * x + d * (1.0 - v + @math.ln(v)) {
        return Some(scale * d * v)
      }
    }
    None
  }
}

///|
fn stats_sample_finite(
  items : Array[(@symcore.Expr, @symnum.BigRational)],
  rng : @random.Rand,
) -> @symcore.Expr? {
  if items.is_empty() {
    return None
  }
  let target = stats_uniform01(rng)
  let mut accum = 0.0
  for item in items {
    let (value, prob) = item
    match stats_rational_to_double(prob) {
      Some(p) => {
        accum += p
        if target <= accum {
          return Some(value)
        }
      }
      None => return None
    }
  }
  Some(items[items.length() - 1].0)
}

///|
fn stats_sample_binomial(
  n : @symcore.Expr,
  p : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match (expr_as_int(n), stats_expr_to_double(p)) {
    (Some(trials), Some(prob)) if trials >= 0 && prob >= 0.0 && prob <= 1.0 => {
      let mut successes = 0
      for _ in 0..<trials {
        if stats_uniform01(rng) <= prob {
          successes += 1
        }
      }
      Some(@symcore.int(successes))
    }
    _ => None
  }
}

///|
fn stats_sample_poisson(
  rate : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match stats_expr_to_double(rate) {
    Some(lambda) if lambda > 0.0 => {
      let limit = @math.exp(-lambda)
      let mut k = 0
      let mut prod = 1.0
      while prod > limit {
        k += 1
        prod *= stats_uniform01(rng)
      }
      Some(@symcore.int(k - 1))
    }
    Some(lambda) if lambda == 0.0 => Some(@symcore.int(0))
    _ => None
  }
}

///|
fn stats_sample_geometric(
  p : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match stats_expr_to_double(p) {
    Some(prob) if prob > 0.0 && prob <= 1.0 => {
      let mut count = 1
      while stats_uniform01(rng) > prob {
        count += 1
      }
      Some(@symcore.int(count))
    }
    _ => None
  }
}

///|
fn stats_sample_negative_binomial(
  r : @symcore.Expr,
  p : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match expr_as_int(r) {
    Some(successes) if successes > 0 => {
      let mut failures = 0
      for _ in 0..<successes {
        match stats_sample_geometric(p, rng) {
          Some(sampled) =>
            match expr_as_int(sampled) {
              Some(trials) => failures += trials - 1
              None => return None
            }
          None => return None
        }
      }
      Some(@symcore.int(failures))
    }
    _ => None
  }
}

///|
fn stats_sample_continuous_normal(
  mu : @symcore.Expr,
  sigma : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match (stats_expr_to_double(mu), stats_expr_to_double(sigma)) {
    (Some(m), Some(s)) if s >= 0.0 =>
      Some(stats_expr_from_double(m + s * stats_sample_standard_normal(rng)))
    _ => None
  }
}

///|
fn stats_sample_exponential(
  rate : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match stats_expr_to_double(rate) {
    Some(lambda) if lambda > 0.0 =>
      Some(stats_expr_from_double(-@math.ln(stats_uniform01(rng)) / lambda))
    _ => None
  }
}

///|
fn stats_sample_gamma(
  shape : @symcore.Expr,
  scale : @symcore.Expr,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match (stats_expr_to_double(shape), stats_expr_to_double(scale)) {
    (Some(k), Some(theta)) =>
      match stats_sample_gamma_double(k, theta, rng) {
        Some(value) => Some(stats_expr_from_double(value))
        None => None
      }
    _ => None
  }
}

///|
fn stats_double_params(
  params : Array[@symcore.Expr],
  count : Int,
) -> Array[Double]? {
  if params.length() != count {
    return None
  }
  let values : Array[Double] = []
  for param in params {
    match stats_expr_to_double(param) {
      Some(value) => values.push(value)
      None => return None
    }
  }
  Some(values)
}

///|
fn stats_expr_weight_to_double(value : @symcore.Expr) -> Double? {
  match stats_expr_to_double(eval_arith(value)) {
    Some(v) if v >= 0.0 => Some(v)
    _ => None
  }
}

///|
fn stats_sample_expr_weighted(
  items : Array[(@symcore.Expr, @symcore.Expr)],
  rng : @random.Rand,
) -> @symcore.Expr? {
  if items.is_empty() {
    return None
  }
  let weights : Array[Double] = []
  let mut total = 0.0
  for item in items {
    match stats_expr_weight_to_double(item.1) {
      Some(weight) => {
        weights.push(weight)
        total += weight
      }
      None => return None
    }
  }
  if total <= 0.0 {
    return None
  }
  let target = stats_uniform01(rng) * total
  let mut accum = 0.0
  for i in 0..<items.length() {
    accum += weights[i]
    if target <= accum {
      return Some(items[i].0)
    }
  }
  Some(items[items.length() - 1].0)
}

///|
fn stats_sample_beta_double(
  alpha : Double,
  beta : Double,
  rng : @random.Rand,
) -> Double? {
  match
    (
      stats_sample_gamma_double(alpha, 1.0, rng),
      stats_sample_gamma_double(beta, 1.0, rng),
    ) {
    (Some(x), Some(y)) if x + y > 0.0 => Some(x / (x + y))
    _ => None
  }
}

///|
fn stats_sample_uniform_double(
  left : Double,
  right : Double,
  rng : @random.Rand,
) -> Double? {
  if !(left < right) {
    return None
  }
  Some(left + (right - left) * stats_uniform01(rng))
}

///|
fn stats_sample_triangular_double(
  a : Double,
  b : Double,
  c : Double,
  rng : @random.Rand,
) -> Double? {
  if !(a <= c && c <= b && a < b) {
    return None
  }
  let u = stats_uniform01(rng)
  let split = (c - a) / (b - a)
  if u <= split {
    Some(a + ((b - a) * (c - a) * u).sqrt())
  } else {
    Some(b - ((b - a) * (b - c) * (1.0 - u)).sqrt())
  }
}

///|
fn stats_sample_trapezoidal_double(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  rng : @random.Rand,
) -> Double? {
  if !(a <= b && b < c && c <= d && a < d) {
    return None
  }
  let total = d + c - a - b
  if total <= 0.0 {
    return None
  }
  let rise = (b - a) / total
  let flat = 2.0 * (c - b) / total
  let u = stats_uniform01(rng)
  if u < rise {
    if b == a {
      return Some(a)
    }
    Some(a + ((b - a) * total * u).sqrt())
  } else if u < rise + flat {
    Some(b + (u - rise) * total / 2.0)
  } else {
    if d == c {
      return Some(d)
    }
    Some(d - ((d - c) * total * (1.0 - u)).sqrt())
  }
}

///|
fn stats_sample_symbolic_continuous(
  tag : ContinuousTag,
  params : Array[@symcore.Expr],
  rng : @random.Rand,
) -> @symcore.Expr? {
  match tag {
    ContinuousTag::Arcsin if params.length() == 0 =>
      match stats_sample_beta_double(0.5, 0.5, rng) {
        Some(value) => Some(stats_expr_from_double(value))
        None => None
      }
    ContinuousTag::Beta if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) =>
          match stats_sample_beta_double(values[0], values[1], rng) {
            Some(value) => Some(stats_expr_from_double(value))
            None => None
          }
        None => None
      }
    ContinuousTag::BetaPrime if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) =>
          match
            (
              stats_sample_gamma_double(values[0], 1.0, rng),
              stats_sample_gamma_double(values[1], 1.0, rng),
            ) {
            (Some(x), Some(y)) if y > 0.0 => Some(stats_expr_from_double(x / y))
            _ => None
          }
        None => None
      }
    ContinuousTag::Cauchy if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[1] > 0.0 =>
          Some(
            stats_expr_from_double(
              values[0] +
              values[1] * @math.tan(@math.PI * (stats_uniform01(rng) - 0.5)),
            ),
          )
        _ => None
      }
    ContinuousTag::Chi if params.length() == 1 =>
      match stats_double_params(params, 1) {
        Some(values) =>
          match stats_sample_gamma_double(values[0] / 2.0, 2.0, rng) {
            Some(value) => Some(stats_expr_from_double(value.sqrt()))
            None => None
          }
        None => None
      }
    ContinuousTag::ChiSquared if params.length() == 1 =>
      match stats_double_params(params, 1) {
        Some(values) =>
          match stats_sample_gamma_double(values[0] / 2.0, 2.0, rng) {
            Some(value) => Some(stats_expr_from_double(value))
            None => None
          }
        None => None
      }
    ContinuousTag::Erlang if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[1] > 0.0 =>
          match stats_sample_gamma_double(values[0], 1.0 / values[1], rng) {
            Some(value) => Some(stats_expr_from_double(value))
            None => None
          }
        _ => None
      }
    ContinuousTag::Exponential if params.length() == 1 =>
      stats_sample_exponential(params[0], rng)
    ContinuousTag::GammaInverse if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) =>
          match stats_sample_gamma_double(values[0], 1.0 / values[1], rng) {
            Some(value) if value > 0.0 =>
              Some(stats_expr_from_double(1.0 / value))
            _ => None
          }
        None => None
      }
    ContinuousTag::Kumaraswamy if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] > 0.0 && values[1] > 0.0 =>
          Some(
            stats_expr_from_double(
              @math.pow(
                1.0 - @math.pow(1.0 - stats_uniform01(rng), 1.0 / values[1]),
                1.0 / values[0],
              ),
            ),
          )
        _ => None
      }
    ContinuousTag::Laplace if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[1] > 0.0 => {
          let u = stats_uniform01(rng)
          let value = if u < 0.5 {
            values[0] + values[1] * @math.ln(2.0 * u)
          } else {
            values[0] - values[1] * @math.ln(2.0 * (1.0 - u))
          }
          Some(stats_expr_from_double(value))
        }
        _ => None
      }
    ContinuousTag::LogLogistic if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] > 0.0 && values[1] > 0.0 => {
          let u = stats_uniform01(rng)
          Some(
            stats_expr_from_double(
              values[0] * @math.pow(u / (1.0 - u), 1.0 / values[1]),
            ),
          )
        }
        _ => None
      }
    ContinuousTag::LogNormal if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[1] >= 0.0 =>
          Some(
            stats_expr_from_double(
              @math.exp(
                values[0] + values[1] * stats_sample_standard_normal(rng),
              ),
            ),
          )
        _ => None
      }
    ContinuousTag::Logistic if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[1] > 0.0 => {
          let u = stats_uniform01(rng)
          Some(
            stats_expr_from_double(
              values[0] + values[1] * @math.ln(u / (1.0 - u)),
            ),
          )
        }
        _ => None
      }
    ContinuousTag::Lomax if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] > 0.0 && values[1] > 0.0 => {
          let u = stats_uniform01(rng)
          Some(
            stats_expr_from_double(
              values[1] * (@math.pow(1.0 - u, -1.0 / values[0]) - 1.0),
            ),
          )
        }
        _ => None
      }
    ContinuousTag::Maxwell if params.length() == 1 =>
      match stats_double_params(params, 1) {
        Some(values) if values[0] > 0.0 => {
          let x = stats_sample_standard_normal(rng)
          let y = stats_sample_standard_normal(rng)
          let z = stats_sample_standard_normal(rng)
          Some(
            stats_expr_from_double(values[0] * (x * x + y * y + z * z).sqrt()),
          )
        }
        _ => None
      }
    ContinuousTag::Nakagami if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] >= 0.5 && values[1] > 0.0 =>
          match
            stats_sample_gamma_double(values[0], values[1] / values[0], rng) {
            Some(value) => Some(stats_expr_from_double(value.sqrt()))
            None => None
          }
        _ => None
      }
    ContinuousTag::Pareto if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] > 0.0 && values[1] > 0.0 => {
          let u = stats_uniform01(rng)
          Some(
            stats_expr_from_double(
              values[0] / @math.pow(1.0 - u, 1.0 / values[1]),
            ),
          )
        }
        _ => None
      }
    ContinuousTag::PowerFunction if params.length() == 3 =>
      match stats_double_params(params, 3) {
        Some(values) if values[0] > 0.0 =>
          match stats_sample_uniform_double(values[1], values[2], rng) {
            Some(_) =>
              Some(
                stats_expr_from_double(
                  values[1] +
                  (values[2] - values[1]) *
                  @math.pow(stats_uniform01(rng), 1.0 / values[0]),
                ),
              )
            None => None
          }
        _ => None
      }
    ContinuousTag::Rayleigh if params.length() == 1 =>
      match stats_double_params(params, 1) {
        Some(values) if values[0] > 0.0 =>
          Some(
            stats_expr_from_double(
              values[0] * (-2.0 * @math.ln(1.0 - stats_uniform01(rng))).sqrt(),
            ),
          )
        _ => None
      }
    ContinuousTag::Reciprocal if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] > 0.0 && values[0] < values[1] =>
          Some(
            stats_expr_from_double(
              @math.exp(
                @math.ln(values[0]) +
                stats_uniform01(rng) *
                (@math.ln(values[1]) - @math.ln(values[0])),
              ),
            ),
          )
        _ => None
      }
    ContinuousTag::Triangular if params.length() == 3 =>
      match stats_double_params(params, 3) {
        Some(values) =>
          match
            stats_sample_triangular_double(values[0], values[1], values[2], rng) {
            Some(value) => Some(stats_expr_from_double(value))
            None => None
          }
        None => None
      }
    ContinuousTag::Trapezoidal if params.length() == 4 =>
      match stats_double_params(params, 4) {
        Some(values) =>
          match
            stats_sample_trapezoidal_double(
              values[0],
              values[1],
              values[2],
              values[3],
              rng,
            ) {
            Some(value) => Some(stats_expr_from_double(value))
            None => None
          }
        None => None
      }
    ContinuousTag::Uniform if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) =>
          match stats_sample_uniform_double(values[0], values[1], rng) {
            Some(value) => Some(stats_expr_from_double(value))
            None => None
          }
        None => None
      }
    ContinuousTag::Weibull if params.length() == 2 =>
      match stats_double_params(params, 2) {
        Some(values) if values[0] > 0.0 && values[1] > 0.0 =>
          Some(
            stats_expr_from_double(
              values[0] *
              @math.pow(-@math.ln(1.0 - stats_uniform01(rng)), 1.0 / values[1]),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn stats_sample_symbolic_discrete(
  tag : DiscreteTag,
  params : Array[@symcore.Expr],
  rng : @random.Rand,
) -> @symcore.Expr? {
  match tag {
    DiscreteTag::BetaBinomial if params.length() == 3 =>
      match
        (expr_as_int(params[0]), stats_double_params([params[1], params[2]], 2)) {
        (Some(n), Some(values)) if n >= 0 =>
          match stats_sample_beta_double(values[0], values[1], rng) {
            Some(prob) =>
              stats_sample_binomial(
                params[0],
                stats_expr_from_double(prob),
                rng,
              )
            None => None
          }
        _ => None
      }
    DiscreteTag::FiniteDistributionHandmade =>
      match symbolic_finite_handmade_pairs(params) {
        Some(pairs) => stats_sample_expr_weighted(pairs, rng)
        None => None
      }
    DiscreteTag::FlorySchulz if params.length() == 1 =>
      match stats_sample_negative_binomial(@symcore.int(2), params[0], rng) {
        Some(value) =>
          match expr_as_int(value) {
            Some(n) => Some(@symcore.int(n + 1))
            None => None
          }
        None => None
      }
    DiscreteTag::Hermite if params.length() == 2 =>
      match
        (
          stats_sample_poisson(params[0], rng),
          stats_sample_poisson(params[1], rng),
        ) {
        (Some(a), Some(b)) =>
          match (expr_as_int(a), expr_as_int(b)) {
            (Some(x), Some(y)) => Some(@symcore.int(x + 2 * y))
            _ => None
          }
        _ => None
      }
    DiscreteTag::Hypergeometric if params.length() == 3 =>
      match
        (expr_as_int(params[0]), expr_as_int(params[1]), expr_as_int(params[2])) {
        (Some(population), Some(successes0), Some(draws)) if population >= 0 &&
          successes0 >= 0 &&
          successes0 <= population &&
          draws >= 0 &&
          draws <= population => {
          let mut successes = successes0
          let mut failures = population - successes0
          let mut observed = 0
          for _ in 0..<draws {
            let total = successes + failures
            if total <= 0 {
              return None
            }
            if stats_uniform01(rng) * total.to_double() < successes.to_double() {
              observed += 1
              successes -= 1
            } else {
              failures -= 1
            }
          }
          Some(@symcore.int(observed))
        }
        _ => None
      }
    DiscreteTag::Skellam if params.length() == 2 =>
      match
        (
          stats_sample_poisson(params[0], rng),
          stats_sample_poisson(params[1], rng),
        ) {
        (Some(a), Some(b)) =>
          match (expr_as_int(a), expr_as_int(b)) {
            (Some(x), Some(y)) => Some(@symcore.int(x - y))
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn sample_random_var_with_rng(
  rv : RandomVar,
  rng : @random.Rand,
) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(items) => stats_sample_finite(items, rng)
    RVKind::Binomial(n~, p~) => stats_sample_binomial(n, p, rng)
    RVKind::Poisson(rate~) => stats_sample_poisson(rate, rng)
    RVKind::Geometric(p~) => stats_sample_geometric(p, rng)
    RVKind::NegativeBinomial(r~, p~) =>
      stats_sample_negative_binomial(r, p, rng)
    RVKind::Normal(mu~, sigma~) =>
      stats_sample_continuous_normal(mu, sigma, rng)
    RVKind::Exponential(rate~) => stats_sample_exponential(rate, rng)
    RVKind::Gamma(shape~, scale~) => stats_sample_gamma(shape, scale, rng)
    RVKind::JointIndependent(items) => {
      let values : Array[@symcore.Expr] = []
      for item in items {
        match sample_random_var_with_rng(item, rng) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(@symcore.Expr::Tuple(values))
    }
    RVKind::Compound(items) => {
      let weighted : Array[(@symcore.Expr, @symnum.BigRational)] = []
      for item in items {
        let (weight, component) = item
        weighted.push((@symcore.Expr::Symbol(component.name), weight))
      }
      match stats_sample_finite(weighted, rng) {
        Some(@symcore.Expr::Symbol(name)) => {
          for item in items {
            let (_, component) = item
            if component.name == name {
              return sample_random_var_with_rng(component, rng)
            }
          }
          None
        }
        _ => None
      }
    }
    RVKind::Symbolic(kind~, params~) =>
      match kind {
        SymbolicKind::Continuous(tag) =>
          stats_sample_symbolic_continuous(tag, params, rng)
        SymbolicKind::Discrete(tag) =>
          stats_sample_symbolic_discrete(tag, params, rng)
        SymbolicKind::Joint(_)
        | SymbolicKind::Process(_)
        | SymbolicKind::Matrix(_) => None
      }
    RVKind::StochasticProcess(_) | RVKind::Matrix(_) => None
  }
}

///|
pub fn sample_random_var(rv : RandomVar, seed? : Int? = None) -> @symcore.Expr? {
  sample_random_var_with_rng(rv, stats_rng(seed~))
}

///|
fn sample_random_var_many(
  rv : RandomVar,
  n : Int,
  seed? : Int? = None,
) -> Array[@symcore.Expr]? {
  if n < 0 {
    return None
  }
  let rng = stats_rng(seed~)
  let out : Array[@symcore.Expr] = []
  for _ in 0..<n {
    match sample_random_var_with_rng(rv, rng) {
      Some(value) => out.push(value)
      None => return None
    }
  }
  Some(out)
}

///|
pub fn do_sample_numpy(
  rv : RandomVar,
  n? : Int = 1,
  seed? : Int? = None,
) -> Array[@symcore.Expr]? {
  sample_random_var_many(rv, n, seed~)
}

///|
pub fn do_sample_scipy(
  rv : RandomVar,
  n? : Int = 1,
  seed? : Int? = None,
) -> Array[@symcore.Expr]? {
  sample_random_var_many(rv, n, seed~)
}

///|
pub fn do_sample_pymc(
  rv : RandomVar,
  n? : Int = 1,
  seed? : Int? = None,
) -> Array[@symcore.Expr]? {
  sample_random_var_many(rv, n, seed~)
}

///|
fn sample_env_with_rng(
  rvs : Array[RandomVar],
  rng : @random.Rand,
) -> Map[String, @symcore.Expr]? {
  let env : Map[String, @symcore.Expr] = {}
  for rv in rvs {
    match sample_random_var_with_rng(rv, rng) {
      Some(value) => env[rv.name] = value
      None => return None
    }
  }
  Some(env)
}

///|
fn sample_expr_with_rng(
  expr : @symcore.Expr,
  rvs : Array[RandomVar],
  rng : @random.Rand,
) -> @symcore.Expr? {
  if rvs.is_empty() {
    return Some(expr)
  }
  match sample_env_with_rng(rvs, rng) {
    Some(env) => Some(eval_arith(@symcore.subst(expr, env)))
    None => None
  }
}

///|
pub fn sample_expr(
  expr : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
  seed? : Int? = None,
) -> @symcore.Expr? {
  sample_expr_with_rng(expr, rvs, stats_rng(seed~))
}
