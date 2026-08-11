///|
/// Differentiation and Euler-Lagrange helpers.
///
/// Current Limits:
/// - Differentiation covers common arithmetic, selected elementary functions,
///   and symbolic derivative fallback.
/// - Full assumption-aware calculus and all special-function derivatives are
///   not complete.

///|
/// Build a derivative expression with explicit differentiation variables.
///
/// This constructs the symbolic derivative node directly without evaluating it.
///
/// - Does: Creates a symbolic derivative node.
/// - Input: A source expression and an ordered array of differentiation
///   variables.
/// - Returns: A `Derivative` expression.
/// - Limits: Does not evaluate the derivative or validate higher-order grouping
///   beyond the shared core constructor.
pub fn derivative_expr(expr : Expr, vars : Array[Expr]) -> Expr {
  let args : Array[Expr] = Array::new()
  args.push(expr)
  for v in vars {
    args.push(v)
  }
  @symcore.raw_derivative(expr, args[1:])
}

///|
fn expr_is_zero(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn expr_is_number(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_is_symbol(expr : Expr) -> Bool {
  match expr {
    Symbol(_) => true
    _ => false
  }
}

///|
fn expr_is_symbol_like(expr : Expr) -> Bool {
  match expr {
    Symbol(_) | Dummy(_, _) => true
    _ => false
  }
}

///|
fn subs_items_local(expr : Expr) -> Array[Expr] {
  match expr {
    Tuple(items) => items
    other => [other]
  }
}

///|
fn append_derivative_wrt(
  inner : Expr,
  deriv_args : Array[Expr],
  wrt : Expr,
) -> Expr {
  let out = @symcore.canonical_derivative_args(deriv_args[:])
  if out.length() >= 2 && @symcore.compare_expr(out[out.length() - 2], wrt) == 0 {
    match out[out.length() - 1] {
      Number(n) if n.denominator() == 1N => {
        out[out.length() - 1] = Number(n.add_r(@symnum.BigRational::one()))
        return Derivative(inner, out)
      }
      _ => ()
    }
  }
  out.push(wrt)
  out.push(@symcore.int(1))
  Derivative(inner, out)
}

///|
fn diff_subs_chain(
  inner : Expr,
  variable : Expr,
  value : Expr,
  wrt : Expr,
) -> Expr? {
  guard @symcore.subs_signature_error(variable, value) is None else {
    return None
  }
  let variables = subs_items_local(variable)
  let values = subs_items_local(value)
  for item in variables {
    guard expr_is_symbol_like(item) else { return None }
  }
  let out : Array[Expr] = Array::new()
  if !variables.any(item => @symcore.compare_expr(item, wrt) == 0) {
    let direct = diff(inner, wrt)
    if !expr_is_zero(direct) {
      out.push(@symcore.subs_expr(direct, variable, value))
    }
  }
  for i in 0..<variables.length() {
    let dvalue = diff(values[i], wrt)
    if expr_is_zero(dvalue) {
      continue
    }
    let partial = diff(inner, variables[i])
    if expr_is_zero(partial) {
      continue
    }
    out.push(
      @symcore.mul([@symcore.subs_expr(partial, variable, value), dvalue]),
    )
  }
  Some(if out.is_empty() { @symcore.int(0) } else { @symcore.add(out) })
}

///|
fn expr_depends_on(expr : Expr, wrt : Expr) -> Bool {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return true
  }
  match expr {
    Add(args) | Mul(args) => args.any(arg => expr_depends_on(arg, wrt))
    Pow(base, exp) => expr_depends_on(base, wrt) || expr_depends_on(exp, wrt)
    _ => @symcore.args(expr).any(arg => expr_depends_on(arg, wrt))
  }
}

///|
fn diff_add(args : Array[Expr], wrt : Expr) -> Expr {
  let out : Array[Expr] = Array::new()
  for arg in args {
    let d = diff(arg, wrt)
    if !expr_is_zero(d) {
      out.push(d)
    }
  }
  if out.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(out)
  }
}

