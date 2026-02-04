///|
/// DIMACS CNF loader (subset of sympy.logic.utilities.dimacs).

///|
pub fn dimacs_load(s : String) -> BoolExpr raise {
  let clauses : Array[BoolExpr] = Array::new()
  let lines = Array::from_iter(s.split("\n"))
  for line_view in lines {
    let line = line_view.trim()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("c") {
      continue
    }
    if line.has_prefix("p") {
      continue
    }
    let lits : Array[BoolExpr] = Array::new()
    let parts = Array::from_iter(line.split(" "))
    for part_view in parts {
      let part = part_view.trim()
      if part.is_empty() {
        continue
      }
      let value = @strconv.parse_int(part, base=10)
      if value == 0 {
        continue
      }
      let num = if value < 0 { -value } else { value }
      let sym = bool_symbol("cnf_\{num}")
      if value < 0 {
        lits.push(bool_not(sym))
      } else {
        lits.push(sym)
      }
    }
    if !lits.is_empty() {
      clauses.push(bool_or(lits))
    }
  }
  bool_and(clauses)
}
