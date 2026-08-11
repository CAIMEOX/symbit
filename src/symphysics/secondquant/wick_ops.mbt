///|
/// Symbolic second-quantization algebra that sits on top of fermionic
/// operators/states: normal-order brackets, contractions, Wick expansion,
/// dummy-index cleanup, and permutation helpers.

///|
fn sq_is_fermion_operator(expr : Expr) -> Bool {
  sq_fermion_operator_parts(expr) is Some(_)
}

///|
fn sq_is_scalar_secondquant_factor(expr : Expr) -> Bool {
  !sq_is_fermion_operator(expr) &&
  !@symquant.quantum_is_state_expr(expr) &&
  !@symquant.quantum_expr_has_name(expr, "NO")
}

///|
fn sq_delta(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.raw_function("KroneckerDelta", [lhs, rhs])
}

///|
fn sq_dummy_above() -> Expr {
  Symbol("_a")
}

///|
fn sq_dummy_below() -> Expr {
  Symbol("_i")
}

///|
pub fn tensor_symbol(symbol : Expr) -> Expr {
  @symcore.raw_function("TensorSymbol", [symbol])
}

///|
pub fn anti_symmetric_tensor(
  symbol : Expr,
  upper : Array[Expr],
  lower : Array[Expr],
) -> Expr {
  let (upper_sorted, upper_sign, upper_invalid) = sq_sort_fermion_indices(
    upper, 0,
  )
  let (lower_sorted, lower_sign, lower_invalid) = sq_sort_fermion_indices(
    lower, 0,
  )
  if upper_invalid || lower_invalid {
    return int(0)
  }
  let base = @symcore.raw_function("AntiSymmetricTensor", [
    symbol,
    @symcore.raw_function("Tuple", upper_sorted),
    @symcore.raw_function("Tuple", lower_sorted),
  ])
  sq_sign_expr(upper_sign + lower_sign, base)
}

///|
fn sq_extract_secondquant_mul(expr : Expr) -> (Array[Expr], Array[Expr]) {
  let scalar : Array[Expr] = []
  let ops : Array[Expr] = []
  match expr {
    Mul(args) =>
      for arg in args {
        if sq_is_scalar_secondquant_factor(arg) {
          scalar.push(arg)
        } else {
          ops.push(arg)
        }
      }
    _ =>
      if sq_is_scalar_secondquant_factor(expr) {
        scalar.push(expr)
      } else {
        ops.push(expr)
      }
  }
  (scalar, ops)
}

///|
fn sq_no_mul_body(expr : Expr) -> Expr {
  match expr {
    Mul(args) => @symcore.raw_mul(args)
    _ => expr
  }
}

///|
fn sq_no_from_ops(ops : Array[Expr]) -> Expr {
  match ops.length() {
    0 => int(1)
    1 => ops[0]
    _ => @symcore.raw_function("NO", [sq_raw_mul(ops)])
  }
}

///|
pub fn no(expr : Expr) -> Expr {
  match expr {
    Add(args) => sq_raw_add(args.map(no))
    _ if @symquant.quantum_expr_has_name(expr, "NO") =>
      match @symquant.quantum_expr_args(expr) {
        Some([arg]) => no(arg)
        _ => expr
      }
    _ => {
      let (scalar, ops0) = sq_extract_secondquant_mul(expr)
      if ops0.is_empty() {
        return sq_raw_mul(scalar)
      }
      if !ops0.all(sq_is_fermion_operator) {
        return sq_raw_mul(scalar) *
          @symcore.raw_function("NO", [sq_no_mul_body(sq_raw_mul(ops0))])
      }
      let expanded : Array[Expr] = []
      for op in ops0 {
        if @symquant.quantum_expr_has_name(op, "NO") {
          match @symquant.quantum_expr_args(op) {
            Some([arg]) =>
              match arg {
                Mul(inner) =>
                  for item in inner {
                    expanded.push(item)
                  }
                _ => expanded.push(arg)
              }
            _ => expanded.push(op)
          }
        } else {
          expanded.push(op)
        }
      }
      let sorted = expanded.copy()
      let mut sign = 0
      if sorted.length() > 1 {
        let mut i = 0
        while i < sorted.length() {
          let mut j = 0
          while j + 1 < sorted.length() - i {
            let left = sorted[j]
            let right = sorted[j + 1]
            if left == right {
              return int(0)
            }
            let swap = match
              (
                sq_fermion_operator_parts(left),
                sq_fermion_operator_parts(right),
              ) {
              (Some((li, lann)), Some((ri, rann))) =>
                if lann != rann {
                  lann && !rann
                } else {
                  sq_compare_fermion_indices(li, ri, 0) > 0
                }
              _ => false
            }
            if swap {
              let tmp = sorted[j]
              sorted[j] = sorted[j + 1]
              sorted[j + 1] = tmp
              sign += 1
            }
            j += 1
          }
          i += 1
        }
      }
      sq_sign_expr(
        sign,
        sq_raw_mul([sq_raw_mul(scalar), sq_no_from_ops(sorted)]),
      )
    }
  }
}

