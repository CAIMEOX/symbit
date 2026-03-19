///|
/// Unevaluated and evaluated inner-product helpers for `Bra * Ket` pairs.
///
/// Generic `Bra`/`Ket` combinations stay symbolic, while concrete state
/// families such as qubits, bosonic Fock/coherent states, and fermionic Fock
/// states evaluate to the same closed forms that SymPy uses.

///|
fn quantum_accumulate_linear_term(
  terms : Array[(@symcore.Expr, @symnum.BigRational)],
  base : @symcore.Expr,
  coeff : @symnum.BigRational,
) -> Unit {
  for idx in 0..<terms.length() {
    if terms[idx].0 == base {
      terms[idx] = (base, terms[idx].1.add_r(coeff))
      return
    }
  }
  terms.push((base, coeff))
}

///|
fn quantum_linear_term(
  expr : @symcore.Expr,
) -> (@symcore.Expr?, @symnum.BigRational)? {
  match expr {
    @symcore.Expr::Number(n) => Some((None, n))
    @symcore.Expr::Add(_) => None
    @symcore.Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let bases : Array[@symcore.Expr] = []
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) => coeff = coeff.mul_r(n)
          _ => bases.push(arg)
        }
      }
      if bases.is_empty() {
        Some((None, coeff))
      } else {
        Some((Some(quantum_mul_from_args_preserve(bases)), coeff))
      }
    }
    _ => Some((Some(expr), @symnum.BigRational::one()))
  }
}

///|
fn quantum_collect_linear_terms(
  expr : @symcore.Expr,
) -> (Array[(@symcore.Expr, @symnum.BigRational)], @symnum.BigRational)? {
  match expr {
    @symcore.Expr::Add(args) => {
      let terms : Array[(@symcore.Expr, @symnum.BigRational)] = []
      let mut const_coeff = @symnum.BigRational::zero()
      for arg in args {
        match quantum_collect_linear_terms(arg) {
          Some((child_terms, child_const)) => {
            const_coeff = const_coeff.add_r(child_const)
            for term in child_terms {
              quantum_accumulate_linear_term(terms, term.0, term.1)
            }
          }
          None => return None
        }
      }
      Some((terms, const_coeff))
    }
    _ =>
      match quantum_linear_term(expr) {
        Some((None, coeff)) => Some(([], coeff))
        Some((Some(base), coeff)) =>
          Some(([(base, coeff)], @symnum.BigRational::zero()))
        None => None
      }
  }
}

