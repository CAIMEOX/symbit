///|
/// Errors raised by the query solver.
///
/// `InconsistentAssumptions` means the supplied assumptions contradict one
/// another, so no truth value can be derived safely.
pub(all) suberror AskError {
  InconsistentAssumptions
}

///|
let global_assumptions_ref : Ref[Array[Query]] = { val: [] }

///|
/// Return a copy of the current global assumptions list.
pub fn get_global_assumptions() -> Array[Query] {
  global_assumptions_ref.val.map(v => v)
}

///|
/// Remove all globally registered assumptions.
pub fn clear_global_assumptions() -> Unit {
  global_assumptions_ref.val = []
}

///|
/// Add one query to the global assumptions list.
///
/// Duplicate entries are ignored.
pub fn add_global_assumption(query : Query) -> Unit {
  for item in global_assumptions_ref.val {
    if item == query {
      return
    }
  }
  global_assumptions_ref.val.push(query)
}

///|
/// Remove one query from the global assumptions list.
pub fn remove_global_assumption(query : Query) -> Unit {
  let kept : Array[Query] = Array::new()
  for item in global_assumptions_ref.val {
    if item != query {
      kept.push(item)
    }
  }
  global_assumptions_ref.val = kept
}

///|
/// Evaluate a proposition against explicit inputs plus the global context.
///
/// This is a convenience wrapper around [`ask`](#ask) that automatically adds
/// assumptions registered through [`add_global_assumption`](#add_global_assumption).
pub fn ask_global(
  proposition : Query,
  assumptions? : Query = query_true(),
  env? : AssumeEnv = {},
) -> Tri raise AskError {
  ask(proposition, assumptions~, env~, context=get_global_assumptions())
}

///|
/// Evaluate a symbolic proposition under assumptions and known symbol facts.
///
/// `assumptions` is an explicit logical guard, `env` supplies per-symbol unary
/// facts, and `context` adds extra propositions that should be treated as true
/// while answering the query. The result is three-valued: true, false, or
/// unknown. Contradictory assumptions raise [`AskError`](#askerror).
pub fn ask(
  proposition : Query,
  assumptions? : Query = query_true(),
  env? : AssumeEnv = {},
  context? : Array[Query] = [],
) -> Tri raise AskError {
  let merged_assumptions = and_q([
    assumptions,
    env_to_query(env),
    and_q(context),
  ])
  let eval_env = assumptions_eval_env(merged_assumptions, env)

  let builder = SatBuilder::new()
  builder.assert_true(merged_assumptions)
  let proposition_var = builder.encode(proposition)

  let relevant_exprs = builder.relevant_exprs()
  for expr in relevant_exprs {
    for fact in known_fact_formulas(expr) {
      builder.assert_true(fact)
    }
  }
  for _, info in builder.atom_infos {
    let (key, args) = info
    for fact in known_atom_formulas(key, args) {
      builder.assert_true(fact)
    }
  }

  builder.apply_direct_atom_truth(eval_env)
  let base_cnf = builder.clauses_copy()
  if !cnf_satisfiable(base_cnf) {
    raise InconsistentAssumptions
  }

  let can_be_true = cnf_satisfiable(with_unit_clause(base_cnf, proposition_var))
  let can_be_false = cnf_satisfiable(
    with_unit_clause(base_cnf, -proposition_var),
  )
  if can_be_true && can_be_false {
    Unknown
  } else if can_be_true {
    True
  } else if can_be_false {
    False
  } else {
    raise InconsistentAssumptions
  }
}

///|
fn assumptions_eval_env(query : Query, base : AssumeEnv) -> AssumeEnv {
  let out : AssumeEnv = Map([])
  for name, facts in base {
    out[name] = normalize_facts(facts)
  }
  collect_conjunct_literals(query, out)
  out
}

///|
fn collect_conjunct_literals(query : Query, env : AssumeEnv) -> Unit {
  match query {
    And(items) =>
      for item in items {
        collect_conjunct_literals(item, env)
      }
    Atom(key, args) => absorb_symbol_literal(env, key, args, True)
    Not(inner) =>
      match inner {
        Atom(key, args) => absorb_symbol_literal(env, key, args, False)
        _ => ()
      }
    _ => ()
  }
}

///|
fn absorb_symbol_literal(
  env : AssumeEnv,
  key : PredicateKey,
  args : Array[Expr],
  value : Tri,
) -> Unit {
  if args.length() != 1 {
    return
  }
  match args[0] {
    Symbol(name) =>
      match key {
        Zero | Nonzero | Integer | Rational | Real | Positive | Nonnegative => {
          let facts = env_get(env, name)
          env[name] = with_symbol_fact(facts, key, value)
        }
        _ => ()
      }
    _ => ()
  }
}

