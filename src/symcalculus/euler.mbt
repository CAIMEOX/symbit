///|
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
    Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn expr_is_number(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_is_symbol(expr : Expr) -> Bool {
  match expr {
    Expr::Symbol(_) => true
    _ => false
  }
}

///|
fn expr_depends_on(expr : Expr, wrt : Expr) -> Bool {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return true
  }
  match expr {
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(arg => expr_depends_on(arg, wrt))
    Expr::Pow(base, exp) =>
      expr_depends_on(base, wrt) || expr_depends_on(exp, wrt)
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
fn diff_mul(args : Array[Expr], wrt : Expr) -> Expr {
  let out : Array[Expr] = Array::new()
  for i in 0..<args.length() {
    let d = diff(args[i], wrt)
    if expr_is_zero(d) {
      continue
    }
    let factors : Array[Expr] = Array::new()
    for j in 0..<args.length() {
      if i == j {
        factors.push(d)
      } else {
        factors.push(args[j])
      }
    }
    out.push(@symcore.mul(factors))
  }
  if out.is_empty() {
    @symcore.int(0)
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
      let pow_expr = @symcore.pow(base, @symcore.Expr::Number(n_minus_one))
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
    "tan" => {
      let sec2 = @symcore.pow(@symcore.function("sec", [arg]), @symcore.int(2))
      @symcore.mul([sec2, darg])
    }
    "gamma" => {
      let g = @symcore.function("gamma", [arg])
      let dg = @symcore.function("digamma", [arg])
      @symcore.mul([g, dg, darg])
    }
    _ =>
      if expr_depends_on(@symcore.function(name, args), wrt) {
        derivative_expr(@symcore.function(name, args), [wrt])
      } else {
        @symcore.int(0)
      }
  }
}

///|
pub fn diff(expr : Expr, wrt : Expr) -> Expr {
  if @symcore.compare_expr(expr, wrt) == 0 {
    return @symcore.int(1)
  }
  match expr {
    Expr::Number(_)
    | Expr::Float(_)
    | Expr::ComplexFloat(_)
    | Expr::NumberSymbol(_)
    | Expr::Boolean(_) => @symcore.int(0)
    Expr::Symbol(_)
    | Expr::Dummy(_, _)
    | Expr::Wild(_, _, _)
    | Expr::FunctionHead(_)
    | Expr::UndefinedFunction(_) => @symcore.int(0)
    Expr::Apply(head, args) =>
      match @symcore.function_head_name(head) {
        Some(name) => diff_function(name, args, wrt)
        None =>
          if args.any(arg => expr_depends_on(arg, wrt)) {
            derivative_expr(expr, [wrt])
          } else {
            @symcore.int(0)
          }
      }
    Expr::Add(args) => diff_add(args, wrt)
    Expr::Mul(args) => diff_mul(args, wrt)
    Expr::Pow(base, exp) => diff_pow(base, exp, wrt)
    Expr::Mod(_, _) =>
      if expr_depends_on(expr, wrt) {
        derivative_expr(expr, [wrt])
      } else {
        @symcore.int(0)
      }
    Expr::Tuple(_)
    | Expr::Dict(_)
    | Expr::Relational(_, _, _)
    | Expr::Subs(_, _, _)
    | Expr::Lambda(_, _) =>
      if expr_depends_on(expr, wrt) {
        derivative_expr(expr, [wrt])
      } else {
        @symcore.int(0)
      }
    Expr::Derivative(_, _) =>
      if expr_is_symbol(wrt) {
        derivative_expr(expr, [wrt])
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
        Expr::Add(args) | Expr::Mul(args) => {
          let mut max = 0
          for arg in args {
            let m = max_derivative_order(arg, target)
            if m > max {
              max = m
            }
          }
          max
        }
        Expr::Pow(base, exp) => {
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
    let eq_expr = @symcore.Expr::Relational(
      @symcore.RelOp::Eq,
      eq,
      @symcore.int(0),
    )
    eqns.push(eq_expr)
  }
  eqns
}
