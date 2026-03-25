///|
fn variant_rank(expr : Expr) -> Int {
  match expr {
    Expr::Pow(_, _) => 0
    Expr::Mul(_) => 1
    Expr::NumberSymbol(_) => 2
    Expr::Symbol(_) | Expr::Dummy(_, _) | Expr::Wild(_) => 3
    Expr::UndefinedFunction(_) => 4
    Expr::Boolean(_) => 5
    Expr::Tuple(_) => 6
    Expr::Dict(_) => 7
    Expr::Relational(_, _, _) => 8
    Expr::Derivative(_, _) => 9
    Expr::Subs(_, _, _) => 10
    Expr::Lambda(_, _) => 11
    Expr::Function(_, _) => 12
    Expr::Add(_) => 13
    Expr::Number(_) => 14
    Expr::Float(_) => 15
    Expr::ComplexFloat(_) => 16
  }
}

///|
fn compare_number_symbol(a : NumberSymbolKind, b : NumberSymbolKind) -> Int {
  number_symbol_name(a).compare(number_symbol_name(b))
}

///|
fn compare_relop(a : RelOp, b : RelOp) -> Int {
  let rank = fn(op : RelOp) -> Int {
    match op {
      RelOp::Eq => 0
      RelOp::Ne => 1
      RelOp::Lt => 2
      RelOp::Le => 3
      RelOp::Gt => 4
      RelOp::Ge => 5
    }
  }
  cmp_int(rank(a), rank(b))
}

///|
fn compare_float(a : Float, b : Float) -> Int {
  if a == b {
    0
  } else {
    let cmp = @symnum.mpf_cmp(a.to_mpf(), b.to_mpf())
    if cmp != 0 {
      cmp
    } else {
      let prec_cmp = cmp_int(a.precision(), b.precision())
      if prec_cmp != 0 {
        prec_cmp
      } else {
        a.format().compare(b.format())
      }
    }
  }
}

