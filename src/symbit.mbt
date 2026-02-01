///|
pub type Expr = @symcore.Expr

///|
pub type BigRational = @symnum.BigRational

///|
pub fn symbol(name : String) -> Expr {
  @symcore.symbol(name)
}

///|
pub fn integer(value : Int) -> Expr {
  @symcore.int(value)
}

///|
pub fn rational(num : Int, den : Int) -> Expr raise @symnum.RationalError {
  @symcore.rational_from_ints(num, den)
}

///|
pub fn add(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    @symcore.int(0)
  } else {
    let mut acc = args[0]
    for i in 1..<args.length() {
      acc = acc + args[i]
    }
    acc
  }
}

///|
pub fn mul(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    @symcore.int(1)
  } else {
    let mut acc = args[0]
    for i in 1..<args.length() {
      acc = acc * args[i]
    }
    acc
  }
}

///|
pub fn pow(base : Expr, exp : Expr) -> Expr {
  base ^ exp
}

///|
pub fn debug_repr(expr : Expr) -> String {
  @symprint.debug_repr(expr)
}

///|
pub fn to_string(expr : Expr) -> String {
  @symprint.to_string(expr)
}
