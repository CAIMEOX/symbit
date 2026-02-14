///|
pub fn combsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  fixpoint_special(expr, rewrite_combsimp, max_passes~)
}

///|
pub fn hyperexpand(
  expr : @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  fixpoint_special(expr, rewrite_hyperexpand, max_passes~)
}

///|
fn fixpoint_special(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
  max_passes? : Int = 6,
) -> @symcore.Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = rewrite_bottom_up_special(cur, rule)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn rewrite_bottom_up_special(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
) -> @symcore.Expr {
  let rewritten = @symcore.map_children(
    expr,
    child => rewrite_bottom_up_special(child, rule),
  )
  rule(rewritten)
}

///|
fn rewrite_combsimp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, args) => rewrite_combinatorial_call(name, args, expr)
    @symcore.Expr::Mul(args) => reduce_factorial_ratios(args)
    _ => expr
  }
}

///|
fn rewrite_combinatorial_call(
  name : String,
  args : Array[@symcore.Expr],
  original : @symcore.Expr,
) -> @symcore.Expr {
  match (name, args) {
    ("factorial", [@symcore.Expr::Number(n)]) =>
      match to_nonnegative_int(n) {
        Some(k) => @symcore.number(int_factorial_rational(k))
        None => original
      }
    ("gamma", [@symcore.Expr::Number(n)]) =>
      match to_positive_int(n) {
        Some(k) => @symcore.number(int_factorial_rational(k - 1))
        None => original
      }
    ("binomial", [@symcore.Expr::Number(n), @symcore.Expr::Number(k)]) =>
      match (to_nonnegative_int(n), to_nonnegative_int(k)) {
        (Some(ni), Some(ki)) =>
          if ki > ni {
            @symcore.int(0)
          } else if ki == 0 || ki == ni {
            @symcore.int(1)
          } else if ki == 1 {
            @symcore.number(n)
          } else {
            @symcore.number(int_binomial_rational(ni, ki))
          }
        _ => original
      }
    ("binomial", [n, @symcore.Expr::Number(k)]) =>
      match to_nonnegative_int(k) {
        Some(0) => @symcore.int(1)
        Some(1) => n
        _ => original
      }
    _ => original
  }
}

///|
fn reduce_factorial_ratios(args : Array[@symcore.Expr]) -> @symcore.Expr {
  let mut reduced = @symcore.mul(args)
  for i in 0..<args.length() {
    for j in 0..<args.length() {
      if i == j {
        continue
      }
      let lhs = args[i]
      let rhs = args[j]
      match (factorial_arg(lhs), inverse_factorial_arg(rhs)) {
        (Some(a), Some(b)) if a == @symcore.add([b, @symcore.int(1)]) =>
          reduced = @symcore.mul([
            @symcore.add([b, @symcore.int(1)]),
            strip_factor_pair(args, i, j),
          ])
        (Some(a), Some(b)) if b == @symcore.add([a, @symcore.int(1)]) =>
          reduced = @symcore.mul([
            @symcore.pow(@symcore.add([a, @symcore.int(1)]), @symcore.int(-1)),
            strip_factor_pair(args, i, j),
          ])
        _ => ()
      }
    }
  }
  reduced
}

///|
fn strip_factor_pair(
  args : Array[@symcore.Expr],
  idx_a : Int,
  idx_b : Int,
) -> @symcore.Expr {
  let kept : Array[@symcore.Expr] = Array::new()
  for i in 0..<args.length() {
    if i == idx_a || i == idx_b {
      continue
    }
    kept.push(args[i])
  }
  @symcore.mul(kept)
}

///|
fn factorial_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Function(name, [arg]) if name == "factorial" => Some(arg)
    _ => None
  }
}

///|
fn inverse_factorial_arg(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Pow(@symcore.Expr::Function(name, [arg]), @symcore.Expr::Number(exp)) =>
      if name == "factorial" && exp.is_integral() && exp.numerator().to_int() == -1 {
        Some(arg)
      } else {
        None
      }
    _ => None
  }
}

///|
fn rewrite_hyperexpand(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [a_params, b_params, z]) if name == "hyper" =>
      match (parse_tuple(a_params), parse_tuple(b_params)) {
        (Some(a), Some(b)) =>
          match (a.length(), b.length()) {
            (0, 0) => @symcore.function("exp", [z])
            (1, 1) if a[0] == b[0] => @symcore.function("exp", [z])
            (1, 0) if a[0] == @symcore.int(1) =>
              @symcore.pow(
                @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), z])]),
                @symcore.int(-1),
              )
            _ => expr
          }
        _ => expr
      }
    _ => expr
  }
}

///|
fn parse_tuple(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function(name, args) if name == "Tuple" => Some(args.map(x => x))
    _ => None
  }
}

///|
fn to_nonnegative_int(n : @symnum.BigRational) -> Int? {
  if !n.is_integral() {
    return None
  }
  let k = n.numerator().to_int()
  if k < 0 {
    None
  } else {
    Some(k)
  }
}

///|
fn to_positive_int(n : @symnum.BigRational) -> Int? {
  match to_nonnegative_int(n) {
    Some(k) if k > 0 => Some(k)
    _ => None
  }
}

///|
fn int_factorial_bigint(n : Int) -> BigInt {
  let mut out = BigInt::from_int(1)
  for i in 2..=n {
    out = out.mul(BigInt::from_int(i))
  }
  out
}

///|
fn int_factorial_rational(n : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_bigint(int_factorial_bigint(n))
}

///|
fn int_binomial_rational(n : Int, k : Int) -> @symnum.BigRational {
  let kk = if k < n - k { k } else { n - k }
  let mut num = BigInt::from_int(1)
  let mut den = BigInt::from_int(1)
  for i in 1..=kk {
    num = num.mul(BigInt::from_int(n - kk + i))
    den = den.mul(BigInt::from_int(i))
  }
  @symnum.BigRational::new(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
}