///|
fn with_symbol_fact(
  facts : SymbolFacts,
  key : PredicateKey,
  value : Tri,
) -> SymbolFacts {
  match key {
    Zero =>
      symbol_facts(
        is_zero=value,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    Nonzero =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=value,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    Integer =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=value,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    Rational =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=value,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    Real =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=value,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    Positive =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=value,
        is_nonnegative=facts.is_nonnegative,
      )
    Nonnegative =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=value,
      )
    _ => facts
  }
}

///|
priv struct SatBuilder {
  mut next_var : Int
  clauses : Array[Array[Int]]
  atom_vars : Map[String, Int]
  atom_infos : Map[Int, (PredicateKey, Array[Expr])]
}

///|
fn SatBuilder::new() -> SatBuilder {
  { next_var: 1, clauses: [], atom_vars: {}, atom_infos: {} }
}

///|
fn SatBuilder::fresh(self : SatBuilder) -> Int {
  let v = self.next_var
  self.next_var += 1
  v
}

///|
fn SatBuilder::add_clause(self : SatBuilder, clause : Array[Int]) -> Unit {
  self.clauses.push(clause.map(v => v))
}

///|
fn SatBuilder::assert_true(self : SatBuilder, query : Query) -> Unit {
  let v = self.encode(query)
  self.add_clause([v])
}

///|
fn SatBuilder::encode(self : SatBuilder, query : Query) -> Int {
  match query {
    Bool(v) => {
      let out = self.fresh()
      if v {
        self.add_clause([out])
      } else {
        self.add_clause([-out])
      }
      out
    }
    Atom(key, args) => self.atom_var(key, args)
    Not(inner) => {
      let a = self.encode(inner)
      let v = self.fresh()
      self.add_clause([-v, -a])
      self.add_clause([v, a])
      v
    }
    And(items) => {
      if items.is_empty() {
        return self.encode(query_true())
      }
      let args : Array[Int] = Array::new()
      for item in items {
        args.push(self.encode(item))
      }
      let v = self.fresh()
      for a in args {
        self.add_clause([-v, a])
      }
      let big : Array[Int] = [v]
      for a in args {
        big.push(-a)
      }
      self.add_clause(big)
      v
    }
    Or(items) => {
      if items.is_empty() {
        return self.encode(query_false())
      }
      let args : Array[Int] = Array::new()
      for item in items {
        args.push(self.encode(item))
      }
      let v = self.fresh()
      for a in args {
        self.add_clause([v, -a])
      }
      let big : Array[Int] = [-v]
      for a in args {
        big.push(a)
      }
      self.add_clause(big)
      v
    }
    Implies(lhs, rhs) => self.encode(or_q([not_q(lhs), rhs]))
    Equivalent(items) => {
      if items.length() <= 1 {
        return self.encode(query_true())
      }
      let first = items[0]
      let eq_parts : Array[Query] = Array::new()
      for i in 1..<items.length() {
        let other = items[i]
        eq_parts.push(implies_q(first, other))
        eq_parts.push(implies_q(other, first))
      }
      self.encode(and_q(eq_parts))
    }
  }
}

///|
fn SatBuilder::atom_var(
  self : SatBuilder,
  key : PredicateKey,
  args : Array[Expr],
) -> Int {
  let cache_key = query_atom_key(key, args)
  match self.atom_vars.get(cache_key) {
    Some(v) => v
    None => {
      let v = self.fresh()
      self.atom_vars[cache_key] = v
      self.atom_infos[v] = (key, args.map(x => x))
      v
    }
  }
}

///|
fn SatBuilder::clauses_copy(self : SatBuilder) -> Array[Array[Int]] {
  self.clauses.map(clause => clause.map(x => x))
}

///|
fn SatBuilder::relevant_exprs(self : SatBuilder) -> Array[Expr] {
  let seen : Map[String, Expr] = Map([])
  for _, info in self.atom_infos {
    let (_, args) = info
    for arg in args {
      let key = @symprint.pretty_string(arg)
      if !seen.contains(key) {
        seen[key] = arg
      }
    }
  }
  let out : Array[Expr] = Array::new()
  for _, expr in seen {
    out.push(expr)
  }
  out
}

///|
fn SatBuilder::apply_direct_atom_truth(
  self : SatBuilder,
  env : AssumeEnv,
) -> Unit {
  for var_id, info in self.atom_infos {
    let (key, args) = info
    match eval_atom(key, args, env) {
      True => self.add_clause([var_id])
      False => self.add_clause([-var_id])
      Unknown => ()
    }
  }
}

