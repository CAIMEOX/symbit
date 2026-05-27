///|
/// Vector-aware string printers.

///|
fn basis_name(frame : ReferenceFrame, axis : Int) -> String {
  frame.name_ + "." + frame.indices_[axis]
}

///|
fn join_signed(parts : Array[String]) -> String {
  if parts.is_empty() {
    return "0"
  }
  let mut out = parts[0]
  for part in parts[1:] {
    let piece = part.to_string()
    if piece.has_prefix("-") {
      out = out + " - " + piece[1:].to_owned()
    } else {
      out = out + " + " + piece
    }
  }
  out
}

///|
fn scalar_with_basis(coeff : Expr, basis : String) -> String {
  let txt = @symprint.pretty_string(simplify_expr(coeff))
  if txt == "1" {
    basis
  } else if txt == "-1" {
    "-" + basis
  } else if txt.has_prefix("-1*") {
    "-" + txt[3:].to_owned() + "*" + basis
  } else {
    txt + "*" + basis
  }
}

///|
pub fn vsprint(vector : Vector) -> String {
  if vector.args.is_empty() {
    return "0"
  }
  let parts : Array[String] = []
  for item in vector.args {
    let frame = frame_registry_get(item.0)
    let comps = item.1
    for axis in 0..<3 {
      if !expr_is_zero(comps[axis]) {
        parts.push(scalar_with_basis(comps[axis], basis_name(frame, axis)))
      }
    }
  }
  join_signed(parts)
}

///|
pub fn vsprint_dyadic(dyadic : Dyadic) -> String {
  if dyadic.args.is_empty() {
    return "0"
  }
  let parts : Array[String] = []
  for item in dyadic.args {
    let left = basis_name(frame_registry_get(item.1), item.2)
    let right = basis_name(frame_registry_get(item.3), item.4)
    let basis = "(" + left + "|" + right + ")"
    parts.push(scalar_with_basis(item.0, basis))
  }
  join_signed(parts)
}
