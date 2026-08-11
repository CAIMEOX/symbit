///|
pub fn children(expr : Expr) -> ArrayView[Expr] {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Add(args) | Mul(args) | Tuple(args) | Apply(_, args) => args[:]
    Mod(lhs, rhs) => [lhs, rhs][:]
    Dict(items) => {
      let sorted = sorted_dict_entries(items)
      let out : Array[Expr] = []
      for item in sorted {
        let (key, value) = item
        out.push(Tuple([key, value]))
      }
      out[:]
    }
    Pow(base, exp) => [base, exp][:]
    Relational(_, lhs, rhs) => [lhs, rhs][:]
    Derivative(inner, deriv_args) => {
      let out : Array[Expr] = [inner]
      let pair_count = deriv_args.length() / 2
      for i in 0..<pair_count {
        let wrt = deriv_args[i * 2]
        let order_idx = i * 2 + 1
        if order_idx < deriv_args.length() {
          out.push(Tuple([wrt, deriv_args[order_idx]]))
        } else {
          out.push(Tuple([wrt, int(1)]))
        }
      }
      out[:]
    }
    Subs(inner, variable, value) =>
      [
        inner,
        match variable {
          Tuple(_) => variable
          _ => Tuple([variable])
        },
        match value {
          Tuple(_) => value
          _ => Tuple([value])
        },
      ][:]
    Lambda(vars, body) =>
      [
        match vars {
          Tuple(_) => vars
          _ => Tuple([vars])
        },
        body,
      ][:]
    Function(_, _) => abort("legacy function should be normalized")
    _ => [][:]
  }
}

///|
pub fn preorder(expr : Expr) -> Array[Expr] {
  let expr = normalize_legacy_expr(expr)
  let out : Array[Expr] = [expr]
  for child in children(expr) {
    for item in preorder(child) {
      out.push(item)
    }
  }
  out
}

///|
pub fn postorder(expr : Expr) -> Array[Expr] {
  let expr = normalize_legacy_expr(expr)
  let out : Array[Expr] = []
  for child in children(expr) {
    for item in postorder(child) {
      out.push(item)
    }
  }
  out.push(expr)
  out
}

///|
pub fn map_children(expr : Expr, f : (Expr) -> Expr) -> Expr {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Add(args) => add(args.map(f))
    Mul(args) => mul(args.map(f))
    Pow(base, exp) => pow(f(base), f(exp))
    Mod(lhs, rhs) => mod_expr(f(lhs), f(rhs))
    Tuple(args) => Tuple(args.map(f))
    Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((f(key), f(value)))
      }
      Dict(out)
    }
    Relational(op, lhs, rhs) =>
      match op {
        Eq => Relational(Eq, f(lhs), f(rhs))
        Ne => Relational(Ne, f(lhs), f(rhs))
        Lt => Relational(Lt, f(lhs), f(rhs))
        Le => Relational(Le, f(lhs), f(rhs))
        Gt => Relational(Gt, f(lhs), f(rhs))
        Ge => Relational(Ge, f(lhs), f(rhs))
      }
    Derivative(inner, deriv_args) => {
      let out : Array[Expr] = []
      for arg in deriv_args {
        out.push(f(arg))
      }
      Derivative(f(inner), out)
    }
    Subs(inner, variable, value) => subs_expr(f(inner), f(variable), f(value))
    Lambda(vars, body) => lambda_expr(f(vars), f(body))
    Apply(head, args) =>
      match raw_apply(head, args.map(f)) {
        Some(applied) => applied
        None => Apply(head, args.map(f))
      }
    FunctionHead(name) => FunctionHead(name)
    Function(_, _) => abort("legacy function should be normalized")
    _ => expr
  }
}

///|
fn clone_subst_env(env : Map[String, Expr]) -> Map[String, Expr] {
  let out : Map[String, Expr] = Map([])
  for key, value in env {
    out.set(key, value)
  }
  out
}

///|
fn remove_bound_names_from_env(bound : Expr, env : Map[String, Expr]) -> Unit {
  match bound {
    Symbol(name) => ignore(env.remove(name))
    _ =>
      match tuple_items(bound) {
        Some(items) =>
          for item in items {
            remove_bound_names_from_env(item, env)
          }
        None => ()
      }
  }
}

