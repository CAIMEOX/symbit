///|
/// Symbolic roots for low-degree univariate polynomials (subset).
fn ensure_univar(poly : Poly) -> Unit raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
fn coeff_expr(poly : Poly, exp : Int) -> @symcore.Expr raise PolyError {
  let mono = monomial_one(1)
  mono.exps.set(0, exp)
  match poly.coeffs.get(mono) {
    Some(c) => field_elem_to_expr(c, poly.domain)
    None => @symcore.int(0)
  }
}

///|
pub fn roots_linear(poly : Poly) -> Array[@symcore.Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 1 {
    raise PolyError::BadExponent
  }
  let a = coeff_expr(poly, 1)
  let b = coeff_expr(poly, 0)
  let neg_b = @symcore.mul([@symcore.int(-1), b])
  let denom = a
  let inv = @symcore.pow(denom, @symcore.int(-1))
  let root = @symcore.mul([neg_b, inv])
  [root]
}

///|
pub fn roots_quadratic(poly : Poly) -> Array[@symcore.Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 2 {
    raise PolyError::BadExponent
  }
  let a = coeff_expr(poly, 2)
  let b = coeff_expr(poly, 1)
  let c = coeff_expr(poly, 0)
  let four = @symcore.int(4)
  let two = @symcore.int(2)
  let b2 = b ^ @symcore.int(2)
  let ac4 = @symcore.mul([four, a, c])
  let disc = @symcore.add([b2, @symcore.mul([@symcore.int(-1), ac4])])
  let half = try @symcore.rational_from_ints(1, 2) catch {
    _ => raise PolyError::NotImplemented("quadratic: half")
  }
  let sqrt_disc = @symcore.pow(disc, half)
  let neg_b = @symcore.mul([@symcore.int(-1), b])
  let denom = @symcore.mul([two, a])
  let inv = @symcore.pow(denom, @symcore.int(-1))
  let r1 = @symcore.mul([@symcore.add([neg_b, @symcore.mul([@symcore.int(-1), sqrt_disc])]), inv])
  let r2 = @symcore.mul([@symcore.add([neg_b, sqrt_disc]), inv])
  [r1, r2]
}

///|
fn append_roots(
  out : Array[@symcore.Expr],
  roots : Array[@symcore.Expr],
  mult : Int,
) -> Unit {
  for _ in 0..<mult {
    for r in roots {
      out.push(r)
    }
  }
}

///|
fn rootof_expr(poly : Poly, index : Int) -> @symcore.Expr {
  @symcore.function(
    "CRootOf",
    [poly.to_expr(), @symcore.int(index)],
  )
}

///|
pub fn roots_cubic(poly : Poly) -> Array[@symcore.Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 3 {
    raise PolyError::BadExponent
  }
  let (_, factors) = poly.factor_list()
  let roots : Array[@symcore.Expr] = Array::new()
  for pair in factors {
    let (f, mult) = pair
    let fdeg = f.degree(0)
    if fdeg == 1 {
      append_roots(roots, roots_linear(f), mult)
    } else if fdeg == 2 {
      append_roots(roots, roots_quadratic(f), mult)
    } else {
      let ros : Array[@symcore.Expr] = Array::new()
      for i in 0..<fdeg {
        ros.push(rootof_expr(f, i))
      }
      append_roots(roots, ros, mult)
    }
  }
  roots
}

///|
pub fn roots_quartic(poly : Poly) -> Array[@symcore.Expr] raise PolyError {
  ensure_univar(poly)
  let deg = poly.degree(0)
  if deg != 4 {
    raise PolyError::BadExponent
  }
  let (_, factors) = poly.factor_list()
  let roots : Array[@symcore.Expr] = Array::new()
  for pair in factors {
    let (f, mult) = pair
    let fdeg = f.degree(0)
    if fdeg == 1 {
      append_roots(roots, roots_linear(f), mult)
    } else if fdeg == 2 {
      append_roots(roots, roots_quadratic(f), mult)
    } else {
      let ros : Array[@symcore.Expr] = Array::new()
      for i in 0..<fdeg {
        ros.push(rootof_expr(f, i))
      }
      append_roots(roots, ros, mult)
    }
  }
  roots
}
