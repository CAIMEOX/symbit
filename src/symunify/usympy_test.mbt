///|
fn render_expr_subst(subst : Map[@symcore.Expr, @symcore.Expr]) -> String {
  let rendered : Array[String] = []
  for key, value in subst {
    rendered.push(
      @symprint.pretty_string(key) + ": " + @symprint.pretty_string(value),
    )
  }
  rendered.sort()
  "{" + rendered.join(", ") + "}"
}

///|
fn render_expr_substs(
  items : Array[Map[@symcore.Expr, @symcore.Expr]],
) -> String {
  let rendered = items.map(render_expr_subst)
  rendered.sort()
  "[" + rendered.join(", ") + "]"
}

///|
fn x() -> @symcore.Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn y() -> @symcore.Expr {
  @symcore.Expr::Symbol("y")
}

///|
fn z() -> @symcore.Expr {
  @symcore.Expr::Symbol("z")
}

///|
fn n() -> @symcore.Expr {
  @symcore.Expr::Symbol("n")
}

///|
test "symunify deconstruct and construct preserve core expressions" {
  let expr = @symcore.raw_function("Basic", [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  inspect(
    render_expr_term(deconstruct(expr)),
    content="Function(Basic)[1, 2, 3]",
  )
  inspect(
    @symprint.pretty_string(construct(deconstruct(expr))),
    content="Basic(1, 2, 3)",
  )

  let nested = @symcore.raw_function("Basic", [
    @symcore.int(1),
    @symcore.raw_function("Basic", [@symcore.int(2)]),
    @symcore.int(3),
  ])
  inspect(
    @symprint.pretty_string(construct(deconstruct(nested))),
    content="Basic(1, Basic(2), 3)",
  )
}

///|
fn render_expr_term(term : UnifyTerm[@symcore.Expr, ExprOp]) -> String {
  match term {
    UnifyTerm::Atom(expr) => @symprint.pretty_string(expr)
    UnifyTerm::Variable(key) =>
      "Variable(" + @symprint.pretty_string(key.arg()) + ")"
    UnifyTerm::CondVariable(key, _) =>
      "CondVariable(" + @symprint.pretty_string(key.arg()) + ")"
    UnifyTerm::Sequence(items) =>
      "(" + items.map(render_expr_term).join(", ") + ")"
    UnifyTerm::Compound(op, args) =>
      match op {
        @strategies_util.ExprOp::Number =>
          "Number[" + args.map(render_expr_term).join(", ") + "]"
        @strategies_util.ExprOp::Symbol =>
          "Symbol[" + args.map(render_expr_term).join(", ") + "]"
        @strategies_util.ExprOp::Add =>
          "Add[" + args.map(render_expr_term).join(", ") + "]"
        @strategies_util.ExprOp::Mul =>
          "Mul[" + args.map(render_expr_term).join(", ") + "]"
        @strategies_util.ExprOp::Pow =>
          "Pow[" + args.map(render_expr_term).join(", ") + "]"
        @strategies_util.ExprOp::Function(name) =>
          "Function(" +
          name +
          ")[" +
          args.map(render_expr_term).join(", ") +
          "]"
      }
  }
}

///|
test "symunify unify handles expression variables and associative commutative matches" {
  let expr = @symcore.raw_function("Basic", [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let pattern = @symcore.raw_function("Basic", [a, b, c])
  inspect(
    render_expr_substs(unify(expr, pattern, variables=[a, b, c])),
    content="[{a: 1, b: 2, c: 3}]",
  )

  let add_expr = @symcore.raw_add([
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let p = @symcore.Expr::Symbol("p")
  let q = @symcore.Expr::Symbol("q")
  inspect(
    unify(add_expr, @symcore.raw_add([p, q]), variables=[p, q]).length(),
    content="12",
  )
}

///|
test "symunify handles matrix symbols sets and boolean ops" {
  let xname = @symcore.Expr::Symbol("X")
  let xmat = @symcore.function("MatrixSymbol", [xname, n(), n()])
  let ymat = @symcore.function("MatrixSymbol", [
    @symcore.Expr::Symbol("Y"),
    @symcore.int(2),
    @symcore.int(2),
  ])
  inspect(
    render_expr_substs(unify(xmat, ymat, variables=[n(), xname])),
    content="[{X: Y, n: 2}]",
  )

  let finite = @symcore.function("FiniteSet", [x(), y(), z()])
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  inspect(
    unify(finite, @symcore.function("FiniteSet", [a, b]), variables=[a, b]).length() >
    0,
    content="true",
  )

  let rel = @symcore.function("And", [
    @symcore.function("Gt", [z(), @symcore.int(0)]),
    @symcore.function("Lt", [n(), @symcore.int(3)]),
  ])
  let p = @symcore.Expr::Symbol("p")
  let q = @symcore.Expr::Symbol("q")
  inspect(
    render_expr_substs(
      unify(rel, @symcore.function("And", [p, q]), variables=[p, q]),
    ),
    content="[{p: z > 0, q: n < 3}]",
  )
}