///|
/// Convert an assumptions environment into a conjunction of atomic queries.
///
/// This is useful when a caller wants to inspect or reuse the logical meaning of
/// a stored environment instead of asking against it directly.
pub fn env_to_query(env : AssumeEnv) -> Query {
  let facts : Array[Query] = Array::new()
  for name, sf in env {
    let x = Expr::Symbol(name)
    push_fact_literal(facts, q_zero(x), sf.is_zero)
    push_fact_literal(facts, q_nonzero(x), sf.is_nonzero)
    push_fact_literal(facts, q_integer(x), sf.is_integer)
    push_fact_literal(facts, q_rational(x), sf.is_rational)
    push_fact_literal(facts, q_real(x), sf.is_real)
    push_fact_literal(facts, q_positive(x), sf.is_positive)
    push_fact_literal(facts, q_nonnegative(x), sf.is_nonnegative)
  }
  and_q(facts)
}

///|
fn push_fact_literal(out : Array[Query], atom : Query, tri : Tri) -> Unit {
  match tri {
    True => out.push(atom)
    False => out.push(not_q(atom))
    Unknown => ()
  }
}

///|
fn known_fact_formulas(expr : Expr) -> Array[Query] {
  let f : Array[Query] = Array::new()
  let ni = q1(NegativeInfinite, expr)
  let n = q_negative(expr)
  let z = q_zero(expr)
  let p = q_positive(expr)
  let pi = q1(PositiveInfinite, expr)
  let r = q_real(expr)
  let i = q1(Imaginary, expr)
  let c = q1(Complex, expr)
  let a = q1(Algebraic, expr)
  let integer_q = q_integer(expr)
  let rat = q_rational(expr)
  let irrational = q_irrational(expr)
  let even = q_even(expr)
  let odd = q_odd(expr)
  let prime = q_prime(expr)
  let composite = q_composite(expr)
  let herm = q1(Hermitian, expr)
  let antiherm = q1(Antihermitian, expr)
  let finite = q_finite(expr)
  let infinite = q_infinite(expr)
  let commutative = q1(Commutative, expr)
  let nonpositive = q_nonpositive(expr)
  let nonnegative = q_nonnegative(expr)
  let nonzero = q_nonzero(expr)
  let ext_real = q_extended_real(expr)
  let ext_pos = q1(ExtendedPositive, expr)
  let ext_neg = q1(ExtendedNegative, expr)
  let ext_nz = q1(ExtendedNonzero, expr)
  let ext_np = q1(ExtendedNonpositive, expr)
  let ext_nn = q1(ExtendedNonnegative, expr)
  let symmetric = q1(Symmetric, expr)
  let invertible = q1(Invertible, expr)
  let orthogonal = q1(Orthogonal, expr)
  let unitary = q1(Unitary, expr)
  let positive_definite = q1(PositiveDefinite, expr)
  let upper_triangular = q1(UpperTriangular, expr)
  let lower_triangular = q1(LowerTriangular, expr)
  let diagonal = q1(Diagonal, expr)
  let fullrank = q1(Fullrank, expr)
  let square = q1(Square, expr)
  let integer_elements = q1(IntegerElements, expr)
  let real_elements = q1(RealElements, expr)
  let complex_elements = q1(ComplexElements, expr)
  let singular = q1(Singular, expr)
  let normal = q1(Normal, expr)
  let triangular = q1(Triangular, expr)
  let unit_triangular = q1(UnitTriangular, expr)
  let z0 = int(0)
  let eq0 = q_eq(expr, z0)
  let ne0 = q_ne(expr, z0)
  let ge0 = q_ge(expr, z0)
  let lt0 = q_lt(expr, z0)

  push_exclusive_pairs(f, [ni, n, z, p, pi])
  push_exclusive_pairs(f, [r, i])
  push_exclusive_pairs(f, [irrational, rat])
  push_exclusive_pairs(f, [even, odd])
  push_exclusive_pairs(f, [composite, prime])
  push_exclusive_pairs(f, [infinite, finite])

  f.push(equivalent_q([r, or_q([n, z, p])]))
  f.push(equivalent_q([integer_q, or_q([even, odd])]))
  // These sign partitions are valid for real finite values; infinities are
  // handled through extended_* predicates below.
  f.push(implies_q(r, equivalent_q([nonpositive, or_q([n, z])])))
  f.push(implies_q(r, equivalent_q([nonzero, or_q([n, p])])))
  f.push(implies_q(r, equivalent_q([nonnegative, or_q([z, p])])))
  f.push(equivalent_q([ext_real, or_q([ni, n, z, p, pi])]))
  f.push(equivalent_q([ext_pos, or_q([p, pi])]))
  f.push(equivalent_q([ext_neg, or_q([n, ni])]))
  f.push(equivalent_q([ext_nz, or_q([ni, n, p, pi])]))
  f.push(equivalent_q([ext_np, or_q([ni, n, z])]))
  f.push(equivalent_q([ext_nn, or_q([z, p, pi])]))

  f.push(implies_q(or_q([r, i]), c))
  f.push(implies_q(rat, a))
  f.push(implies_q(integer_q, rat))
  f.push(implies_q(z, even))
  f.push(implies_q(or_q([composite, prime]), and_q([integer_q, p])))
  f.push(implies_q(and_q([even, p, not_q(prime)]), composite))
  f.push(implies_q(r, herm))
  f.push(implies_q(i, antiherm))
  f.push(implies_q(z, or_q([herm, antiherm])))
  f.push(implies_q(c, finite))
  f.push(implies_q(or_q([ni, pi]), infinite))
  f.push(implies_q(or_q([finite, infinite]), commutative))
  f.push(implies_q(diagonal, upper_triangular))
  f.push(implies_q(diagonal, lower_triangular))
  f.push(implies_q(diagonal, triangular))
  f.push(implies_q(diagonal, symmetric))
  f.push(implies_q(diagonal, normal))
  f.push(implies_q(diagonal, square))
  f.push(implies_q(upper_triangular, triangular))
  f.push(implies_q(lower_triangular, triangular))
  f.push(implies_q(unit_triangular, triangular))
  f.push(implies_q(symmetric, square))
  f.push(implies_q(normal, square))
  f.push(implies_q(orthogonal, unitary))
  f.push(implies_q(orthogonal, invertible))
  f.push(implies_q(orthogonal, normal))
  f.push(implies_q(unitary, invertible))
  f.push(implies_q(unitary, normal))
  f.push(implies_q(positive_definite, invertible))
  f.push(implies_q(invertible, fullrank))
  f.push(implies_q(integer_elements, real_elements))
  f.push(implies_q(real_elements, complex_elements))
  f.push(implies_q(integer_elements, complex_elements))
  f.push(implies_q(invertible, not_q(singular)))
  f.push(implies_q(singular, not_q(invertible)))
  if is_matrix_symbol_expr(expr) {
    // SymPy ask currently resolves these as False for MatrixSymbol with
    // positive_definite assumptions.
    f.push(implies_q(positive_definite, not_q(herm)))
    f.push(implies_q(positive_definite, not_q(antiherm)))
  }
  f.push(implies_q(z, eq0))
  f.push(implies_q(nonzero, ne0))
  f.push(implies_q(nonnegative, ge0))
  if is_symbol_expr(expr) {
    // Keep strict sign-to-order implication on plain symbols only; extending
    // this to composite expressions over-constrains compared to SymPy ask.
    f.push(implies_q(n, lt0))
  }

  f
}

