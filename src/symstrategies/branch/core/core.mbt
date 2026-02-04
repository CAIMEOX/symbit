///|\
/// Branching strategies (core).

///|
pub type BRule[T] = (T) -> Array[T]

///|
/// Identity branching rule.
pub fn[T] identity(x : T) -> Array[T] {
  [x]
}

///|
/// Apply a branching rule repeatedly until it has no effect.
pub fn[T : Eq + Hash] exhaust(brule : BRule[T]) -> BRule[T] {
  (expr : T) => {
    let seen : Map[T, Bool] = Map::new()
    seen[expr] = true
    let out : Array[T] = Array::new()
    let mut progressed = false
    for nexpr in brule(expr) {
      if !seen.contains(nexpr) {
        seen[nexpr] = true
        progressed = true
        for item in exhaust(brule)(nexpr) {
          out.push(item)
        }
      }
    }
    if !progressed {
      out.push(expr)
    }
    out
  }
}

///|
/// Invoke a callback on each action.
pub fn[T : Eq] onaction(
  brule : BRule[T],
  action : (BRule[T], T, T) -> Unit,
) -> BRule[T] {
  (expr : T) => {
    let out : Array[T] = Array::new()
    for result in brule(expr) {
      if result != expr {
        action(brule, expr, result)
      }
      out.push(result)
    }
    out
  }
}

///|
/// Print input and output expressions at each rule application.
pub fn[T : Eq + Show] debug(
  brule : BRule[T],
  name? : String = "rule",
  write? : (String) -> Unit = s => println(s),
) -> BRule[T] {
  let logger = (rule : BRule[T], expr : T, result : T) => {
    ignore(rule)
    write("Rule: " + name + "\n")
    write("In: " + expr.to_string() + "\nOut: " + result.to_string() + "\n\n")
  }
  onaction(brule, logger)
}

///|
/// Multiplex many branching rules into one.
pub fn[T : Eq + Hash] multiplex(brules : Array[BRule[T]]) -> BRule[T] {
  (expr : T) => {
    let seen : Map[T, Bool] = Map::new()
    let out : Array[T] = Array::new()
    for brule in brules {
      for nexpr in brule(expr) {
        if !seen.contains(nexpr) {
          seen[nexpr] = true
          out.push(nexpr)
        }
      }
    }
    out
  }
}

///|
/// Only apply branching rule if condition is true.
pub fn[T] condition(cond : (T) -> Bool, brule : BRule[T]) -> BRule[T] {
  (expr : T) => if cond(expr) { brule(expr) } else { [] }
}

///|
/// Yield only results which satisfy the predicate.
pub fn[T] sfilter(pred : (T) -> Bool, brule : BRule[T]) -> BRule[T] {
  (expr : T) => {
    let out : Array[T] = Array::new()
    for nexpr in brule(expr) {
      if pred(nexpr) {
        out.push(nexpr)
      }
    }
    out
  }
}

///|
/// Ensure a branching rule yields at least one result.
pub fn[T] notempty(brule : BRule[T]) -> BRule[T] {
  (expr : T) => {
    let res = brule(expr)
    if res.is_empty() {
      [expr]
    } else {
      res
    }
  }
}

///|
/// Execute one of the branching rules.
pub fn[T] do_one(brules : Array[BRule[T]]) -> BRule[T] {
  (expr : T) => {
    for brule in brules {
      let res = brule(expr)
      if !res.is_empty() {
        return res
      }
    }
    []
  }
}

///|
/// Compose a sequence of brules so that they apply sequentially.
pub fn[T] chain(brules : Array[BRule[T]]) -> BRule[T] {
  (expr : T) => {
    if brules.is_empty() {
      return [expr]
    }
    let mut cur : Array[T] = [expr]
    for brule in brules {
      let next : Array[T] = Array::new()
      for item in cur {
        for nexpr in brule(item) {
          next.push(nexpr)
        }
      }
      cur = next
    }
    cur
  }
}

///|
/// Turn a rule into a branching rule.
pub fn[T] yieldify(rule : (T) -> T) -> BRule[T] {
  (expr : T) => [rule(expr)]
}
