///|
/// Predicate names that can appear in symbolic queries.
///
/// Unary keys describe properties of one expression, while the relational keys
/// at the end describe binary comparisons such as equality and ordering.
pub(all) enum PredicateKey {
  Hermitian
  Antihermitian
  Real
  ExtendedReal
  Imaginary
  Complex
  Algebraic
  Transcendental
  Integer
  NonInteger
  Rational
  Irrational
  Finite
  Infinite
  PositiveInfinite
  NegativeInfinite
  Positive
  Negative
  Zero
  ExtendedPositive
  ExtendedNegative
  Nonzero
  Nonpositive
  Nonnegative
  ExtendedNonzero
  ExtendedNonpositive
  ExtendedNonnegative
  Even
  Odd
  Prime
  Composite
  Commutative
  IsTrue
  Symmetric
  Invertible
  Orthogonal
  Unitary
  PositiveDefinite
  UpperTriangular
  LowerTriangular
  Diagonal
  Fullrank
  Square
  IntegerElements
  RealElements
  ComplexElements
  Singular
  Normal
  Triangular
  UnitTriangular
  Eq
  Ne
  Gt
  Ge
  Lt
  Le
} derive(Eq, Debug)

///|
/// Logical query tree consumed by [`ask`](#ask).
///
/// Queries can be atomic predicate applications or boolean combinations of other
/// queries.
pub(all) enum Query {
  Bool(Bool)
  Atom(PredicateKey, Array[Expr])
  Not(Query)
  And(Array[Query])
  Or(Array[Query])
  Implies(Query, Query)
  Equivalent(Array[Query])
} derive(Eq)

///|
/// Return the stable textual name used for one predicate key.
pub fn predicate_name(key : PredicateKey) -> String {
  match key {
    Hermitian => "hermitian"
    Antihermitian => "antihermitian"
    Real => "real"
    ExtendedReal => "extended_real"
    Imaginary => "imaginary"
    Complex => "complex"
    Algebraic => "algebraic"
    Transcendental => "transcendental"
    Integer => "integer"
    NonInteger => "noninteger"
    Rational => "rational"
    Irrational => "irrational"
    Finite => "finite"
    Infinite => "infinite"
    PositiveInfinite => "positive_infinite"
    NegativeInfinite => "negative_infinite"
    Positive => "positive"
    Negative => "negative"
    Zero => "zero"
    ExtendedPositive => "extended_positive"
    ExtendedNegative => "extended_negative"
    Nonzero => "nonzero"
    Nonpositive => "nonpositive"
    Nonnegative => "nonnegative"
    ExtendedNonzero => "extended_nonzero"
    ExtendedNonpositive => "extended_nonpositive"
    ExtendedNonnegative => "extended_nonnegative"
    Even => "even"
    Odd => "odd"
    Prime => "prime"
    Composite => "composite"
    Commutative => "commutative"
    IsTrue => "is_true"
    Symmetric => "symmetric"
    Invertible => "invertible"
    Orthogonal => "orthogonal"
    Unitary => "unitary"
    PositiveDefinite => "positive_definite"
    UpperTriangular => "upper_triangular"
    LowerTriangular => "lower_triangular"
    Diagonal => "diagonal"
    Fullrank => "fullrank"
    Square => "square"
    IntegerElements => "integer_elements"
    RealElements => "real_elements"
    ComplexElements => "complex_elements"
    Singular => "singular"
    Normal => "normal"
    Triangular => "triangular"
    UnitTriangular => "unit_triangular"
    Eq => "eq"
    Ne => "ne"
    Gt => "gt"
    Ge => "ge"
    Lt => "lt"
    Le => "le"
  }
}

///|
/// Return the query that is always true.
pub fn query_true() -> Query {
  Bool(true)
}

///|
/// Return the query that is always false.
pub fn query_false() -> Query {
  Bool(false)
}

///|
/// Build an atomic query from a predicate key and explicit arguments.
pub fn pred(key : PredicateKey, args : Array[Expr]) -> Query {
  Atom(key, args.map(v => v))
}

///|
/// Build a unary atomic query.
pub fn q1(key : PredicateKey, arg : Expr) -> Query {
  pred(key, [arg])
}