///|
fn known_atom_formulas(_key : PredicateKey, args : Array[Expr]) -> Array[Query] {
  let f : Array[Query] = Array::new()
  if args.length() != 2 {
    return f
  }
  let lhs = args[0]
  let rhs = args[1]
  let eq = q_eq(lhs, rhs)
  let ne = q_ne(lhs, rhs)
  let gt = q_gt(lhs, rhs)
  let ge = q_ge(lhs, rhs)
  let lt = q_lt(lhs, rhs)
  let le = q_le(lhs, rhs)
  let relation_axioms = [
    implies_q(eq, and_q([ge, le])),
    implies_q(eq, not_q(ne)),
    implies_q(ne, not_q(eq)),
    implies_q(gt, and_q([ge, ne])),
    implies_q(lt, and_q([le, ne])),
    implies_q(gt, not_q(le)),
    implies_q(lt, not_q(ge)),
    equivalent_q([gt, q_lt(rhs, lhs)]),
    equivalent_q([ge, q_le(rhs, lhs)]),
  ]
  for ax in relation_axioms {
    f.push(ax)
  }
  f
}

///|
fn push_exclusive_pairs(out : Array[Query], atoms : Array[Query]) -> Unit {
  for i in 0..<atoms.length() {
    for j in (i + 1)..<atoms.length() {
      out.push(or_q([not_q(atoms[i]), not_q(atoms[j])]))
    }
  }
}

///|
fn is_matrix_symbol_expr(expr : Expr) -> Bool {
  @symcore.application_has_name(expr, "MatrixSymbol", arity=3)
}

///|
fn is_symbol_expr(expr : Expr) -> Bool {
  match expr {
    Symbol(_) => true
    _ => false
  }
}

