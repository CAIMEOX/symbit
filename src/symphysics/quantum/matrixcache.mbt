///|
/// Small exact matrix cache aligned with `sympy.physics.quantum.matrixcache`.
///
/// SymPy stores frequently used 2x2 and 4x4 matrices in multiple backends.
/// SymBit only needs the exact symbolic matrix form, but keeping the same
/// named cache removes duplication across gate- and qubit-level code.

///|
pub struct MatrixCache {
  dtype : String
  entries : Map[String, @symphysics.ExplicitMatrix]
}

///|
pub let sqrt2_inv : Expr = @symcore.raw_pow(
  int(2),
  try! @symcore.rational_from_ints(-1, 2),
)

///|
fn cached_matrix(
  rows : Array[Array[Expr]],
) -> @symphysics.ExplicitMatrix {
  match (try? @symphysics.explicit_matrix_from_rows(rows)) {
    Ok(matrix) => matrix
    Err(_) => panic()
  }
}

///|
pub fn matrix_cache(dtype? : String = "complex") -> MatrixCache {
  let cache = MatrixCache::{ dtype, entries: {} }
  let quarter = try! @symcore.rational_from_ints(1, 4)
  cache.cache_matrix(
    "eye2",
    cached_matrix([
      [int(1), int(0)],
      [int(0), int(1)],
    ]),
  )
  cache.cache_matrix(
    "op11",
    cached_matrix([
      [int(0), int(0)],
      [int(0), int(1)],
    ]),
  )
  cache.cache_matrix(
    "op00",
    cached_matrix([
      [int(1), int(0)],
      [int(0), int(0)],
    ]),
  )
  cache.cache_matrix(
    "op10",
    cached_matrix([
      [int(0), int(0)],
      [int(1), int(0)],
    ]),
  )
  cache.cache_matrix(
    "op01",
    cached_matrix([
      [int(0), int(1)],
      [int(0), int(0)],
    ]),
  )
  cache.cache_matrix(
    "X",
    cached_matrix([
      [int(0), int(1)],
      [int(1), int(0)],
    ]),
  )
  cache.cache_matrix(
    "Y",
    cached_matrix([
      [int(0), int(-1) * symbol("I")],
      [symbol("I"), int(0)],
    ]),
  )
  cache.cache_matrix(
    "Z",
    cached_matrix([
      [int(1), int(0)],
      [int(0), int(-1)],
    ]),
  )
  cache.cache_matrix(
    "S",
    cached_matrix([
      [int(1), int(0)],
      [int(0), symbol("I")],
    ]),
  )
  cache.cache_matrix(
    "T",
    cached_matrix([
      [int(1), int(0)],
      [
        int(0),
        @symcore.raw_function("exp", [
          symbol("I") * symbol("pi") * quarter,
        ]),
      ],
    ]),
  )
  cache.cache_matrix(
    "H",
    cached_matrix([
      [sqrt2_inv, sqrt2_inv],
      [sqrt2_inv, int(-1) * sqrt2_inv],
    ]),
  )
  cache.cache_matrix(
    "Hsqrt2",
    cached_matrix([
      [int(1), int(1)],
      [int(1), int(-1)],
    ]),
  )
  cache.cache_matrix(
    "SWAP",
    cached_matrix([
      [int(1), int(0), int(0), int(0)],
      [int(0), int(0), int(1), int(0)],
      [int(0), int(1), int(0), int(0)],
      [int(0), int(0), int(0), int(1)],
    ]),
  )
  cache.cache_matrix(
    "ZX",
    cached_matrix([
      [sqrt2_inv, sqrt2_inv],
      [sqrt2_inv, int(-1) * sqrt2_inv],
    ]),
  )
  cache.cache_matrix(
    "ZY",
    cached_matrix([
      [symbol("I"), int(0)],
      [int(0), int(-1) * symbol("I")],
    ]),
  )
  cache
}

///|
pub fn MatrixCache::cache_matrix(
  self : MatrixCache,
  name : String,
  matrix : @symphysics.ExplicitMatrix,
) -> Unit {
  self.entries.set(name, matrix)
}

///|
pub fn MatrixCache::get_matrix(
  self : MatrixCache,
  name : String,
  format? : String = "sympy",
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  guard format == "sympy" else {
    raise @symphysics.PhysicsError::ValueError(
      "Only the exact sympy-style matrix backend is available",
    )
  }
  match self.entries.get(name) {
    Some(matrix) => matrix
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "Matrix with name \{name} and format \{format} is not available",
      )
  }
}

///|
pub let quantum_matrix_cache : MatrixCache = matrix_cache()