///|
fn compare_complex_float(a : ComplexFloat, b : ComplexFloat) -> Int {
  if a == b {
    0
  } else {
    let real_cmp = @symnum.mpf_cmp(a.to_mpc().real, b.to_mpc().real)
    if real_cmp != 0 {
      real_cmp
    } else {
      let imag_cmp = @symnum.mpf_cmp(a.to_mpc().imag, b.to_mpc().imag)
      if imag_cmp != 0 {
        imag_cmp
      } else {
        let prec_cmp = cmp_int(a.precision(), b.precision())
        if prec_cmp != 0 {
          prec_cmp
        } else {
          a.format().compare(b.format())
        }
      }
    }
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
    (Expr::Pow(base_a, _), Expr::Dummy(name_b, id_b)) => {
      let base_cmp = compare_expr(base_a, Expr::Dummy(name_b, id_b))
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (Expr::Pow(base_a, _), Expr::Wild(name_b)) => {
      let base_cmp = compare_expr(base_a, Expr::Wild(name_b))
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
    (Expr::Dummy(name_a, id_a), Expr::Pow(base_b, _)) => {
      let base_cmp = compare_symbol_base(dummy_display_name(name_a), base_b)
      if base_cmp != 0 {
        return base_cmp
      }
      match base_b {
        Expr::Dummy(name_b, id_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            return name_cmp
          }
          return cmp_int(id_a, id_b)
        }
        _ => return 1
      }
    }
    (Expr::Wild(name_a), Expr::Pow(base_b, _)) => {
      let base_cmp = compare_symbol_base(wild_display_name(name_a), base_b)
      if base_cmp != 0 {
        return base_cmp
      }
      return 1
    }
    (Expr::Pow(base_a, _), Expr::NumberSymbol(nb)) => {
      let base_cmp = compare_expr(base_a, Expr::NumberSymbol(nb))
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (Expr::NumberSymbol(na), Expr::Pow(base_b, _)) => {
      let base_cmp = compare_number_symbol_base(na, base_b)
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
    Expr::Float(fa) =>
      match b {
        Expr::Float(fb) => compare_float(fa, fb)
        _ => 0
      }
    Expr::ComplexFloat(za) =>
      match b {
        Expr::ComplexFloat(zb) => compare_complex_float(za, zb)
        _ => 0
      }
    Expr::Boolean(ba) =>
      match b {
        Expr::Boolean(bb) =>
          cmp_int(if ba { 1 } else { 0 }, if bb { 1 } else { 0 })
        _ => 0
      }
    Expr::NumberSymbol(na) =>
      match b {
        Expr::NumberSymbol(nb) => compare_number_symbol(na, nb)
        Expr::Symbol(sb) => number_symbol_name(na).compare(sb)
        _ => 0
      }
    Expr::Symbol(sa) =>
      match b {
        Expr::NumberSymbol(nb) => sa.compare(number_symbol_name(nb))
        Expr::Symbol(sb) => sa.compare(sb)
        Expr::Dummy(name_b, _) => sa.compare(dummy_display_name(name_b))
        Expr::Wild(name_b) => sa.compare(wild_display_name(name_b))
        _ => 0
      }
    Expr::Dummy(name_a, id_a) =>
      match b {
        Expr::NumberSymbol(nb) =>
          dummy_display_name(name_a).compare(number_symbol_name(nb))
        Expr::Symbol(sb) => dummy_display_name(name_a).compare(sb)
        Expr::Dummy(name_b, id_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            name_cmp
          } else {
            cmp_int(id_a, id_b)
          }
        }
        Expr::Wild(name_b) =>
          dummy_display_name(name_a).compare(wild_display_name(name_b))
        _ => 0
      }
    Expr::Wild(name_a) =>
      match b {
        Expr::NumberSymbol(nb) =>
          wild_display_name(name_a).compare(number_symbol_name(nb))
        Expr::Symbol(sb) => wild_display_name(name_a).compare(sb)
        Expr::Dummy(name_b, _) =>
          wild_display_name(name_a).compare(dummy_display_name(name_b))
        Expr::Wild(name_b) => name_a.compare(name_b)
        Expr::UndefinedFunction(name_b) =>
          wild_display_name(name_a).compare(name_b)
        _ => 0
      }
    Expr::UndefinedFunction(name_a) =>
      match b {
        Expr::NumberSymbol(nb) => name_a.compare(number_symbol_name(nb))
        Expr::Symbol(sb) => name_a.compare(sb)
        Expr::Dummy(name_b, _) => name_a.compare(dummy_display_name(name_b))
        Expr::Wild(name_b) => name_a.compare(wild_display_name(name_b))
        Expr::UndefinedFunction(name_b) => name_a.compare(name_b)
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
    Expr::Tuple(xs) =>
      match b {
        Expr::Tuple(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Expr::Dict(xs) =>
      match b {
        Expr::Dict(ys) => compare_dict_items(xs, ys)
        _ => 0
      }
    Expr::Relational(op_a, lhs_a, rhs_a) =>
      match b {
        Expr::Relational(op_b, lhs_b, rhs_b) => {
          let op_cmp = compare_relop(op_a, op_b)
          if op_cmp != 0 {
            op_cmp
          } else {
            let lhs_cmp = compare_expr(lhs_a, lhs_b)
            if lhs_cmp != 0 {
              lhs_cmp
            } else {
              compare_expr(rhs_a, rhs_b)
            }
          }
        }
        _ => 0
      }
    Expr::Derivative(inner_a, deriv_args_a) =>
      match b {
        Expr::Derivative(inner_b, deriv_args_b) => {
          let inner_cmp = compare_expr(inner_a, inner_b)
          if inner_cmp != 0 {
            inner_cmp
          } else {
            compare_arrays(deriv_args_a, deriv_args_b)
          }
        }
        _ => 0
      }
    Expr::Subs(inner_a, variable_a, value_a) =>
      match b {
        Expr::Subs(inner_b, variable_b, value_b) => {
          let inner_cmp = compare_expr(inner_a, inner_b)
          if inner_cmp != 0 {
            inner_cmp
          } else {
            let variable_cmp = compare_expr(variable_a, variable_b)
            if variable_cmp != 0 {
              variable_cmp
            } else {
              compare_expr(value_a, value_b)
            }
          }
        }
        _ => 0
      }
    Expr::Lambda(vars_a, body_a) =>
      match b {
        Expr::Lambda(vars_b, body_b) => {
          let vars_cmp = compare_expr(vars_a, vars_b)
          if vars_cmp != 0 {
            vars_cmp
          } else {
            compare_expr(body_a, body_b)
          }
        }
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
    Expr::NumberSymbol(kind) => sym_name.compare(number_symbol_name(kind))
    Expr::Boolean(value) =>
      if value {
        compare_expr(Expr::Symbol("True"), expr)
      } else {
        compare_expr(Expr::Symbol("False"), expr)
      }
    Expr::Symbol(sb) => sym_name.compare(sb)
    Expr::Dummy(name, _) => sym_name.compare(dummy_display_name(name))
    Expr::Wild(name) => sym_name.compare(wild_display_name(name))
    Expr::UndefinedFunction(name) => sym_name.compare(name)
    Expr::Pow(base, _) => compare_symbol_base(sym_name, base)
    _ => compare_expr(Expr::Symbol(sym_name), expr)
  }
}

///|
fn compare_number_symbol_base(kind : NumberSymbolKind, expr : Expr) -> Int {
  compare_symbol_base(number_symbol_name(kind), expr)
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
fn compare_dict_items(
  xs : Array[(Expr, Expr)],
  ys : Array[(Expr, Expr)],
) -> Int {
  let len_x = xs.length()
  let len_y = ys.length()
  let min_len = if len_x < len_y { len_x } else { len_y }
  for i in 0..<min_len {
    let (xk, xv) = xs[i]
    let (yk, yv) = ys[i]
    let key_cmp = compare_expr(xk, yk)
    if key_cmp != 0 {
      return key_cmp
    }
    let value_cmp = compare_expr(xv, yv)
    if value_cmp != 0 {
      return value_cmp
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
    Expr::Float(f) => {
      hasher.combine_int(f.precision())
      hasher.combine_string(f.format())
    }
    Expr::ComplexFloat(z) => {
      hasher.combine_int(z.precision())
      hasher.combine_string(z.format())
    }
    Expr::NumberSymbol(kind) => hasher.combine_string(number_symbol_name(kind))
    Expr::Boolean(value) => hasher.combine_bool(value)
    Expr::Symbol(name) => hasher.combine_string(name)
    Expr::Dummy(name, id) => {
      hasher.combine_string(name)
      hasher.combine_int(id)
    }
    Expr::Wild(name) => hasher.combine_string(name)
    Expr::UndefinedFunction(name) => hasher.combine_string(name)
    Expr::Pow(base, exp) => {
      base.hash_combine(hasher)
      exp.hash_combine(hasher)
    }
    Expr::Mul(args) | Expr::Add(args) | Expr::Tuple(args) =>
      for child in args {
        child.hash_combine(hasher)
      }
    Expr::Dict(items) =>
      for item in items {
        let (key, value) = item
        key.hash_combine(hasher)
        value.hash_combine(hasher)
      }
    Expr::Relational(op, lhs, rhs) => {
      hasher.combine_int(compare_relop(op, RelOp::Eq))
      lhs.hash_combine(hasher)
      rhs.hash_combine(hasher)
    }
    Expr::Derivative(inner, deriv_args) => {
      inner.hash_combine(hasher)
      for arg in deriv_args {
        arg.hash_combine(hasher)
      }
    }
    Expr::Subs(inner, variable, value) => {
      inner.hash_combine(hasher)
      variable.hash_combine(hasher)
      value.hash_combine(hasher)
    }
    Expr::Lambda(vars, body) => {
      vars.hash_combine(hasher)
      body.hash_combine(hasher)
    }
    Expr::Function(name, args) => {
      hasher.combine_string(name)
      for child in args {
        child.hash_combine(hasher)
      }
    }
  }
}
