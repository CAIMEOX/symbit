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
  True
}

///|
pub fn bool_false() -> BoolExpr {
  False
}

///|
pub fn bool_symbol(name : String) -> BoolExpr {
  Symbol(name)
}

///|
pub fn bool_not(expr : BoolExpr) -> BoolExpr {
  match expr {
    True => False
    False => True
    Not(inner) => inner
    _ => Not(expr)
  }
}

///|
pub fn bool_and(args : Array[BoolExpr]) -> BoolExpr {
  let flat : Array[BoolExpr] = Array::new()
  let mut has_false = false
  for arg in args {
    match arg {
      And(inner) =>
        for child in inner {
          flat.push(child)
        }
      False => has_false = true
      True => ()
      _ => flat.push(arg)
    }
  }
  if has_false {
    return False
  }
  let uniq : Array[BoolExpr] = Array::new()
  let seen : Map[BoolExpr, Bool] = Map([])
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
    return True
  }
  uniq.sort_by(compare_bool)
  if uniq.length() == 1 {
    uniq[0]
  } else {
    And(uniq)
  }
}

///|
pub fn bool_or(args : Array[BoolExpr]) -> BoolExpr {
  let flat : Array[BoolExpr] = Array::new()
  let mut has_true = false
  for arg in args {
    match arg {
      Or(inner) =>
        for child in inner {
          flat.push(child)
        }
      True => has_true = true
      False => ()
      _ => flat.push(arg)
    }
  }
  if has_true {
    return True
  }
  let uniq : Array[BoolExpr] = Array::new()
  let seen : Map[BoolExpr, Bool] = Map([])
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
    return False
  }
  uniq.sort_by(compare_bool)
  if uniq.length() == 1 {
    uniq[0]
  } else {
    Or(uniq)
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
      Xor(inner) =>
        for child in inner {
          flat.push(child)
        }
      True => true_count += 1
      False => ()
      _ => flat.push(arg)
    }
  }
  let toggled : Map[BoolExpr, Bool] = Map([])
  for arg in flat {
    if toggled.contains(arg) {
      toggled.remove(arg)
    } else {
      toggled[arg] = true
    }
  }
  if toggled.is_empty() {
    if true_count % 2 == 0 {
      return False
    }
    return True
  }
  let uniq : Array[BoolExpr] = Array::new()
  for k, _ in toggled {
    uniq.push(k)
  }
  if keep_true && true_count % 2 == 1 {
    uniq.push(True)
  }
  uniq.sort_by(compare_bool)
  if keep_true {
    if uniq.length() == 1 {
      return uniq[0]
    }
    return Xor(uniq)
  }
  let base = if uniq.length() == 1 { uniq[0] } else { Xor(uniq) }
  if true_count % 2 == 0 {
    base
  } else {
    bool_not(base)
  }
}

///|
pub fn bool_implies(antecedent : BoolExpr, consequent : BoolExpr) -> BoolExpr {
  if antecedent == True {
    return consequent
  }
  if antecedent == False {
    return True
  }
  if consequent == True {
    return True
  }
  if consequent == False {
    return bool_not(antecedent)
  }
  if antecedent == consequent {
    return True
  }
  Implies(antecedent, consequent)
}

///|
pub fn bool_equivalent(args : Array[BoolExpr]) -> BoolExpr {
  if args.length() <= 1 {
    return True
  }
  let uniq_map : Map[BoolExpr, Bool] = Map([])
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
      True => has_true = true
      False => has_false = true
      _ => rest.push(arg)
    }
  }
  if has_true && has_false {
    return False
  }
  if rest.is_empty() {
    return True
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
    return True
  }
  rest.sort_by(compare_bool)
  Equivalent(rest)
}

