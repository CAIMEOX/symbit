///|
/// Normal forms and distribution utilities for boolalg.

///|
pub fn is_literal(expr : BoolExpr) -> Bool {
  match expr {
    BoolExpr::True => true
    BoolExpr::False => true
    BoolExpr::Symbol(_) => true
    BoolExpr::LRA(_) => true
    BoolExpr::Not(inner) => is_literal(inner)
    _ => false
  }
}

///|
pub fn conjuncts(expr : BoolExpr) -> Array[BoolExpr] {
  match expr {
    BoolExpr::And(args) => args
    _ => [expr]
  }
}

///|
pub fn disjuncts(expr : BoolExpr) -> Array[BoolExpr] {
  match expr {
    BoolExpr::Or(args) => args
    _ => [expr]
  }
}

///|
priv enum LogicOp {
  And
  Or
  Xor
}

///|
fn op_is(expr : BoolExpr, op : LogicOp) -> Bool {
  match op {
    LogicOp::And =>
      match expr {
        BoolExpr::And(_) => true
        _ => false
      }
    LogicOp::Or =>
      match expr {
        BoolExpr::Or(_) => true
        _ => false
      }
    LogicOp::Xor =>
      match expr {
        BoolExpr::Xor(_) => true
        _ => false
      }
  }
}

///|
fn op_args(expr : BoolExpr, op : LogicOp) -> Array[BoolExpr] {
  match op {
    LogicOp::And =>
      match expr {
        BoolExpr::And(args) => args
        _ => []
      }
    LogicOp::Or =>
      match expr {
        BoolExpr::Or(args) => args
        _ => []
      }
    LogicOp::Xor =>
      match expr {
        BoolExpr::Xor(args) => args
        _ => []
      }
  }
}

///|
fn op_make(op : LogicOp, args : Array[BoolExpr]) -> BoolExpr {
  match op {
    LogicOp::And => bool_and(args)
    LogicOp::Or => bool_or(args)
    LogicOp::Xor => xor_keep_true(args)
  }
}

///|
fn _distribute(expr : BoolExpr, op1 : LogicOp, op2 : LogicOp) -> BoolExpr {
  if op_is(expr, op2) {
    let args = op_args(expr, op2)
    let mut conj_idx = -1
    for i in 0..<args.length() {
      if op_is(args[i], op1) {
        conj_idx = i
        break
      }
    }
    if conj_idx == -1 {
      return expr
    }
    let conj = args[conj_idx]
    let rest_args : Array[BoolExpr] = Array::new()
    for i in 0..<args.length() {
      if i != conj_idx {
        rest_args.push(args[i])
      }
    }
    let rest = op_make(op2, rest_args)
    let conj_args = op_args(conj, op1)
    let mapped : Array[BoolExpr] = Array::new()
    for c in conj_args {
      mapped.push(_distribute(op_make(op2, [c, rest]), op1, op2))
    }
    return op_make(op1, mapped)
  } else if op_is(expr, op1) {
    let args = op_args(expr, op1)
    let mapped : Array[BoolExpr] = Array::new()
    for a in args {
      mapped.push(_distribute(a, op1, op2))
    }
    return op_make(op1, mapped)
  }
  expr
}

///|
pub fn distribute_and_over_or(expr : BoolExpr) -> BoolExpr {
  _distribute(expr, LogicOp::And, LogicOp::Or)
}

///|
pub fn distribute_or_over_and(expr : BoolExpr) -> BoolExpr {
  _distribute(expr, LogicOp::Or, LogicOp::And)
}

///|
pub fn distribute_xor_over_and(expr : BoolExpr) -> BoolExpr {
  _distribute(expr, LogicOp::Xor, LogicOp::And)
}

///|
fn parity_terms(bits : Int, odd : Bool) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  let total = 1 << bits
  for mask in 0..<total {
    if (bit_count(mask) % 2 == 1) == odd {
      out.push(ibin(mask, bits))
    }
  }
  out
}

///|
fn xor_cnf_clauses(args : Array[BoolExpr], odd : Bool) -> Array[BoolExpr] {
  let masks = parity_terms(args.length(), odd)
  let clauses : Array[BoolExpr] = Array::new()
  for mask in masks {
    let clause_args : Array[BoolExpr] = Array::new()
    for i in 0..<args.length() {
      let arg = args[i]
      let term = if mask[i] == 1 { bool_not(arg) } else { arg }
      clause_args.push(term)
    }
    clauses.push(bool_or(clause_args))
  }
  clauses
}

///|
fn xor_dnf_terms(args : Array[BoolExpr]) -> Array[BoolExpr] {
  let masks = parity_terms(args.length(), true)
  let terms : Array[BoolExpr] = Array::new()
  for mask in masks {
    let conj_args : Array[BoolExpr] = Array::new()
    for i in 0..<args.length() {
      let arg = args[i]
      let term = if mask[i] == 1 { arg } else { bool_not(arg) }
      conj_args.push(term)
    }
    terms.push(bool_and(conj_args))
  }
  terms
}