///|
fn eval_atom(key : PredicateKey, args : Array[Expr], env : AssumeEnv) -> Tri {
  match key {
    Eq | Ne | Gt | Ge | Lt | Le => eval_relation_atom(key, args, env)
    _ => eval_unary_atom(key, args, env)
  }
}

///|
fn eval_relation_atom(
  key : PredicateKey,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  if args.length() != 2 {
    return Unknown
  }
  if args[0] == args[1] {
    return match key {
      Eq | Ge | Le => True
      Ne | Gt | Lt => False
      _ => Unknown
    }
  }
  match relation_from_linear_symbol_constant(key, args[0], args[1], env) {
    Some(v) => return v
    None => ()
  }
  match
    relation_from_linear_symbol_constant(
      flip_relation_key(key),
      args[1],
      args[0],
      env,
    ) {
    Some(v) => return v
    None => ()
  }
  match (args[0], args[1]) {
    (Number(a), Number(b)) => {
      let cmp = a.compare(b)
      match key {
        Eq => tri_of_bool(cmp == 0)
        Ne => tri_of_bool(cmp != 0)
        Gt => tri_of_bool(cmp > 0)
        Ge => tri_of_bool(cmp >= 0)
        Lt => tri_of_bool(cmp < 0)
        Le => tri_of_bool(cmp <= 0)
        _ => Unknown
      }
    }
    _ => Unknown
  }
}

///|
fn relation_from_linear_symbol_constant(
  key : PredicateKey,
  lhs : Expr,
  rhs : Expr,
  env : AssumeEnv,
) -> Tri? {
  match rhs {
    Number(constant) =>
      match extract_linear_symbol_plus_const(lhs) {
        Some((name, offset)) => {
          let shifted = constant.add_r(offset.neg_r())
          Some(eval_symbol_constant_relation(key, env_get(env, name), shifted))
        }
        None => None
      }
    _ => None
  }
}

///|
fn extract_linear_symbol_plus_const(
  expr : Expr,
) -> (String, @symnum.BigRational)? {
  match expr {
    Symbol(name) => Some((name, @symnum.BigRational::zero()))
    Add(args) => {
      let mut symbol_name : String? = None
      let mut offset = @symnum.BigRational::zero()
      for arg in args {
        match arg {
          Symbol(name) =>
            match symbol_name {
              Some(_) => return None
              None => symbol_name = Some(name)
            }
          Number(n) => offset = offset.add_r(n)
          _ => return None
        }
      }
      match symbol_name {
        Some(name) => Some((name, offset))
        None => None
      }
    }
    _ => None
  }
}

///|
fn eval_symbol_constant_relation(
  key : PredicateKey,
  facts : SymbolFacts,
  constant : @symnum.BigRational,
) -> Tri {
  let cmp = constant.compare(@symnum.BigRational::zero())
  let mut out = Tri::Unknown

  if facts.is_zero == True {
    let v = match key {
      Eq => tri_of_bool(cmp == 0)
      Ne => tri_of_bool(cmp != 0)
      Gt => if cmp >= 0 { False } else { Unknown }
      Ge => if cmp <= 0 { True } else { Unknown }
      Lt => if cmp <= 0 { False } else { Unknown }
      Le => if cmp >= 0 { True } else { Unknown }
      _ => Unknown
    }
    out = tri_merge(out, v)
  }

  if facts.is_nonzero == True && cmp == 0 {
    let v = match key {
      Eq => Tri::False
      Ne => True
      _ => Unknown
    }
    out = tri_merge(out, v)
  }

  if facts.is_positive == True {
    let v = match key {
      Eq => if cmp <= 0 { Tri::False } else { Unknown }
      Ne => if cmp <= 0 { True } else { Unknown }
      Gt => if cmp == 0 { True } else { Unknown }
      Ge => if cmp <= 0 { True } else { Unknown }
      Lt => if cmp <= 0 { False } else { Unknown }
      Le => if cmp == 0 { False } else { Unknown }
      _ => Unknown
    }
    out = tri_merge(out, v)
  }

  if facts.is_nonnegative == True {
    let v = match key {
      Eq => if cmp < 0 { Tri::False } else { Unknown }
      Ne => if cmp < 0 { True } else { Unknown }
      Ge => if cmp <= 0 { True } else { Unknown }
      Lt => if cmp <= 0 { False } else { Unknown }
      _ => Unknown
    }
    out = tri_merge(out, v)
  }

  out
}

///|
fn flip_relation_key(key : PredicateKey) -> PredicateKey {
  match key {
    Gt => Lt
    Ge => Le
    Lt => Gt
    Le => Ge
    other => other
  }
}

