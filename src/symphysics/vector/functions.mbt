///|
/// Functional helpers aligned with `sympy.physics.vector.functions`.

///|
pub fn dynamicsymbol(name : String, level? : Int = 0) -> Expr {
  dynamicsymbol_single(name, level)
}

///|
pub fn dynamicsymbols(names : String, level? : Int = 0) -> Array[Expr] {
  let out : Array[Expr] = []
  for token in tokenize_dynamicsymbols(names) {
    for expanded in expand_dynamicsymbol_token(token) {
      out.push(dynamicsymbol_single(expanded, level))
    }
  }
  out
}

///|
pub fn dot(vec1 : Vector, vec2 : Vector) -> Expr raise VectorError {
  vec1.dot(vec2)
}

///|
pub fn cross(vec1 : Vector, vec2 : Vector) -> Vector raise VectorError {
  vec1.cross(vec2)
}

///|
pub fn outer(vec1 : Vector, vec2 : Vector) -> Dyadic raise VectorError {
  vec1.outer(vec2)
}

///|
pub fn express(
  expr : Vector,
  frame : ReferenceFrame,
  variables? : Bool = false,
) -> Vector raise VectorError {
  expr.express(frame, variables~)
}

///|
pub fn express_scalar(
  expr : Expr,
  frame : ReferenceFrame,
  variables? : Bool = false,
) -> Expr {
  if !variables {
    return expr
  }
  let seen : Map[String, Bool] = Map([])
  collect_symbol_names(expr, seen)
  let env : Map[String, Expr] = Map([])
  for entry in seen {
    let name = entry.0
    match vector_coordinate_registry.get(name) {
      Some((other_id, _)) if other_id != frame.index_ => {
        let other = frame_registry_get(other_id)
        let mapping = other.variable_map(frame) catch { _ => {} }
        for mapping_entry in mapping {
          env.set(mapping_entry.0, mapping_entry.1)
        }
      }
      _ => ()
    }
  }
  if env.is_empty() {
    expr
  } else {
    simplify_expr(@symcore.subst(expr, env))
  }
}

///|
pub fn time_derivative(
  expr : Vector,
  frame : ReferenceFrame,
  order? : Int = 1,
) -> Vector raise VectorError {
  expr.dt(frame, order~)
}

///|
pub fn time_derivative_scalar(
  expr : Expr,
  frame : ReferenceFrame,
  order? : Int = 1,
) -> Expr {
  let base = express_scalar(expr, frame, variables=true)
  let mut out = base
  for _ in 0..<order {
    out = @symcalculus.diff(out, dynamicsymbols_t)
  }
  simplify_expr(out)
}

///|
pub fn time_derivative_dyadic(
  expr : Dyadic,
  frame : ReferenceFrame,
  order? : Int = 1,
) -> Dyadic raise VectorError {
  expr.dt(frame, order~)
}
