///|
fn variant_rank(expr : Expr) -> Int {
  match expr {
    Expr::Pow(_, _) => 0
    Expr::Mul(_) => 1
    Expr::Symbol(_) => 2
    Expr::Function(_, _) => 3
    Expr::Add(_) => 4
    Expr::Number(_) => 5
  }
}

///|
pub fn compare_expr(a : Expr, b : Expr) -> Int {
  match (a, b) {
    (Expr::Pow(base_a, _), Expr::Symbol(sb)) => {
      let base_cmp = compare_expr(base_a, Expr::Symbol(sb))
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (Expr::Symbol(sa), Expr::Pow(base_b, _)) => {
      let base_cmp = compare_symbol_base(sa, base_b)
      if base_cmp != 0 {
        return base_cmp
      }
      return 1
    }
    _ => ()
  }
  let rank_diff = cmp_int(variant_rank(a), variant_rank(b))
  if rank_diff != 0 {
    return rank_diff
  }
  match a {
    Expr::Number(na) =>
      match b {
        Expr::Number(nb) => na.compare(nb)
        _ => 0
      }
    Expr::Symbol(sa) =>
      match b {
        Expr::Symbol(sb) => sa.compare(sb)
        _ => 0
      }
    Expr::Pow(base_a, exp_a) =>
      match b {
        Expr::Pow(base_b, exp_b) => {
          let base_cmp = compare_expr(base_a, base_b)
          if base_cmp != 0 {
            base_cmp
          } else {
            compare_expr(exp_a, exp_b)
          }
        }
        _ => 0
      }
    Expr::Mul(xs) =>
      match b {
        Expr::Mul(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Expr::Add(xs) =>
      match b {
        Expr::Add(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Expr::Function(name_a, args_a) =>
      match b {
        Expr::Function(name_b, args_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            name_cmp
          } else {
            compare_arrays(args_a, args_b)
          }
        }
        _ => 0
      }
  }
}

///|
fn compare_symbol_base(sym_name : String, expr : Expr) -> Int {
  match expr {
    Expr::Symbol(sb) => sym_name.compare(sb)
    Expr::Pow(base, _) => compare_symbol_base(sym_name, base)
    _ => compare_expr(Expr::Symbol(sym_name), expr)
  }
}

///|
fn compare_arrays(xs : Array[Expr], ys : Array[Expr]) -> Int {
  let len_x = xs.length()
  let len_y = ys.length()
  let min_len = if len_x < len_y { len_x } else { len_y }
  for i in 0..<min_len {
    let cmp = compare_expr(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  cmp_int(len_x, len_y)
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
pub fn sort_exprs_in_place(args : Array[Expr]) -> Unit {
  args.sort_by(compare_expr)
}

///|
pub impl Compare for Expr with compare(self, other : Expr) -> Int {
  compare_expr(self, other)
}

///|
pub impl Eq for Expr with equal(self, other : Expr) -> Bool {
  compare_expr(self, other) == 0
}

///|
pub impl Eq for Expr with not_equal(self, other : Expr) -> Bool {
  !self.equal(other)
}

///|
pub impl Hash for Expr with hash(self) -> Int {
  let hasher = Hasher::new()
  self.hash_combine(hasher)
  hasher.finalize()
}

///|
pub impl Hash for Expr with hash_combine(self, hasher : Hasher) -> Unit {
  hasher.combine_int(variant_rank(self))
  match self {
    Expr::Number(n) => n.hash_combine(hasher)
    Expr::Symbol(name) => hasher.combine_string(name)
    Expr::Pow(base, exp) => {
      base.hash_combine(hasher)
      exp.hash_combine(hasher)
    }
    Expr::Mul(args) | Expr::Add(args) =>
      for child in args {
        child.hash_combine(hasher)
      }
    Expr::Function(name, args) => {
      hasher.combine_string(name)
      for child in args {
        child.hash_combine(hasher)
      }
    }
  }
}
