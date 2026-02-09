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
        let name = symbolic_tag_name(tag)
        match name {
          "BernoulliProcess" if params.length() >= 1 => {
            let p = params[0]
            let success =
              if params.length() >= 2 {
                params[1]
              } else {
                @symcore.int(1)
              }
            let failure =
              if params.length() >= 3 {
                params[2]
              } else {
                @symcore.int(0)
              }
            Some(eval_arith(@symcore.add([
              @symcore.mul([p, success]),
              @symcore.mul([eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])])), failure]),
            ])))
          }
          "GammaProcess" if params.length() >= 2 => {
            let lamda = params[0]
            let gamma = params[1]
            Some(eval_arith(@symcore.mul([
              gamma,
              t,
              @symcore.pow(lamda, @symcore.int(-1)),
            ])))
          }
          _ => {
            let args : Array[@symcore.Expr] = [t]
            for p in params {
              args.push(p)
            }
            Some(@symcore.function("\{name}MeanAt", args))
          }
        }
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
        let name = symbolic_tag_name(tag)
        match name {
          "BernoulliProcess" if params.length() >= 1 => {
            let p = params[0]
            let success =
              if params.length() >= 2 {
                params[1]
              } else {
                @symcore.int(1)
              }
            let failure =
              if params.length() >= 3 {
                params[2]
              } else {
                @symcore.int(0)
              }
            Some(eval_arith(@symcore.mul([
              p,
              eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])])),
              @symcore.pow(eval_arith(@symcore.add([success, @symcore.mul([@symcore.int(-1), failure])])), @symcore.int(2)),
            ])))
          }
          "GammaProcess" if params.length() >= 2 => {
            let lamda = params[0]
            let gamma = params[1]
            Some(eval_arith(@symcore.mul([
              gamma,
              t,
              @symcore.pow(lamda, @symcore.int(-2)),
            ])))
          }
          _ => {
            let args : Array[@symcore.Expr] = [t]
            for p in params {
              args.push(p)
            }
            Some(@symcore.function("\{name}VarianceAt", args))
          }
        }
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
  if @symcore.compare_expr(t0, t1) == 0 {
    return Some(@symcore.function("Piecewise", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.function("Eq", [to, from])]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.symbol("True")]),
    ]))
  }
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
        let name = symbolic_tag_name(tag)
        match name {
          "DiscreteMarkovChain" if params.length() >= 1 => {
            let tmat = params[0]
            Some(@symcore.function("MatrixElement", [
              @symcore.pow(tmat, delta_t),
              from,
              to,
            ]))
          }
          "ContinuousMarkovChain" if params.length() >= 1 => {
            let qmat = params[0]
            Some(@symcore.function("MatrixElement", [
              @symcore.function("MatrixExp", [eval_arith(@symcore.mul([delta_t, qmat]))]),
              from,
              to,
            ]))
          }
          "BernoulliProcess" if params.length() >= 1 => {
            let p = params[0]
            let success =
              if params.length() >= 2 {
                params[1]
              } else {
                @symcore.int(1)
              }
            let failure =
              if params.length() >= 3 {
                params[2]
              } else {
                @symcore.int(0)
              }
            Some(eval_arith(@symcore.function("Piecewise", [
              @symcore.function("Tuple", [p, @symcore.function("Eq", [to, success])]),
              @symcore.function("Tuple", [eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])])), @symcore.function("Eq", [to, failure])]),
              @symcore.function("Tuple", [@symcore.int(0), @symcore.symbol("True")]),
            ])))
          }
          "GammaProcess" if params.length() >= 2 => {
            let lamda = params[0]
            let gamma = params[1]
            let delta = eval_arith(process_expr_sub(to, from))
            let k = eval_arith(@symcore.mul([gamma, process_expr_sub(t1, t0)]))
            Some(@symcore.function("Piecewise", [
              @symcore.function("Tuple", [eval_arith(@symcore.mul([
                @symcore.pow(lamda, k),
                @symcore.pow(delta, eval_arith(@symcore.add([k, @symcore.int(-1)]))),
                @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.int(-1), lamda, delta]))]),
                @symcore.pow(@symcore.function("gamma", [k]), @symcore.int(-1)),
              ])), @symcore.function("Ge", [delta, @symcore.int(0)])]),
              @symcore.function("Tuple", [@symcore.int(0), @symcore.symbol("True")]),
            ]))
          }
          _ => {
            let args : Array[@symcore.Expr] = [from, to, t0, t1]
            for p in params {
              args.push(p)
            }
            Some(@symcore.function("\{name}TransitionProb", args))
          }
        }
      } else {
        None
      }
    _ => None
  }
}
