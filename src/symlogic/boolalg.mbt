///|
/// Boolean algebra (subset of SymPy logic.boolalg).

///|
pub(all) enum BoolExpr {
  True
  False
  Symbol(String)
  LRA(LinearConstraint)
  Not(BoolExpr)
  And(Array[BoolExpr])
  Or(Array[BoolExpr])
  Xor(Array[BoolExpr])
  Implies(BoolExpr, BoolExpr)
  Equivalent(Array[BoolExpr])
  ITE(BoolExpr, BoolExpr, BoolExpr)
}

///|
pub fn bool_true() -> BoolExpr {
  BoolExpr::True
}

///|
pub fn bool_false() -> BoolExpr {
  BoolExpr::False
}

///|
pub fn bool_symbol(name : String) -> BoolExpr {
  BoolExpr::Symbol(name)
}

///|
pub fn bool_not(expr : BoolExpr) -> BoolExpr {
  match expr {
    BoolExpr::True => BoolExpr::False
    BoolExpr::False => BoolExpr::True
    BoolExpr::Not(inner) => inner
    _ => BoolExpr::Not(expr)
  }
}

///|
pub fn bool_and(args : Array[BoolExpr]) -> BoolExpr {
  let flat : Array[BoolExpr] = Array::new()
  let mut has_false = false
  for arg in args {
    match arg {
      BoolExpr::And(inner) =>
        for child in inner {
          flat.push(child)
        }
      BoolExpr::False => has_false = true
      BoolExpr::True => ()
      _ => flat.push(arg)
    }
  }
  if has_false {
    return BoolExpr::False
  }
  let uniq : Array[BoolExpr] = Array::new()
  let seen : Map[BoolExpr, Bool] = Map::new()
  for arg in flat {
    match seen.get(arg) {
      Some(_) => ()
      None => {
        seen[arg] = true
        uniq.push(arg)
      }
    }
  }
  if uniq.is_empty() {
    return BoolExpr::True
  }
  uniq.sort_by(compare_bool)
  if uniq.length() == 1 {
    uniq[0]
  } else {
    BoolExpr::And(uniq)
  }
}

///|
pub fn bool_or(args : Array[BoolExpr]) -> BoolExpr {
  let flat : Array[BoolExpr] = Array::new()
  let mut has_true = false
  for arg in args {
    match arg {
      BoolExpr::Or(inner) =>
        for child in inner {
          flat.push(child)
        }
      BoolExpr::True => has_true = true
      BoolExpr::False => ()
      _ => flat.push(arg)
    }
  }
  if has_true {
    return BoolExpr::True
  }
  let uniq : Array[BoolExpr] = Array::new()
  let seen : Map[BoolExpr, Bool] = Map::new()
  for arg in flat {
    match seen.get(arg) {
      Some(_) => ()
      None => {
        seen[arg] = true
        uniq.push(arg)
      }
    }
  }
  if uniq.is_empty() {
    return BoolExpr::False
  }
  uniq.sort_by(compare_bool)
  if uniq.length() == 1 {
    uniq[0]
  } else {
    BoolExpr::Or(uniq)
  }
}

///|
pub fn bool_xor(args : Array[BoolExpr]) -> BoolExpr {
  xor_internal(args, false)
}

///|
fn xor_keep_true(args : Array[BoolExpr]) -> BoolExpr {
  xor_internal(args, true)
}

///|
fn xor_internal(args : Array[BoolExpr], keep_true : Bool) -> BoolExpr {
  let flat : Array[BoolExpr] = Array::new()
  let mut true_count = 0
  for arg in args {
    match arg {
      BoolExpr::Xor(inner) =>
        for child in inner {
          flat.push(child)
        }
      BoolExpr::True => true_count += 1
      BoolExpr::False => ()
      _ => flat.push(arg)
    }
  }
  let toggled : Map[BoolExpr, Bool] = Map::new()
  for arg in flat {
    if toggled.contains(arg) {
      toggled.remove(arg)
    } else {
      toggled[arg] = true
    }
  }
  if toggled.is_empty() {
    if true_count % 2 == 0 {
      return BoolExpr::False
    }
    return BoolExpr::True
  }
  let uniq : Array[BoolExpr] = Array::new()
  for k, _ in toggled {
    uniq.push(k)
  }
  if keep_true && true_count % 2 == 1 {
    uniq.push(BoolExpr::True)
  }
  uniq.sort_by(compare_bool)
  if keep_true {
    if uniq.length() == 1 {
      return uniq[0]
    }
    return BoolExpr::Xor(uniq)
  }
  let base = if uniq.length() == 1 { uniq[0] } else { BoolExpr::Xor(uniq) }
  if true_count % 2 == 0 {
    base
  } else {
    bool_not(base)
  }
}