///|
pub fn eliminate_implications(expr : BoolExpr, form? : String) -> BoolExpr {
  to_nnf(expr, simplify=false, form?)
}

///|
pub fn to_nnf(
  expr : BoolExpr,
  simplify? : Bool = true,
  form? : String,
) -> BoolExpr {
  let form_str = match form {
    Some(v) => v
    None => ""
  }
  if is_nnf(expr, simplified=simplify) {
    return expr
  }
  to_nnf_inner(expr, simplify, form_str)
}

///|
fn to_nnf_inner(expr : BoolExpr, simplify : Bool, form : String) -> BoolExpr {
  if is_literal(expr) {
    return expr
  }
  match expr {
    BoolExpr::And(args) => {
      let mapped = args.map(a => to_nnf_inner(a, simplify, form))
      if simplify {
        let seen : Map[BoolExpr, Bool] = Map::new()
        for arg in mapped {
          let comp = bool_not(arg)
          if seen.contains(comp) {
            return BoolExpr::False
          }
          seen[arg] = true
        }
      }
      bool_and(mapped)
    }
    BoolExpr::Or(args) => {
      let mapped = args.map(a => to_nnf_inner(a, simplify, form))
      if simplify {
        let seen : Map[BoolExpr, Bool] = Map::new()
        for arg in mapped {
          let comp = bool_not(arg)
          if seen.contains(comp) {
            return BoolExpr::True
          }
          seen[arg] = true
        }
      }
      bool_or(mapped)
    }
    BoolExpr::Not(inner) => {
      if is_literal(inner) {
        return expr
      }
      match inner {
        BoolExpr::And(args) =>
          bool_or(args.map(a => to_nnf_inner(bool_not(a), simplify, form)))
        BoolExpr::Or(args) =>
          bool_and(args.map(a => to_nnf_inner(bool_not(a), simplify, form)))
        BoolExpr::Implies(a, b) =>
          to_nnf_inner(bool_and([a, bool_not(b)]), simplify, form)
        BoolExpr::Equivalent(args) => {
          let pos = bool_or(args)
          let neg_args : Array[BoolExpr] = Array::new()
          for arg in args {
            neg_args.push(bool_not(arg))
          }
          let neg = bool_or(neg_args)
          to_nnf_inner(bool_and([pos, neg]), simplify, form)
        }
        BoolExpr::Xor(args) => {
          let clauses = xor_cnf_clauses(args, true)
          to_nnf_inner(bool_and(clauses), simplify, form)
        }
        BoolExpr::ITE(c, t, e) => {
          let left = bool_or([c, bool_not(e)])
          let right = bool_or([bool_not(c), bool_not(t)])
          to_nnf_inner(bool_and([left, right]), simplify, form)
        }
        _ => bool_not(to_nnf_inner(inner, simplify, form))
      }
    }
    BoolExpr::Implies(a, b) =>
      to_nnf_inner(bool_or([bool_not(a), b]), simplify, form)
    BoolExpr::Equivalent(args) => {
      if args.is_empty() {
        return BoolExpr::True
      }
      let pairs : Array[BoolExpr] = Array::new()
      for i in 0..<(args.length() - 1) {
        pairs.push(bool_or([bool_not(args[i]), args[i + 1]]))
      }
      pairs.push(bool_or([bool_not(args[args.length() - 1]), args[0]]))
      to_nnf_inner(bool_and(pairs), simplify, form)
    }
    BoolExpr::Xor(args) => {
      let nnf_args = args.map(a => to_nnf_inner(a, simplify, form))
      if form == "dnf" {
        let terms = xor_dnf_terms(nnf_args)
        to_nnf_inner(bool_or(terms), simplify, form)
      } else {
        let clauses = xor_cnf_clauses(nnf_args, false)
        to_nnf_inner(bool_and(clauses), simplify, form)
      }
    }
    BoolExpr::ITE(c, t, e) => {
      let left = bool_or([bool_not(c), t])
      let right = bool_or([c, e])
      to_nnf_inner(bool_and([left, right]), simplify, form)
    }
    _ => expr
  }
}

///|
pub fn is_nnf(expr : BoolExpr, simplified? : Bool = true) -> Bool {
  if is_literal(expr) {
    return true
  }
  let stack : Array[BoolExpr] = [expr]
  while !stack.is_empty() {
    let current = stack.remove(stack.length() - 1)
    match current {
      BoolExpr::And(args) | BoolExpr::Or(args) => {
        if simplified {
          let seen : Map[BoolExpr, Bool] = Map::new()
          for arg in args {
            let comp = bool_not(arg)
            if seen.contains(comp) {
              return false
            }
            seen[arg] = true
          }
        }
        for arg in args {
          stack.push(arg)
        }
      }
      _ => {
        if !is_literal(current) {
          return false
        }
      }
    }
  }
  true
}

///|
pub fn is_cnf(expr : BoolExpr) -> Bool {
  let clauses = match expr {
    BoolExpr::And(args) => args
    _ => [expr]
  }
  for clause in clauses {
    let lits = match clause {
      BoolExpr::Or(args) => args
      _ => [clause]
    }
    for lit in lits {
      if !is_literal(lit) {
        return false
      }
    }
  }
  true
}

