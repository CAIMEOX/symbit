///|
/// Symbolic second-quantization algebra that sits on top of fermionic
/// operators/states: normal-order brackets, contractions, Wick expansion,
/// dummy-index cleanup, and permutation helpers.

///|
fn sq_is_fermion_operator(expr : @symcore.Expr) -> Bool {
  sq_fermion_operator_parts(expr) is Some(_)
}

///|
fn sq_is_scalar_secondquant_factor(expr : @symcore.Expr) -> Bool {
  !sq_is_fermion_operator(expr) &&
  !@symquant.quantum_is_state_expr(expr) &&
  !@symquant.quantum_expr_has_name(expr, "NO")
}

///|
fn sq_delta(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("KroneckerDelta", [lhs, rhs])
}

///|
fn sq_dummy_above() -> @symcore.Expr {
  @symcore.symbol("_a")
}

///|
fn sq_dummy_below() -> @symcore.Expr {
  @symcore.symbol("_i")
}

///|
pub fn tensor_symbol(symbol : @symcore.Expr) -> @symcore.Expr {
  @symcore.raw_function("TensorSymbol", [symbol])
}

///|
pub fn anti_symmetric_tensor(
  symbol : @symcore.Expr,
  upper : Array[@symcore.Expr],
  lower : Array[@symcore.Expr],
) -> @symcore.Expr {
  let (upper_sorted, upper_sign, upper_invalid) = sq_sort_fermion_indices(
    upper, 0,
  )
  let (lower_sorted, lower_sign, lower_invalid) = sq_sort_fermion_indices(
    lower, 0,
  )
  if upper_invalid || lower_invalid {
    return @symcore.int(0)
  }
  let base = @symcore.raw_function("AntiSymmetricTensor", [
    symbol,
    @symcore.raw_function("Tuple", upper_sorted),
    @symcore.raw_function("Tuple", lower_sorted),
  ])
  sq_sign_expr(upper_sign + lower_sign, base)
}

