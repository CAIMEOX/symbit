///|
/// Stochastic process starter layer.

///|
pub fn poisson_process(
  name : String,
  rate : @symcore.Expr,
  time_symbol? : String = "t",
) -> RandomVar {
  random_var(name, RVKind::StochasticProcess(ProcessKind::PoissonProcess(rate~, time_symbol~)))
}

///|
pub fn wiener_process(
  name : String,
  time_symbol? : String = "t",
) -> RandomVar {
  random_var(name, RVKind::StochasticProcess(ProcessKind::WienerProcess(time_symbol~)))
}

///|
pub fn process_value(proc : RandomVar, t : @symcore.Expr) -> @symcore.Expr {
  @symcore.function(proc.name, [t])
}

///|
fn process_expr_sub(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.add([a, @symcore.mul([@symcore.int(-1), b])])
}

///|
pub fn process_mean_at(proc : RandomVar, t : @symcore.Expr) -> @symcore.Expr? {
  match proc.kind {
    RVKind::StochasticProcess(ProcessKind::PoissonProcess(rate~, ..)) =>
      Some(eval_arith(@symcore.mul([rate, t])))
    RVKind::StochasticProcess(ProcessKind::WienerProcess(..)) => Some(@symcore.int(0))
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) == "P" {
        let args : Array[@symcore.Expr] = [t]
        for p in params {
          args.push(p)
        }
        Some(@symcore.function("\{symbolic_tag_name(tag)}MeanAt", args))
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn process_variance_at(proc : RandomVar, t : @symcore.Expr) -> @symcore.Expr? {
  match proc.kind {
    RVKind::StochasticProcess(ProcessKind::PoissonProcess(rate~, ..)) =>
      Some(eval_arith(@symcore.mul([rate, t])))
    RVKind::StochasticProcess(ProcessKind::WienerProcess(..)) => Some(t)
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) == "P" {
        let args : Array[@symcore.Expr] = [t]
        for p in params {
          args.push(p)
        }
        Some(@symcore.function("\{symbolic_tag_name(tag)}VarianceAt", args))
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn process_increment_mean(
  proc : RandomVar,
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
) -> @symcore.Expr? {
  process_mean_at(proc, process_expr_sub(t1, t0))
}

///|
pub fn process_increment_variance(
  proc : RandomVar,
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
) -> @symcore.Expr? {
  process_variance_at(proc, process_expr_sub(t1, t0))
}

///|
pub fn process_transition_probability(
  proc : RandomVar,
  from : @symcore.Expr,
  to : @symcore.Expr,
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
) -> @symcore.Expr? {
  let delta_t = process_expr_sub(t1, t0)
  let k = eval_arith(process_expr_sub(to, from))
  match proc.kind {
    RVKind::StochasticProcess(ProcessKind::PoissonProcess(rate~, ..)) =>
      Some(eval_arith(@symcore.mul([
        @symcore.function("exp", [@symcore.mul([@symcore.int(-1), rate, delta_t])]),
        @symcore.pow(eval_arith(@symcore.mul([rate, delta_t])), k),
        @symcore.pow(@symcore.function("factorial", [k]), @symcore.int(-1)),
      ])))
    RVKind::StochasticProcess(ProcessKind::WienerProcess(..)) =>
      Some(@symcore.function("NormalTransitionProb", [from, to, delta_t]))
    RVKind::Symbolic(tag~, params~) =>
      if symbolic_tag_family(tag) == "P" {
        let args : Array[@symcore.Expr] = [from, to, t0, t1]
        for p in params {
          args.push(p)
        }
        Some(@symcore.function("\{symbolic_tag_name(tag)}TransitionProb", args))
      } else {
        None
      }
    _ => None
  }
}
