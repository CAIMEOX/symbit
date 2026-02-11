///|
pub(all) suberror AskError {
  InconsistentAssumptions
}

///|
let global_assumptions_ref : Ref[Array[Query]] = { val: [] }

///|
pub fn get_global_assumptions() -> Array[Query] {
  global_assumptions_ref.val.map(v => v)
}

///|
pub fn clear_global_assumptions() -> Unit {
  global_assumptions_ref.val = []
}

///|
pub fn add_global_assumption(query : Query) -> Unit {
  for item in global_assumptions_ref.val {
    if item == query {
      return
    }
  }
  global_assumptions_ref.val.push(query)
}

///|
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
pub fn ask_global(
  proposition : Query,
  assumptions? : Query = query_true(),
  env? : AssumeEnv = {},
) -> Tri raise AskError {
  ask(proposition, assumptions~, env~, context=get_global_assumptions())
}

///|
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
    raise AskError::InconsistentAssumptions
  }

  let can_be_true = cnf_satisfiable(with_unit_clause(base_cnf, proposition_var))
  let can_be_false = cnf_satisfiable(
    with_unit_clause(base_cnf, -proposition_var),
  )
  if can_be_true && can_be_false {
    Tri::Unknown
  } else if can_be_true {
    Tri::True
  } else if can_be_false {
    Tri::False
  } else {
    raise AskError::InconsistentAssumptions
  }
}

///|
fn assumptions_eval_env(query : Query, base : AssumeEnv) -> AssumeEnv {
  let out : AssumeEnv = {}
  for name, facts in base {
    out[name] = normalize_facts(facts)
  }
  collect_conjunct_literals(query, out)
  out
}

///|
fn collect_conjunct_literals(query : Query, env : AssumeEnv) -> Unit {
  match query {
    Query::And(items) =>
      for item in items {
        collect_conjunct_literals(item, env)
      }
    Query::Atom(key, args) => absorb_symbol_literal(env, key, args, Tri::True)
    Query::Not(inner) =>
      match inner {
        Query::Atom(key, args) =>
          absorb_symbol_literal(env, key, args, Tri::False)
        _ => ()
      }
    _ => ()
  }
}

