///|
fn expr_sym(name : String) -> @symcore.Expr {
  @symcore.symbol(name)
}

///|
fn expr_int(n : Int) -> @symcore.Expr {
  @symcore.int(n)
}

///|
fn expr_pow(base : @symcore.Expr, exp : Int) -> @symcore.Expr {
  @symcore.pow(base, @symcore.int(exp))
}

///|
fn expr_add(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.add(args)
}

///|
fn expr_mul(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.mul(args)
}
