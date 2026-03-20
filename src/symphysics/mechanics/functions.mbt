///|
/// High-value functional helpers aligned with `sympy.physics.mechanics.functions`.

///|
pub fn linear_momentum(
  frame : @symvector.ReferenceFrame,
  bodies : Array[BodyLike],
) -> @symvector.Vector raise @symvector.VectorError {
  let mut out = @symvector.vector_zero()
  for body in bodies {
    out = out + (mech_bodylike_linear_momentum(body, frame))
  }
  out
}

///|
pub fn angular_momentum(
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
  bodies : Array[BodyLike],
) -> @symvector.Vector raise @symvector.VectorError {
  let mut out = @symvector.vector_zero()
  for body in bodies {
    out = out + (mech_bodylike_angular_momentum(body, point, frame))
  }
  out
}

///|
pub fn kinetic_energy(
  frame : @symvector.ReferenceFrame,
  bodies : Array[BodyLike],
) -> Expr raise @symvector.VectorError {
  let mut out = mech_zero_expr()
  for body in bodies {
    out = mech_simplify_expr(
      out + (mech_bodylike_kinetic_energy(body, frame)),
    )
  }
  out
}

///|
pub fn potential_energy(bodies : Array[BodyLike]) -> Expr {
  let mut out = mech_zero_expr()
  for body in bodies {
    out = mech_simplify_expr(out + mech_bodylike_potential_energy(body))
  }
  out
}

///|
pub fn center_of_mass(
  point : @symvector.Point,
  bodies : Array[BodyLike],
) -> @symvector.Vector raise @symvector.VectorError {
  if bodies.is_empty() {
    return @symvector.vector_zero()
  }
  let mut total_mass = mech_zero_expr()
  let mut acc = @symvector.vector_zero()
  for body in bodies {
    let mass = mech_bodylike_mass(body)
    total_mass = mech_simplify_expr(total_mass + mass)
    let offset = mech_bodylike_masscenter(body).pos_from(point)
    acc = acc + offset.scale(mass)
  }
  acc.truediv(total_mass)
}

///|
pub fn lagrangian(
  frame : @symvector.ReferenceFrame,
  bodies : Array[BodyLike],
) -> Expr raise @symvector.VectorError {
  mech_simplify_expr(kinetic_energy(frame, bodies) - potential_energy(bodies))
}

///|
pub fn find_dynamicsymbols_expr(
  expr : Expr,
  exclude? : Array[Expr] = [],
) -> Array[Expr] {
  let seen : Map[String, Expr] = {}
  mech_find_dynamicsymbols_go(expr, seen)
  for item in exclude {
    seen.remove(mech_expr_key(item))
  }
  let keys : Array[String] = []
  for entry in seen {
    keys.push(entry.0)
  }
  keys.sort()
  keys.map(key => seen[key])
}

///|
pub fn find_dynamicsymbols_vector(
  expr : @symvector.Vector,
  reference_frame : @symvector.ReferenceFrame,
  exclude? : Array[Expr] = [],
) -> Array[Expr] raise @symvector.VectorError {
  let comps = expr.to_matrix(reference_frame)
  let found : Map[String, Expr] = {}
  for row in comps.rows_copy() {
    for value in row {
      mech_find_dynamicsymbols_go(value, found)
    }
  }
  for item in exclude {
    found.remove(mech_expr_key(item))
  }
  let keys : Array[String] = []
  for entry in found {
    keys.push(entry.0)
  }
  keys.sort()
  keys.map(key => found[key])
}

///|
pub fn msubs_expr(
  expr : Expr,
  substitutions : Array[Substitution],
  smart? : Bool = false,
) -> Expr {
  let base = if smart { mech_rewrite_tan(expr) } else { expr }
  let replaced = mech_apply_subs_exact(base, substitutions)
  if smart {
    let trigged = @symsimplify.trigsimp(replaced, max_passes=6)
    let rational = @symsimplify.ratsimp(trigged, max_passes=6)
    mech_simplify_expr(mech_eval_special_trig(rational))
  } else {
    mech_simplify_expr(replaced)
  }
}

///|
pub fn msubs_vector(
  expr : @symvector.Vector,
  substitutions : Array[Substitution],
  smart? : Bool = false,
) -> @symvector.Vector {
  expr.applyfunc(fn(term) { msubs_expr(term, substitutions, smart~) })
}

///|
pub fn msubs_dyadic(
  expr : @symvector.Dyadic,
  substitutions : Array[Substitution],
  smart? : Bool = false,
) -> @symvector.Dyadic {
  expr.applyfunc(fn(term) { msubs_expr(term, substitutions, smart~) })
}

///|
pub fn msubs_matrix(
  expr : @symphysics.ExplicitMatrix,
  substitutions : Array[Substitution],
  smart? : Bool = false,
) -> @symphysics.ExplicitMatrix {
  expr.map(fn(term) { msubs_expr(term, substitutions, smart~) })
}

///|
pub fn validate_coordinates(
  coordinates? : Array[Expr] = [],
  speeds? : Array[Expr] = [],
  check_duplicates? : Bool = true,
  is_dynamicsymbols? : Bool = true,
  u_auxiliary? : Array[Expr] = [],
) -> Unit raise @symphysics.PhysicsError {
  if check_duplicates {
    let coord_keys = coordinates.map(mech_expr_key)
    let speed_keys = speeds.map(mech_expr_key)
    let aux_keys = u_auxiliary.map(mech_expr_key)
    if coord_keys.length() != Set::from_array(coord_keys).length() {
      raise @symphysics.PhysicsError::ValueError(
        "duplicate generalized coordinates",
      )
    }
    if speed_keys.length() != Set::from_array(speed_keys).length() {
      raise @symphysics.PhysicsError::ValueError("duplicate generalized speeds")
    }
    if aux_keys.length() != Set::from_array(aux_keys).length() {
      raise @symphysics.PhysicsError::ValueError("duplicate auxiliary speeds")
    }
    for coord in coordinates {
      if speeds.any(fn(speed) { @symcore.compare_expr(coord, speed) == 0 }) {
        raise @symphysics.PhysicsError::ValueError(
          "coordinate also appears in generalized speeds",
        )
      }
      if u_auxiliary.any(fn(aux) { @symcore.compare_expr(coord, aux) == 0 }) {
        raise @symphysics.PhysicsError::ValueError(
          "coordinate also appears in auxiliary speeds",
        )
      }
    }
    for speed in speeds {
      if u_auxiliary.any(fn(aux) { @symcore.compare_expr(speed, aux) == 0 }) {
        raise @symphysics.PhysicsError::ValueError(
          "speed also appears in auxiliary speeds",
        )
      }
    }
  }
  if is_dynamicsymbols {
    for coord in coordinates {
      if !mech_is_dynamicsymbol(coord) {
        raise @symphysics.PhysicsError::ValueError(
          "generalized coordinate is not a dynamicsymbol",
        )
      }
    }
    for speed in speeds {
      if !mech_is_dynamicsymbol(speed) {
        raise @symphysics.PhysicsError::ValueError(
          "generalized speed is not a dynamicsymbol",
        )
      }
    }
    for aux in u_auxiliary {
      if !mech_is_dynamicsymbol(aux) {
        raise @symphysics.PhysicsError::ValueError(
          "auxiliary speed is not a dynamicsymbol",
        )
      }
    }
  }
}
