///|
pub type Expr = @symcore.Expr

///|
fn expr_simplify(expr : Expr) -> Expr {
  @symsimplify.simplify(expr)
}

///|
fn expr_neg(expr : Expr) -> Expr {
  expr_simplify(@symcore.mul([@symcore.int(-1), expr]))
}

///|
fn expr_add(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(@symcore.add([lhs, rhs]))
}

///|
fn expr_sub(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(@symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]))
}

///|
fn expr_mul(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(@symcore.mul([lhs, rhs]))
}

///|
fn expr_div(lhs : Expr, rhs : Expr) -> Expr {
  expr_simplify(@symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))]))
}

///|
fn expr_is_zero(expr : Expr) -> Bool {
  expr_simplify(expr) == @symcore.int(0)
}

///|
fn expr_eq(lhs : Expr, rhs : Expr) -> Bool {
  expr_is_zero(expr_sub(lhs, rhs))
}

///|
fn clone_expr_rows(rows : Array[Array[Expr]]) -> Array[Array[Expr]] {
  let out : Array[Array[Expr]] = []
  for row in rows {
    let copied : Array[Expr] = []
    for item in row {
      copied.push(item)
    }
    out.push(copied)
  }
  out
}

///|
fn matrix_string(rows : Array[Array[Expr]]) -> String {
  let rendered_rows : Array[String] = []
  for row in rows {
    rendered_rows.push("[" + row.map(@symprint.pretty_string).join(", ") + "]")
  }
  "Matrix([" + rendered_rows.join(", ") + "])"
}