///|
pub fn is_dnf(expr : BoolExpr) -> Bool {
  let clauses = match expr {
    BoolExpr::Or(args) => args
    _ => [expr]
  }
  for clause in clauses {
    let lits = match clause {
      BoolExpr::And(args) => args
      _ => [clause]
    }
    for lit in lits {
      if !is_literal(lit) {
        return false
      }
    }
  }
  true
}

///|
pub fn to_cnf(
  expr : BoolExpr,
  simplify? : Bool = false,
  force? : Bool = false,
) -> BoolExpr {
  if simplify {
    let vars = symbols_in(expr)
    if !force && vars.length() > 8 {
      return expr
    }
    return simplify_logic(expr, form="cnf", deep=true, force=force)
  }
  if is_cnf(expr) {
    return expr
  }
  let nnf = eliminate_implications(expr, form="cnf")
  distribute_and_over_or(nnf)
}

///|
pub fn to_dnf(
  expr : BoolExpr,
  simplify? : Bool = false,
  force? : Bool = false,
) -> BoolExpr {
  if simplify {
    let vars = symbols_in(expr)
    if !force && vars.length() > 8 {
      return expr
    }
    return simplify_logic(expr, form="dnf", deep=true, force=force)
  }
  if is_dnf(expr) {
    return expr
  }
  let nnf = eliminate_implications(expr, form="dnf")
  distribute_or_over_and(nnf)
}

///|
fn maybe_to_anf(arg : BoolExpr, deep : Bool) -> BoolExpr {
  if !deep {
    return arg
  }
  if !is_literal(arg) {
    return to_anf(arg, deep=deep)
  }
  match arg {
    BoolExpr::Not(_) => to_anf(arg, deep=deep)
    _ => arg
  }
}

///|
pub fn to_anf(expr : BoolExpr, deep? : Bool = true) -> BoolExpr {
  if is_anf(expr) {
    return expr
  }
  match expr {
    BoolExpr::True => BoolExpr::True
    BoolExpr::False => BoolExpr::False
    BoolExpr::Symbol(_) => expr
    BoolExpr::LRA(_) => expr
    BoolExpr::Not(inner) => {
      let term = maybe_to_anf(inner, deep)
      xor_keep_true([BoolExpr::True, term])
    }
    BoolExpr::And(args) => {
      if !deep {
        return expr
      }
      let mapped = args.map(a => maybe_to_anf(a, deep))
      distribute_xor_over_and(bool_and(mapped))
    }
    BoolExpr::Or(args) => {
      let terms : Array[BoolExpr] = Array::new()
      for size in 1..=args.length() {
        let combos = combinations_bool(args, size)
        for combo in combos {
          let term = bool_and(combo)
          terms.push(if deep { to_anf(term, deep=deep) } else { term })
        }
      }
      xor_keep_true(terms)
    }
    BoolExpr::Xor(args) => {
      let mapped = args.map(a => maybe_to_anf(a, deep))
      xor_keep_true(mapped)
    }
    BoolExpr::Implies(a, b) => {
      let term = bool_and([a, b])
      let args = [BoolExpr::True, a, term]
      let mapped = args.map(a0 => maybe_to_anf(a0, deep))
      xor_keep_true(mapped)
    }
    BoolExpr::Equivalent(args) => {
      let a = bool_and(args)
      let negs : Array[BoolExpr] = Array::new()
      for arg in args {
        negs.push(to_anf(bool_not(arg), deep=false))
      }
      let b = bool_and(negs)
      let b_dist = distribute_xor_over_and(b)
      let mapped = [a, b_dist].map(a0 => maybe_to_anf(a0, deep))
      xor_keep_true(mapped)
    }
    BoolExpr::ITE(c, t, e) => {
      if !deep {
        return expr
      }
      BoolExpr::ITE(
        to_anf(c, deep=deep),
        to_anf(t, deep=deep),
        to_anf(e, deep=deep),
      )
    }
  }
}

///|
pub fn is_anf(expr : BoolExpr) -> Bool {
  match expr {
    BoolExpr::True => true
    BoolExpr::False => true
    BoolExpr::Symbol(_) => true
    BoolExpr::LRA(_) => true
    BoolExpr::Not(_) => false
    BoolExpr::And(args) => {
      for arg in args {
        match arg {
          BoolExpr::Symbol(_) => ()
          BoolExpr::LRA(_) => ()
          _ => return false
        }
      }
      true
    }
    BoolExpr::Xor(args) => {
      for arg in args {
        match arg {
          BoolExpr::And(terms) => {
            for t in terms {
              match t {
                BoolExpr::Symbol(_) => ()
                BoolExpr::LRA(_) => ()
                _ => return false
              }
            }
          }
          BoolExpr::Symbol(_) => ()
          BoolExpr::LRA(_) => ()
          BoolExpr::True => ()
          BoolExpr::False => ()
          _ => return false
        }
      }
      true
    }
    _ => false
  }
}