///|
pub fn contraction(lhs : Expr, rhs : Expr) -> Expr {
  match (sq_fermion_operator_parts(lhs), sq_fermion_operator_parts(rhs)) {
    (Some((lidx, lann)), Some((ridx, rann))) =>
      if lann && !rann {
        let left_group = sq_index_group(lidx, 0)
        let right_group = sq_index_group(ridx, 0)
        if left_group == 1 || right_group == 1 {
          int(0)
        } else if left_group == 0 || right_group == 0 {
          sq_delta(lidx, ridx)
        } else {
          sq_raw_mul([sq_delta(sq_dummy_above(), ridx), sq_delta(lidx, ridx)])
        }
      } else if !lann && rann {
        let left_group = sq_index_group(lidx, 0)
        let right_group = sq_index_group(ridx, 0)
        if left_group == 0 || right_group == 0 {
          int(0)
        } else if left_group == 1 || right_group == 1 {
          sq_delta(lidx, ridx)
        } else {
          sq_raw_mul([sq_delta(sq_dummy_below(), ridx), sq_delta(lidx, ridx)])
        }
      } else {
        int(0)
      }
    _ => int(0)
  }
}

///|
fn sq_wicks_sequence(
  ops : Array[Expr],
  keep_only_fully_contracted : Bool,
) -> Expr {
  match ops.length() {
    0 => int(1)
    1 => if keep_only_fully_contracted { int(0) } else { ops[0] }
    _ => {
      let terms : Array[Expr] = []
      if !keep_only_fully_contracted {
        terms.push(no(sq_raw_mul(ops)))
      }
      let first = ops[0]
      for j in 1..<ops.length() {
        let c = contraction(first, ops[j])
        if c != int(0) {
          let remaining : Array[Expr] = []
          for idx in 1..<ops.length() {
            if idx != j {
              remaining.push(ops[idx])
            }
          }
          let tail = sq_wicks_sequence(remaining, keep_only_fully_contracted)
          if tail != int(0) {
            let sign = if (j - 1) % 2 == 0 { int(1) } else { int(-1) }
            terms.push(sq_raw_mul([sign, c, tail]))
          }
        }
      }
      sq_raw_add(terms)
    }
  }
}

///|
fn sq_collect_symbol_counts(expr : Expr, counts : Map[String, Int]) -> Unit {
  match expr {
    Symbol(name) => counts.set(name, counts.get(name).unwrap_or(0) + 1)
    Add(args) | Mul(args) =>
      for arg in args {
        sq_collect_symbol_counts(arg, counts)
      }
    Pow(base, exp) => {
      sq_collect_symbol_counts(base, counts)
      sq_collect_symbol_counts(exp, counts)
    }
    _ =>
      match @symcore.application_args(expr) {
        Some(args) =>
          for arg in args {
            sq_collect_symbol_counts(arg, counts)
          }
        None => ()
      }
  }
}

///|
fn sq_preferred_index(lhs : Expr, rhs : Expr) -> Expr {
  let lg = sq_index_group(lhs, 0)
  let rg = sq_index_group(rhs, 0)
  if lg < rg {
    lhs
  } else if rg < lg {
    rhs
  } else if sq_expr_text(lhs) <= sq_expr_text(rhs) {
    lhs
  } else {
    rhs
  }
}

///|
fn sq_subst_one(expr : Expr, name : String, value : Expr) -> Expr {
  let env : Map[String, Expr] = Map([])
  env.set(name, value)
  @symcore.subst(expr, env)
}

