///|
fn variant_rank(expr : Expr) -> Int {
  match expr {
    Pow(_, _) => 0
    Mul(_) => 1
    FunctionHead(_) => 2
    UndefinedFunction(_) => 3
    IdentityFunction => 4
    Dummy(_, _) | Wild(_, _, _) | WildFunction(_, _) => 5
    NumberSymbol(_) => 6
    Symbol(_) => 7
    Apply(_, _) => 8
    Derivative(_, _) => 9
    Dict(_) => 10
    Relational(_, _, _) => 11
    Lambda(_, _) => 12
    Subs(_, _, _) => 13
    Tuple(_) => 14
    Mod(_, _) => 15
    Boolean(_) => 16
    Add(_) => 17
    Number(_) => 18
    Float(_) => 19
    ComplexFloat(_) => 20
    Function(_, _) => abort("legacy function should be normalized")
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
      Eq => 0
      Ne => 1
      Lt => 2
      Le => 3
      Gt => 4
      Ge => 5
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
fn compare_apply_heads(head_a : Expr, head_b : Expr) -> Int {
  match (head_a, head_b) {
    (UndefinedFunction(_), FunctionHead(_)) => -1
    (FunctionHead(_), UndefinedFunction(_)) => 1
    _ => compare_expr_canonical(head_a, head_b)
  }
}

///|
fn compare_wild_properties(
  props_a : Array[WildProperty],
  props_b : Array[WildProperty],
) -> Int {
  let len_a = props_a.length()
  let len_b = props_b.length()
  let min_len = if len_a < len_b { len_a } else { len_b }
  for i in 0..<min_len {
    let cmp = wild_property_name(props_a[i]).compare(
      wild_property_name(props_b[i]),
    )
    if cmp != 0 {
      return cmp
    }
  }
  cmp_int(len_a, len_b)
}

///|
fn compare_expr_canonical(a : Expr, b : Expr) -> Int {
  if physical_equal(a, b) {
    return 0
  }
  match (a, b) {
    (Pow(base_a, _), Symbol(sb)) => {
      let base_cmp = compare_expr_canonical(base_a, Symbol(sb))
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (Pow(base_a, _), Dummy(name_b, id_b)) => {
      let base_cmp = compare_expr_canonical(base_a, Dummy(name_b, id_b))
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (Pow(base_a, _), Wild(name_b, exclude_b, properties_b)) => {
      let base_cmp = compare_expr_canonical(
        base_a,
        Wild(name_b, exclude_b, properties_b),
      )
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (Symbol(sa), Pow(base_b, _)) => {
      let base_cmp = compare_symbol_base(sa, base_b)
      if base_cmp != 0 {
        return base_cmp
      }
      return 1
    }
    (Dummy(name_a, _id_a), Pow(base_b, _)) => {
      let base_cmp = compare_symbol_base(dummy_display_name(name_a), base_b)
      if base_cmp != 0 {
        return base_cmp
      }
      return 1
    }
    (Wild(name_a, _, _), Pow(base_b, _)) => {
      let base_cmp = compare_symbol_base(wild_display_name(name_a), base_b)
      if base_cmp != 0 {
        return base_cmp
      }
      return 1
    }
    (Pow(base_a, _), NumberSymbol(nb)) => {
      let base_cmp = compare_expr_canonical(base_a, NumberSymbol(nb))
      if base_cmp != 0 {
        return base_cmp
      }
      return -1
    }
    (NumberSymbol(na), Pow(base_b, _)) => {
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
    Number(na) =>
      match b {
        Number(nb) => na.compare(nb)
        _ => 0
      }
    Float(fa) =>
      match b {
        Float(fb) => compare_float(fa, fb)
        _ => 0
      }
    ComplexFloat(za) =>
      match b {
        ComplexFloat(zb) => compare_complex_float(za, zb)
        _ => 0
      }
    Boolean(ba) =>
      match b {
        Boolean(bb) => cmp_int(if ba { 1 } else { 0 }, if bb { 1 } else { 0 })
        _ => 0
      }
    NumberSymbol(na) =>
      match b {
        NumberSymbol(nb) => compare_number_symbol(na, nb)
        Symbol(sb) => number_symbol_name(na).compare(sb)
        _ => 0
      }
    Symbol(sa) =>
      match b {
        NumberSymbol(nb) => sa.compare(number_symbol_name(nb))
        Symbol(sb) => sa.compare(sb)
        Dummy(name_b, _) => sa.compare(dummy_display_name(name_b))
        Wild(name_b, _, _) => sa.compare(wild_display_name(name_b))
        WildFunction(name_b, _) => sa.compare(wild_display_name(name_b))
        _ => 0
      }
    Dummy(name_a, id_a) =>
      match b {
        NumberSymbol(nb) =>
          dummy_display_name(name_a).compare(number_symbol_name(nb))
        Symbol(sb) => dummy_display_name(name_a).compare(sb)
        Dummy(name_b, id_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            name_cmp
          } else {
            cmp_int(id_a, id_b)
          }
        }
        Wild(name_b, _, _) =>
          dummy_display_name(name_a).compare(wild_display_name(name_b))
        WildFunction(name_b, _) =>
          dummy_display_name(name_a).compare(wild_display_name(name_b))
        _ => 0
      }
    Wild(name_a, exclude_a, properties_a) =>
      match b {
        NumberSymbol(nb) =>
          wild_display_name(name_a).compare(number_symbol_name(nb))
        Symbol(sb) => wild_display_name(name_a).compare(sb)
        Dummy(name_b, _) =>
          wild_display_name(name_a).compare(dummy_display_name(name_b))
        Wild(name_b, exclude_b, properties_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            name_cmp
          } else {
            let exclude_cmp = compare_arrays(exclude_a, exclude_b)
            if exclude_cmp != 0 {
              exclude_cmp
            } else {
              compare_wild_properties(properties_a, properties_b)
            }
          }
        }
        WildFunction(name_b, nargs_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            name_cmp
          } else {
            compare_int_arrays([], nargs_b)
          }
        }
        FunctionHead(name_b) => wild_display_name(name_a).compare(name_b)
        UndefinedFunction(name_b) => wild_display_name(name_a).compare(name_b)
        _ => 0
      }
    WildFunction(name_a, nargs_a) =>
      match b {
        NumberSymbol(nb) =>
          wild_display_name(name_a).compare(number_symbol_name(nb))
        Symbol(sb) => wild_display_name(name_a).compare(sb)
        Dummy(name_b, _) =>
          wild_display_name(name_a).compare(dummy_display_name(name_b))
        Wild(name_b, _, _) =>
          wild_display_name(name_a).compare(wild_display_name(name_b))
        WildFunction(name_b, nargs_b) => {
          let name_cmp = name_a.compare(name_b)
          if name_cmp != 0 {
            name_cmp
          } else {
            compare_int_arrays(nargs_a, nargs_b)
          }
        }
        FunctionHead(name_b) => wild_display_name(name_a).compare(name_b)
        UndefinedFunction(name_b) => wild_display_name(name_a).compare(name_b)
        _ => 0
      }
    FunctionHead(name_a) =>
      match b {
        NumberSymbol(nb) => name_a.compare(number_symbol_name(nb))
        Symbol(sb) => name_a.compare(sb)
        Dummy(name_b, _) => name_a.compare(dummy_display_name(name_b))
        Wild(name_b, _, _) => name_a.compare(wild_display_name(name_b))
        WildFunction(name_b, _) => name_a.compare(wild_display_name(name_b))
        FunctionHead(name_b) => name_a.compare(name_b)
        UndefinedFunction(name_b) => name_a.compare(name_b)
        _ => 0
      }
    UndefinedFunction(name_a) =>
      match b {
        NumberSymbol(nb) => name_a.compare(number_symbol_name(nb))
        Symbol(sb) => name_a.compare(sb)
        Dummy(name_b, _) => name_a.compare(dummy_display_name(name_b))
        Wild(name_b, _, _) => name_a.compare(wild_display_name(name_b))
        WildFunction(name_b, _) => name_a.compare(wild_display_name(name_b))
        FunctionHead(name_b) => name_a.compare(name_b)
        UndefinedFunction(name_b) => name_a.compare(name_b)
        _ => 0
      }
    IdentityFunction =>
      match b {
        IdentityFunction => 0
        _ => 0
      }
    Apply(head_a, args_a) =>
      match b {
        Apply(head_b, args_b) => {
          let head_cmp = compare_apply_heads(head_a, head_b)
          if head_cmp != 0 {
            head_cmp
          } else {
            compare_arrays(args_a, args_b)
          }
        }
        _ => 0
      }
    Pow(base_a, exp_a) =>
      match b {
        Pow(base_b, exp_b) => {
          let base_cmp = compare_expr_canonical(base_a, base_b)
          if base_cmp != 0 {
            base_cmp
          } else {
            compare_expr_canonical(exp_a, exp_b)
          }
        }
        _ => 0
      }
    Mod(lhs_a, rhs_a) =>
      match b {
        Mod(lhs_b, rhs_b) => {
          let lhs_cmp = compare_expr_canonical(lhs_a, lhs_b)
          if lhs_cmp != 0 {
            lhs_cmp
          } else {
            compare_expr_canonical(rhs_a, rhs_b)
          }
        }
        _ => 0
      }
    Mul(xs) =>
      match b {
        Mul(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Add(xs) =>
      match b {
        Add(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Tuple(xs) =>
      match b {
        Tuple(ys) => compare_arrays(xs, ys)
        _ => 0
      }
    Dict(xs) =>
      match b {
        Dict(ys) => compare_dict_items(xs, ys)
        _ => 0
      }
    Relational(op_a, lhs_a, rhs_a) =>
      match b {
        Relational(op_b, lhs_b, rhs_b) => {
          let op_cmp = compare_relop(op_a, op_b)
          if op_cmp != 0 {
            op_cmp
          } else {
            let lhs_cmp = compare_expr_canonical(lhs_a, lhs_b)
            if lhs_cmp != 0 {
              lhs_cmp
            } else {
              compare_expr_canonical(rhs_a, rhs_b)
            }
          }
        }
        _ => 0
      }
    Derivative(inner_a, deriv_args_a) =>
      match b {
        Derivative(inner_b, deriv_args_b) => {
          let inner_cmp = compare_expr_canonical(inner_a, inner_b)
          if inner_cmp != 0 {
            inner_cmp
          } else {
            compare_arrays(deriv_args_a, deriv_args_b)
          }
        }
        _ => 0
      }
    Subs(inner_a, variable_a, value_a) =>
      match b {
        Subs(inner_b, variable_b, value_b) => {
          let inner_cmp = compare_expr_canonical(
            subs_canonical_inner(inner_a, variable_a, value_a),
            subs_canonical_inner(inner_b, variable_b, value_b),
          )
          if inner_cmp != 0 {
            inner_cmp
          } else {
            compare_arrays(
              subs_hashable_pairs(inner_a, variable_a, value_a),
              subs_hashable_pairs(inner_b, variable_b, value_b),
            )
          }
        }
        _ => 0
      }
    Lambda(vars_a, body_a) =>
      match b {
        Lambda(vars_b, body_b) => {
          let vars_cmp = compare_expr_canonical(vars_a, vars_b)
          if vars_cmp != 0 {
            vars_cmp
          } else {
            compare_expr_canonical(body_a, body_b)
          }
        }
        _ => 0
      }
    Function(_, _) => abort("legacy function should be normalized")
  }
}

///|
pub fn compare_expr(a : Expr, b : Expr) -> Int {
  compare_expr_canonical(normalize_legacy_expr(a), normalize_legacy_expr(b))
}

///|
pub fn compare_expr_normalized(a : Expr, b : Expr) -> Int {
  compare_expr_canonical(a, b)
}

///|
fn compare_symbol_base(sym_name : String, expr : Expr) -> Int {
  match expr {
    NumberSymbol(kind) => sym_name.compare(number_symbol_name(kind))
    Boolean(value) =>
      if value {
        compare_expr_canonical(Boolean(true), expr)
      } else {
        compare_expr_canonical(Boolean(false), expr)
      }
    Symbol(sb) => sym_name.compare(sb)
    Dummy(name, _) => sym_name.compare(dummy_display_name(name))
    Wild(name, _, _) => sym_name.compare(wild_display_name(name))
    FunctionHead(name) => sym_name.compare(name)
    UndefinedFunction(name) => sym_name.compare(name)
    Apply(head, args) =>
      match head {
        FunctionHead(name) | UndefinedFunction(name) => {
          let name_cmp = sym_name.compare(name)
          if name_cmp != 0 {
            name_cmp
          } else {
            Int::compare(0, args.length())
          }
        }
        _ => compare_expr_canonical(Symbol(sym_name), expr)
      }
    Pow(base, _) => compare_symbol_base(sym_name, base)
    _ => compare_expr_canonical(Symbol(sym_name), expr)
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
    let cmp = compare_expr_canonical(xs[i], ys[i])
    if cmp != 0 {
      return cmp
    }
  }
  cmp_int(len_x, len_y)
}

///|
fn subs_items_for_order(expr : Expr) -> Array[Expr] {
  match normalize_legacy_expr(expr) {
    Tuple(items) => items
    other => [other]
  }
}

///|
fn canonical_subs_placeholder(index : Int) -> Expr {
  Dummy("__subs", -index - 1)
}

///|
fn canonical_subs_point_placeholders(
  point : Array[Expr],
) -> Array[(Expr, Expr)] {
  let unique = point.copy()
  unique.sort_by(compare_expr_canonical)
  let deduped : Array[Expr] = []
  for item in unique {
    if deduped.is_empty() ||
      compare_expr_canonical(deduped[deduped.length() - 1], item) != 0 {
      deduped.push(item)
    }
  }
  let out : Array[(Expr, Expr)] = []
  for i in 0..<deduped.length() {
    out.push((deduped[i], canonical_subs_placeholder(i)))
  }
  out
}

///|
fn canonical_subs_placeholder_for(
  mapping : Array[(Expr, Expr)],
  point : Expr,
) -> Expr {
  for item in mapping {
    let (current, placeholder) = item
    if compare_expr_canonical(current, point) == 0 {
      return placeholder
    }
  }
  abort("missing Subs canonical placeholder")
}

///|
fn subs_canonical_inner(inner : Expr, variable : Expr, value : Expr) -> Expr {
  let variables = subs_items_for_order(variable)
  let values = subs_items_for_order(value)
  let placeholders = canonical_subs_point_placeholders(values)
  let rules : Array[(Expr, Expr)] = []
  for i in 0..<variables.length() {
    rules.push(
      (variables[i], canonical_subs_placeholder_for(placeholders, values[i])),
    )
  }
  xreplace(inner, rules)
}

///|
fn subs_hashable_pairs(
  inner : Expr,
  variable : Expr,
  value : Expr,
) -> Array[Expr] {
  let variables = subs_items_for_order(variable)
  let values = subs_items_for_order(value)
  let pairs : Array[Expr] = []
  for i in 0..<variables.length() {
    if !has(inner, variables[i]) {
      pairs.push(Tuple([variables[i], values[i]]))
    }
  }
  pairs.sort_by(compare_expr)
  pairs
}

///|
fn compare_int_arrays(xs : Array[Int], ys : Array[Int]) -> Int {
  let len_x = xs.length()
  let len_y = ys.length()
  let min_len = if len_x < len_y { len_x } else { len_y }
  for i in 0..<min_len {
    let cmp = cmp_int(xs[i], ys[i])
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
    let key_cmp = compare_expr_canonical(xk, yk)
    if key_cmp != 0 {
      return key_cmp
    }
    let value_cmp = compare_expr_canonical(xv, yv)
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
  for i in 0..<args.length() {
    args[i] = normalize_legacy_expr(args[i])
  }
  let mut already_sorted = true
  for i in 1..<args.length() {
    if compare_expr_canonical(args[i - 1], args[i]) > 0 {
      already_sorted = false
      break
    }
  }
  if !already_sorted {
    if args.length() <= 16 {
      for i in 1..<args.length() {
        let current = args[i]
        let mut j = i
        while j > 0 && compare_expr_canonical(args[j - 1], current) > 0 {
          args[j] = args[j - 1]
          j -= 1
        }
        args[j] = current
      }
    } else {
      args.sort_by(compare_expr_canonical)
    }
  }
}

///|
pub impl Compare for Expr with fn compare(self, other : Expr) -> Int {
  compare_expr(self, other)
}

///|
pub impl Eq for Expr with fn equal(self, other : Expr) -> Bool {
  compare_expr(self, other) == 0
}

///|
pub impl Eq for Expr with fn not_equal(self, other : Expr) -> Bool {
  !Eq::equal(self, other)
}

///|
pub impl Hash for Expr with fn hash(self) -> Int {
  let hasher = Hasher()
  hash_expr_canonical(normalize_legacy_expr(self), hasher)
  hasher.finalize()
}

///|
pub impl Hash for Expr with fn hash_combine(self, hasher : Hasher) -> Unit {
  hash_expr_canonical(normalize_legacy_expr(self), hasher)
}

///|
fn hash_expr_canonical(expr : Expr, hasher : Hasher) -> Unit {
  hasher.combine_int(variant_rank(expr))
  match expr {
    Number(n) => Hash::hash_combine(n, hasher)
    Float(f) => {
      hasher.combine_int(f.precision())
      hasher.combine_string(f.format())
    }
    ComplexFloat(z) => {
      hasher.combine_int(z.precision())
      hasher.combine_string(z.format())
    }
    NumberSymbol(kind) => hasher.combine_string(number_symbol_name(kind))
    Boolean(value) => hasher.combine_bool(value)
    IdentityFunction => hasher.combine_string("IdentityFunction")
    Symbol(name) => hasher.combine_string(name)
    Dummy(name, id) => {
      hasher.combine_string(name)
      hasher.combine_int(id)
    }
    Wild(name, exclude, properties) => {
      hasher.combine_string(name)
      for item in exclude {
        hash_expr_canonical(item, hasher)
      }
      for property in properties {
        hasher.combine_string(wild_property_name(property))
      }
    }
    WildFunction(name, nargs) => {
      hasher.combine_string(name)
      for arity in nargs {
        hasher.combine_int(arity)
      }
    }
    FunctionHead(name) => hasher.combine_string(name)
    UndefinedFunction(name) => hasher.combine_string(name)
    Apply(head, args) => {
      hash_expr_canonical(head, hasher)
      for child in args {
        hash_expr_canonical(child, hasher)
      }
    }
    Pow(base, exp) => {
      hash_expr_canonical(base, hasher)
      hash_expr_canonical(exp, hasher)
    }
    Mod(lhs, rhs) => {
      hash_expr_canonical(lhs, hasher)
      hash_expr_canonical(rhs, hasher)
    }
    Mul(args) | Add(args) | Tuple(args) =>
      for child in args {
        hash_expr_canonical(child, hasher)
      }
    Dict(items) =>
      for item in items {
        let (key, value) = item
        hash_expr_canonical(key, hasher)
        hash_expr_canonical(value, hasher)
      }
    Relational(op, lhs, rhs) => {
      hasher.combine_int(compare_relop(op, Eq))
      hash_expr_canonical(lhs, hasher)
      hash_expr_canonical(rhs, hasher)
    }
    Derivative(inner, deriv_args) => {
      hash_expr_canonical(inner, hasher)
      for arg in deriv_args {
        hash_expr_canonical(arg, hasher)
      }
    }
    Subs(inner, variable, value) => {
      hash_expr_canonical(subs_canonical_inner(inner, variable, value), hasher)
      for pair in subs_hashable_pairs(inner, variable, value) {
        hash_expr_canonical(pair, hasher)
      }
    }
    Lambda(vars, body) => {
      hash_expr_canonical(vars, hasher)
      hash_expr_canonical(body, hasher)
    }
    Function(_, _) => abort("legacy function should be normalized")
  }
}

///|
pub fn hash_expr_normalized(expr : Expr) -> Int {
  let hasher = Hasher()
  hash_expr_canonical(expr, hasher)
  hasher.finalize()
}