///|
/// Build a binary atomic query.
pub fn q2(key : PredicateKey, lhs : Expr, rhs : Expr) -> Query {
  pred(key, [lhs, rhs])
}

///|
/// Negate a query with light simplification.
///
/// Boolean constants are flipped directly and double negation is removed.
pub fn not_q(expr : Query) -> Query {
  match expr {
    Bool(v) => Bool(!v)
    Not(inner) => inner
    _ => Not(expr)
  }
}

///|
/// Conjoin several queries with light simplification.
///
/// Nested conjunctions are flattened, `true` terms are dropped, and any `false`
/// term collapses the whole conjunction to `false`.
pub fn and_q(args : Array[Query]) -> Query {
  let flat : Array[Query] = Array::new()
  for arg in args {
    match arg {
      Bool(false) => return Bool(false)
      Bool(true) => ()
      And(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  if flat.is_empty() {
    Bool(true)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    And(flat)
  }
}

///|
/// Disjoin several queries with light simplification.
///
/// Nested disjunctions are flattened, `false` terms are dropped, and any `true`
/// term collapses the whole disjunction to `true`.
pub fn or_q(args : Array[Query]) -> Query {
  let flat : Array[Query] = Array::new()
  for arg in args {
    match arg {
      Bool(true) => return Bool(true)
      Bool(false) => ()
      Or(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  if flat.is_empty() {
    Bool(false)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    Or(flat)
  }
}

///|
/// Build a logical implication with simple constant folding.
pub fn implies_q(lhs : Query, rhs : Query) -> Query {
  match (lhs, rhs) {
    (Bool(false), _) => Bool(true)
    (Bool(true), other) => other
    (_, Bool(true)) => Bool(true)
    (_, Bool(false)) => not_q(lhs)
    _ => Implies(lhs, rhs)
  }
}

///|
/// Build a logical equivalence over several queries.
///
/// Empty and singleton inputs reduce to `true`.
pub fn equivalent_q(args : Array[Query]) -> Query {
  let filtered = args.map(v => v)
  if filtered.is_empty() {
    Bool(true)
  } else if filtered.length() == 1 {
    Bool(true)
  } else {
    Equivalent(filtered)
  }
}

///|
/// Build the query “`arg` is real”.
pub fn q_real(arg : Expr) -> Query {
  q1(Real, arg)
}

///|
/// Build the query “`arg` is an integer”.
pub fn q_integer(arg : Expr) -> Query {
  q1(Integer, arg)
}

///|
/// Build the query “`arg` is rational”.
pub fn q_rational(arg : Expr) -> Query {
  q1(Rational, arg)
}

///|
/// Build the query “`arg` is irrational”.
pub fn q_irrational(arg : Expr) -> Query {
  q1(Irrational, arg)
}

///|
/// Build the query “`arg` is strictly positive”.
pub fn q_positive(arg : Expr) -> Query {
  q1(Positive, arg)
}

///|
/// Build the query “`arg` is strictly negative”.
pub fn q_negative(arg : Expr) -> Query {
  q1(Negative, arg)
}

///|
/// Build the query “`arg` is zero”.
pub fn q_zero(arg : Expr) -> Query {
  q1(Zero, arg)
}

///|
/// Build the query “`arg` is nonzero”.
pub fn q_nonzero(arg : Expr) -> Query {
  q1(Nonzero, arg)
}

///|
/// Build the query “`arg` is nonnegative”.
pub fn q_nonnegative(arg : Expr) -> Query {
  q1(Nonnegative, arg)
}

///|
/// Build the query “`arg` is nonpositive”.
pub fn q_nonpositive(arg : Expr) -> Query {
  q1(Nonpositive, arg)
}

///|
/// Build the query “`arg` is even”.
pub fn q_even(arg : Expr) -> Query {
  q1(Even, arg)
}

///|
/// Build the query “`arg` is odd”.
pub fn q_odd(arg : Expr) -> Query {
  q1(Odd, arg)
}

///|
/// Build the query “`arg` is prime”.
pub fn q_prime(arg : Expr) -> Query {
  q1(Prime, arg)
}

///|
/// Build the query “`arg` is composite”.
pub fn q_composite(arg : Expr) -> Query {
  q1(Composite, arg)
}

///|
/// Build the query “`arg` is finite”.
pub fn q_finite(arg : Expr) -> Query {
  q1(Finite, arg)
}

///|
/// Build the query “`arg` is infinite”.
pub fn q_infinite(arg : Expr) -> Query {
  q1(Infinite, arg)
}

///|
/// Build the query “`arg` belongs to the extended real line”.
pub fn q_extended_real(arg : Expr) -> Query {
  q1(ExtendedReal, arg)
}

///|
/// Build the query “`arg` is complex”.
pub fn q_complex(arg : Expr) -> Query {
  q1(Complex, arg)
}

///|
/// Build the query “`arg` is purely imaginary”.
pub fn q_imaginary(arg : Expr) -> Query {
  q1(Imaginary, arg)
}

///|
/// Build the query “`arg` is algebraic”.
pub fn q_algebraic(arg : Expr) -> Query {
  q1(Algebraic, arg)
}

///|
/// Build the query “`arg` is transcendental”.
pub fn q_transcendental(arg : Expr) -> Query {
  q1(Transcendental, arg)
}

///|
/// Build the query “`arg` is positive infinity”.
pub fn q_positive_infinite(arg : Expr) -> Query {
  q1(PositiveInfinite, arg)
}

///|
/// Build the query “`arg` is negative infinity”.
pub fn q_negative_infinite(arg : Expr) -> Query {
  q1(NegativeInfinite, arg)
}

///|
/// Build the query “`arg` is extended-positive”.
pub fn q_extended_positive(arg : Expr) -> Query {
  q1(ExtendedPositive, arg)
}

///|
/// Build the query “`arg` is extended-negative”.
pub fn q_extended_negative(arg : Expr) -> Query {
  q1(ExtendedNegative, arg)
}

///|
/// Build the query “`arg` is extended-nonzero”.
pub fn q_extended_nonzero(arg : Expr) -> Query {
  q1(ExtendedNonzero, arg)
}

///|
/// Build the query “`arg` is extended-nonpositive”.
pub fn q_extended_nonpositive(arg : Expr) -> Query {
  q1(ExtendedNonpositive, arg)
}

///|
/// Build the query “`arg` is extended-nonnegative”.
pub fn q_extended_nonnegative(arg : Expr) -> Query {
  q1(ExtendedNonnegative, arg)
}

///|
/// Build the query “`arg` is not an integer”.
pub fn q_noninteger(arg : Expr) -> Query {
  q1(NonInteger, arg)
}

///|
/// Build the query “`arg` is Hermitian”.
pub fn q_hermitian(arg : Expr) -> Query {
  q1(Hermitian, arg)
}

///|
/// Build the query “`arg` is anti-Hermitian”.
pub fn q_antihermitian(arg : Expr) -> Query {
  q1(Antihermitian, arg)
}

///|
/// Build the query “`arg` is commutative”.
pub fn q_commutative(arg : Expr) -> Query {
  q1(Commutative, arg)
}

///|
/// Build the query “`arg` is logically true”.
pub fn q_is_true(arg : Expr) -> Query {
  q1(IsTrue, arg)
}

///|
/// Build the query “`arg` is symmetric”.
pub fn q_symmetric(arg : Expr) -> Query {
  q1(Symmetric, arg)
}

///|
/// Build the query “`arg` is invertible”.
pub fn q_invertible(arg : Expr) -> Query {
  q1(Invertible, arg)
}

///|
/// Build the query “`arg` is orthogonal”.
pub fn q_orthogonal(arg : Expr) -> Query {
  q1(Orthogonal, arg)
}

///|
/// Build the query “`arg` is unitary”.
pub fn q_unitary(arg : Expr) -> Query {
  q1(Unitary, arg)
}

///|
/// Build the query “`arg` is positive definite”.
pub fn q_positive_definite(arg : Expr) -> Query {
  q1(PositiveDefinite, arg)
}

///|
/// Build the query “`arg` is upper triangular”.
pub fn q_upper_triangular(arg : Expr) -> Query {
  q1(UpperTriangular, arg)
}

///|
/// Build the query “`arg` is lower triangular”.
pub fn q_lower_triangular(arg : Expr) -> Query {
  q1(LowerTriangular, arg)
}

///|
/// Build the query “`arg` is diagonal”.
pub fn q_diagonal(arg : Expr) -> Query {
  q1(Diagonal, arg)
}

///|
/// Build the query “`arg` has full rank”.
pub fn q_fullrank(arg : Expr) -> Query {
  q1(Fullrank, arg)
}

///|
/// Build the query “`arg` is square”.
pub fn q_square(arg : Expr) -> Query {
  q1(Square, arg)
}

///|
/// Build the query “all elements of `arg` are integers”.
pub fn q_integer_elements(arg : Expr) -> Query {
  q1(IntegerElements, arg)
}

///|
/// Build the query “all elements of `arg` are real”.
pub fn q_real_elements(arg : Expr) -> Query {
  q1(RealElements, arg)
}

///|
/// Build the query “all elements of `arg` are complex”.
pub fn q_complex_elements(arg : Expr) -> Query {
  q1(ComplexElements, arg)
}

///|
/// Build the query “`arg` is singular”.
pub fn q_singular(arg : Expr) -> Query {
  q1(Singular, arg)
}

///|
/// Build the query “`arg` is normal”.
pub fn q_normal(arg : Expr) -> Query {
  q1(Normal, arg)
}

///|
/// Build the query “`arg` is triangular”.
pub fn q_triangular(arg : Expr) -> Query {
  q1(Triangular, arg)
}

///|
/// Build the query “`arg` is unit triangular”.
pub fn q_unit_triangular(arg : Expr) -> Query {
  q1(UnitTriangular, arg)
}

///|
/// Build the query “`lhs == rhs`”.
pub fn q_eq(lhs : Expr, rhs : Expr) -> Query {
  q2(Eq, lhs, rhs)
}

///|
/// Build the query “`lhs != rhs`”.
pub fn q_ne(lhs : Expr, rhs : Expr) -> Query {
  q2(Ne, lhs, rhs)
}

///|
/// Build the query “`lhs > rhs`”.
pub fn q_gt(lhs : Expr, rhs : Expr) -> Query {
  q2(Gt, lhs, rhs)
}

///|
/// Build the query “`lhs >= rhs`”.
pub fn q_ge(lhs : Expr, rhs : Expr) -> Query {
  q2(Ge, lhs, rhs)
}

///|
/// Build the query “`lhs < rhs`”.
pub fn q_lt(lhs : Expr, rhs : Expr) -> Query {
  q2(Lt, lhs, rhs)
}

///|
/// Build the query “`lhs <= rhs`”.
pub fn q_le(lhs : Expr, rhs : Expr) -> Query {
  q2(Le, lhs, rhs)
}

///|
/// Render a query in the external predicate-language text format.
///
/// This formatter is mainly useful for diagnostics and cross-language oracle
/// tooling. It is not intended as the primary user-facing display format.
pub fn query_to_sympy(expr : Query) -> String {
  match expr {
    Bool(v) => if v { "True" } else { "False" }
    Atom(key, args) => {
      let rendered = args.map(arg => @symprint.pretty_string(arg)).join(", ")
      match key {
        Eq => "Eq(\{rendered})"
        Ne => "Ne(\{rendered})"
        Gt => "Gt(\{rendered})"
        Ge => "Ge(\{rendered})"
        Lt => "Lt(\{rendered})"
        Le => "Le(\{rendered})"
        _ => "Q.\{predicate_name(key)}(\{rendered})"
      }
    }
    Not(inner) => "~(\{query_to_sympy(inner)})"
    And(args) =>
      if args.is_empty() {
        "True"
      } else {
        args.map(x => "(\{query_to_sympy(x)})").join(" & ")
      }
    Or(args) =>
      if args.is_empty() {
        "False"
      } else {
        args.map(x => "(\{query_to_sympy(x)})").join(" | ")
      }
    Implies(lhs, rhs) =>
      "Implies(\{query_to_sympy(lhs)}, \{query_to_sympy(rhs)})"
    Equivalent(args) =>
      if args.is_empty() {
        "True"
      } else {
        let rendered = args.map(query_to_sympy).join(", ")
        "Equivalent(\{rendered})"
      }
  }
}

///|
/// Build a stable cache key for one atomic query.
///
/// The key combines the predicate name with the printed argument list.
pub fn query_atom_key(key : PredicateKey, args : Array[Expr]) -> String {
  let rendered = args.map(arg => @symprint.pretty_string(arg)).join(",")
  "\{predicate_name(key)}:\{rendered}"
}