///|
fn eval_unary_atom(
  key : PredicateKey,
  args : Array[Expr],
  env : AssumeEnv,
) -> Tri {
  if args.length() != 1 {
    return Unknown
  }
  let expr = args[0]
  let direct = eval_from_expr(key, expr, env)
  if direct != Unknown {
    return direct
  }
  match key {
    Complex => {
      let real = eval_from_expr(Real, expr, env)
      let imag = eval_from_expr(Imaginary, expr, env)
      if real == True || imag == True {
        True
      } else {
        Unknown
      }
    }
    Finite => {
      let inf = eval_from_expr(Infinite, expr, env)
      if inf == True {
        False
      } else {
        let complex = eval_unary_atom(Complex, args, env)
        let real = eval_from_expr(Real, expr, env)
        if complex == True || real == True {
          True
        } else {
          Unknown
        }
      }
    }
    Infinite => tri_not(eval_unary_atom(Finite, args, env))
    ExtendedReal => {
      let real = eval_from_expr(Real, expr, env)
      if real == True {
        True
      } else {
        let pos_inf = eval_from_expr(PositiveInfinite, expr, env)
        let neg_inf = eval_from_expr(NegativeInfinite, expr, env)
        if pos_inf == True || neg_inf == True {
          True
        } else if eval_unary_atom(Complex, args, env) == True {
          False
        } else {
          Unknown
        }
      }
    }
    ExtendedPositive =>
      tri_or(
        eval_from_expr(Positive, expr, env),
        eval_from_expr(PositiveInfinite, expr, env),
      )
    ExtendedNegative =>
      tri_or(
        eval_from_expr(Negative, expr, env),
        eval_from_expr(NegativeInfinite, expr, env),
      )
    ExtendedNonzero =>
      tri_or(
        eval_unary_atom(ExtendedPositive, args, env),
        tri_or(
          eval_unary_atom(ExtendedNegative, args, env),
          eval_from_expr(Nonzero, expr, env),
        ),
      )
    ExtendedNonpositive =>
      tri_or(
        eval_from_expr(Nonpositive, expr, env),
        eval_from_expr(NegativeInfinite, expr, env),
      )
    ExtendedNonnegative =>
      tri_or(
        eval_from_expr(Nonnegative, expr, env),
        eval_from_expr(PositiveInfinite, expr, env),
      )
    Negative => {
      let pos = eval_from_expr(Positive, expr, env)
      let zero = eval_from_expr(Zero, expr, env)
      let nonneg = eval_from_expr(Nonnegative, expr, env)
      if pos == True || zero == True || nonneg == True {
        False
      } else {
        Unknown
      }
    }
    Nonpositive => {
      let neg = eval_unary_atom(Negative, args, env)
      let zero = eval_unary_atom(Zero, args, env)
      tri_or(neg, zero)
    }
    Irrational => {
      let real = eval_unary_atom(Real, args, env)
      let rat = eval_unary_atom(Rational, args, env)
      if rat == True {
        False
      } else if real == True && rat == False {
        True
      } else {
        Unknown
      }
    }
    NonInteger => Unknown
    _ => Unknown
  }
}

///|
fn eval_from_expr(key : PredicateKey, expr : Expr, env : AssumeEnv) -> Tri {
  match expr {
    Number(_) => eval_number_predicate(key, expr)
    Symbol(name) => eval_symbol_predicate(key, name, env)
    _ =>
      match key {
        Imaginary => expr_is_imaginary(expr, env)
        Zero => is_zero(expr, env~)
        Nonzero => is_nonzero(expr, env~)
        Integer => is_integer(expr, env~)
        Rational => is_rational(expr, env~)
        Real => is_real(expr, env~)
        Positive => is_positive(expr, env~)
        Nonnegative => is_nonnegative(expr, env~)
        Commutative => True
        _ => Unknown
      }
  }
}

///|
fn expr_is_imaginary(expr : Expr, env : AssumeEnv) -> Tri {
  match expr {
    Mul(args) => {
      let mut imag_count = 0
      for arg in args {
        let imag = eval_unary_atom(Imaginary, [arg], env)
        if imag == True {
          imag_count += 1
          continue
        }
        if eval_unary_atom(Real, [arg], env) == True {
          continue
        }
        return Unknown
      }
      tri_of_bool(imag_count % 2 != 0)
    }
    Add(args) => {
      let mut all_imag = true
      let mut all_real = true
      for arg in args {
        let imag = eval_unary_atom(Imaginary, [arg], env)
        let real = eval_unary_atom(Real, [arg], env)
        if imag != True {
          all_imag = false
        }
        if real != True {
          all_real = false
        }
      }
      if all_imag {
        True
      } else if all_real {
        False
      } else {
        Unknown
      }
    }
    _ => Unknown
  }
}

