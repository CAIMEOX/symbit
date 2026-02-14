///|
pub fn sub_pre(expr : @symcore.Expr) -> @symcore.Expr {
  rewrite_bottom_up_cseopts(expr, rewrite_sub_pre)
}

///|
pub fn sub_post(expr : @symcore.Expr) -> @symcore.Expr {
  rewrite_bottom_up_cseopts(expr, rewrite_sub_post)
}

///|
fn rewrite_bottom_up_cseopts(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
) -> @symcore.Expr {
  let rewritten = @symcore.map_children(
    expr,
    child => rewrite_bottom_up_cseopts(child, rule),
  )
  rule(rewritten)
}

///|
fn rewrite_sub_pre(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add([a, b]) => {
      let (sa, pa) = split_sign(a)
      let (sb, pb) = split_sign(b)
      if sa < 0 && sb > 0 {
        @symcore.mul([
          @symcore.int(-1),
          @symcore.add([pa, @symcore.mul([@symcore.int(-1), pb])]),
        ])
      } else if sb < 0 && sa > 0 {
        @symcore.mul([
          @symcore.int(-1),
          @symcore.add([pb, @symcore.mul([@symcore.int(-1), pa])]),
        ])
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_sub_post(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Mul(args) => {
      if args.length() < 2 {
        return expr
      }
      let filtered : Array[@symcore.Expr] = Array::new()
      let mut neg_count = 0
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) if n.is_one() => ()
          @symcore.Expr::Number(n) if n.compare(@symnum.BigRational::from_int(-1)) == 0 =>
            neg_count = neg_count + 1
          _ => filtered.push(arg)
        }
      }
      let out = @symcore.mul(filtered)
      if neg_count % 2 == 1 {
        @symcore.mul([@symcore.int(-1), out])
      } else {
        out
      }
    }
    _ => expr
  }
}

///|
fn split_sign(expr : @symcore.Expr) -> (Int, @symcore.Expr) {
  match expr {
    @symcore.Expr::Number(n) =>
      if n.compare(@symnum.BigRational::zero()) < 0 {
        (-1, @symcore.number(n.neg_r()))
      } else {
        (1, expr)
      }
    @symcore.Expr::Mul(args) => {
      let mut sign = 1
      let factors : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) if n.compare(@symnum.BigRational::zero()) < 0 => {
            sign = -sign
            factors.push(@symcore.number(n.neg_r()))
          }
          _ => factors.push(arg)
        }
      }
      (sign, @symcore.mul(factors))
    }
    _ => (1, expr)
  }
}
