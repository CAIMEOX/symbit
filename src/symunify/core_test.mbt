///|
enum CoreAtom {
  Text(String)
  Int(Int)
} derive(Eq, Hash)

///|
fn render_atom(atom_ : CoreAtom) -> String {
  match atom_ {
    CoreAtom::Text(text) => text
    CoreAtom::Int(value) => value.to_string()
  }
}

///|
fn render_key(key : MatchVar[CoreAtom]) -> String {
  match key {
    MatchVar::Variable(key0) => "Variable(" + render_atom(key0.arg()) + ")"
    MatchVar::CondVariable(key0) =>
      "CondVariable(" + render_atom(key0.arg()) + ")"
  }
}

///|
fn render_core_term(term : UnifyTerm[CoreAtom, String]) -> String {
  match term {
    UnifyTerm::Atom(atom_) => render_atom(atom_)
    UnifyTerm::Variable(key0) => "Variable(" + render_atom(key0.arg()) + ")"
    UnifyTerm::CondVariable(key0, _) =>
      "CondVariable(" + render_atom(key0.arg()) + ")"
    UnifyTerm::Sequence(items) =>
      "(" + items.map(render_core_term).join(", ") + ")"
    UnifyTerm::Compound(op, args) =>
      op + "[" + args.map(render_core_term).join(", ") + "]"
  }
}

///|
fn render_subst(subst : Substitution[CoreAtom, String]) -> String {
  let rendered = substitution_pairs(subst).map(entry => {
    render_key(entry.0) + ": " + render_core_term(entry.1)
  })
  rendered.sort()
  "{" + rendered.join(", ") + "}"
}

///|
fn render_substs(items : Array[Substitution[CoreAtom, String]]) -> String {
  let rendered = items.map(render_subst)
  rendered.sort()
  "[" + rendered.join(", ") + "]"
}

///|
fn t(text : String) -> UnifyTerm[CoreAtom, String] {
  atom(CoreAtom::Text(text))
}

///|
fn i(value : Int) -> UnifyTerm[CoreAtom, String] {
  atom(CoreAtom::Int(value))
}

///|
fn add(
  args : Array[UnifyTerm[CoreAtom, String]],
) -> UnifyTerm[CoreAtom, String] {
  compound("Add", args)
}

///|
fn mul(
  args : Array[UnifyTerm[CoreAtom, String]],
) -> UnifyTerm[CoreAtom, String] {
  compound("Mul", args)
}

///|
fn cadd(
  args : Array[UnifyTerm[CoreAtom, String]],
) -> UnifyTerm[CoreAtom, String] {
  compound("CAdd", args)
}

///|
let w_key : VariableKey[CoreAtom] = variable(CoreAtom::Text("w"))

///|
let x_key : VariableKey[CoreAtom] = variable(CoreAtom::Text("x"))

///|
let y_key : VariableKey[CoreAtom] = variable(CoreAtom::Text("y"))

///|
let z_key : VariableKey[CoreAtom] = variable(CoreAtom::Text("z"))

///|
let w_var : UnifyTerm[CoreAtom, String] = variable_term(w_key)

///|
let x_var : UnifyTerm[CoreAtom, String] = variable_term(x_key)

///|
let y_var : UnifyTerm[CoreAtom, String] = variable_term(y_key)

///|
let z_var : UnifyTerm[CoreAtom, String] = variable_term(z_key)

///|
fn bind_x(term : UnifyTerm[CoreAtom, String]) -> Substitution[CoreAtom, String] {
  let subst : Substitution[CoreAtom, String] = {}
  subst[MatchVar::Variable(x_key)] = term
  subst
}

///|
fn is_associative(term : UnifyTerm[CoreAtom, String]) -> Bool {
  match term {
    UnifyTerm::Compound(op, _) =>
      op == "Add" || op == "Mul" || op == "CAdd" || op == "CMul"
    _ => false
  }
}

///|
fn is_commutative(term : UnifyTerm[CoreAtom, String]) -> Bool {
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
  core_unify(lhs, rhs, s=subst, is_associative~, is_commutative~)
}

///|
test "unify core handles basic substitutions" {
  inspect(
    render_substs(core_match(t("a"), x_var)),
    content="[{Variable(x): a}]",
  )
  inspect(
    render_substs(core_match(t("a"), x_var, subst=bind_x(i(10)))),
    content="[]",
  )
  inspect(render_substs(core_match(i(1), x_var)), content="[{Variable(x): 1}]")
  inspect(render_substs(core_match(t("a"), t("a"))), content="[{}]")
  inspect(
    render_substs(
      core_match(sequence([w_var, x_var]), sequence([y_var, z_var])),
    ),
    content="[{Variable(w): Variable(y), Variable(x): Variable(z)}]",
  )
  inspect(
    render_substs(core_match(x_var, sequence([t("a"), t("b")]))),
    content="[{Variable(x): (a, b)}]",
  )
}

///|
test "unify core handles compound matching and associative regrouping" {
  inspect(
    render_substs(
      core_match(add([t("a"), t("b"), t("c")]), add([t("a"), x_var, y_var])),
    ),
    content="[{Variable(x): b, Variable(y): c}]",
  )
  let mul_match = render_substs(
    core_match(
      add([mul([i(1), i(2)]), t("b"), t("c")]),
      add([x_var, y_var, t("c")]),
    ),
  )
  inspect(
    mul_match.contains("Variable(x): Mul[1, 2]") &&
    mul_match.contains("Variable(y): b"),
    content="true",
  )
  let assoc_match = render_substs(
    core_match(add([i(1), i(2), i(3)]), add([x_var, y_var])),
  )
  inspect(
    assoc_match.contains("{Variable(x): 1, Variable(y): Add[2, 3]}") &&
    assoc_match.contains("Variable(x): Add[1, 2]") &&
    assoc_match.contains("Variable(y): 3"),
    content="true",
  )
}

///|
test "unify core handles commutative regrouping and conditional variables" {
  let even_key = cond_variable(CoreAtom::Text("y"))
  let large_key = cond_variable(CoreAtom::Text("z"))
  let even_var : UnifyTerm[CoreAtom, String] = cond_variable_term(even_key, term => {
    match term {
      UnifyTerm::Atom(CoreAtom::Int(value)) => value % 2 == 0
      _ => false
    }
  })
  let large_var : UnifyTerm[CoreAtom, String] = cond_variable_term(large_key, term => {
    match term {
      UnifyTerm::Atom(CoreAtom::Int(value)) => value > 3
      _ => false
    }
  })

  let comm_results = core_match(cadd([i(1), i(2), i(3)]), cadd([x_var, y_var]))
  inspect(comm_results.length(), content="12")
  inspect(
    render_substs(core_match(cadd([i(1), i(2)]), cadd([x_var, even_var]))),
    content="[{Variable(x): 1, CondVariable(y): 2}]",
  )
  inspect(
    render_substs(core_match(cadd([i(1), i(2)]), cadd([large_var, even_var]))),
    content="[]",
  )
}

///|
test "unify core allcombinations matches SymPy examples" {
  let assoc = allcombinations([1, 2, 3], [5, 6], CombineMode::Associative)
  inspect(assoc.length(), content="2")
  let comm = allcombinations([1, 2], [1, 2], CombineMode::Commutative)
  inspect(comm.length(), content="2")
}