///|
fn absorb_symbol_literal(
  env : AssumeEnv,
  key : PredicateKey,
  args : Array[@symcore.Expr],
  value : Tri,
) -> Unit {
  if args.length() != 1 {
    return
  }
  match args[0] {
    @symcore.Expr::Symbol(name) =>
      match key {
        PredicateKey::Zero
        | PredicateKey::Nonzero
        | PredicateKey::Integer
        | PredicateKey::Rational
        | PredicateKey::Real
        | PredicateKey::Positive
        | PredicateKey::Nonnegative => {
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
    PredicateKey::Zero =>
      symbol_facts(
        is_zero=value,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    PredicateKey::Nonzero =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=value,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    PredicateKey::Integer =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=value,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    PredicateKey::Rational =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=value,
        is_real=facts.is_real,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    PredicateKey::Real =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=value,
        is_positive=facts.is_positive,
        is_nonnegative=facts.is_nonnegative,
      )
    PredicateKey::Positive =>
      symbol_facts(
        is_zero=facts.is_zero,
        is_nonzero=facts.is_nonzero,
        is_integer=facts.is_integer,
        is_rational=facts.is_rational,
        is_real=facts.is_real,
        is_positive=value,
        is_nonnegative=facts.is_nonnegative,
      )
    PredicateKey::Nonnegative =>
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
  atom_infos : Map[Int, (PredicateKey, Array[@symcore.Expr])]
}

///|
fn SatBuilder::new() -> SatBuilder {
  SatBuilder::{ next_var: 1, clauses: [], atom_vars: {}, atom_infos: {} }
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
    Query::Bool(v) => {
      let out = self.fresh()
      if v {
        self.add_clause([out])
      } else {
        self.add_clause([-out])
      }
      out
    }
    Query::Atom(key, args) => self.atom_var(key, args)
    Query::Not(inner) => {
      let a = self.encode(inner)
      let v = self.fresh()
      self.add_clause([-v, -a])
      self.add_clause([v, a])
      v
    }
    Query::And(items) => {
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
    Query::Or(items) => {
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
    Query::Implies(lhs, rhs) => self.encode(or_q([not_q(lhs), rhs]))
    Query::Equivalent(items) => {
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
  args : Array[@symcore.Expr],
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
fn SatBuilder::relevant_exprs(self : SatBuilder) -> Array[@symcore.Expr] {
  let seen : Map[String, @symcore.Expr] = {}
  for _, info in self.atom_infos {
    let (_, args) = info
    for arg in args {
      let key = @symprint.to_string(arg)
      if !seen.contains(key) {
        seen[key] = arg
      }
    }
  }
  let out : Array[@symcore.Expr] = Array::new()
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
      Tri::True => self.add_clause([var_id])
      Tri::False => self.add_clause([-var_id])
      Tri::Unknown => ()
    }
  }
}

///|
pub fn env_to_query(env : AssumeEnv) -> Query {
  let facts : Array[Query] = Array::new()
  for name, sf in env {
    let x = @symcore.symbol(name)
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
    Tri::True => out.push(atom)
    Tri::False => out.push(not_q(atom))
    Tri::Unknown => ()
  }
}

///|
fn known_fact_formulas(expr : @symcore.Expr) -> Array[Query] {
  let f : Array[Query] = Array::new()
  let ni = q1(PredicateKey::NegativeInfinite, expr)
  let n = q_negative(expr)
  let z = q_zero(expr)
  let p = q_positive(expr)
  let pi = q1(PredicateKey::PositiveInfinite, expr)
  let r = q_real(expr)
  let i = q1(PredicateKey::Imaginary, expr)
  let c = q1(PredicateKey::Complex, expr)
  let a = q1(PredicateKey::Algebraic, expr)
  let integer_q = q_integer(expr)
  let rat = q_rational(expr)
  let irrational = q_irrational(expr)
  let even = q_even(expr)
  let odd = q_odd(expr)
  let prime = q_prime(expr)
  let composite = q_composite(expr)
  let herm = q1(PredicateKey::Hermitian, expr)
  let antiherm = q1(PredicateKey::Antihermitian, expr)
  let finite = q_finite(expr)
  let infinite = q_infinite(expr)
  let commutative = q1(PredicateKey::Commutative, expr)
  let nonpositive = q_nonpositive(expr)
  let nonnegative = q_nonnegative(expr)
  let nonzero = q_nonzero(expr)
  let ext_real = q_extended_real(expr)
  let ext_pos = q1(PredicateKey::ExtendedPositive, expr)
  let ext_neg = q1(PredicateKey::ExtendedNegative, expr)
  let ext_nz = q1(PredicateKey::ExtendedNonzero, expr)
  let ext_np = q1(PredicateKey::ExtendedNonpositive, expr)
  let ext_nn = q1(PredicateKey::ExtendedNonnegative, expr)
  let symmetric = q1(PredicateKey::Symmetric, expr)
  let invertible = q1(PredicateKey::Invertible, expr)
  let orthogonal = q1(PredicateKey::Orthogonal, expr)
  let unitary = q1(PredicateKey::Unitary, expr)
  let positive_definite = q1(PredicateKey::PositiveDefinite, expr)
  let upper_triangular = q1(PredicateKey::UpperTriangular, expr)
  let lower_triangular = q1(PredicateKey::LowerTriangular, expr)
  let diagonal = q1(PredicateKey::Diagonal, expr)
  let fullrank = q1(PredicateKey::Fullrank, expr)
  let square = q1(PredicateKey::Square, expr)
  let integer_elements = q1(PredicateKey::IntegerElements, expr)
  let real_elements = q1(PredicateKey::RealElements, expr)
  let complex_elements = q1(PredicateKey::ComplexElements, expr)
  let singular = q1(PredicateKey::Singular, expr)
  let normal = q1(PredicateKey::Normal, expr)
  let triangular = q1(PredicateKey::Triangular, expr)
  let unit_triangular = q1(PredicateKey::UnitTriangular, expr)
  let z0 = @symcore.int(0)
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
fn known_atom_formulas(
  _key : PredicateKey,
  args : Array[@symcore.Expr],
) -> Array[Query] {
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
fn is_matrix_symbol_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function(name, args) =>
      name == "MatrixSymbol" && args.length() == 3
    _ => false
  }
}

///|
fn is_symbol_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(_) => true
    _ => false
  }
}

///|
fn eval_atom(
  key : PredicateKey,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  match key {
    PredicateKey::Eq
    | PredicateKey::Ne
    | PredicateKey::Gt
    | PredicateKey::Ge
    | PredicateKey::Lt
    | PredicateKey::Le => eval_relation_atom(key, args, env)
    _ => eval_unary_atom(key, args, env)
  }
}

///|
fn eval_relation_atom(
  key : PredicateKey,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  if args.length() != 2 {
    return Tri::Unknown
  }
  if args[0] == args[1] {
    return match key {
      PredicateKey::Eq | PredicateKey::Ge | PredicateKey::Le => Tri::True
      PredicateKey::Ne | PredicateKey::Gt | PredicateKey::Lt => Tri::False
      _ => Tri::Unknown
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
    (@symcore.Expr::Number(a), @symcore.Expr::Number(b)) => {
      let cmp = a.compare(b)
      match key {
        PredicateKey::Eq => tri_of_bool(cmp == 0)
        PredicateKey::Ne => tri_of_bool(cmp != 0)
        PredicateKey::Gt => tri_of_bool(cmp > 0)
        PredicateKey::Ge => tri_of_bool(cmp >= 0)
        PredicateKey::Lt => tri_of_bool(cmp < 0)
        PredicateKey::Le => tri_of_bool(cmp <= 0)
        _ => Tri::Unknown
      }
    }
    _ => Tri::Unknown
  }
}

///|
fn relation_from_linear_symbol_constant(
  key : PredicateKey,
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
  env : AssumeEnv,
) -> Tri? {
  match rhs {
    @symcore.Expr::Number(constant) =>
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
  expr : @symcore.Expr,
) -> (String, @symnum.BigRational)? {
  match expr {
    @symcore.Expr::Symbol(name) => Some((name, @symnum.BigRational::zero()))
    @symcore.Expr::Add(args) => {
      let mut symbol_name : String? = None
      let mut offset = @symnum.BigRational::zero()
      for arg in args {
        match arg {
          @symcore.Expr::Symbol(name) =>
            match symbol_name {
              Some(_) => return None
              None => symbol_name = Some(name)
            }
          @symcore.Expr::Number(n) => offset = offset.add_r(n)
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

  if facts.is_zero == Tri::True {
    let v = match key {
      PredicateKey::Eq => tri_of_bool(cmp == 0)
      PredicateKey::Ne => tri_of_bool(cmp != 0)
      PredicateKey::Gt => if cmp >= 0 { Tri::False } else { Tri::Unknown }
      PredicateKey::Ge => if cmp <= 0 { Tri::True } else { Tri::Unknown }
      PredicateKey::Lt => if cmp <= 0 { Tri::False } else { Tri::Unknown }
      PredicateKey::Le => if cmp >= 0 { Tri::True } else { Tri::Unknown }
      _ => Tri::Unknown
    }
    out = tri_merge(out, v)
  }

  if facts.is_nonzero == Tri::True && cmp == 0 {
    let v = match key {
      PredicateKey::Eq => Tri::False
      PredicateKey::Ne => Tri::True
      _ => Tri::Unknown
    }
    out = tri_merge(out, v)
  }

  if facts.is_positive == Tri::True {
    let v = match key {
      PredicateKey::Eq => if cmp <= 0 { Tri::False } else { Tri::Unknown }
      PredicateKey::Ne => if cmp <= 0 { Tri::True } else { Tri::Unknown }
      PredicateKey::Gt => if cmp == 0 { Tri::True } else { Tri::Unknown }
      PredicateKey::Ge => if cmp <= 0 { Tri::True } else { Tri::Unknown }
      PredicateKey::Lt => if cmp <= 0 { Tri::False } else { Tri::Unknown }
      PredicateKey::Le => if cmp == 0 { Tri::False } else { Tri::Unknown }
      _ => Tri::Unknown
    }
    out = tri_merge(out, v)
  }

  if facts.is_nonnegative == Tri::True {
    let v = match key {
      PredicateKey::Eq => if cmp < 0 { Tri::False } else { Tri::Unknown }
      PredicateKey::Ne => if cmp < 0 { Tri::True } else { Tri::Unknown }
      PredicateKey::Ge => if cmp <= 0 { Tri::True } else { Tri::Unknown }
      PredicateKey::Lt => if cmp <= 0 { Tri::False } else { Tri::Unknown }
      _ => Tri::Unknown
    }
    out = tri_merge(out, v)
  }

  out
}

///|
fn flip_relation_key(key : PredicateKey) -> PredicateKey {
  match key {
    PredicateKey::Gt => PredicateKey::Lt
    PredicateKey::Ge => PredicateKey::Le
    PredicateKey::Lt => PredicateKey::Gt
    PredicateKey::Le => PredicateKey::Ge
    other => other
  }
}

///|
fn eval_unary_atom(
  key : PredicateKey,
  args : Array[@symcore.Expr],
  env : AssumeEnv,
) -> Tri {
  if args.length() != 1 {
    return Tri::Unknown
  }
  let expr = args[0]
  let direct = eval_from_expr(key, expr, env)
  if direct != Tri::Unknown {
    return direct
  }
  match key {
    PredicateKey::Complex => {
      let real = eval_from_expr(PredicateKey::Real, expr, env)
      let imag = eval_from_expr(PredicateKey::Imaginary, expr, env)
      if real == Tri::True || imag == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    }
    PredicateKey::Finite => {
      let inf = eval_from_expr(PredicateKey::Infinite, expr, env)
      if inf == Tri::True {
        Tri::False
      } else {
        let complex = eval_unary_atom(PredicateKey::Complex, args, env)
        let real = eval_from_expr(PredicateKey::Real, expr, env)
        if complex == Tri::True || real == Tri::True {
          Tri::True
        } else {
          Tri::Unknown
        }
      }
    }
    PredicateKey::Infinite =>
      tri_not(eval_unary_atom(PredicateKey::Finite, args, env))
    PredicateKey::ExtendedReal => {
      let real = eval_from_expr(PredicateKey::Real, expr, env)
      if real == Tri::True {
        Tri::True
      } else {
        let pos_inf = eval_from_expr(PredicateKey::PositiveInfinite, expr, env)
        let neg_inf = eval_from_expr(PredicateKey::NegativeInfinite, expr, env)
        if pos_inf == Tri::True || neg_inf == Tri::True {
          Tri::True
        } else if eval_unary_atom(PredicateKey::Complex, args, env) == Tri::True {
          Tri::False
        } else {
          Tri::Unknown
        }
      }
    }
    PredicateKey::ExtendedPositive =>
      tri_or(
        eval_from_expr(PredicateKey::Positive, expr, env),
        eval_from_expr(PredicateKey::PositiveInfinite, expr, env),
      )
    PredicateKey::ExtendedNegative =>
      tri_or(
        eval_from_expr(PredicateKey::Negative, expr, env),
        eval_from_expr(PredicateKey::NegativeInfinite, expr, env),
      )
    PredicateKey::ExtendedNonzero =>
      tri_or(
        eval_unary_atom(PredicateKey::ExtendedPositive, args, env),
        tri_or(
          eval_unary_atom(PredicateKey::ExtendedNegative, args, env),
          eval_from_expr(PredicateKey::Nonzero, expr, env),
        ),
      )
    PredicateKey::ExtendedNonpositive =>
      tri_or(
        eval_from_expr(PredicateKey::Nonpositive, expr, env),
        eval_from_expr(PredicateKey::NegativeInfinite, expr, env),
      )
    PredicateKey::ExtendedNonnegative =>
      tri_or(
        eval_from_expr(PredicateKey::Nonnegative, expr, env),
        eval_from_expr(PredicateKey::PositiveInfinite, expr, env),
      )
    PredicateKey::Negative => {
      let pos = eval_from_expr(PredicateKey::Positive, expr, env)
      let zero = eval_from_expr(PredicateKey::Zero, expr, env)
      let nonneg = eval_from_expr(PredicateKey::Nonnegative, expr, env)
      if pos == Tri::True || zero == Tri::True || nonneg == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    }
    PredicateKey::Nonpositive => {
      let neg = eval_unary_atom(PredicateKey::Negative, args, env)
      let zero = eval_unary_atom(PredicateKey::Zero, args, env)
      tri_or(neg, zero)
    }
    PredicateKey::Irrational => {
      let real = eval_unary_atom(PredicateKey::Real, args, env)
      let rat = eval_unary_atom(PredicateKey::Rational, args, env)
      if rat == Tri::True {
        Tri::False
      } else if real == Tri::True && rat == Tri::False {
        Tri::True
      } else {
        Tri::Unknown
      }
    }
    PredicateKey::NonInteger => Tri::Unknown
    _ => Tri::Unknown
  }
}

///|
fn eval_from_expr(
  key : PredicateKey,
  expr : @symcore.Expr,
  env : AssumeEnv,
) -> Tri {
  match expr {
    @symcore.Expr::Number(_) => eval_number_predicate(key, expr)
    @symcore.Expr::Symbol(name) => eval_symbol_predicate(key, name, env)
    _ =>
      match key {
        PredicateKey::Imaginary => expr_is_imaginary(expr, env)
        PredicateKey::Zero => is_zero(expr, env~)
        PredicateKey::Nonzero => is_nonzero(expr, env~)
        PredicateKey::Integer => is_integer(expr, env~)
        PredicateKey::Rational => is_rational(expr, env~)
        PredicateKey::Real => is_real(expr, env~)
        PredicateKey::Positive => is_positive(expr, env~)
        PredicateKey::Nonnegative => is_nonnegative(expr, env~)
        PredicateKey::Commutative => Tri::True
        _ => Tri::Unknown
      }
  }
}

///|
fn expr_is_imaginary(expr : @symcore.Expr, env : AssumeEnv) -> Tri {
  match expr {
    @symcore.Expr::Mul(args) => {
      let mut imag_count = 0
      for arg in args {
        let imag = eval_unary_atom(PredicateKey::Imaginary, [arg], env)
        if imag == Tri::True {
          imag_count += 1
          continue
        }
        if eval_unary_atom(PredicateKey::Real, [arg], env) == Tri::True {
          continue
        }
        return Tri::Unknown
      }
      tri_of_bool(imag_count % 2 != 0)
    }
    @symcore.Expr::Add(args) => {
      let mut all_imag = true
      let mut all_real = true
      for arg in args {
        let imag = eval_unary_atom(PredicateKey::Imaginary, [arg], env)
        let real = eval_unary_atom(PredicateKey::Real, [arg], env)
        if imag != Tri::True {
          all_imag = false
        }
        if real != Tri::True {
          all_real = false
        }
      }
      if all_imag {
        Tri::True
      } else if all_real {
        Tri::False
      } else {
        Tri::Unknown
      }
    }
    _ => Tri::Unknown
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
    PredicateKey::Zero => facts.is_zero
    PredicateKey::Nonzero => facts.is_nonzero
    PredicateKey::Integer => facts.is_integer
    PredicateKey::Rational => facts.is_rational
    PredicateKey::Real => facts.is_real
    PredicateKey::Positive => facts.is_positive
    PredicateKey::Nonnegative => facts.is_nonnegative
    PredicateKey::Negative =>
      if facts.is_positive == Tri::True || facts.is_zero == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    PredicateKey::Nonpositive =>
      if facts.is_positive == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    PredicateKey::Irrational =>
      if facts.is_rational == Tri::True {
        Tri::False
      } else {
        Tri::Unknown
      }
    PredicateKey::Finite =>
      if facts.is_real == Tri::True {
        Tri::True
      } else {
        Tri::Unknown
      }
    PredicateKey::Commutative => Tri::True
    _ => Tri::Unknown
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
    PredicateKey::Infinite => Tri::True
    PredicateKey::Finite => Tri::False
    PredicateKey::ExtendedReal => Tri::False
    PredicateKey::Complex => Tri::False
    PredicateKey::Real => Tri::False
    PredicateKey::Imaginary => Tri::False
    PredicateKey::Hermitian => Tri::False
    PredicateKey::Antihermitian => Tri::False
    PredicateKey::Algebraic => Tri::False
    PredicateKey::Integer => Tri::False
    PredicateKey::Rational => Tri::False
    PredicateKey::Irrational => Tri::False
    PredicateKey::PositiveInfinite => Tri::False
    PredicateKey::NegativeInfinite => Tri::False
    PredicateKey::Positive => Tri::False
    PredicateKey::Negative => Tri::False
    PredicateKey::Zero => Tri::False
    PredicateKey::Nonzero => Tri::False
    PredicateKey::Nonnegative => Tri::False
    PredicateKey::Nonpositive => Tri::False
    PredicateKey::ExtendedPositive => Tri::False
    PredicateKey::ExtendedNegative => Tri::False
    PredicateKey::ExtendedNonzero => Tri::False
    PredicateKey::ExtendedNonpositive => Tri::False
    PredicateKey::ExtendedNonnegative => Tri::False
    PredicateKey::Even => Tri::False
    PredicateKey::Odd => Tri::False
    PredicateKey::Prime => Tri::False
    PredicateKey::Composite => Tri::False
    PredicateKey::Commutative => Tri::True
    _ => Tri::Unknown
  }
}

///|
fn eval_i_symbol_predicate(key : PredicateKey) -> Tri {
  match key {
    PredicateKey::Imaginary => Tri::True
    PredicateKey::Complex => Tri::True
    PredicateKey::Algebraic => Tri::True
    PredicateKey::Transcendental => Tri::Unknown
    PredicateKey::Real => Tri::False
    PredicateKey::ExtendedReal => Tri::False
    PredicateKey::Hermitian => Tri::False
    PredicateKey::Antihermitian => Tri::True
    PredicateKey::Integer => Tri::False
    PredicateKey::Rational => Tri::False
    PredicateKey::Irrational => Tri::False
    PredicateKey::Finite => Tri::True
    PredicateKey::Infinite => Tri::False
    PredicateKey::PositiveInfinite => Tri::False
    PredicateKey::NegativeInfinite => Tri::False
    PredicateKey::Positive => Tri::False
    PredicateKey::Negative => Tri::False
    PredicateKey::Zero => Tri::False
    PredicateKey::Nonzero => Tri::False
    PredicateKey::Nonpositive => Tri::False
    PredicateKey::Nonnegative => Tri::False
    PredicateKey::ExtendedPositive => Tri::False
    PredicateKey::ExtendedNegative => Tri::False
    PredicateKey::ExtendedNonzero => Tri::False
    PredicateKey::ExtendedNonpositive => Tri::False
    PredicateKey::ExtendedNonnegative => Tri::False
    PredicateKey::Even => Tri::False
    PredicateKey::Odd => Tri::False
    PredicateKey::Prime => Tri::False
    PredicateKey::Composite => Tri::False
    PredicateKey::Commutative => Tri::True
    _ => Tri::Unknown
  }
}

///|
fn eval_transc_symbol_predicate(key : PredicateKey) -> Tri {
  match key {
    PredicateKey::Real => Tri::True
    PredicateKey::ExtendedReal => Tri::True
    PredicateKey::Imaginary => Tri::False
    PredicateKey::Complex => Tri::True
    PredicateKey::Algebraic => Tri::False
    PredicateKey::Transcendental => Tri::Unknown
    PredicateKey::Integer => Tri::False
    PredicateKey::Rational => Tri::False
    PredicateKey::Irrational => Tri::True
    PredicateKey::Finite => Tri::True
    PredicateKey::Infinite => Tri::False
    PredicateKey::PositiveInfinite => Tri::False
    PredicateKey::NegativeInfinite => Tri::False
    PredicateKey::Positive => Tri::True
    PredicateKey::Negative => Tri::False
    PredicateKey::Zero => Tri::False
    PredicateKey::Nonzero => Tri::True
    PredicateKey::Nonpositive => Tri::False
    PredicateKey::Nonnegative => Tri::True
    PredicateKey::ExtendedPositive => Tri::True
    PredicateKey::ExtendedNegative => Tri::False
    PredicateKey::ExtendedNonzero => Tri::True
    PredicateKey::ExtendedNonpositive => Tri::False
    PredicateKey::ExtendedNonnegative => Tri::True
    PredicateKey::Even => Tri::False
    PredicateKey::Odd => Tri::False
    PredicateKey::Prime => Tri::False
    PredicateKey::Composite => Tri::False
    PredicateKey::Commutative => Tri::True
    PredicateKey::Hermitian => Tri::True
    PredicateKey::Antihermitian => Tri::False
    _ => Tri::Unknown
  }
}

///|
fn eval_infinity_symbol_predicate(key : PredicateKey, positive : Bool) -> Tri {
  match key {
    PredicateKey::Infinite => Tri::True
    PredicateKey::Finite => Tri::False
    PredicateKey::Real => Tri::False
    PredicateKey::ExtendedReal => Tri::True
    PredicateKey::Imaginary => Tri::False
    PredicateKey::Complex => Tri::False
    PredicateKey::Algebraic => Tri::False
    PredicateKey::Transcendental => Tri::Unknown
    PredicateKey::Integer => Tri::False
    PredicateKey::NonInteger => Tri::Unknown
    PredicateKey::Rational => Tri::False
    PredicateKey::Irrational => Tri::False
    PredicateKey::Hermitian => Tri::False
    PredicateKey::Antihermitian => Tri::False
    PredicateKey::PositiveInfinite => tri_of_bool(positive)
    PredicateKey::NegativeInfinite => tri_of_bool(!positive)
    PredicateKey::Positive => Tri::False
    PredicateKey::Negative => Tri::False
    PredicateKey::Zero => Tri::False
    PredicateKey::Nonzero => Tri::False
    PredicateKey::Nonnegative => Tri::False
    PredicateKey::Nonpositive => Tri::False
    PredicateKey::ExtendedPositive => tri_of_bool(positive)
    PredicateKey::ExtendedNegative => tri_of_bool(!positive)
    PredicateKey::ExtendedNonzero => Tri::True
    PredicateKey::ExtendedNonpositive => tri_of_bool(!positive)
    PredicateKey::ExtendedNonnegative => tri_of_bool(positive)
    PredicateKey::Even => Tri::False
    PredicateKey::Odd => Tri::False
    PredicateKey::Prime => Tri::False
    PredicateKey::Composite => Tri::False
    PredicateKey::Commutative => Tri::True
    _ => Tri::Unknown
  }
}

///|
fn eval_number_predicate(key : PredicateKey, expr : @symcore.Expr) -> Tri {
  match expr {
    @symcore.Expr::Number(n) => {
      let cmp = n.compare(@symnum.BigRational::zero())
      let is_int = n.is_integral()
      let int_val = if is_int { Some(n.numerator().to_int()) } else { None }
      match key {
        PredicateKey::Zero => tri_of_bool(cmp == 0)
        PredicateKey::Nonzero => tri_of_bool(cmp != 0)
        PredicateKey::Positive => tri_of_bool(cmp > 0)
        PredicateKey::Negative => tri_of_bool(cmp < 0)
        PredicateKey::Nonnegative => tri_of_bool(cmp >= 0)
        PredicateKey::Nonpositive => tri_of_bool(cmp <= 0)
        PredicateKey::Integer => tri_of_bool(is_int)
        PredicateKey::NonInteger => Tri::Unknown
        PredicateKey::Rational => Tri::True
        PredicateKey::Irrational => Tri::False
        PredicateKey::Real => Tri::True
        PredicateKey::ExtendedReal => Tri::True
        PredicateKey::Complex => Tri::True
        PredicateKey::Algebraic => Tri::True
        PredicateKey::Transcendental => Tri::False
        PredicateKey::Finite => Tri::True
        PredicateKey::Infinite => Tri::False
        PredicateKey::PositiveInfinite => Tri::False
        PredicateKey::NegativeInfinite => Tri::False
        PredicateKey::Even =>
          match int_val {
            Some(v) => tri_of_bool(v % 2 == 0)
            None => Tri::False
          }
        PredicateKey::Odd =>
          match int_val {
            Some(v) => tri_of_bool(v % 2 != 0)
            None => Tri::False
          }
        PredicateKey::Prime =>
          match int_val {
            Some(v) => tri_of_bool(is_int_prime(v))
            None => Tri::False
          }
        PredicateKey::Composite =>
          match int_val {
            Some(v) => tri_of_bool(is_int_composite(v))
            None => Tri::False
          }
        PredicateKey::Commutative => Tri::True
        PredicateKey::Hermitian => Tri::True
        PredicateKey::Antihermitian => tri_of_bool(cmp == 0)
        _ => Tri::Unknown
      }
    }
    _ => Tri::Unknown
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