///|
fn bound_symbol_names(bound : Expr) -> Array[String] {
  let out : Array[String] = []
  letrec collect = (expr : Expr) => {
    match expr {
      Symbol(name) => if !out.contains(name) { out.push(name) }
      _ =>
        match tuple_items(expr) {
          Some(items) =>
            for item in items {
              collect(item)
            }
          None => ()
        }
    }
  }
  collect(bound)
  out
}

///|
fn replacement_conflicts_with_bound_names(
  value : Expr,
  current_name : String,
  original_names : Array[String],
  rename_env : Map[String, Expr],
) -> Bool {
  match value {
    Symbol(new_name) => {
      if new_name != current_name && original_names.contains(new_name) {
        return true
      }
      for _, existing in rename_env {
        match existing {
          Symbol(existing_name) if existing_name == new_name => return true
          _ => ()
        }
      }
      false
    }
    Dummy(_, id) => {
      for _, existing in rename_env {
        match existing {
          Dummy(_, existing_id) if existing_id == id => return true
          _ => ()
        }
      }
      false
    }
    _ => true
  }
}

///|
fn rename_bound_vars(
  bound : Expr,
  env : Map[String, Expr],
  rename_env : Map[String, Expr],
  original_names : Array[String],
) -> Expr {
  match bound {
    Symbol(name) =>
      match env.get(name) {
        Some(value) =>
          match value {
            Symbol(_) | Dummy(_, _) => {
              if replacement_conflicts_with_bound_names(
                  value, name, original_names, rename_env,
                ) {
                return bound
              }
              rename_env.set(name, value)
              value
            }
            _ => bound
          }
        None => bound
      }
    _ =>
      match tuple_items(bound) {
        Some(items) => {
          let out : Array[Expr] = []
          for item in items {
            out.push(rename_bound_vars(item, env, rename_env, original_names))
          }
          Tuple(out)
        }
        None => bound
      }
  }
}

///|
fn expr_symbol_names(expr : Expr) -> Array[String] {
  let names : Array[String] = []
  for item in free_symbols(expr) {
    match item {
      Symbol(name) => if !names.contains(name) { names.push(name) }
      _ => ()
    }
  }
  names
}

///|
fn derivative_wrt_names(deriv_args : Array[Expr]) -> Array[String] {
  let out : Array[String] = []
  let pair_count = deriv_args.length() / 2
  for i in 0..<pair_count {
    match deriv_args[i * 2] {
      Symbol(name) => if !out.contains(name) { out.push(name) }
      _ => ()
    }
  }
  out
}

///|
fn expr_mentions_any_symbol_name(expr : Expr, names : Array[String]) -> Bool {
  if names.is_empty() {
    return false
  }
  for item in free_symbols(expr) {
    match item {
      Symbol(name) if names.contains(name) => return true
      _ => ()
    }
  }
  false
}

///|
fn expr_contains_exact_subexpr(expr : Expr, target : Expr) -> Bool {
  let expr = normalize_legacy_expr(expr)
  let target = normalize_legacy_expr(target)
  if expr == target {
    return true
  }
  for child in children(expr) {
    if expr_contains_exact_subexpr(child, target) {
      return true
    }
  }
  false
}

///|
fn lambda_match_signature(
  param : Expr,
  arg : Expr,
  rules : Array[(Expr, Expr)],
) -> Bool {
  match normalize_legacy_expr(param) {
    Symbol(_) | Dummy(_, _) | Wild(_, _, _) => {
      rules.push((param, arg))
      true
    }
    Tuple(items) =>
      match tuple_items(arg) {
        Some(arg_items) => {
          if items.length() != arg_items.length() {
            return false
          }
          for i = 0; i < items.length(); i = i + 1 {
            if !lambda_match_signature(items[i], arg_items[i], rules) {
              return false
            }
          }
          true
        }
        None => false
      }
    _ => false
  }
}

