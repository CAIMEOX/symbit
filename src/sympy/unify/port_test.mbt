///|
using @symunify {
  type ExprOp,
  type CombineMode,
  type MatchVar,
  type Substitution,
  type UnifyTerm,
  type VariableKey,
  allcombinations,
  atom,
  compound,
  cond_variable,
  cond_variable_term,
  construct,
  core_unify,
  deconstruct,
  rewriterule,
  substitution_pairs,
  variable,
  variable_term,
  unify,
}

///|
enum CoreAtom {
  Text(String)
  Int(Int)
} derive(Eq, Hash)

///|
fn render_core_atom(atom_ : CoreAtom) -> String {
  match atom_ {
    CoreAtom::Text(text) => text
    CoreAtom::Int(value) => value.to_string()
  }
}

///|
fn render_core_key(key : MatchVar[CoreAtom]) -> String {
  match key {
    MatchVar::Variable(key0) => "Variable(" + render_core_atom(key0.arg()) + ")"
    MatchVar::CondVariable(key0) =>
      "CondVariable(" + render_core_atom(key0.arg()) + ")"
  }
}

///|
fn compare_core_atom(lhs : CoreAtom, rhs : CoreAtom) -> Int {
  match lhs {
    CoreAtom::Text(lhs0) =>
      match rhs {
        CoreAtom::Text(rhs0) => lhs0.compare(rhs0)
        CoreAtom::Int(_) => -1
      }
    CoreAtom::Int(lhs0) =>
      match rhs {
        CoreAtom::Text(_) => 1
        CoreAtom::Int(rhs0) =>
          if lhs0 < rhs0 {
            -1
          } else if lhs0 > rhs0 {
            1
          } else {
            0
          }
      }
  }
}

///|
fn compare_core_key_struct(
  lhs : MatchVar[CoreAtom],
  rhs : MatchVar[CoreAtom],
) -> Int {
  match lhs {
    MatchVar::CondVariable(lhs0) =>
      match rhs {
        MatchVar::CondVariable(rhs0) =>
          compare_core_atom(lhs0.arg(), rhs0.arg())
        MatchVar::Variable(_) => -1
      }
    MatchVar::Variable(lhs0) =>
      match rhs {
        MatchVar::CondVariable(_) => 1
        MatchVar::Variable(rhs0) => compare_core_atom(lhs0.arg(), rhs0.arg())
      }
  }
}

///|
fn render_core_term(term : UnifyTerm[CoreAtom, String]) -> String {
  match term {
    UnifyTerm::Atom(atom_) => render_core_atom(atom_)
    UnifyTerm::Variable(key0) =>
      "Variable(" + render_core_atom(key0.arg()) + ")"
    UnifyTerm::CondVariable(key0, _) =>
      "CondVariable(" + render_core_atom(key0.arg()) + ")"
    UnifyTerm::Sequence(items) =>
      "(" + items.map(render_core_term).join(", ") + ")"
    UnifyTerm::Compound(op, args) =>
      op + "[" + args.map(render_core_term).join(", ") + "]"
  }
}

///|
fn sorted_strings(items : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for item in items {
    out.push(item)
  }
  for i in 1..<out.length() {
    let current = out[i]
    let mut j = i
    while j > 0 && out[j - 1].compare(current) > 0 {
      out[j] = out[j - 1]
      j -= 1
    }
    out[j] = current
  }
  out
}

///|
fn render_core_subst(subst : Substitution[CoreAtom, String]) -> String {
  let ordered = substitution_pairs(subst)
  for i in 1..<ordered.length() {
    let current = ordered[i]
    let mut j = i
    while j > 0 && compare_core_key_struct(ordered[j - 1].0, current.0) > 0 {
      ordered[j] = ordered[j - 1]
      j -= 1
    }
    ordered[j] = current
  }
  let rendered = ordered.map(entry => {
    render_core_key(entry.0) + ": " + render_core_term(entry.1)
  })
  "{" + rendered.join(", ") + "}"
}

///|
fn render_core_substs(items : Array[Substitution[CoreAtom, String]]) -> String {
  let rendered = items.map(render_core_subst)
  "[" + sorted_strings(rendered).join(", ") + "]"
}

///|
fn render_expr_subst(subst : Map[@symcore.Expr, @symcore.Expr]) -> String {
  let rendered : Array[String] = []
  for key, value in subst {
    rendered.push(@symprint.to_string(key) + ": " + @symprint.to_string(value))
  }
  "{" + sorted_strings(rendered).join(", ") + "}"
}

