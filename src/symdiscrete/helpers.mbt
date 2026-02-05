///|
pub type Expr = @symcore.Expr

///|
pub type BigRational = @symnum.BigRational

///|
pub type BigInt = @bigint.BigInt

///|
fn expr_zero() -> Expr {
  @symcore.int(0)
}

///|
fn expr_one() -> Expr {
  @symcore.int(1)
}

///|
fn expr_neg_one() -> Expr {
  @symcore.int(-1)
}

///|
fn expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn expr_rational(num : Int, den : Int) -> Expr {
  if den == 1 {
    return expr_int(num)
  }
  try! @symcore.rational_from_ints(num, den)
}

///|
fn expr_add2(a : Expr, b : Expr) -> Expr {
  @symcore.add([a, b])
}

///|
fn expr_mul2(a : Expr, b : Expr) -> Expr {
  @symcore.mul([a, b])
}

///|
fn expr_neg(a : Expr) -> Expr {
  expr_mul2(expr_neg_one(), a)
}

///|
fn expr_sub(a : Expr, b : Expr) -> Expr {
  expr_add2(a, expr_neg(b))
}

///|
fn expr_div_int(a : Expr, n : Int) -> Expr {
  expr_mul2(a, expr_rational(1, n))
}

///|
fn expr_sqrt(a : Expr) -> Expr {
  @symcore.function("sqrt", [a])
}

///|
fn expr_i() -> Expr {
  @symcore.symbol("I")
}

///|
fn expr_pi() -> Expr {
  @symcore.symbol("pi")
}

///|

///|
fn is_const_symbol(name : String) -> Bool {
  name == "I" || name == "pi" || name == "E"
}

///|
fn expr_has_symbol(expr : Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => !is_const_symbol(name)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => expr_has_symbol(child))
    @symcore.Expr::Pow(base, exp) =>
      expr_has_symbol(base) || expr_has_symbol(exp)
    @symcore.Expr::Function(_, args) =>
      args.any(child => expr_has_symbol(child))
    _ => false
  }
}

///|
fn expr_number_value(expr : Expr) -> BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|

///|
fn bigint_to_int_checked(
  value : BigInt,
  max_bits : Int,
  context : String,
) -> Int raise DiscreteError {
  if value.bit_length() > max_bits {
    raise DiscreteError::ValueError("\{context} too large")
  }
  value.to_int()
}

///|
fn expr_to_int_checked(
  expr : Expr,
  context : String,
) -> Int raise DiscreteError {
  match expr_number_value(expr) {
    Some(n) if n.is_integral() =>
      bigint_to_int_checked(n.numerator(), 62, context)
    _ => raise DiscreteError::ValueError("expected integer input")
  }
}

///|
fn mul_mod_int(a : Int, b : Int, modulus : Int) -> Int {
  let res = @bigint.BigInt::from_int(a) *
    @bigint.BigInt::from_int(b) %
    @bigint.BigInt::from_int(modulus)
  res.to_int()
}

///|
fn expand_mul(expr : Expr) -> Expr {
  match expr {
    @symcore.Expr::Mul(args) => expand_mul_args(args)
    @symcore.Expr::Add(args) => @symcore.add(args.map(expand_mul))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(expand_mul(base), expand_mul(exp))
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(expand_mul))
    _ => expr
  }
}

///|
fn expand_mul_args(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    return expr_one()
  }
  let mut terms : Array[Expr] = [expr_one()]
  for arg in args {
    let expanded = expand_mul(arg)
    match expanded {
      @symcore.Expr::Add(adds) => {
        let next_terms : Array[Expr] = Array::new()
        for term in terms {
          for add in adds {
            next_terms.push(@symcore.mul([term, add]))
          }
        }
        terms = next_terms
      }
      _ =>
        for i in 0..<terms.length() {
          terms[i] = @symcore.mul([terms[i], expanded])
        }
    }
  }
  if terms.length() == 1 {
    terms[0]
  } else {
    @symcore.add(terms)
  }
}