///|
fn can_build_diff_mul_term_fast(
  args : Array[Expr],
  replace_index : Int,
  d : Expr,
) -> Bool {
  match d {
    Number(_) | Float(_) | ComplexFloat(_) | Mul(_) => return false
    _ => ()
  }
  for j in 0..<args.length() {
    if j != replace_index && @symcore.compare_expr_normalized(args[j], d) == 0 {
      return false
    }
  }
  true
}

///|
fn build_diff_mul_term(
  args : Array[Expr],
  replace_index : Int,
  d : Expr,
) -> Expr {
  if !can_build_diff_mul_term_fast(args, replace_index, d) {
    let factors : Array[Expr] = Array::new()
    for j in 0..<args.length() {
      if replace_index == j {
        factors.push(d)
      } else {
        factors.push(args[j])
      }
    }
    return @symcore.mul(factors)
  }
  let factors : Array[Expr] = Array::new()
  let mut inserted = false
  for j in 0..<args.length() {
    if j == replace_index {
      continue
    }
    let factor = args[j]
    if !inserted && @symcore.compare_expr_normalized(d, factor) < 0 {
      factors.push(d)
      inserted = true
    }
    factors.push(factor)
  }
  if !inserted {
    factors.push(d)
  }
  match factors.length() {
    0 => @symcore.int(1)
    1 => factors[0]
    _ => Mul(factors)
  }
}

///|
fn diff_mul(args : Array[Expr], wrt : Expr) -> Expr {
  let out : Array[Expr] = Array::new()
  let mut can_return_direct_add = true
  for i in 0..<args.length() {
    let d = diff(args[i], wrt)
    if expr_is_zero(d) {
      continue
    }
    let term = build_diff_mul_term(args, i, d)
    if can_return_direct_add {
      match term {
        Number(_) | Float(_) | ComplexFloat(_) | Add(_) =>
          can_return_direct_add = false
        _ => ()
      }
    }
    if !can_return_direct_add {
      out.push(term)
      continue
    }
    let mut insert_at = out.length()
    let mut duplicate = false
    while insert_at > 0 {
      let cmp = @symcore.compare_expr_normalized(out[insert_at - 1], term)
      if cmp == 0 {
        duplicate = true
        break
      }
      if cmp < 0 {
        break
      }
      insert_at -= 1
    }
    if duplicate {
      can_return_direct_add = false
      out.push(term)
    } else {
      out.insert(insert_at, term)
    }
  }
  if out.is_empty() {
    @symcore.int(0)
  } else if out.length() == 1 {
    out[0]
  } else if can_return_direct_add {
    Add(out)
  } else {
    @symcore.add(out)
  }
}

///|
fn diff_pow(base : Expr, exp : Expr, wrt : Expr) -> Expr {
  let dbase = diff(base, wrt)
  if expr_is_zero(dbase) {
    return @symcore.int(0)
  }
  match expr_is_number(exp) {
    Some(n) => {
      let one = @symnum.BigRational::one()
      let n_minus_one = n.add_r(one.neg_r())
      let coeff = @symcore.Expr::Number(n)
      let pow_expr = @symcore.pow(base, Number(n_minus_one))
      @symcore.mul([coeff, pow_expr, dbase])
    }
    None =>
      if expr_depends_on(exp, wrt) {
        derivative_expr(@symcore.pow(base, exp), [wrt])
      } else {
        @symcore.mul([
          exp,
          @symcore.pow(base, @symcore.add([exp, @symcore.int(-1)])),
          dbase,
        ])
      }
  }
}