///|
fn eval_symbol_predicate(
  key : PredicateKey,
  name : String,
  env : AssumeEnv,
) -> Tri {
  match eval_named_constant_predicate(key, name) {
    Some(v) => return v
    None => ()
  }
  let facts = env_get(env, name)
  match key {
    Zero => facts.is_zero
    Nonzero => facts.is_nonzero
    Integer => facts.is_integer
    Rational => facts.is_rational
    Real => facts.is_real
    Positive => facts.is_positive
    Nonnegative => facts.is_nonnegative
    Negative =>
      if facts.is_positive == True || facts.is_zero == True {
        False
      } else {
        Unknown
      }
    Nonpositive => if facts.is_positive == True { False } else { Unknown }
    Irrational => if facts.is_rational == True { False } else { Unknown }
    Finite => if facts.is_real == True { True } else { Unknown }
    Commutative => True
    _ => Unknown
  }
}

///|
fn eval_named_constant_predicate(key : PredicateKey, name : String) -> Tri? {
  match name {
    "oo" => Some(eval_infinity_symbol_predicate(key, true))
    "-oo" => Some(eval_infinity_symbol_predicate(key, false))
    "zoo" => Some(eval_zoo_symbol_predicate(key))
    "I" => Some(eval_i_symbol_predicate(key))
    "pi" | "E" => Some(eval_transc_symbol_predicate(key))
    _ => None
  }
}

///|
fn eval_zoo_symbol_predicate(key : PredicateKey) -> Tri {
  match key {
    Infinite => True
    Finite => False
    ExtendedReal => False
    Complex => False
    Real => False
    Imaginary => False
    Hermitian => False
    Antihermitian => False
    Algebraic => False
    Integer => False
    Rational => False
    Irrational => False
    PositiveInfinite => False
    NegativeInfinite => False
    Positive => False
    Negative => False
    Zero => False
    Nonzero => False
    Nonnegative => False
    Nonpositive => False
    ExtendedPositive => False
    ExtendedNegative => False
    ExtendedNonzero => False
    ExtendedNonpositive => False
    ExtendedNonnegative => False
    Even => False
    Odd => False
    Prime => False
    Composite => False
    Commutative => True
    _ => Unknown
  }
}

///|
fn eval_i_symbol_predicate(key : PredicateKey) -> Tri {
  match key {
    Imaginary => True
    Complex => True
    Algebraic => True
    Transcendental => Unknown
    Real => False
    ExtendedReal => False
    Hermitian => False
    Antihermitian => True
    Integer => False
    Rational => False
    Irrational => False
    Finite => True
    Infinite => False
    PositiveInfinite => False
    NegativeInfinite => False
    Positive => False
    Negative => False
    Zero => False
    Nonzero => False
    Nonpositive => False
    Nonnegative => False
    ExtendedPositive => False
    ExtendedNegative => False
    ExtendedNonzero => False
    ExtendedNonpositive => False
    ExtendedNonnegative => False
    Even => False
    Odd => False
    Prime => False
    Composite => False
    Commutative => True
    _ => Unknown
  }
}

///|
fn eval_transc_symbol_predicate(key : PredicateKey) -> Tri {
  match key {
    Real => True
    ExtendedReal => True
    Imaginary => False
    Complex => True
    Algebraic => False
    Transcendental => Unknown
    Integer => False
    Rational => False
    Irrational => True
    Finite => True
    Infinite => False
    PositiveInfinite => False
    NegativeInfinite => False
    Positive => True
    Negative => False
    Zero => False
    Nonzero => True
    Nonpositive => False
    Nonnegative => True
    ExtendedPositive => True
    ExtendedNegative => False
    ExtendedNonzero => True
    ExtendedNonpositive => False
    ExtendedNonnegative => True
    Even => False
    Odd => False
    Prime => False
    Composite => False
    Commutative => True
    Hermitian => True
    Antihermitian => False
    _ => Unknown
  }
}

///|
fn eval_infinity_symbol_predicate(key : PredicateKey, positive : Bool) -> Tri {
  match key {
    Infinite => True
    Finite => False
    Real => False
    ExtendedReal => True
    Imaginary => False
    Complex => False
    Algebraic => False
    Transcendental => Unknown
    Integer => False
    NonInteger => Unknown
    Rational => False
    Irrational => False
    Hermitian => False
    Antihermitian => False
    PositiveInfinite => tri_of_bool(positive)
    NegativeInfinite => tri_of_bool(!positive)
    Positive => False
    Negative => False
    Zero => False
    Nonzero => False
    Nonnegative => False
    Nonpositive => False
    ExtendedPositive => tri_of_bool(positive)
    ExtendedNegative => tri_of_bool(!positive)
    ExtendedNonzero => True
    ExtendedNonpositive => tri_of_bool(!positive)
    ExtendedNonnegative => tri_of_bool(positive)
    Even => False
    Odd => False
    Prime => False
    Composite => False
    Commutative => True
    _ => Unknown
  }
}