///|
fn sq_extract_secondquant_mul(
  expr : @symcore.Expr,
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) {
  let scalar : Array[@symcore.Expr] = []
  let ops : Array[@symcore.Expr] = []
  match expr {
    @symcore.Expr::Mul(args) =>
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
fn sq_no_mul_body(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Mul(args) => @symcore.raw_mul(args)
    _ => expr
  }
}

///|
fn sq_no_from_ops(ops : Array[@symcore.Expr]) -> @symcore.Expr {
  match ops.length() {
    0 => @symcore.int(1)
    1 => ops[0]
    _ => @symcore.raw_function("NO", [sq_raw_mul(ops)])
  }
}

///|
pub fn no(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => sq_raw_add(args.map(no))
    @symcore.Expr::Function("NO", args) if args.length() == 1 => no(args[0])
    _ => {
      let (scalar, ops0) = sq_extract_secondquant_mul(expr)
      if ops0.is_empty() {
        return sq_raw_mul(scalar)
      }
      if !ops0.all(sq_is_fermion_operator) {
        return sq_raw_mul(scalar) *
          @symcore.raw_function("NO", [sq_no_mul_body(sq_raw_mul(ops0))])
      }
      let expanded : Array[@symcore.Expr] = []
      for op in ops0 {
        match op {
          @symcore.Expr::Function("NO", args) if args.length() == 1 =>
            match args[0] {
              @symcore.Expr::Mul(inner) =>
                for item in inner {
                  expanded.push(item)
                }
              _ => expanded.push(args[0])
            }
          _ => expanded.push(op)
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
              return @symcore.int(0)
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
pub fn contraction(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  match (sq_fermion_operator_parts(lhs), sq_fermion_operator_parts(rhs)) {
    (Some((lidx, lann)), Some((ridx, rann))) =>
      if lann && !rann {
        let left_group = sq_index_group(lidx, 0)
        let right_group = sq_index_group(ridx, 0)
        if left_group == 1 || right_group == 1 {
          @symcore.int(0)
        } else if left_group == 0 || right_group == 0 {
          sq_delta(lidx, ridx)
        } else {
          sq_raw_mul([sq_delta(sq_dummy_above(), ridx), sq_delta(lidx, ridx)])
        }
      } else if !lann && rann {
        let left_group = sq_index_group(lidx, 0)
        let right_group = sq_index_group(ridx, 0)
        if left_group == 0 || right_group == 0 {
          @symcore.int(0)
        } else if left_group == 1 || right_group == 1 {
          sq_delta(lidx, ridx)
        } else {
          sq_raw_mul([sq_delta(sq_dummy_below(), ridx), sq_delta(lidx, ridx)])
        }
      } else {
        @symcore.int(0)
      }
    _ => @symcore.int(0)
  }
}

///|
fn sq_wicks_sequence(
  ops : Array[@symcore.Expr],
  keep_only_fully_contracted : Bool,
) -> @symcore.Expr {
  match ops.length() {
    0 => @symcore.int(1)
    1 => if keep_only_fully_contracted { @symcore.int(0) } else { ops[0] }
    _ => {
      let terms : Array[@symcore.Expr] = []
      if !keep_only_fully_contracted {
        terms.push(no(sq_raw_mul(ops)))
      }
      let first = ops[0]
      for j in 1..<ops.length() {
        let c = contraction(first, ops[j])
        if c != @symcore.int(0) {
          let remaining : Array[@symcore.Expr] = []
          for idx in 1..<ops.length() {
            if idx != j {
              remaining.push(ops[idx])
            }
          }
          let tail = sq_wicks_sequence(remaining, keep_only_fully_contracted)
          if tail != @symcore.int(0) {
            let sign = if (j - 1) % 2 == 0 {
              @symcore.int(1)
            } else {
              @symcore.int(-1)
            }
            terms.push(sq_raw_mul([sign, c, tail]))
          }
        }
      }
      sq_raw_add(terms)
    }
  }
}

///|
fn sq_collect_symbol_counts(
  expr : @symcore.Expr,
  counts : Map[String, Int],
) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) =>
      counts.set(name, counts.get(name).unwrap_or(0) + 1)
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      for arg in args {
        sq_collect_symbol_counts(arg, counts)
      }
    @symcore.Expr::Pow(base, exp) => {
      sq_collect_symbol_counts(base, counts)
      sq_collect_symbol_counts(exp, counts)
    }
    _ => ()
  }
}

///|
fn sq_preferred_index(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
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
fn sq_subst_one(
  expr : @symcore.Expr,
  name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env.set(name, value)
  @symcore.subst(expr, env)
}

///|
pub fn evaluate_deltas(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => sq_raw_add(args.map(evaluate_deltas))
    @symcore.Expr::Mul(args) => {
      let counts : Map[String, Int] = {}
      for arg in args {
        sq_collect_symbol_counts(arg, counts)
      }
      let mut out = sq_raw_mul(args)
      for arg in args {
        match arg {
          @symcore.Expr::Function("KroneckerDelta", dargs) if dargs.length() ==
            2 =>
            match (dargs[0], dargs[1]) {
              (@symcore.Expr::Symbol(lhs), @symcore.Expr::Symbol(rhs)) => {
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
fn sq_term_scalar_and_body(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) {
  match expr {
    @symcore.Expr::Mul(args) => {
      let scalar : Array[@symcore.Expr] = []
      let body : Array[@symcore.Expr] = []
      for arg in args {
        match arg {
          @symcore.Expr::Number(_) => scalar.push(arg)
          _ => body.push(arg)
        }
      }
      (sq_raw_mul(scalar), sq_raw_mul(body))
    }
    @symcore.Expr::Number(_) => (expr, @symcore.int(1))
    _ => (@symcore.int(1), expr)
  }
}

///|
fn sq_collect_symbols_by_group(
  expr : @symcore.Expr,
  above : Array[String],
  below : Array[String],
  general : Array[String],
) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) =>
      if !name.has_prefix("_") {
        match sq_index_group(expr, 0) {
          0 => if !above.contains(name) { above.push(name) }
          1 => if !below.contains(name) { below.push(name) }
          _ => if !general.contains(name) { general.push(name) }
        }
      }
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      for arg in args {
        sq_collect_symbols_by_group(arg, above, below, general)
      }
    @symcore.Expr::Pow(base, exp) => {
      sq_collect_symbols_by_group(base, above, below, general)
      sq_collect_symbols_by_group(exp, above, below, general)
    }
    _ => ()
  }
}

///|
fn sq_term_normalization_env(
  expr : @symcore.Expr,
  new_indices : Bool,
  pretty_indices : Map[String, String],
) -> Map[String, @symcore.Expr] {
  let above : Array[String] = []
  let below : Array[String] = []
  let general : Array[String] = []
  sq_collect_symbols_by_group(expr, above, below, general)
  above.sort()
  below.sort()
  general.sort()
  let env : Map[String, @symcore.Expr] = {}
  let above_letters = pretty_indices.get("above").unwrap_or("ab")
  let below_letters = pretty_indices.get("below").unwrap_or("ij")
  let general_letters = pretty_indices.get("general").unwrap_or("pq")
  for idx in 0..<above.length() {
    let name = if new_indices && idx < above_letters.length() {
      "_" + above_letters[idx:idx + 1].to_string()
    } else {
      "_" + "a_\{idx}"
    }
    env.set(above[idx], @symcore.symbol(name))
  }
  for idx in 0..<below.length() {
    let name = if new_indices && idx < below_letters.length() {
      "_" + below_letters[idx:idx + 1].to_string()
    } else {
      "_" + "i_\{idx}"
    }
    env.set(below[idx], @symcore.symbol(name))
  }
  for idx in 0..<general.length() {
    let name = if new_indices && idx < general_letters.length() {
      "_" + general_letters[idx:idx + 1].to_string()
    } else {
      "_" + "p_\{idx}"
    }
    env.set(general[idx], @symcore.symbol(name))
  }
  env
}

///|
pub fn substitute_dummies(
  expr : @symcore.Expr,
  new_indices? : Bool = false,
  pretty_indices? : Map[String, String] = {},
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let terms : Map[String, (@symcore.Expr, @symcore.Expr)] = {}
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
      let rebuilt : Array[@symcore.Expr] = []
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
  expr : @symcore.Expr,
  simplify_kronecker_deltas? : Bool = false,
  expand? : Bool = true,
  simplify_dummies? : Bool = false,
  keep_only_fully_contracted? : Bool = false,
) -> @symcore.Expr {
  ignore(expand)
  if expr == @symcore.int(0) {
    return @symcore.int(0)
  }
  match expr {
    @symcore.Expr::Function("NO", _)
    | @symcore.Expr::Function("AnnihilateFermion", _)
    | @symcore.Expr::Function("CreateFermion", _) =>
      if keep_only_fully_contracted {
        @symcore.int(0)
      } else {
        expr
      }
    @symcore.Expr::Add(args) => {
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
    @symcore.Expr::Mul(args) => {
      for idx in 0..<args.length() {
        match args[idx] {
          @symcore.Expr::Add(inner) => {
            let expanded : Array[@symcore.Expr] = []
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
pub fn permutation_operator(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  if @symcore.compare_expr(lhs, rhs) <= 0 {
    @symcore.raw_function("PermutationOperator", [lhs, rhs])
  } else {
    @symcore.raw_function("PermutationOperator", [rhs, lhs])
  }
}

///|
fn sq_swap_indices(
  expr : @symcore.Expr,
  lhs : String,
  rhs : String,
) -> @symcore.Expr {
  let tmp = "__perm_tmp__"
  sq_subst_one(
    sq_subst_one(
      sq_subst_one(expr, lhs, @symcore.symbol(tmp)),
      rhs,
      @symcore.symbol(lhs),
    ),
    tmp,
    @symcore.symbol(rhs),
  )
}

///|
fn sq_permuted_term(
  perm : @symcore.Expr,
  expr : @symcore.Expr,
) -> @symcore.Expr? {
  match perm {
    @symcore.Expr::Function("PermutationOperator", args) if args.length() == 2 =>
      match (args[0], args[1]) {
        (@symcore.Expr::Symbol(lhs), @symcore.Expr::Symbol(rhs)) =>
          Some(@symcore.int(-1) * sq_swap_indices(expr, lhs, rhs))
        _ => None
      }
    _ => None
  }
}

///|
pub fn simplify_index_permutations(
  expr : @symcore.Expr,
  permutation_operators : Array[@symcore.Expr],
) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => {
      let mut terms = args.copy()
      for perm in permutation_operators {
        let next_terms : Array[@symcore.Expr] = []
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