///|
fn diff_function(name : String, args : Array[Expr], wrt : Expr) -> Expr {
  if args.is_empty() {
    return @symcore.int(0)
  }
  let arg = args[0]
  let darg = diff(arg, wrt)
  if expr_is_zero(darg) {
    return @symcore.int(0)
  }
  match name {
    "sin" => @symcore.mul([@symcore.function("cos", [arg]), darg])
    "cos" =>
      @symcore.mul([@symcore.int(-1), @symcore.function("sin", [arg]), darg])
    "exp" => @symcore.mul([@symcore.function("exp", [arg]), darg])
    "log" => @symcore.mul([darg, @symcore.pow(arg, @symcore.int(-1))])
    "sqrt" => {
      let denom = @symcore.mul([
        @symcore.int(2),
        @symcore.function("sqrt", [arg]),
      ])
      @symcore.mul([darg, @symcore.pow(denom, @symcore.int(-1))])
    }
    "tan" => {
      let sec2 = @symcore.pow(@symcore.function("sec", [arg]), @symcore.int(2))
      @symcore.mul([sec2, darg])
    }
    "atan" =>
      @symcore.mul([
        darg,
        @symcore.pow(
          @symcore.add([@symcore.int(1), @symcore.pow(arg, @symcore.int(2))]),
          @symcore.int(-1),
        ),
      ])
    "gamma" => {
      let g = @symcore.function("gamma", [arg])
      let dg = @symcore.function("digamma", [arg])
      @symcore.mul([g, dg, darg])
    }
    _ => diff_apply(FunctionHead(name), args, wrt)
  }
}

///|
fn diff_apply(head : Expr, args : Array[Expr], wrt : Expr) -> Expr {
  if args.is_empty() {
    return @symcore.int(0)
  }
  let out : Array[Expr] = Array::new()
  for i in 0..<args.length() {
    let darg = diff(args[i], wrt)
    if expr_is_zero(darg) {
      continue
    }
    let lifted = args.copy()
    let dummy = @symcore.Expr::Symbol("_xi\{i}")
    lifted[i] = dummy
    let partial = @symcore.Expr::Subs(
      derivative_expr(Apply(head, lifted), [dummy]),
      dummy,
      args[i],
    )
    out.push(@symcore.mul([partial, darg]))
  }
  if out.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(out)
  }
}

///|
fn diff_undefined_function(
  expr : Expr,
  head : Expr,
  args : Array[Expr],
  wrt : Expr,
) -> Expr {
  if args.is_empty() {
    return @symcore.int(0)
  }
  if args.all(arg => expr_is_symbol_like(arg)) &&
    args.any(arg => @symcore.compare_expr(arg, wrt) == 0) {
    return derivative_expr(expr, [wrt])
  }
  diff_apply(head, args, wrt)
}

///|
/// Differentiate an expression with respect to one variable.
///
/// The implementation handles common arithmetic, several standard elementary
/// functions, symbolic applications, and simple substitution-chain cases.
///
/// - Does: Differentiates an expression with respect to one variable.
/// - Input: A source expression and one differentiation variable.
/// - Returns: A symbolic derivative result.
/// - Limits: Unsupported dependent constructs are preserved as symbolic
///   derivative nodes or return conservative zero when independent.
pub fn diff(expr : Expr, wrt : Expr) -> Expr {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return @symcore.int(1)
  }
  match expr {
    Number(_) | Float(_) | ComplexFloat(_) | NumberSymbol(_) | Boolean(_) =>
      @symcore.int(0)
    Symbol(_)
    | Dummy(_, _)
    | Wild(_, _, _)
    | FunctionHead(_)
    | UndefinedFunction(_) => @symcore.int(0)
    Apply(head, args) =>
      match @symcore.undefined_application_parts(expr) {
        Some((_, undefined_args)) =>
          diff_undefined_function(expr, head, undefined_args, wrt)
        None =>
          match @symcore.function_head_name(head) {
            Some(name) => diff_function(name, args, wrt)
            None => diff_apply(head, args, wrt)
          }
      }
    Add(args) => diff_add(args, wrt)
    Mul(args) => diff_mul(args, wrt)
    Pow(base, exp) => diff_pow(base, exp, wrt)
    Mod(_, _) =>
      if expr_depends_on(expr, wrt) {
        derivative_expr(expr, [wrt])
      } else {
        @symcore.int(0)
      }
    Subs(inner, variable, value) =>
      match diff_subs_chain(inner, variable, value, wrt) {
        Some(applied) => applied
        None =>
          if expr_depends_on(expr, wrt) {
            derivative_expr(expr, [wrt])
          } else {
            @symcore.int(0)
          }
      }
    Tuple(_) | Dict(_) | Relational(_, _, _) | Lambda(_, _) =>
      if expr_depends_on(expr, wrt) {
        derivative_expr(expr, [wrt])
      } else {
        @symcore.int(0)
      }
    Derivative(inner, deriv_args) =>
      if expr_is_symbol(wrt) && expr_depends_on(expr, wrt) {
        append_derivative_wrt(inner, deriv_args, wrt)
      } else {
        @symcore.int(0)
      }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.function_head_name(head) {
            Some(name) => diff_function(name, args, wrt)
            None => @symcore.int(0)
          }
        None => @symcore.int(0)
      }
  }
}

