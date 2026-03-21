///|
/// Hypergeometric and Meijer G functions.

///|
pub fn hyper(a : Array[Expr], b : Array[Expr], z : Expr) -> Expr {
  let args : Array[Expr] = Array::new()
  args.push(@symcore.function("Tuple", a))
  args.push(@symcore.function("Tuple", b))
  args.push(z)
  @symcore.function("hyper", args)
}

///|
pub fn meijerg(
  a1 : Array[Expr],
  a2 : Array[Expr],
  b1 : Array[Expr],
  b2 : Array[Expr],
  z : Expr,
) -> Expr {
  let args : Array[Expr] = Array::new()
  let a = @symcore.function("Tuple", [
    @symcore.function("Tuple", a1),
    @symcore.function("Tuple", a2),
  ])
  let b = @symcore.function("Tuple", [
    @symcore.function("Tuple", b1),
    @symcore.function("Tuple", b2),
  ])
  args.push(a)
  args.push(b)
  args.push(z)
  @symcore.function("meijerg", args)
}

///|
pub fn appellf1(
  a : Expr,
  b1 : Expr,
  b2 : Expr,
  c : Expr,
  x : Expr,
  y : Expr,
) -> Expr {
  @symcore.function("appellf1", [a, b1, b2, c, x, y])
}
