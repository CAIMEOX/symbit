///|\
/// Core strategy combinators.

///|
pub fn[T] identity(x : T) -> T {
  x
}

///|
/// Apply a rule repeatedly until it has no effect.
pub fn[T : Eq] exhaust(rule : (T) -> T) -> (T) -> T {
  (expr : T) => {
    let mut old = expr
    let mut new = rule(expr)
    while new != old {
      old = new
      new = rule(new)
    }
    new
  }
}

///|
/// Memoized version of a rule.
pub fn[T : Eq + Hash, U] memoize(rule : (T) -> U) -> (T) -> U {
  let cache : Map[T, U] = Map::new()
  (expr : T) => {
    match cache.get(expr) {
      Some(v) => v
      None => {
        let res = rule(expr)
        cache[expr] = res
        res
      }
    }
  }
}

///|
/// Only apply rule if condition is true.
pub fn[T] condition(cond : (T) -> Bool, rule : (T) -> T) -> (T) -> T {
  (expr : T) => if cond(expr) { rule(expr) } else { expr }
}

///|
/// Compose a sequence of rules so that they apply sequentially.
pub fn[T] chain(rules : Array[(T) -> T]) -> (T) -> T {
  (expr : T) => {
    let mut cur = expr
    for rule in rules {
      cur = rule(cur)
    }
    cur
  }
}

///|
/// Print before/after expressions each time rule is used.
///
/// Note: `name` is required to emulate Python's `__name__`.
pub fn[T : Eq + Show] debug(
  rule : (T) -> T,
  name? : String = "rule",
  write? : (String) -> Unit = s => println(s),
) -> (T) -> T {
  (expr : T) => {
    let result = rule(expr)
    if result != expr {
      write("Rule: " + name + "\n")
      write("In:   " + expr.to_string() + "\n")
      write("Out:  " + result.to_string() + "\n\n")
    }
    result
  }
}

///|
/// Return original expr if rule returns None.
pub fn[T] null_safe(rule : (T) -> T?) -> (T) -> T {
  (expr : T) => {
    match rule(expr) {
      Some(res) => res
      None => expr
    }
  }
}

///|
/// Return original expr if rule raises an error.
pub fn[T] tryit(rule : (T) -> T raise, _exception? : String = "") -> (T) -> T {
  (expr : T) => rule(expr) catch { _ => expr }
}

///|
/// Try each rule until one changes the expression.
pub fn[T : Eq] do_one(rules : Array[(T) -> T]) -> (T) -> T {
  (expr : T) => {
    for rule in rules {
      let res = rule(expr)
      if res != expr {
        return res
      }
    }
    expr
  }
}

///|
/// Select a rule based on the result of key called on the expr.
pub fn[T, K : Eq + Hash] switch(
  key : (T) -> K,
  ruledict : Map[K, (T) -> T],
) -> (T) -> T {
  (expr : T) => {
    match ruledict.get(key(expr)) {
      Some(rule) => rule(expr)
      None => identity(expr)
    }
  }
}

///|
/// Select result of rules that minimizes objective.
pub fn[T : Compare] minimize(
  rules : Array[(T) -> T],
  objective? : (T) -> T = identity,
) -> (T) -> T {
  (expr : T) => {
    if rules.is_empty() {
      return expr
    }
    let mut best = rules[0](expr)
    let mut best_key = objective(best)
    for i in 1..<rules.length() {
      let candidate = rules[i](expr)
      let cand_key = objective(candidate)
      if cand_key.compare(best_key) < 0 {
        best = candidate
        best_key = cand_key
      }
    }
    best
  }
}
