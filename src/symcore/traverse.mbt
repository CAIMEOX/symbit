///|
pub fn children(expr : Expr) -> ArrayView[Expr] {
  match expr {
    Expr::Add(args)
    | Expr::Mul(args)
    | Expr::Tuple(args)
    | Expr::AppliedUndef(_, args)
    | Expr::Function(_, args) => args[:]
    Expr::Mod(lhs, rhs) => [lhs, rhs][:]
    Expr::Dict(items) => {
      let out : Array[Expr] = []
      for item in items {
        let (key, value) = item
        out.push(tuple_expr([key, value]))
      }
      out[:]
    }
    Expr::Pow(base, exp) => [base, exp][:]
    Expr::Relational(_, lhs, rhs) => [lhs, rhs][:]
    Expr::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = [inner]
      for arg in deriv_args {
        out.push(arg)
      }
      out[:]
    }
    Expr::Subs(inner, variable, value) => [inner, variable, value][:]
    Expr::Lambda(vars, body) => [vars, body][:]
    _ => [][:]
  }
}

///|
pub fn map_children(expr : Expr, f : (Expr) -> Expr) -> Expr {
  match expr {
    Expr::Add(args) => add(args.map(f))
    Expr::Mul(args) => mul(args.map(f))
    Expr::Pow(base, exp) => pow(f(base), f(exp))
    Expr::Mod(lhs, rhs) => mod_expr(f(lhs), f(rhs))
    Expr::Tuple(args) => tuple_expr(args.map(f))
    Expr::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((f(key), f(value)))
      }
      dict_expr(out)
    }
    Expr::Relational(op, lhs, rhs) =>
      match op {
        RelOp::Eq => eq(f(lhs), f(rhs))
        RelOp::Ne => ne(f(lhs), f(rhs))
        RelOp::Lt => lt(f(lhs), f(rhs))
        RelOp::Le => le(f(lhs), f(rhs))
        RelOp::Gt => gt(f(lhs), f(rhs))
        RelOp::Ge => ge(f(lhs), f(rhs))
      }
    Expr::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = []
      for arg in deriv_args {
        out.push(f(arg))
      }
      Expr::Derivative(f(inner), out)
    }
    Expr::Subs(inner, variable, value) =>
      subs_expr(f(inner), f(variable), f(value))
    Expr::Lambda(vars, body) => lambda_expr(f(vars), f(body))
    Expr::AppliedUndef(name, args) =>
      applied_undefined_function(name, args.map(f))
    Expr::Function(name, args) => function(name, args.map(f))
    _ => expr
  }
}

///|
fn clone_subst_env(env : Map[String, Expr]) -> Map[String, Expr] {
  let out : Map[String, Expr] = {}
  for key, value in env {
    out.set(key, value)
  }
  out
}

///|
fn remove_bound_names_from_env(bound : Expr, env : Map[String, Expr]) -> Unit {
  match bound {
    Expr::Symbol(name) => ignore(env.remove(name))
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
fn rename_lambda_bound_vars(
  bound : Expr,
  env : Map[String, Expr],
  rename_env : Map[String, Expr],
) -> Expr {
  match bound {
    Expr::Symbol(name) =>
      match env.get(name) {
        Some(value) =>
          match value {
            Expr::Symbol(_) | Expr::Dummy(_, _) => {
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
            out.push(rename_lambda_bound_vars(item, env, rename_env))
          }
          tuple_expr(out)
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
      Expr::Symbol(name) => if !names.contains(name) { names.push(name) }
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
      Expr::Symbol(name) => if !out.contains(name) { out.push(name) }
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
      Expr::Symbol(name) if names.contains(name) => return true
      _ => ()
    }
  }
  false
}

///|
fn subst_derivative(
  inner : Expr,
  deriv_args : Array[Expr],
  env : Map[String, Expr],
) -> Expr {
  let original_wrt_names = derivative_wrt_names(deriv_args)
  let original_free_names = expr_symbol_names(inner)
  let rename_env : Map[String, Expr] = {}
  let inner_env = clone_subst_env(env)
  let outer_env : Map[String, Expr] = {}

  for wrt_name in original_wrt_names {
    match env.get(wrt_name) {
      Some(value) => {
        let safe_rename = match value {
          Expr::Symbol(new_name) =>
            new_name == wrt_name ||
            (
              !original_free_names.contains(new_name) &&
              !original_wrt_names.contains(new_name)
            )
          Expr::Dummy(_, _) => true
          _ => false
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
  let rebuilt = Expr::Derivative(subst(renamed_inner, inner_env), renamed_args)
  let outer_keys : Array[String] = []
  for key in outer_env.keys() {
    outer_keys.push(key)
  }
  outer_keys.sort()
  let mut out = rebuilt
  for key in outer_keys {
    match outer_env.get(key) {
      Some(value) => out = subs_expr(out, symbol(key), subst(value, env))
      None => ()
    }
  }
  out
}

///|
pub fn subst(expr : Expr, env : Map[String, Expr]) -> Expr {
  match expr {
    Expr::Symbol(name) =>
      match env.get(name) {
        Some(value) => value
        None => expr
      }
    Expr::Dummy(_, _) | Expr::Wild(_) => expr
    Expr::Number(_)
    | Expr::Float(_)
    | Expr::ComplexFloat(_)
    | Expr::NumberSymbol(_)
    | Expr::UndefinedFunction(_)
    | Expr::Boolean(_) => expr
    Expr::AppliedUndef(name, args) =>
      applied_undefined_function(name, args.map(arg => subst(arg, env)))
    Expr::Derivative(inner, deriv_args) =>
      subst_derivative(inner, deriv_args, env)
    Expr::Lambda(vars, body) => {
      let rename_env : Map[String, Expr] = {}
      let renamed_vars = rename_lambda_bound_vars(vars, env, rename_env)
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
    Expr::Subs(inner, variable, value) => {
      let restricted = clone_subst_env(env)
      remove_bound_names_from_env(variable, restricted)
      subs_expr(subst(inner, restricted), variable, subst(value, env))
    }
    _ => map_children(expr, child => subst(child, env))
  }
}

///|
pub fn xreplace(expr : Expr, rules : Array[(Expr, Expr)]) -> Expr {
  for rule in rules {
    let (old_expr, new_expr) = rule
    if expr == old_expr {
      return new_expr
    }
  }
  map_children(expr, child => xreplace(child, rules))
}