///|
pub fn evaluate_deltas(expr : Expr) -> Expr {
  match expr {
    Add(args) => sq_raw_add(args.map(evaluate_deltas))
    Mul(args) => {
      let counts : Map[String, Int] = Map([])
      for arg in args {
        sq_collect_symbol_counts(arg, counts)
      }
      let mut out = sq_raw_mul(args)
      for arg in args {
        match @symquant.quantum_expr_args(arg) {
          Some(dargs) if @symquant.quantum_expr_has_name(arg, "KroneckerDelta") &&
            dargs.length() == 2 =>
            match (dargs[0], dargs[1]) {
              (Symbol(lhs), Symbol(rhs)) => {
                let preferred = sq_preferred_index(dargs[0], dargs[1])
                let killable = if preferred == dargs[0] { rhs } else { lhs }
                if counts.get(killable).unwrap_or(0) > 1 {
                  out = sq_subst_one(out, killable, preferred)
                }
              }
              _ => ()
            }
          _ => ()
        }
      }
      out
    }
    _ => expr
  }
}

///|
fn sq_term_scalar_and_body(expr : Expr) -> (Expr, Expr) {
  match expr {
    Mul(args) => {
      let scalar : Array[Expr] = []
      let body : Array[Expr] = []
      for arg in args {
        match arg {
          Number(_) => scalar.push(arg)
          _ => body.push(arg)
        }
      }
      (sq_raw_mul(scalar), sq_raw_mul(body))
    }
    Number(_) => (expr, int(1))
    _ => (int(1), expr)
  }
}

///|
fn sq_collect_symbols_by_group(
  expr : Expr,
  above : Array[String],
  below : Array[String],
  general : Array[String],
) -> Unit {
  match expr {
    Symbol(name) =>
      if !name.has_prefix("_") {
        match sq_index_group(expr, 0) {
          0 => if !above.contains(name) { above.push(name) }
          1 => if !below.contains(name) { below.push(name) }
          _ => if !general.contains(name) { general.push(name) }
        }
      }
    Add(args) | Mul(args) =>
      for arg in args {
        sq_collect_symbols_by_group(arg, above, below, general)
      }
    Pow(base, exp) => {
      sq_collect_symbols_by_group(base, above, below, general)
      sq_collect_symbols_by_group(exp, above, below, general)
    }
    _ =>
      match @symcore.application_args(expr) {
        Some(args) =>
          for arg in args {
            sq_collect_symbols_by_group(arg, above, below, general)
          }
        None => ()
      }
  }
}

///|
fn sq_term_normalization_env(
  expr : Expr,
  new_indices : Bool,
  pretty_indices : Map[String, String],
) -> Map[String, Expr] {
  let above : Array[String] = []
  let below : Array[String] = []
  let general : Array[String] = []
  sq_collect_symbols_by_group(expr, above, below, general)
  above.sort()
  below.sort()
  general.sort()
  let env : Map[String, Expr] = Map([])
  let above_letters = pretty_indices.get("above").unwrap_or("ab")
  let below_letters = pretty_indices.get("below").unwrap_or("ij")
  let general_letters = pretty_indices.get("general").unwrap_or("pq")
  for idx in 0..<above.length() {
    let name = if new_indices && idx < above_letters.length() {
      "_" + above_letters[idx:idx + 1].to_owned()
    } else {
      "_" + "a_\{idx}"
    }
    env.set(above[idx], Symbol(name))
  }
  for idx in 0..<below.length() {
    let name = if new_indices && idx < below_letters.length() {
      "_" + below_letters[idx:idx + 1].to_owned()
    } else {
      "_" + "i_\{idx}"
    }
    env.set(below[idx], Symbol(name))
  }
  for idx in 0..<general.length() {
    let name = if new_indices && idx < general_letters.length() {
      "_" + general_letters[idx:idx + 1].to_owned()
    } else {
      "_" + "p_\{idx}"
    }
    env.set(general[idx], Symbol(name))
  }
  env
}

///|
pub fn substitute_dummies(
  expr : Expr,
  new_indices? : Bool = false,
  pretty_indices? : Map[String, String] = {},
) -> Expr {
  match expr {
    Add(args) => {
      let terms : Map[String, (Expr, Expr)] = Map([])
      for arg in args {
        let env = sq_term_normalization_env(arg, new_indices, pretty_indices)
        let normalized = @symcore.subst(arg, env)
        let (scalar, body) = sq_term_scalar_and_body(normalized)
        let key = sq_expr_text(body)
        match terms.get(key) {
          Some((prev_scalar, prev_body)) =>
            terms.set(key, (prev_scalar + scalar, prev_body))
          None => terms.set(key, (scalar, body))
        }
      }
      let rebuilt : Array[Expr] = []
      for entry in terms.values() {
        rebuilt.push(sq_raw_mul([entry.0, entry.1]))
      }
      sq_raw_add(rebuilt)
    }
    _ =>
      @symcore.subst(
        expr,
        sq_term_normalization_env(expr, new_indices, pretty_indices),
      )
  }
}