///|
pub fn bool_implies(antecedent : BoolExpr, consequent : BoolExpr) -> BoolExpr {
  if antecedent == BoolExpr::True {
    return consequent
  }
  if antecedent == BoolExpr::False {
    return BoolExpr::True
  }
  if consequent == BoolExpr::True {
    return BoolExpr::True
  }
  if consequent == BoolExpr::False {
    return bool_not(antecedent)
  }
  if antecedent == consequent {
    return BoolExpr::True
  }
  BoolExpr::Implies(antecedent, consequent)
}

///|
pub fn bool_equivalent(args : Array[BoolExpr]) -> BoolExpr {
  if args.length() <= 1 {
    return BoolExpr::True
  }
  let uniq_map : Map[BoolExpr, Bool] = Map::new()
  for arg in args {
    uniq_map[arg] = true
  }
  let uniq : Array[BoolExpr] = Array::new()
  for k, _ in uniq_map {
    uniq.push(k)
  }
  let mut has_true = false
  let mut has_false = false
  let rest : Array[BoolExpr] = Array::new()
  for arg in uniq {
    match arg {
      BoolExpr::True => has_true = true
      BoolExpr::False => has_false = true
      _ => rest.push(arg)
    }
  }
  if has_true && has_false {
    return BoolExpr::False
  }
  if rest.is_empty() {
    return BoolExpr::True
  }
  if has_true {
    return bool_and(rest)
  }
  if has_false {
    let negs : Array[BoolExpr] = Array::new()
    for arg in rest {
      negs.push(bool_not(arg))
    }
    return bool_and(negs)
  }
  if rest.length() == 1 {
    return BoolExpr::True
  }
  rest.sort_by(compare_bool)
  BoolExpr::Equivalent(rest)
}

///|
pub fn bool_ite(
  cond : BoolExpr,
  then_ : BoolExpr,
  else_ : BoolExpr,
) -> BoolExpr {
  if cond == BoolExpr::True {
    return then_
  }
  if cond == BoolExpr::False {
    return else_
  }
  if then_ == else_ {
    return then_
  }
  if then_ == BoolExpr::True && else_ == BoolExpr::False {
    return cond
  }
  if then_ == BoolExpr::False && else_ == BoolExpr::True {
    return bool_not(cond)
  }
  BoolExpr::ITE(cond, then_, else_)
}

///|
pub fn bool_nand(args : Array[BoolExpr]) -> BoolExpr {
  bool_not(bool_and(args))
}

///|
pub fn bool_nor(args : Array[BoolExpr]) -> BoolExpr {
  bool_not(bool_or(args))
}

///|
pub fn bool_xnor(args : Array[BoolExpr]) -> BoolExpr {
  bool_not(bool_xor(args))
}

///|
pub fn bool_exclusive(args : Array[BoolExpr]) -> BoolExpr {
  let and_args : Array[BoolExpr] = Array::new()
  let n = args.length()
  if n <= 1 {
    return BoolExpr::True
  }
  for i in 0..<n {
    for j in (i + 1)..<n {
      and_args.push(bool_not(bool_and([args[i], args[j]])))
    }
  }
  bool_and(and_args)
}

///|
pub fn to_string(expr : BoolExpr) -> String {
  format_expr(expr, 0)
}

///|
impl Show for BoolExpr with to_string(self) {
  to_string(self)
}

///|
impl Show for BoolExpr with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
fn variant_rank(expr : BoolExpr) -> Int {
  match expr {
    BoolExpr::Symbol(_) => 0
    BoolExpr::Not(_) => 1
    BoolExpr::And(_) => 2
    BoolExpr::Or(_) => 3
    BoolExpr::Xor(_) => 4
    BoolExpr::Implies(_, _) => 5
    BoolExpr::Equivalent(_) => 6
    BoolExpr::ITE(_, _, _) => 7
    BoolExpr::True => 8
    BoolExpr::False => 9
    BoolExpr::LRA(_) => 10
  }
}