///|
fn render_expr_substs(
  items : Array[Map[@symcore.Expr, @symcore.Expr]],
) -> String {
  let rendered = items.map(render_expr_subst)
  "[" + sorted_strings(rendered).join(", ") + "]"
}

///|
fn render_expr_term(term : UnifyTerm[@symcore.Expr, ExprOp]) -> String {
  match term {
    UnifyTerm::Atom(expr) => @symprint.to_string(expr)
    UnifyTerm::Variable(key) =>
      "Variable(" + @symprint.to_string(key.arg()) + ")"
    UnifyTerm::CondVariable(key, _) =>
      "CondVariable(" + @symprint.to_string(key.arg()) + ")"
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
fn core_is_associative(term : UnifyTerm[CoreAtom, String]) -> Bool {
  match term {
    UnifyTerm::Compound(op, _) =>
      op == "Add" || op == "Mul" || op == "CAdd" || op == "CMul"
    _ => false
  }
}

///|
fn core_is_commutative(term : UnifyTerm[CoreAtom, String]) -> Bool {
  match term {
    UnifyTerm::Compound(op, _) => op == "CAdd" || op == "CMul"
    _ => false
  }
}

///|
fn core_match(
  lhs : UnifyTerm[CoreAtom, String],
  rhs : UnifyTerm[CoreAtom, String],
  subst? : Substitution[CoreAtom, String] = {},
) -> Array[Substitution[CoreAtom, String]] {
  core_unify(
    lhs,
    rhs,
    s=subst,
    is_associative=core_is_associative,
    is_commutative=core_is_commutative,
  )
}

///|
fn ct(text : String) -> UnifyTerm[CoreAtom, String] {
  atom(CoreAtom::Text(text))
}

///|
fn ci(value : Int) -> UnifyTerm[CoreAtom, String] {
  atom(CoreAtom::Int(value))
}

///|
fn cadd(
  args : Array[UnifyTerm[CoreAtom, String]],
) -> UnifyTerm[CoreAtom, String] {
  compound("Add", args)
}

///|
fn ccadd(
  args : Array[UnifyTerm[CoreAtom, String]],
) -> UnifyTerm[CoreAtom, String] {
  compound("CAdd", args)
}

///|
fn core_summary() -> String {
  let x_key : VariableKey[CoreAtom] = variable(CoreAtom::Text("x"))
  let y_key : VariableKey[CoreAtom] = variable(CoreAtom::Text("y"))
  let x_var : UnifyTerm[CoreAtom, String] = variable_term(x_key)
  let y_var : UnifyTerm[CoreAtom, String] = variable_term(y_key)
  let subst_x : Substitution[CoreAtom, String] = {}
  subst_x[MatchVar::Variable(x_key)] = ci(10)
  let even_key = cond_variable(CoreAtom::Text("y"))
  let even_var : UnifyTerm[CoreAtom, String] = cond_variable_term(even_key, term => {
    match term {
      UnifyTerm::Atom(CoreAtom::Int(value)) => value % 2 == 0
      _ => false
    }
  })
  [
    render_core_substs(core_match(ct("a"), x_var)),
    render_core_substs(core_match(ct("a"), x_var, subst=subst_x)),
    render_core_substs(
      core_match(
        cadd([ct("a"), ct("b"), ct("c")]),
        cadd([ct("a"), x_var, y_var]),
      ),
    ),
    render_core_substs(
      core_match(cadd([ci(1), ci(2), ci(3)]), cadd([x_var, y_var])),
    ),
    core_match(ccadd([ci(1), ci(2), ci(3)]), ccadd([x_var, y_var]))
    .length()
    .to_string(),
    render_core_substs(
      core_match(ccadd([ci(1), ci(2)]), ccadd([x_var, even_var])),
    ),
    allcombinations([1, 2], [1, 2], CombineMode::Commutative)
    .length()
    .to_string(),
  ].join("\n")
}

///|
fn usympy_summary() -> String {
  let expr = @symcore.raw_function("Basic", [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  let nested = @symcore.raw_function("Basic", [
    @symcore.int(1),
    @symcore.raw_function("Basic", [@symcore.int(2)]),
    @symcore.int(3),
  ])
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let p = @symcore.Expr::Symbol("p")
  let q = @symcore.Expr::Symbol("q")
  let bool_x = @symcore.Expr::Symbol("x")
  let bool_y = @symcore.Expr::Symbol("y")
  let set_a = @symcore.Expr::Symbol("set_a")
  let set_b = @symcore.Expr::Symbol("set_b")
  let set_c = @symcore.Expr::Symbol("set_c")
  let set_x = @symcore.Expr::Symbol("set_x")
  let set_y = @symcore.Expr::Symbol("set_y")
  let x_name = @symcore.Expr::Symbol("X")
  let n_sym = @symcore.Expr::Symbol("n")
  let xmat = @symcore.function("MatrixSymbol", [x_name, n_sym, n_sym])
  let ymat = @symcore.function("MatrixSymbol", [
    @symcore.Expr::Symbol("Y"),
    @symcore.int(2),
    @symcore.int(2),
  ])
  let finite = @symcore.function("FiniteSet", [set_a, set_b, set_c])
  let rel = @symcore.function("And", [
    @symcore.function("Gt", [@symcore.Expr::Symbol("z"), @symcore.int(0)]),
    @symcore.function("Lt", [n_sym, @symcore.int(3)]),
  ])
  [
    render_expr_term(deconstruct(expr)),
    @symprint.to_string(construct(deconstruct(nested))),
    render_expr_substs(
      unify(expr, @symcore.raw_function("Basic", [a, b, c]), variables=[a, b, c]),
    ),
    unify(
      @symcore.raw_add([@symcore.int(1), @symcore.int(2), @symcore.int(3)]),
      @symcore.raw_add([p, q]),
      variables=[p, q],
    )
    .length()
    .to_string(),
    render_expr_substs(unify(xmat, ymat, variables=[n_sym, x_name])),
    if unify(finite, @symcore.function("FiniteSet", [set_x, set_y]), variables=[
        set_x, set_y,
      ]).length() >
      0 {
      "True"
    } else {
      "False"
    },
    render_expr_substs(
      unify(rel, @symcore.function("And", [bool_x, bool_y]), variables=[
        bool_x, bool_y,
      ]),
    ),
  ].join("\n")
}

///|
fn rewrite_summary() -> String raise {
  let rx = @symcore.Expr::Symbol("x")
  let ry = @symcore.Expr::Symbol("y")
  let rp = @symcore.Expr::Symbol("p")
  let rq = @symcore.Expr::Symbol("q")
  let simple_rule = rewriterule(
    @symcore.raw_function("Basic", [rp, @symcore.int(1)]),
    @symcore.raw_function("Basic", [rp, @symcore.int(2)]),
    variables=[rp],
  )
  let pow_rule = rewriterule(
    @symcore.raw_pow(rp, @symcore.int(2)),
    @symcore.raw_pow(rp, @symcore.int(3)),
    variables=[rp],
  )
  let moderate_rule = rewriterule(
    @symcore.raw_add([
      @symcore.raw_pow(rp, @symcore.int(2)),
      @symcore.raw_pow(rq, @symcore.int(3)),
    ]),
    @symcore.raw_pow(@symcore.raw_mul([rp, rq]), @symcore.int(4)),
    variables=[rp, rq],
  )
  let cond_rule = rewriterule(
    rx,
    @symcore.add([rx, @symcore.int(1)]),
    variables=[rx],
    condition=args => {
      match args {
        [@symcore.Expr::Number(value)] =>
          value.compare(@symnum.BigRational::from_int(10)) < 0
        _ => false
      }
    },
  )
  let assume_rule = rewriterule(
    @symcore.raw_add([rx, ry]),
    @symcore.raw_pow(rx, ry),
    variables=[rx, ry],
    assumption_query=Some(@symassume.q_integer(rx)),
  )
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  [
    "[" +
    simple_rule
    .apply(@symcore.raw_function("Basic", [@symcore.int(3), @symcore.int(1)]))
    .map(@symprint.to_string)
    .join(", ") +
    "]",
    "[" +
    pow_rule
    .apply(@symcore.raw_pow(rx, @symcore.int(2)))
    .map(@symprint.to_string)
    .join(", ") +
    "]",
    "[" +
    moderate_rule
    .apply(
      @symcore.raw_add([
        @symcore.raw_pow(rx, @symcore.int(2)),
        @symcore.raw_pow(ry, @symcore.int(3)),
      ]),
    )
    .map(@symprint.to_string)
    .join(", ") +
    "]",
    "[" +
    cond_rule.apply(@symcore.int(5)).map(@symprint.to_string).join(", ") +
    "]",
    "[" +
    assume_rule
    .apply(@symcore.raw_add([a, b]), assumptions=@symassume.q_integer(b))
    .map(@symprint.to_string)
    .join(", ") +
    "]",
  ].join("\n")
}

///|
test "unify parity core summary" {
  assert_eq(core_summary(), core_parity_summary())
}

///|
test "unify parity usympy summary" {
  assert_eq(usympy_summary(), usympy_parity_summary())
}

///|
test "unify parity rewrite summary" {
  assert_eq(rewrite_summary(), rewrite_parity_summary())
}
