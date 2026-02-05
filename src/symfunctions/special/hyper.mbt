///|
/// Hypergeometric and Meijer G functions.

///|
pub fn hyper(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  z : @symcore.Expr,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = Array::new()
  args.push(@symcore.function("Tuple", a))
  args.push(@symcore.function("Tuple", b))
  args.push(z)
  @symcore.function("hyper", args)
}

///|
pub fn meijerg(
  a1 : Array[@symcore.Expr],
  a2 : Array[@symcore.Expr],
  b1 : Array[@symcore.Expr],
  b2 : Array[@symcore.Expr],
  z : @symcore.Expr,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = Array::new()
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
  a : @symcore.Expr,
  b1 : @symcore.Expr,
  b2 : @symcore.Expr,
  c : @symcore.Expr,
  x : @symcore.Expr,
  y : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("appellf1", [a, b1, b2, c, x, y])
}