///|
pub fn bool_ite(
  cond : BoolExpr,
  then_ : BoolExpr,
  else_ : BoolExpr,
) -> BoolExpr {
  if cond == True {
    return then_
  }
  if cond == False {
    return else_
  }
  if then_ == else_ {
    return then_
  }
  if then_ == True && else_ == False {
    return cond
  }
  if then_ == False && else_ == True {
    return bool_not(cond)
  }
  ITE(cond, then_, else_)
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
    return True
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
impl Show for BoolExpr with fn to_string(self) {
  to_string(self)
}

///|
/// Keep the `BoolExpr::to_string` dot-style API explicit.
#deprecated
pub extend BoolExpr with Show::{to_string}

///|
impl Show for BoolExpr with fn output(self, logger) {
  logger.write_string(Show::to_string(self))
}

///|
fn variant_rank(expr : BoolExpr) -> Int {
  match expr {
    Symbol(_) => 0
    Not(_) => 1
    And(_) => 2
    Or(_) => 3
    Xor(_) => 4
    Implies(_, _) => 5
    Equivalent(_) => 6
    ITE(_, _, _) => 7
    True => 8
    False => 9
    LRA(_) => 10
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
    Symbol(sa) =>
      match b {
        Symbol(sb) => sa.compare(sb)
        _ => 0
      }
    LRA(ca) =>
      match b {
        LRA(cb) => linear_constraint_key(ca).compare(linear_constraint_key(cb))
        _ => 0
      }
    Not(ia) =>
      match b {
        Not(ib) => compare_bool(ia, ib)
        _ => 0
      }
    And(xs) =>
      match b {
        And(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Or(xs) =>
      match b {
        Or(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Xor(xs) =>
      match b {
        Xor(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Implies(a1, b1) =>
      match b {
        Implies(a2, b2) => {
          let first = compare_bool(a1, a2)
          if first != 0 {
            first
          } else {
            compare_bool(b1, b2)
          }
        }
        _ => 0
      }
    Equivalent(xs) =>
      match b {
        Equivalent(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    ITE(c1, t1, e1) =>
      match b {
        ITE(c2, t2, e2) => {
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
pub impl Compare for BoolExpr with fn compare(self, other : BoolExpr) -> Int {
  compare_bool(self, other)
}

///|
pub impl Eq for BoolExpr with fn equal(self, other : BoolExpr) -> Bool {
  compare_bool(self, other) == 0
}

///|
pub impl Eq for BoolExpr with fn not_equal(self, other : BoolExpr) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Hash for BoolExpr with fn hash(self) -> Int {
  let hasher = Hasher()
  Hash::hash_combine(self, hasher)
  hasher.finalize()
}

///|
pub impl Hash for BoolExpr with fn hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(variant_rank(self))
  match self {
    Symbol(name) => hasher.combine_string(name)
    LRA(constraint) => hasher.combine_string(linear_constraint_key(constraint))
    Not(inner) => Hash::hash_combine(inner, hasher)
    And(args) | Or(args) | Xor(args) | Equivalent(args) =>
      for child in args {
        Hash::hash_combine(child, hasher)
      }
    Implies(a, b) => {
      Hash::hash_combine(a, hasher)
      Hash::hash_combine(b, hasher)
    }
    ITE(c, t, e) => {
      Hash::hash_combine(c, hasher)
      Hash::hash_combine(t, hasher)
      Hash::hash_combine(e, hasher)
    }
    _ => ()
  }
}

///|
fn precedence(expr : BoolExpr) -> Int {
  match expr {
    Or(_) => 1
    Xor(_) => 2
    And(_) => 3
    Not(_) => 4
    Implies(_, _) | Equivalent(_) => 0
    _ => 4
  }
}

///|
fn format_expr(expr : BoolExpr, parent_prec : Int) -> String {
  let prec = precedence(expr)
  let body = match expr {
    True => "True"
    False => "False"
    Symbol(name) => name
    LRA(constraint) => Show::to_string(constraint)
    Not(inner) => {
      let inner_str = format_expr(inner, 0)
      let wrapped = if precedence(inner) < prec {
        "(\{inner_str})"
      } else {
        inner_str
      }
      "~\{wrapped}"
    }
    And(args) => args.map(child => format_expr(child, prec)).join(" & ")
    Or(args) => {
      let rendered : Array[String] = Array::new()
      for child in args {
        match child {
          And(_) | Xor(_) | Implies(_, _) | Equivalent(_) =>
            rendered.push("(\{format_expr(child, 0)})")
          _ => rendered.push(format_expr(child, prec))
        }
      }
      rendered.join(" | ")
    }
    Xor(args) => {
      let rendered : Array[String] = Array::new()
      for child in args {
        match child {
          And(_) | Or(_) | Implies(_, _) | Equivalent(_) =>
            rendered.push("(\{format_expr(child, 0)})")
          _ => rendered.push(format_expr(child, prec))
        }
      }
      rendered.join(" ^ ")
    }
    Implies(a, b) => "Implies(\{format_expr(a, 0)}, \{format_expr(b, 0)})"
    Equivalent(args) => {
      let rendered = args.map(child => format_expr(child, 0)).join(", ")
      "Equivalent(\{rendered})"
    }
    ITE(c, t, e) =>
      "ITE(\{format_expr(c, 0)}, \{format_expr(t, 0)}, \{format_expr(e, 0)})"
  }
  if prec < parent_prec {
    "(\{body})"
  } else {
    body
  }
}
