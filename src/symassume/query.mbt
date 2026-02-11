///|
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
} derive(Eq, Show)

///|
pub(all) enum Query {
  Bool(Bool)
  Atom(PredicateKey, Array[@symcore.Expr])
  Not(Query)
  And(Array[Query])
  Or(Array[Query])
  Implies(Query, Query)
  Equivalent(Array[Query])
} derive(Eq)

///|
pub fn predicate_name(key : PredicateKey) -> String {
  match key {
    PredicateKey::Hermitian => "hermitian"
    PredicateKey::Antihermitian => "antihermitian"
    PredicateKey::Real => "real"
    PredicateKey::ExtendedReal => "extended_real"
    PredicateKey::Imaginary => "imaginary"
    PredicateKey::Complex => "complex"
    PredicateKey::Algebraic => "algebraic"
    PredicateKey::Transcendental => "transcendental"
    PredicateKey::Integer => "integer"
    PredicateKey::NonInteger => "noninteger"
    PredicateKey::Rational => "rational"
    PredicateKey::Irrational => "irrational"
    PredicateKey::Finite => "finite"
    PredicateKey::Infinite => "infinite"
    PredicateKey::PositiveInfinite => "positive_infinite"
    PredicateKey::NegativeInfinite => "negative_infinite"
    PredicateKey::Positive => "positive"
    PredicateKey::Negative => "negative"
    PredicateKey::Zero => "zero"
    PredicateKey::ExtendedPositive => "extended_positive"
    PredicateKey::ExtendedNegative => "extended_negative"
    PredicateKey::Nonzero => "nonzero"
    PredicateKey::Nonpositive => "nonpositive"
    PredicateKey::Nonnegative => "nonnegative"
    PredicateKey::ExtendedNonzero => "extended_nonzero"
    PredicateKey::ExtendedNonpositive => "extended_nonpositive"
    PredicateKey::ExtendedNonnegative => "extended_nonnegative"
    PredicateKey::Even => "even"
    PredicateKey::Odd => "odd"
    PredicateKey::Prime => "prime"
    PredicateKey::Composite => "composite"
    PredicateKey::Commutative => "commutative"
    PredicateKey::IsTrue => "is_true"
    PredicateKey::Symmetric => "symmetric"
    PredicateKey::Invertible => "invertible"
    PredicateKey::Orthogonal => "orthogonal"
    PredicateKey::Unitary => "unitary"
    PredicateKey::PositiveDefinite => "positive_definite"
    PredicateKey::UpperTriangular => "upper_triangular"
    PredicateKey::LowerTriangular => "lower_triangular"
    PredicateKey::Diagonal => "diagonal"
    PredicateKey::Fullrank => "fullrank"
    PredicateKey::Square => "square"
    PredicateKey::IntegerElements => "integer_elements"
    PredicateKey::RealElements => "real_elements"
    PredicateKey::ComplexElements => "complex_elements"
    PredicateKey::Singular => "singular"
    PredicateKey::Normal => "normal"
    PredicateKey::Triangular => "triangular"
    PredicateKey::UnitTriangular => "unit_triangular"
    PredicateKey::Eq => "eq"
    PredicateKey::Ne => "ne"
    PredicateKey::Gt => "gt"
    PredicateKey::Ge => "ge"
    PredicateKey::Lt => "lt"
    PredicateKey::Le => "le"
  }
}

///|
pub fn query_true() -> Query {
  Query::Bool(true)
}

///|
pub fn query_false() -> Query {
  Query::Bool(false)
}

///|
pub fn pred(key : PredicateKey, args : Array[@symcore.Expr]) -> Query {
  Query::Atom(key, args.map(v => v))
}

///|
pub fn q1(key : PredicateKey, arg : @symcore.Expr) -> Query {
  pred(key, [arg])
}

///|
pub fn q2(
  key : PredicateKey,
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> Query {
  pred(key, [lhs, rhs])
}

///|
pub fn not_q(expr : Query) -> Query {
  match expr {
    Query::Bool(v) => Query::Bool(!v)
    Query::Not(inner) => inner
    _ => Query::Not(expr)
  }
}

///|
pub fn and_q(args : Array[Query]) -> Query {
  let flat : Array[Query] = Array::new()
  for arg in args {
    match arg {
      Query::Bool(false) => return Query::Bool(false)
      Query::Bool(true) => ()
      Query::And(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  if flat.is_empty() {
    Query::Bool(true)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    Query::And(flat)
  }
}

///|
pub fn or_q(args : Array[Query]) -> Query {
  let flat : Array[Query] = Array::new()
  for arg in args {
    match arg {
      Query::Bool(true) => return Query::Bool(true)
      Query::Bool(false) => ()
      Query::Or(inner) =>
        for item in inner {
          flat.push(item)
        }
      _ => flat.push(arg)
    }
  }
  if flat.is_empty() {
    Query::Bool(false)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    Query::Or(flat)
  }
}

///|
pub fn implies_q(lhs : Query, rhs : Query) -> Query {
  match (lhs, rhs) {
    (Query::Bool(false), _) => Query::Bool(true)
    (Query::Bool(true), other) => other
    (_, Query::Bool(true)) => Query::Bool(true)
    (_, Query::Bool(false)) => not_q(lhs)
    _ => Query::Implies(lhs, rhs)
  }
}

///|
pub fn equivalent_q(args : Array[Query]) -> Query {
  let filtered = args.map(v => v)
  if filtered.is_empty() {
    Query::Bool(true)
  } else if filtered.length() == 1 {
    Query::Bool(true)
  } else {
    Query::Equivalent(filtered)
  }
}

///|
pub fn q_real(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Real, arg)
}

///|
pub fn q_integer(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Integer, arg)
}

///|
pub fn q_rational(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Rational, arg)
}

///|
pub fn q_irrational(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Irrational, arg)
}