///|
fn quantum_difference_is_zero(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> Bool? {
  match (quantum_collect_linear_terms(lhs), quantum_collect_linear_terms(rhs)) {
    (Some((lhs_terms, lhs_const)), Some((rhs_terms, rhs_const))) => {
      let terms = lhs_terms.copy()
      for term in rhs_terms {
        quantum_accumulate_linear_term(terms, term.0, term.1.neg_r())
      }
      let const_diff = lhs_const.add_r(rhs_const.neg_r())
      let nonzero_terms : Array[(@symcore.Expr, @symnum.BigRational)] = []
      for term in terms {
        if !term.1.is_zero() {
          nonzero_terms.push(term)
        }
      }
      if nonzero_terms.is_empty() {
        Some(const_diff.is_zero())
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn quantum_secondquant_tuple_args(
  expr : @symcore.Expr,
) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function(_, args) if args.length() == 1 =>
      match args[0] {
        @symcore.Expr::Function("Tuple", items) => Some(items)
        _ => None
      }
    _ => None
  }
}

///|
fn quantum_tuple_inner_product(
  lhs : Array[@symcore.Expr],
  rhs : Array[@symcore.Expr],
) -> @symcore.Expr {
  if lhs.length() != rhs.length() {
    return @symcore.int(0)
  }
  let mut out = @symcore.int(1)
  for idx in 0..<lhs.length() {
    if lhs[idx] == rhs[idx] {
      ()
    } else if lhs[idx] is @symcore.Expr::Number(_) &&
      rhs[idx] is @symcore.Expr::Number(_) {
      return @symcore.int(0)
    } else {
      out = out * @symcore.raw_function("KroneckerDelta", [lhs[idx], rhs[idx]])
    }
  }
  out
}

///|
pub fn inner_product(
  bra_expr : @symcore.Expr,
  ket_expr : @symcore.Expr,
  evaluate? : Bool = true,
) -> @symcore.Expr {
  guard quantum_is_bra_expr(bra_expr) else {
    return @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
  guard quantum_is_ket_expr(ket_expr) else {
    return @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
  if !evaluate {
    return @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
  }
  match (bra_expr, ket_expr) {
    (
      @symcore.Expr::Function("OrthogonalBra", bargs),
      @symcore.Expr::Function("OrthogonalKet", kargs),
    ) =>
      if bargs.length() != kargs.length() {
        @symcore.int(0)
      } else if bargs == kargs {
        @symcore.int(1)
      } else {
        let mut definitely_zero = false
        let mut maybe_zero = true
        for idx in 0..<bargs.length() {
          match quantum_difference_is_zero(bargs[idx], kargs[idx]) {
            Some(true) => ()
            Some(false) => {
              definitely_zero = true
              break
            }
            None => maybe_zero = false
          }
        }
        if definitely_zero {
          @symcore.int(0)
        } else if maybe_zero {
          @symcore.int(1)
        } else {
          @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
        }
      }
    (
      @symcore.Expr::Function("QubitBra", bargs),
      @symcore.Expr::Function("Qubit", kargs),
    ) => if bargs == kargs { @symcore.int(1) } else { @symcore.int(0) }
    (
      @symcore.Expr::Function("BosonFockBra", bargs),
      @symcore.Expr::Function("BosonFockKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      if bargs[0] == kargs[0] {
        @symcore.int(1)
      } else {
        @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
      }
    (
      @symcore.Expr::Function("FockStateBosonBra", _),
      @symcore.Expr::Function("FockStateBosonKet", _),
    ) =>
      match
        (
          quantum_secondquant_tuple_args(bra_expr),
          quantum_secondquant_tuple_args(ket_expr),
        ) {
        (Some(bitems), Some(kitems)) =>
          quantum_tuple_inner_product(bitems, kitems)
        _ => @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
      }
    (
      @symcore.Expr::Function("FermionFockBra", bargs),
      @symcore.Expr::Function("FermionFockKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      if bargs[0] == kargs[0] {
        @symcore.int(1)
      } else {
        @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
      }
    (
      @symcore.Expr::Function("BosonCoherentBra", bargs),
      @symcore.Expr::Function("BosonCoherentKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 => {
      let bra_alpha = bargs[0]
      let ket_alpha = kargs[0]
      if bra_alpha == ket_alpha {
        @symcore.int(1)
      } else {
        let half = try! @symcore.rational_from_ints(1, 2)
        let exponent = @symcore.int(-1) *
          half *
          (
            expr_conjugate(bra_alpha) * bra_alpha +
            expr_conjugate(ket_alpha) * ket_alpha -
            @symcore.int(2) * expr_conjugate(bra_alpha) * ket_alpha
          )
        @symcore.raw_function("exp", [exponent])
      }
    }
    (
      @symcore.Expr::Function("PIABBra", bargs),
      @symcore.Expr::Function("PIABKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
    (
      @symcore.Expr::Function("SHOBra", bargs),
      @symcore.Expr::Function("SHOKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
    (
      @symcore.Expr::Function("SigmaZBra", bargs),
      @symcore.Expr::Function("SigmaZKet", kargs),
    ) if bargs.length() == 1 && kargs.length() == 1 =>
      if bargs[0] == kargs[0] {
        @symcore.int(1)
      } else {
        @symcore.raw_function("KroneckerDelta", [bargs[0], kargs[0]])
      }
    _ =>
      match spin_inner_product(bra_expr, ket_expr) {
        Some(value) => value
        None =>
          match cartesian_inner_product(bra_expr, ket_expr) {
            Some(value) => value
            None => @symcore.raw_function("InnerProduct", [bra_expr, ket_expr])
          }
      }
  }
}

///|
pub fn inner_product_doit(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("InnerProduct", args) if args.length() == 2 =>
      inner_product(args[0], args[1])
    _ => expr
  }
}