///|
fn compare_arrays(xs : Array[BoolExpr], ys : Array[BoolExpr]) -> Int {
  let len_x = xs.length()
  let len_y = ys.length()
  let len_cmp = cmp_int(len_x, len_y)
  if len_cmp != 0 {
    return len_cmp
  }
  for i in 0..<len_x {
    let cmp = compare_bool(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  0
}

///|
fn cmp_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn compare_bool(a : BoolExpr, b : BoolExpr) -> Int {
  let rank_diff = cmp_int(variant_rank(a), variant_rank(b))
  if rank_diff != 0 {
    return rank_diff
  }
  match a {
    BoolExpr::Symbol(sa) =>
      match b {
        BoolExpr::Symbol(sb) => sa.compare(sb)
        _ => 0
      }
    BoolExpr::LRA(ca) =>
      match b {
        BoolExpr::LRA(cb) =>
          linear_constraint_key(ca).compare(linear_constraint_key(cb))
        _ => 0
      }
    BoolExpr::Not(ia) =>
      match b {
        BoolExpr::Not(ib) => compare_bool(ia, ib)
        _ => 0
      }
    BoolExpr::And(xs) =>
      match b {
        BoolExpr::And(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    BoolExpr::Or(xs) =>
      match b {
        BoolExpr::Or(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    BoolExpr::Xor(xs) =>
      match b {
        BoolExpr::Xor(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    BoolExpr::Implies(a1, b1) =>
      match b {
        BoolExpr::Implies(a2, b2) => {
          let first = compare_bool(a1, a2)
          if first != 0 {
            first
          } else {
            compare_bool(b1, b2)
          }
        }
        _ => 0
      }
    BoolExpr::Equivalent(xs) =>
      match b {
        BoolExpr::Equivalent(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    BoolExpr::ITE(c1, t1, e1) =>
      match b {
        BoolExpr::ITE(c2, t2, e2) => {
          let first = compare_bool(c1, c2)
          if first != 0 {
            first
          } else {
            let second = compare_bool(t1, t2)
            if second != 0 {
              second
            } else {
              compare_bool(e1, e2)
            }
          }
        }
        _ => 0
      }
    _ => 0
  }
}

///|
pub impl Compare for BoolExpr with compare(self, other : BoolExpr) -> Int {
  compare_bool(self, other)
}

///|
pub impl Eq for BoolExpr with equal(self, other : BoolExpr) -> Bool {
  compare_bool(self, other) == 0
}

///|
pub impl Eq for BoolExpr with not_equal(self, other : BoolExpr) -> Bool {
  !self.equal(other)
}

///|
pub impl Hash for BoolExpr with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for BoolExpr with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(variant_rank(self))
  match self {
    BoolExpr::Symbol(name) => hasher.combine_string(name)
    BoolExpr::LRA(constraint) =>
      hasher.combine_string(linear_constraint_key(constraint))
    BoolExpr::Not(inner) => inner.hash_combine(hasher)
    BoolExpr::And(args)
    | BoolExpr::Or(args)
    | BoolExpr::Xor(args)
    | BoolExpr::Equivalent(args) =>
      for child in args {
        child.hash_combine(hasher)
      }
    BoolExpr::Implies(a, b) => {
      a.hash_combine(hasher)
      b.hash_combine(hasher)
    }
    BoolExpr::ITE(c, t, e) => {
      c.hash_combine(hasher)
      t.hash_combine(hasher)
      e.hash_combine(hasher)
    }
    _ => ()
  }
}

///|
fn precedence(expr : BoolExpr) -> Int {
  match expr {
    BoolExpr::Or(_) => 1
    BoolExpr::Xor(_) => 2
    BoolExpr::And(_) => 3
    BoolExpr::Not(_) => 4
    BoolExpr::Implies(_, _) | BoolExpr::Equivalent(_) => 0
    _ => 4
  }
}

///|
fn format_expr(expr : BoolExpr, parent_prec : Int) -> String {
  let prec = precedence(expr)
  let body = match expr {
    BoolExpr::True => "True"
    BoolExpr::False => "False"
    BoolExpr::Symbol(name) => name
    BoolExpr::LRA(constraint) => linear_constraint_to_string(constraint)
    BoolExpr::Not(inner) => {
      let inner_str = format_expr(inner, 0)
      let wrapped = if precedence(inner) < prec {
        "(\{inner_str})"
      } else {
        inner_str
      }
      "~\{wrapped}"
    }
    BoolExpr::And(args) =>
      args.map(child => format_expr(child, prec)).join(" & ")
    BoolExpr::Or(args) => {
      let rendered : Array[String] = Array::new()
      for child in args {
        match child {
          BoolExpr::And(_)
          | BoolExpr::Xor(_)
          | BoolExpr::Implies(_, _)
          | BoolExpr::Equivalent(_) =>
            rendered.push("(\{format_expr(child, 0)})")
          _ => rendered.push(format_expr(child, prec))
        }
      }
      rendered.join(" | ")
    }
    BoolExpr::Xor(args) => {
      let rendered : Array[String] = Array::new()
      for child in args {
        match child {
          BoolExpr::And(_)
          | BoolExpr::Or(_)
          | BoolExpr::Implies(_, _)
          | BoolExpr::Equivalent(_) =>
            rendered.push("(\{format_expr(child, 0)})")
          _ => rendered.push(format_expr(child, prec))
        }
      }
      rendered.join(" ^ ")
    }
    BoolExpr::Implies(a, b) =>
      "Implies(\{format_expr(a, 0)}, \{format_expr(b, 0)})"
    BoolExpr::Equivalent(args) => {
      let rendered = args.map(child => format_expr(child, 0)).join(", ")
      "Equivalent(\{rendered})"
    }
    BoolExpr::ITE(c, t, e) =>
      "ITE(\{format_expr(c, 0)}, \{format_expr(t, 0)}, \{format_expr(e, 0)})"
  }
  if prec < parent_prec {
    "(\{body})"
  } else {
    body
  }
}