///|
pub fn apply_lambda_expr(vars : Expr, body : Expr, args : Array[Expr]) -> Expr? {
  let vars = normalize_legacy_expr(vars)
  let body = normalize_legacy_expr(body)
  let args = args.map(normalize_legacy_expr)
  let rules : Array[(Expr, Expr)] = []
  match vars {
    Symbol(_) | Dummy(_, _) | Wild(_, _, _) =>
      if args.length() == 1 {
        rules.push((vars, args[0]))
      } else {
        return None
      }
    Tuple(items) => {
      if items.length() != args.length() {
        return None
      }
      for i = 0; i < items.length(); i = i + 1 {
        if !lambda_match_signature(items[i], args[i], rules) {
          return None
        }
      }
    }
    _ => return None
  }
  Some(xreplace(body, rules))
}

///|
fn callable_subst_apply(
  head : Expr,
  args : Array[Expr],
  env : Map[String, Expr],
) -> Expr? {
  match head {
    FunctionHead(name) | UndefinedFunction(name) =>
      match env.get(name) {
        Some(value) =>
          match normalize_legacy_expr(value) {
            FunctionHead(_) | UndefinedFunction(_) => raw_apply(value, args)
            Lambda(vars, body) =>
              match apply_lambda_expr(vars, body, args) {
                Some(result) => Some(result)
                None => None
              }
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn subst_derivative(
  inner : Expr,
  deriv_args : Array[Expr],
  env : Map[String, Expr],
) -> Expr {
  let deriv_args = canonical_derivative_args(deriv_args)
  let original_wrt_names = derivative_wrt_names(deriv_args)
  let original_free_names = expr_symbol_names(inner)
  let rename_env : Map[String, Expr] = Map([])
  let inner_env = clone_subst_env(env)
  let outer_env : Map[String, Expr] = Map([])

  for wrt_name in original_wrt_names {
    match env.get(wrt_name) {
      Some(value) => {
        let value = normalize_legacy_expr(value)
        let safe_rename = match value {
          Symbol(new_name) =>
            new_name == wrt_name ||
            (
              !original_free_names.contains(new_name) &&
              !original_wrt_names.contains(new_name)
            )
          Dummy(_, _) => true
          _ =>
            expr_can_diff_wrt(value) &&
            !expr_contains_exact_subexpr(inner, value)
        }
        if safe_rename {
          rename_env.set(wrt_name, value)
        } else {
          outer_env.set(wrt_name, value)
        }
        ignore(inner_env.remove(wrt_name))
      }
      None => ()
    }
  }

  let renamed_args : Array[Expr] = []
  let pair_count = deriv_args.length() / 2
  for i in 0..<pair_count {
    let wrt0 = deriv_args[i * 2]
    let wrt1 = if rename_env.is_empty() {
      wrt0
    } else {
      subst(wrt0, rename_env)
    }
    renamed_args.push(wrt1)
    let order_idx = i * 2 + 1
    if order_idx < deriv_args.length() {
      renamed_args.push(subst(deriv_args[order_idx], inner_env))
    }
  }

  let renamed_wrt_names = derivative_wrt_names(renamed_args)
  for key, value in env {
    if original_wrt_names.contains(key) {
      continue
    }
    if renamed_wrt_names.contains(key) ||
      expr_mentions_any_symbol_name(value, renamed_wrt_names) {
      outer_env.set(key, value)
      ignore(inner_env.remove(key))
    }
  }

  let renamed_inner = if rename_env.is_empty() {
    inner
  } else {
    subst(inner, rename_env)
  }
  let mut rebuilt_inner = subst(renamed_inner, inner_env)
  let rebuilt_args : Array[Expr] = []
  let residual_vars : Array[Expr] = []
  let residual_values : Array[Expr] = []
  let pair_count = renamed_args.length() / 2
  for i in 0..<pair_count {
    let wrt = subst(renamed_args[i * 2], inner_env)
    let order = renamed_args[i * 2 + 1]
    if expr_can_diff_wrt(wrt) {
      rebuilt_args.push(wrt)
      rebuilt_args.push(order)
    } else {
      let xi = dummy(name="xi_\{i}")
      rebuilt_inner = xreplace(rebuilt_inner, [(wrt, xi)])
      rebuilt_args.push(xi)
      rebuilt_args.push(order)
      residual_vars.push(xi)
      residual_values.push(wrt)
    }
  }
  let rebuilt = Expr::Derivative(rebuilt_inner, rebuilt_args)
  let outer_keys : Array[String] = []
  for key in outer_env.keys() {
    outer_keys.push(key)
  }
  outer_keys.sort()
  let mut out = if residual_vars.is_empty() {
    rebuilt
  } else {
    subs_expr(
      rebuilt,
      if residual_vars.length() == 1 {
        residual_vars[0]
      } else {
        Tuple(residual_vars)
      },
      if residual_values.length() == 1 {
        residual_values[0]
      } else {
        Tuple(residual_values)
      },
    )
  }
  for key in outer_keys {
    match outer_env.get(key) {
      Some(value) =>
        out = subs_expr(out, Symbol(key), normalize_legacy_expr(value))
      None => ()
    }
  }
  out
}

///|
pub fn subst(expr : Expr, env : Map[String, Expr]) -> Expr {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Symbol(name) =>
      match env.get(name) {
        Some(value) => value
        None => expr
      }
    Dummy(_, _) | Wild(_, _, _) | WildFunction(_, _) => expr
    Number(_)
    | Float(_)
    | ComplexFloat(_)
    | NumberSymbol(_)
    | FunctionHead(_)
    | UndefinedFunction(_)
    | Boolean(_) => expr
    Apply(head, args) => {
      let rewritten_args = args.map(arg => subst(arg, env))
      match callable_subst_apply(head, rewritten_args, env) {
        Some(applied) => applied
        None =>
          match raw_apply(head, rewritten_args) {
            Some(applied) => applied
            None => Apply(head, rewritten_args)
          }
      }
    }
    Derivative(inner, deriv_args) => subst_derivative(inner, deriv_args, env)
    Lambda(vars, body) => {
      let rename_env : Map[String, Expr] = Map([])
      let renamed_vars = rename_bound_vars(
        vars,
        env,
        rename_env,
        bound_symbol_names(vars),
      )
      let restricted = clone_subst_env(env)
      remove_bound_names_from_env(vars, restricted)
      remove_bound_names_from_env(renamed_vars, restricted)
      let renamed_body = if rename_env.is_empty() {
        body
      } else {
        subst(body, rename_env)
      }
      lambda_expr(renamed_vars, subst(renamed_body, restricted))
    }
    Subs(inner, variable, value) => {
      let protected_names = bound_symbol_names(variable)
      for name in expr_symbol_names(subs_expr(inner, variable, value)) {
        if !protected_names.contains(name) {
          protected_names.push(name)
        }
      }
      let rename_env : Map[String, Expr] = Map([])
      let renamed_variable = rename_bound_vars(
        variable, env, rename_env, protected_names,
      )
      let restricted = clone_subst_env(env)
      remove_bound_names_from_env(variable, restricted)
      remove_bound_names_from_env(renamed_variable, restricted)
      let renamed_inner = if rename_env.is_empty() {
        inner
      } else {
        subst(inner, rename_env)
      }
      let renamed_value = if rename_env.is_empty() {
        value
      } else {
        subst(value, rename_env)
      }
      subs_expr(
        subst(renamed_inner, restricted),
        renamed_variable,
        subst(renamed_value, restricted),
      )
    }
    Function(_, _) => abort("legacy function should be normalized")
    _ => map_children(expr, child => subst(child, env))
  }
}

///|
pub fn replace(
  expr : Expr,
  query : (Expr) -> Bool,
  value : (Expr) -> Expr,
) -> Expr {
  let expr = normalize_legacy_expr(expr)
  if query(expr) {
    return value(expr)
  }
  map_children(expr, child => replace(child, query, value))
}

///|
pub fn xreplace(expr : Expr, rules : Array[(Expr, Expr)]) -> Expr {
  let expr = normalize_legacy_expr(expr)
  let normalized_rules = rules.map(rule => {
    let (old_expr, new_expr) = rule
    (normalize_legacy_expr(old_expr), normalize_legacy_expr(new_expr))
  })
  for rule in normalized_rules {
    let (old_expr, new_expr) = rule
    if expr == old_expr {
      return new_expr
    }
  }
  map_children(expr, child => xreplace(child, normalized_rules))
}