///|
fn eval_number_predicate(key : PredicateKey, expr : Expr) -> Tri {
  match expr {
    Number(n) => {
      let cmp = n.compare(@symnum.BigRational::zero())
      let is_int = n.is_integral()
      let int_val = if is_int { Some(n.numerator().to_int()) } else { None }
      match key {
        Zero => tri_of_bool(cmp == 0)
        Nonzero => tri_of_bool(cmp != 0)
        Positive => tri_of_bool(cmp > 0)
        Negative => tri_of_bool(cmp < 0)
        Nonnegative => tri_of_bool(cmp >= 0)
        Nonpositive => tri_of_bool(cmp <= 0)
        Integer => tri_of_bool(is_int)
        NonInteger => Unknown
        Rational => True
        Irrational => False
        Real => True
        ExtendedReal => True
        Complex => True
        Algebraic => True
        Transcendental => False
        Finite => True
        Infinite => False
        PositiveInfinite => False
        NegativeInfinite => False
        Even =>
          match int_val {
            Some(v) => tri_of_bool(v % 2 == 0)
            None => False
          }
        Odd =>
          match int_val {
            Some(v) => tri_of_bool(v % 2 != 0)
            None => False
          }
        Prime =>
          match int_val {
            Some(v) => tri_of_bool(is_int_prime(v))
            None => False
          }
        Composite =>
          match int_val {
            Some(v) => tri_of_bool(is_int_composite(v))
            None => False
          }
        Commutative => True
        Hermitian => True
        Antihermitian => tri_of_bool(cmp == 0)
        _ => Unknown
      }
    }
    _ => Unknown
  }
}

///|
fn is_int_prime(value : Int) -> Bool {
  if value <= 1 {
    return false
  }
  if value == 2 {
    return true
  }
  if value % 2 == 0 {
    return false
  }
  let mut d = 3
  while d * d <= value {
    if value % d == 0 {
      return false
    }
    d += 2
  }
  true
}

///|
fn is_int_composite(value : Int) -> Bool {
  value > 1 && !is_int_prime(value)
}

///|
fn cnf_satisfiable(cnf : Array[Array[Int]]) -> Bool {
  dpll(cnf)
}

///|
fn dpll(input_cnf : Array[Array[Int]]) -> Bool {
  let cnf = match
    propagate_all_units(input_cnf.map(clause => clause.map(v => v))) {
    Some(v) => v
    None => return false
  }
  if cnf.is_empty() {
    return true
  }
  for clause in cnf {
    if clause.is_empty() {
      return false
    }
  }
  let lit = choose_literal(cnf)
  match propagate_literal(cnf, lit) {
    Some(next_true) if dpll(next_true) => true
    _ =>
      match propagate_literal(cnf, -lit) {
        Some(next_false) => dpll(next_false)
        None => false
      }
  }
}

///|
fn propagate_all_units(cnf : Array[Array[Int]]) -> Array[Array[Int]]? {
  match find_unit_literal(cnf) {
    Some(lit) =>
      match propagate_literal(cnf, lit) {
        Some(next) => propagate_all_units(next)
        None => None
      }
    None => Some(cnf)
  }
}

///|
fn find_unit_literal(cnf : Array[Array[Int]]) -> Int? {
  for clause in cnf {
    if clause.length() == 1 {
      return Some(clause[0])
    }
  }
  None
}

///|
fn choose_literal(cnf : Array[Array[Int]]) -> Int {
  for clause in cnf {
    if !clause.is_empty() {
      return clause[0]
    }
  }
  1
}

///|
fn propagate_literal(cnf : Array[Array[Int]], lit : Int) -> Array[Array[Int]]? {
  let out : Array[Array[Int]] = Array::new()
  for clause in cnf {
    if clause_contains(clause, lit) {
      continue
    }
    let reduced : Array[Int] = Array::new()
    for item in clause {
      if item != -lit {
        reduced.push(item)
      }
    }
    if reduced.is_empty() {
      return None
    }
    out.push(reduced)
  }
  Some(out)
}

///|
fn clause_contains(clause : Array[Int], lit : Int) -> Bool {
  for item in clause {
    if item == lit {
      return true
    }
  }
  false
}

///|
fn with_unit_clause(cnf : Array[Array[Int]], lit : Int) -> Array[Array[Int]] {
  let out = cnf.map(clause => clause.map(v => v))
  out.push([lit])
  out
}