///|
pub fn wicks(
  expr : Expr,
  simplify_kronecker_deltas? : Bool = false,
  expand? : Bool = true,
  simplify_dummies? : Bool = false,
  keep_only_fully_contracted? : Bool = false,
) -> Expr {
  ignore(expand)
  if expr == int(0) {
    return int(0)
  }
  match expr {
    _ if @symquant.quantum_expr_has_any_name(expr, [
        "NO", "AnnihilateFermion", "CreateFermion",
      ]) => if keep_only_fully_contracted { int(0) } else { expr }
    Add(args) => {
      let summed = sq_raw_add(
        args.map(term => {
          wicks(
            term,
            simplify_kronecker_deltas~,
            expand~,
            simplify_dummies~,
            keep_only_fully_contracted~,
          )
        }),
      )
      if simplify_dummies {
        substitute_dummies(summed)
      } else {
        summed
      }
    }
    Mul(args) => {
      for idx in 0..<args.length() {
        match args[idx] {
          Add(inner) => {
            let expanded : Array[Expr] = []
            for term in inner {
              let rebuilt = args.copy()
              rebuilt[idx] = term
              expanded.push(
                wicks(
                  sq_raw_mul(rebuilt),
                  simplify_kronecker_deltas~,
                  expand~,
                  simplify_dummies~,
                  keep_only_fully_contracted~,
                ),
              )
            }
            return sq_raw_add(expanded)
          }
          _ => ()
        }
      }
      let (scalar, ops) = sq_extract_secondquant_mul(expr)
      let result = if ops.all(sq_is_fermion_operator) {
        sq_raw_mul([
          sq_raw_mul(scalar),
          sq_wicks_sequence(ops, keep_only_fully_contracted),
        ])
      } else {
        expr
      }
      let delta_done = if simplify_kronecker_deltas {
        evaluate_deltas(result)
      } else {
        result
      }
      if simplify_dummies {
        substitute_dummies(delta_done)
      } else {
        delta_done
      }
    }
    _ => expr
  }
}

///|
pub fn permutation_operator(lhs : Expr, rhs : Expr) -> Expr {
  if @symcore.compare_expr(lhs, rhs) <= 0 {
    @symcore.raw_function("PermutationOperator", [lhs, rhs])
  } else {
    @symcore.raw_function("PermutationOperator", [rhs, lhs])
  }
}

///|
fn sq_swap_indices(expr : Expr, lhs : String, rhs : String) -> Expr {
  let tmp = "__perm_tmp__"
  sq_subst_one(
    sq_subst_one(sq_subst_one(expr, lhs, Symbol(tmp)), rhs, Symbol(lhs)),
    tmp,
    Symbol(rhs),
  )
}

///|
fn sq_permuted_term(perm : Expr, expr : Expr) -> Expr? {
  if @symquant.quantum_expr_has_name(perm, "PermutationOperator") {
    match @symquant.quantum_expr_args(perm) {
      Some([Symbol(lhs), Symbol(rhs)]) =>
        Some(int(-1) * sq_swap_indices(expr, lhs, rhs))
      _ => None
    }
  } else {
    None
  }
}

///|
pub fn simplify_index_permutations(
  expr : Expr,
  permutation_operators : Array[Expr],
) -> Expr {
  match expr {
    Add(args) => {
      let mut terms = args.copy()
      for perm in permutation_operators {
        let next_terms : Array[Expr] = []
        let used : Array[Int] = []
        for i in 0..<terms.length() {
          if used.contains(i) {
            continue
          }
          let term = terms[i]
          let mut matched = false
          match sq_permuted_term(perm, term) {
            Some(permuted) => {
              let mut j = i + 1
              while j < terms.length() {
                if !used.contains(j) && terms[j] == permuted {
                  used.push(j)
                  matched = true
                  let keep = if sq_expr_text(term) <= sq_expr_text(permuted) {
                    term
                  } else {
                    permuted
                  }
                  next_terms.push(sq_raw_mul([keep, perm]))
                  break
                }
                j += 1
              }
            }
            None => ()
          }
          if !matched {
            next_terms.push(term)
          }
        }
        terms = next_terms
      }
      sq_raw_add(terms)
    }
    _ => expr
  }
}