///|
fn max_derivative_order(expr : Expr, target : Expr) -> Int {
  match @symcore.derivative_parts(expr) {
    Some((head, deriv_args)) =>
      if @symcore.compare_expr(head, target) == 0 {
        deriv_args.length() / 2
      } else {
        let mut max = 0
        for arg in @symcore.args(expr) {
          let m = max_derivative_order(arg, target)
          if m > max {
            max = m
          }
        }
        max
      }
    None =>
      match expr {
        Add(args) | Mul(args) => {
          let mut max = 0
          for arg in args {
            let m = max_derivative_order(arg, target)
            if m > max {
              max = m
            }
          }
          max
        }
        Pow(base, exp) => {
          let m1 = max_derivative_order(base, target)
          let m2 = max_derivative_order(exp, target)
          if m1 > m2 {
            m1
          } else {
            m2
          }
        }
        _ => {
          let mut max = 0
          for arg in @symcore.args(expr) {
            let m = max_derivative_order(arg, target)
            if m > max {
              max = m
            }
          }
          max
        }
      }
  }
}

///|
fn combinations_with_replacement(
  items : Array[Expr],
  k : Int,
) -> Array[Array[Expr]] {
  let out : Array[Array[Expr]] = Array::new()
  let cur : Array[Expr] = Array::new()
  letrec rec = (start : Int, depth : Int) => {
    if depth == k {
      let snapshot : Array[Expr] = Array::new()
      for v in cur {
        snapshot.push(v)
      }
      out.push(snapshot)
      return
    }
    for i in start..<items.length() {
      cur.push(items[i])
      rec(i, depth + 1)
      ignore(cur.pop())
    }
  }

  rec(0, 0)
  out
}

///|
fn diff_with_vars(expr : Expr, vars : Array[Expr]) -> Expr {
  let mut out = expr
  for v in vars {
    out = diff(out, v)
  }
  out
}

///|
/// Compute Euler-Lagrange equations for a Lagrangian density.
///
/// `funcs` lists the dependent functions and `vars` lists the independent
/// variables. The result is an array of equations of the form `... = 0`.
///
/// - Does: Builds Euler-Lagrange equations for a Lagrangian density.
/// - Input: Lagrangian expression, dependent function expressions, and
///   independent variable expressions.
/// - Returns: An array of equality expressions with right-hand side zero.
/// - Limits: Relies on the current derivative implementation and detects
///   derivative order structurally.
pub fn euler_equations(
  lagrangian : Expr,
  funcs : Array[Expr],
  vars : Array[Expr],
) -> Array[Expr] {
  let eqns : Array[Expr] = Array::new()
  for f in funcs {
    let mut eq = diff(lagrangian, f)
    let order = max_derivative_order(lagrangian, f)
    for i in 1..<=order {
      let combos = combinations_with_replacement(vars, i)
      for p in combos {
        let df = derivative_expr(f, p)
        let term0 = diff(lagrangian, df)
        let term = diff_with_vars(term0, p)
        let sign = if i % 2 == 0 { 1 } else { -1 }
        let signed = @symcore.mul([@symcore.int(sign), term])
        eq = @symcore.add([eq, signed])
      }
    }
    let eq_expr = @symcore.Expr::Relational(Eq, eq, @symcore.int(0))
    eqns.push(eq_expr)
  }
  eqns
}
