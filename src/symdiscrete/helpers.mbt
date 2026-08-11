///|
/// Expression alias used by the discrete-algorithm package.
pub type Expr = @symcore.Expr

///|
/// Rational-number alias used by transform helpers.
pub type BigRational = @symnum.BigRational

///|
/// Big integer alias used by exact modular arithmetic helpers.
pub type BigInt = @bigint.BigInt

///|
fn expr_rational(num : Int, den : Int) -> Expr {
  if den == 1 {
    return @symcore.int(num)
  }
  @symcore.rational_from_ints(num, den) catch {
    _ =>
      @symcore.mul([
        @symcore.int(num),
        @symcore.pow(@symcore.int(den), @symcore.int(-1)),
      ])
  }
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
  expr_mul2(@symcore.int(-1), a)
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
  NumberSymbol(ImaginaryUnit)
}

///|
fn expr_pi() -> Expr {
  NumberSymbol(Pi)
}

///|

///|
fn is_const_symbol(name : String) -> Bool {
  name == "I" || name == "pi" || name == "E"
}

///|
fn expr_has_symbol(expr : Expr) -> Bool {
  match expr {
    Symbol(name) => !is_const_symbol(name)
    Add(args) | Mul(args) => args.any(child => expr_has_symbol(child))
    Pow(base, exp) => expr_has_symbol(base) || expr_has_symbol(exp)
    _ => @symcore.args(expr).any(child => expr_has_symbol(child))
  }
}

///|
fn expr_number_value(expr : Expr) -> BigRational? {
  match expr {
    Number(n) => Some(n)
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
    raise ValueError("\{context} too large")
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
    _ => raise ValueError("expected integer input")
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
    Mul(args) => expand_mul_args(args)
    Add(args) => @symcore.add(args.map(expand_mul))
    Pow(base, exp) => @symcore.pow(expand_mul(base), expand_mul(exp))
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.raw_apply(head, args.map(expand_mul)) {
            Some(next) => next
            None => expr
          }
        None => expr
      }
  }
}

///|
fn expand_mul_args(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    return @symcore.int(1)
  }
  let mut terms : Array[Expr] = [@symcore.int(1)]
  for arg in args {
    let expanded = expand_mul(arg)
    match expanded {
      Add(adds) => {
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
