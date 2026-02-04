///|
/// Shared helpers for boolalg.

///|
fn collect_symbol_names(expr : BoolExpr, seen : Map[String, BoolExpr]) -> Unit {
  match expr {
    BoolExpr::Symbol(name) => seen[name] = expr
    BoolExpr::LRA(constraint) => {
      let key = linear_constraint_key(constraint)
      seen[key] = expr
    }
    BoolExpr::Not(inner) => collect_symbol_names(inner, seen)
    BoolExpr::And(args)
    | BoolExpr::Or(args)
    | BoolExpr::Xor(args)
    | BoolExpr::Equivalent(args) =>
      for arg in args {
        collect_symbol_names(arg, seen)
      }
    BoolExpr::Implies(a, b) => {
      collect_symbol_names(a, seen)
      collect_symbol_names(b, seen)
    }
    BoolExpr::ITE(c, t, e) => {
      collect_symbol_names(c, seen)
      collect_symbol_names(t, seen)
      collect_symbol_names(e, seen)
    }
    _ => ()
  }
}

///|
pub fn symbols_in(expr : BoolExpr) -> Array[BoolExpr] {
  let seen : Map[String, BoolExpr] = Map::new()
  collect_symbol_names(expr, seen)
  let names : Array[String] = Array::new()
  for name, _ in seen {
    names.push(name)
  }
  names.sort()
  let out : Array[BoolExpr] = Array::new()
  for name in names {
    match seen.get(name) {
      Some(sym) => out.push(sym)
      None => ()
    }
  }
  out
}

///|
fn symbol_names_from_exprs(vars : Array[BoolExpr]) -> Array[String] {
  let names : Array[String] = Array::new()
  for v in vars {
    match v {
      BoolExpr::Symbol(name) => names.push(name)
      BoolExpr::LRA(constraint) => names.push(linear_constraint_key(constraint))
      _ => ()
    }
  }
  names
}

///|
fn symbol_key(expr : BoolExpr) -> String {
  match expr {
    BoolExpr::Symbol(name) => name
    BoolExpr::LRA(constraint) => linear_constraint_key(constraint)
    _ => ""
  }
}

///|
pub fn bool_subst(expr : BoolExpr, env : Map[String, BoolExpr]) -> BoolExpr {
  match expr {
    BoolExpr::Symbol(name) =>
      match env.get(name) {
        Some(v) => v
        None => expr
      }
    BoolExpr::LRA(constraint) =>
      match env.get(linear_constraint_key(constraint)) {
        Some(v) => v
        None => expr
      }
    BoolExpr::Not(inner) => bool_not(bool_subst(inner, env))
    BoolExpr::And(args) => bool_and(args.map(a => bool_subst(a, env)))
    BoolExpr::Or(args) => bool_or(args.map(a => bool_subst(a, env)))
    BoolExpr::Xor(args) => bool_xor(args.map(a => bool_subst(a, env)))
    BoolExpr::Implies(a, b) =>
      bool_implies(bool_subst(a, env), bool_subst(b, env))
    BoolExpr::Equivalent(args) =>
      bool_equivalent(args.map(a => bool_subst(a, env)))
    BoolExpr::ITE(c, t, e) =>
      bool_ite(bool_subst(c, env), bool_subst(t, env), bool_subst(e, env))
    _ => expr
  }
}

///|
pub fn bool_eval(expr : BoolExpr, env : Map[String, Bool]) -> Bool {
  match expr {
    BoolExpr::True => true
    BoolExpr::False => false
    BoolExpr::Symbol(name) =>
      match env.get(name) {
        Some(v) => v
        None => false
      }
    BoolExpr::LRA(constraint) =>
      match env.get(linear_constraint_key(constraint)) {
        Some(v) => v
        None => false
      }
    BoolExpr::Not(inner) => !bool_eval(inner, env)
    BoolExpr::And(args) => {
      for arg in args {
        if !bool_eval(arg, env) {
          return false
        }
      }
      true
    }
    BoolExpr::Or(args) => {
      for arg in args {
        if bool_eval(arg, env) {
          return true
        }
      }
      false
    }
    BoolExpr::Xor(args) => {
      let mut count = 0
      for arg in args {
        if bool_eval(arg, env) {
          count += 1
        }
      }
      count % 2 == 1
    }
    BoolExpr::Implies(a, b) =>
      (!bool_eval(a, env)) || bool_eval(b, env)
    BoolExpr::Equivalent(args) => {
      if args.is_empty() {
        return true
      }
      let first = bool_eval(args[0], env)
      for i in 1..<args.length() {
        if bool_eval(args[i], env) != first {
          return false
        }
      }
      true
    }
    BoolExpr::ITE(c, t, e) =>
      if bool_eval(c, env) { bool_eval(t, env) } else { bool_eval(e, env) }
  }
}

///|
fn bit_count(v0 : Int) -> Int {
  let mut v = v0
  let mut count = 0
  while v > 0 {
    if (v & 1) == 1 {
      count += 1
    }
    v = v >> 1
  }
  count
}

///|
fn ibin(value : Int, bits : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in 0..<bits {
    let shift = bits - 1 - i
    out.push((value >> shift) & 1)
  }
  out
}

///|
fn all_bit_vectors(bits : Int) -> Array[Array[Int]] {
  let total = 1 << bits
  let out : Array[Array[Int]] = Array::new()
  for mask in 0..<total {
    out.push(ibin(mask, bits))
  }
  out
}

///|
fn combinations_bool(items : Array[BoolExpr], k : Int) -> Array[Array[BoolExpr]] {
  let out : Array[Array[BoolExpr]] = Array::new()
  if k <= 0 {
    out.push([])
    return out
  }
  let n = items.length()
  if k > n {
    return out
  }
  fn rec(
    items : Array[BoolExpr],
    start : Int,
    k : Int,
    acc : Array[BoolExpr],
    out : Array[Array[BoolExpr]],
  ) -> Unit {
    if k == 0 {
      out.push(acc.copy())
      return
    }
    let n = items.length()
    for i in start..<(n - k + 1) {
      let next = acc.copy()
      next.push(items[i])
      rec(items, i + 1, k - 1, next, out)
    }
  }
  rec(items, 0, k, [], out)
  out
}

///|
fn permutations_strings(items : Array[String]) -> Array[Array[String]] {
  let out : Array[Array[String]] = Array::new()
  let n = items.length()
  let used : Array[Bool] = Array::make(n, false)
  let current : Array[String] = Array::new()
  fn rec(
    items : Array[String],
    used : Array[Bool],
    current : Array[String],
    out : Array[Array[String]],
  ) -> Unit {
    if current.length() == items.length() {
      out.push(current.copy())
      return
    }
    for i in 0..<items.length() {
      if !used[i] {
        used[i] = true
        current.push(items[i])
        rec(items, used, current, out)
        ignore(current.pop())
        used[i] = false
      }
    }
  }
  rec(items, used, current, out)
  out
}