///|
pub fn q_positive(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Positive, arg)
}

///|
pub fn q_negative(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Negative, arg)
}

///|
pub fn q_zero(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Zero, arg)
}

///|
pub fn q_nonzero(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Nonzero, arg)
}

///|
pub fn q_nonnegative(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Nonnegative, arg)
}

///|
pub fn q_nonpositive(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Nonpositive, arg)
}

///|
pub fn q_even(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Even, arg)
}

///|
pub fn q_odd(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Odd, arg)
}

///|
pub fn q_prime(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Prime, arg)
}

///|
pub fn q_composite(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Composite, arg)
}

///|
pub fn q_finite(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Finite, arg)
}

///|
pub fn q_infinite(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Infinite, arg)
}

///|
pub fn q_extended_real(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ExtendedReal, arg)
}

///|
pub fn q_complex(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Complex, arg)
}

///|
pub fn q_imaginary(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Imaginary, arg)
}

///|
pub fn q_algebraic(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Algebraic, arg)
}

///|
pub fn q_transcendental(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Transcendental, arg)
}

///|
pub fn q_positive_infinite(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::PositiveInfinite, arg)
}

///|
pub fn q_negative_infinite(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::NegativeInfinite, arg)
}

///|
pub fn q_extended_positive(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ExtendedPositive, arg)
}

///|
pub fn q_extended_negative(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ExtendedNegative, arg)
}

///|
pub fn q_extended_nonzero(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ExtendedNonzero, arg)
}

///|
pub fn q_extended_nonpositive(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ExtendedNonpositive, arg)
}

///|
pub fn q_extended_nonnegative(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ExtendedNonnegative, arg)
}

///|
pub fn q_noninteger(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::NonInteger, arg)
}

///|
pub fn q_hermitian(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Hermitian, arg)
}

///|
pub fn q_antihermitian(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Antihermitian, arg)
}

///|
pub fn q_commutative(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Commutative, arg)
}

///|
pub fn q_is_true(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::IsTrue, arg)
}

///|
pub fn q_symmetric(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Symmetric, arg)
}

///|
pub fn q_invertible(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Invertible, arg)
}

///|
pub fn q_orthogonal(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Orthogonal, arg)
}

///|
pub fn q_unitary(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Unitary, arg)
}

///|
pub fn q_positive_definite(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::PositiveDefinite, arg)
}

///|
pub fn q_upper_triangular(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::UpperTriangular, arg)
}

///|
pub fn q_lower_triangular(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::LowerTriangular, arg)
}

///|
pub fn q_diagonal(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Diagonal, arg)
}

///|
pub fn q_fullrank(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Fullrank, arg)
}

///|
pub fn q_square(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Square, arg)
}

///|
pub fn q_integer_elements(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::IntegerElements, arg)
}

///|
pub fn q_real_elements(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::RealElements, arg)
}

///|
pub fn q_complex_elements(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::ComplexElements, arg)
}

///|
pub fn q_singular(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Singular, arg)
}

///|
pub fn q_normal(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Normal, arg)
}

///|
pub fn q_triangular(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::Triangular, arg)
}

///|
pub fn q_unit_triangular(arg : @symcore.Expr) -> Query {
  q1(PredicateKey::UnitTriangular, arg)
}

///|
pub fn q_eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Query {
  q2(PredicateKey::Eq, lhs, rhs)
}

///|
pub fn q_ne(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Query {
  q2(PredicateKey::Ne, lhs, rhs)
}

///|
pub fn q_gt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Query {
  q2(PredicateKey::Gt, lhs, rhs)
}

///|
pub fn q_ge(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Query {
  q2(PredicateKey::Ge, lhs, rhs)
}

///|
pub fn q_lt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Query {
  q2(PredicateKey::Lt, lhs, rhs)
}

///|
pub fn q_le(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Query {
  q2(PredicateKey::Le, lhs, rhs)
}

///|
pub fn query_to_sympy(expr : Query) -> String {
  match expr {
    Query::Bool(v) => if v { "True" } else { "False" }
    Query::Atom(key, args) => {
      let rendered = args.map(arg => @symprint.to_string(arg)).join(", ")
      match key {
        PredicateKey::Eq => "Eq(\{rendered})"
        PredicateKey::Ne => "Ne(\{rendered})"
        PredicateKey::Gt => "Gt(\{rendered})"
        PredicateKey::Ge => "Ge(\{rendered})"
        PredicateKey::Lt => "Lt(\{rendered})"
        PredicateKey::Le => "Le(\{rendered})"
        _ => "Q.\{predicate_name(key)}(\{rendered})"
      }
    }
    Query::Not(inner) => "~(\{query_to_sympy(inner)})"
    Query::And(args) =>
      if args.is_empty() {
        "True"
      } else {
        args.map(x => "(\{query_to_sympy(x)})").join(" & ")
      }
    Query::Or(args) =>
      if args.is_empty() {
        "False"
      } else {
        args.map(x => "(\{query_to_sympy(x)})").join(" | ")
      }
    Query::Implies(lhs, rhs) =>
      "Implies(\{query_to_sympy(lhs)}, \{query_to_sympy(rhs)})"
    Query::Equivalent(args) =>
      if args.is_empty() {
        "True"
      } else {
        let rendered = args.map(query_to_sympy).join(", ")
        "Equivalent(\{rendered})"
      }
  }
}

///|
pub fn query_atom_key(
  key : PredicateKey,
  args : Array[@symcore.Expr],
) -> String {
  let rendered = args.map(arg => @symprint.to_string(arg)).join(",")
  "\{predicate_name(key)}:\{rendered}"
}
