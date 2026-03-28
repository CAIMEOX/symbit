///|
fn evalf_default_prec(prec : Int) -> Int {
  if prec > 0 {
    prec
  } else {
    53
  }
}

///|
fn float_from_exact_evalf(value : @symnum.BigRational, prec : Int) -> Float {
  Float::from_rational(value.numerator(), value.denominator(), prec) catch {
    _ => Float::from_mpf(@symnum.fnan, prec~)
  }
}

///|
fn complex_from_exact_evalf(
  real : @symnum.BigRational,
  imag : @symnum.BigRational,
  prec : Int,
) -> ComplexFloat {
  ComplexFloat::from_exact_parts(real, imag, prec~)
}

///|
fn promote_float_evalf(value : Float, prec : Int) -> Float {
  if value.precision() >= prec {
    value
  } else {
    Float::from_mpf(
      @symnum.mpf_pos(value.to_mpf(), prec, @symnum.round_nearest),
      prec~,
    )
  }
}

///|
fn promote_complex_evalf(value : ComplexFloat, prec : Int) -> ComplexFloat {
  if value.precision() >= prec {
    value
  } else {
    ComplexFloat::from_parts(
      @symnum.mpf_pos(value.to_mpc().real, prec, @symnum.round_nearest),
      @symnum.mpf_pos(value.to_mpc().imag, prec, @symnum.round_nearest),
      prec~,
    )
  }
}

///|
fn complex_imag_unit(prec : Int) -> ComplexFloat {
  ComplexFloat::from_parts(@symnum.fzero, @symnum.fone, prec~)
}

///|
fn expr_from_mpf_evalf(value : @symnum.Mpf, prec : Int) -> Expr {
  Expr::Float(Float::from_mpf(value, prec~))
}

///|
fn expr_from_mpc_evalf(value : @symnum.Mpc, prec : Int) -> Expr {
  if @symnum.is_zero(value.imag) {
    expr_from_mpf_evalf(
      @symnum.mpf_pos(value.real, prec, @symnum.round_nearest),
      prec,
    )
  } else {
    Expr::ComplexFloat(ComplexFloat::from_mpc(value, prec~))
  }
}

///|
fn expr_to_evalf_float(expr : Expr, prec : Int) -> Float? {
  match expr {
    Expr::Number(n) => Some(float_from_exact_evalf(n, prec))
    Expr::Float(f) => Some(promote_float_evalf(f, prec))
    Expr::ComplexFloat(z) =>
      if @symnum.is_zero(z.to_mpc().imag) {
        Some(promote_float_evalf(z.real_part(), prec))
      } else {
        None
      }
    Expr::NumberSymbol(kind) => evalf_number_symbol_constant(kind, prec)
    Expr::Boolean(_) => None
    Expr::Dummy(_, _) | Expr::Wild(_) => None
    Expr::FunctionHead(_) => None
    Expr::UndefinedFunction(_) => None
    Expr::Apply(_, _)
    | Expr::Add(_)
    | Expr::Mul(_)
    | Expr::Pow(_, _)
    | Expr::Mod(_, _) =>
      match expr_to_evalf_complex(expr, prec) {
        Some(value) =>
          if @symnum.is_zero(value.to_mpc().imag) {
            Some(promote_float_evalf(value.real_part(), prec))
          } else {
            None
          }
        None => None
      }
    Expr::Symbol(name) => evalf_symbol_constant(name, prec)
    _ => None
  }
}

///|
fn expr_to_evalf_complex(expr : Expr, prec : Int) -> ComplexFloat? {
  match expr {
    Expr::Number(n) =>
      Some(complex_from_exact_evalf(n, @symnum.BigRational::zero(), prec))
    Expr::Float(f) =>
      Some(ComplexFloat::from_real(promote_float_evalf(f, prec)))
    Expr::ComplexFloat(z) => Some(promote_complex_evalf(z, prec))
    Expr::NumberSymbol(kind) =>
      match kind {
        NumberSymbolKind::ImaginaryUnit => Some(complex_imag_unit(prec))
        _ =>
          match evalf_number_symbol_constant(kind, prec) {
            Some(value) => Some(ComplexFloat::from_real(value))
            None => None
          }
      }
    Expr::Boolean(_) => None
    Expr::Dummy(_, _) | Expr::Wild(_) => None
    Expr::FunctionHead(_) => None
    Expr::UndefinedFunction(_) => None
    Expr::Apply(head, args) =>
      match head {
        Expr::FunctionHead(name) => {
          let eval_args : Array[Expr] = []
          for arg in args {
            match expr_to_evalf_complex(arg, prec) {
              Some(value) =>
                eval_args.push(expr_from_mpc_evalf(value.to_mpc(), prec))
              None => return None
            }
          }
          match evalf_nary_function(name, eval_args, prec) {
            Some(value) => expr_to_evalf_complex(value, prec)
            None => None
          }
        }
        _ => None
      }
    Expr::Add(args) => {
      let mut acc = ComplexFloat::from_exact_parts(
        @symnum.BigRational::zero(),
        @symnum.BigRational::zero(),
        prec~,
      )
      for arg in args {
        let value = match expr_to_evalf_complex(arg, prec) {
          Some(z) => z
          None => return None
        }
        acc = ComplexFloat::from_mpc(
          @symnum.mpc_add(
            acc.to_mpc(),
            value.to_mpc(),
            prec,
            @symnum.round_nearest,
          ),
          prec~,
        )
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = ComplexFloat::from_exact_parts(
        @symnum.BigRational::one(),
        @symnum.BigRational::zero(),
        prec~,
      )
      for arg in args {
        let value = match expr_to_evalf_complex(arg, prec) {
          Some(z) => z
          None => return None
        }
        acc = ComplexFloat::from_mpc(
          @symnum.mpc_mul(
            acc.to_mpc(),
            value.to_mpc(),
            prec,
            @symnum.round_nearest,
          ),
          prec~,
        )
      }
      Some(acc)
    }
    Expr::Pow(base, exp) => {
      let base_z = match expr_to_evalf_complex(base, prec) {
        Some(value) => value
        None => return None
      }
      let exp_z = match expr_to_evalf_complex(exp, prec) {
        Some(value) => value
        None => return None
      }
      let value = match evalf_integer_exponent(exp, prec) {
        Some(n) =>
          @symnum.mpc_pow_int(base_z.to_mpc(), n, prec, @symnum.round_nearest)
        None =>
          @symnum.mpc_pow(
            base_z.to_mpc(),
            exp_z.to_mpc(),
            prec,
            @symnum.round_nearest,
          ) catch {
            _ => return None
          }
      }
      Some(ComplexFloat::from_mpc(value, prec~))
    }
    Expr::Mod(lhs, rhs) =>
      match evalf_impl(Expr::Mod(lhs, rhs), prec) {
        Expr::Float(value) => Some(ComplexFloat::from_real(value))
        Expr::ComplexFloat(value) => Some(value)
        Expr::Number(value) =>
          Some(
            complex_from_exact_evalf(value, @symnum.BigRational::zero(), prec),
          )
        _ => None
      }
    Expr::Symbol(name) =>
      if name == "I" {
        Some(complex_imag_unit(prec))
      } else {
        match evalf_symbol_constant(name, prec) {
          Some(value) => Some(ComplexFloat::from_real(value))
          None => None
        }
      }
    _ => None
  }
}

///|
fn fixed_constant_to_float(
  maker : (Int) -> BigInt raise @symnum.MpfError,
  prec : Int,
) -> Float? {
  let man = maker(prec) catch { _ => return None }
  Some(
    Float::from_mpf(
      @symnum.from_man_exp(man, -prec, prec~, rnd=@symnum.round_nearest),
      prec~,
    ),
  )
}

///|
fn evalf_symbol_constant(name : String, prec : Int) -> Float? {
  match number_symbol_kind_from_name(name) {
    Some(kind) => evalf_number_symbol_constant(kind, prec)
    None => None
  }
}

///|
fn evalf_number_symbol_constant(kind : NumberSymbolKind, prec : Int) -> Float? {
  match kind {
    NumberSymbolKind::Pi =>
      Some(Float::from_mpf(@symnum.mpf_pi(prec, @symnum.round_nearest), prec~))
    NumberSymbolKind::Exp1 =>
      Some(Float::from_mpf(@symnum.mpf_e(prec, @symnum.round_nearest), prec~))
    NumberSymbolKind::EulerGamma =>
      fixed_constant_to_float(@symnum.euler_fixed, prec)
    NumberSymbolKind::GoldenRatio =>
      fixed_constant_to_float(@symnum.phi_fixed, prec)
    NumberSymbolKind::Catalan =>
      fixed_constant_to_float(@symnum.catalan_fixed, prec)
    _ => None
  }
}

///|
fn evalf_integer_exponent(expr : Expr, prec : Int) -> Int? {
  let exp_f = match expr_to_evalf_float(expr, prec) {
    Some(value) => value
    None => return None
  }
  let pair_res : Result[(BigInt, BigInt), @symnum.MpfError] = try? exp_f.to_rational()
  match pair_res {
    Ok((num, den)) if den == 1N && num.bit_length() <= 30 => Some(num.to_int())
    _ => None
  }
}

///|
fn evalf_numeric_pow_expr(base : Expr, exp : Expr, prec : Int) -> Expr? {
  let base_f = expr_to_evalf_float(base, prec)
  let exp_f = expr_to_evalf_float(exp, prec)
  match (base_f, exp_f) {
    (Some(base_value), Some(exp_value)) => {
      let exp_pair_res : Result[(BigInt, BigInt), @symnum.MpfError] = try? exp_value.to_rational()
      let value = match exp_pair_res {
        Ok((num, den)) if den == 1N && num.bit_length() <= 30 =>
          @symnum.mpf_pow_int(
            base_value.to_mpf(),
            num.to_int(),
            prec,
            @symnum.round_nearest,
          ) catch {
            _ => return None
          }
        Ok((num, den)) if num == 1N && den == 2N =>
          @symnum.mpf_sqrt(base_value.to_mpf(), prec, @symnum.round_nearest) catch {
            _ => {
              let base_z = match expr_to_evalf_complex(base, prec) {
                Some(value) => value
                None => return None
              }
              let exp_z = match expr_to_evalf_complex(exp, prec) {
                Some(value) => value
                None => return None
              }
              let pow_value = @symnum.mpc_pow(
                base_z.to_mpc(),
                exp_z.to_mpc(),
                prec,
                @symnum.round_nearest,
              ) catch {
                _ => return None
              }
              return Some(expr_from_mpc_evalf(pow_value, prec))
            }
          }
        Ok((num, den)) if num == -1N && den == 2N => {
          let root = @symnum.mpf_sqrt(
            base_value.to_mpf(),
            prec,
            @symnum.round_nearest,
          ) catch {
            _ => {
              let base_z = match expr_to_evalf_complex(base, prec) {
                Some(value) => value
                None => return None
              }
              let exp_z = match expr_to_evalf_complex(exp, prec) {
                Some(value) => value
                None => return None
              }
              let pow_value = @symnum.mpc_pow(
                base_z.to_mpc(),
                exp_z.to_mpc(),
                prec,
                @symnum.round_nearest,
              ) catch {
                _ => return None
              }
              return Some(expr_from_mpc_evalf(pow_value, prec))
            }
          }
          @symnum.mpf_div(@symnum.fone, root, prec, @symnum.round_nearest) catch {
            _ => return None
          }
        }
        _ =>
          @symnum.mpf_pow(
            base_value.to_mpf(),
            exp_value.to_mpf(),
            prec,
            @symnum.round_nearest,
          ) catch {
            _ => {
              let base_z = match expr_to_evalf_complex(base, prec) {
                Some(value) => value
                None => return None
              }
              let exp_z = match expr_to_evalf_complex(exp, prec) {
                Some(value) => value
                None => return None
              }
              let pow_value = @symnum.mpc_pow(
                base_z.to_mpc(),
                exp_z.to_mpc(),
                prec,
                @symnum.round_nearest,
              ) catch {
                _ => return None
              }
              return Some(expr_from_mpc_evalf(pow_value, prec))
            }
          }
      }
      Some(expr_from_mpf_evalf(value, prec))
    }
    _ => {
      let base_z = match expr_to_evalf_complex(base, prec) {
        Some(value) => value
        None => return None
      }
      let exp_z = match expr_to_evalf_complex(exp, prec) {
        Some(value) => value
        None => return None
      }
      let value = match evalf_integer_exponent(exp, prec) {
        Some(n) =>
          @symnum.mpc_pow_int(base_z.to_mpc(), n, prec, @symnum.round_nearest)
        None =>
          @symnum.mpc_pow(
            base_z.to_mpc(),
            exp_z.to_mpc(),
            prec,
            @symnum.round_nearest,
          ) catch {
            _ => return None
          }
      }
      Some(expr_from_mpc_evalf(value, prec))
    }
  }
}

///|
fn evalf_real_unary_function(name : String, arg : Float, prec : Int) -> Expr? {
  let x = arg.to_mpf()
  let value = match name {
    "sqrt" =>
      @symnum.mpf_sqrt(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    "exp" => @symnum.mpf_exp(x, prec, @symnum.round_nearest)
    "log" | "ln" =>
      @symnum.mpf_log(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    "sin" => @symnum.mpf_sin(x, prec, @symnum.round_nearest)
    "cos" => @symnum.mpf_cos(x, prec, @symnum.round_nearest)
    "tan" => @symnum.mpf_tan(x, prec, @symnum.round_nearest)
    "sinh" => @symnum.mpf_sinh(x, prec, @symnum.round_nearest)
    "cosh" => @symnum.mpf_cosh(x, prec, @symnum.round_nearest)
    "tanh" => @symnum.mpf_tanh(x, prec, @symnum.round_nearest)
    "gamma" =>
      @symnum.mpf_gamma(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    "loggamma" =>
      @symnum.mpf_loggamma(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    "erf" => @symnum.mpf_erf(x, prec, @symnum.round_nearest)
    "erfc" => @symnum.mpf_erfc(x, prec, @symnum.round_nearest)
    "atan" => @symnum.mpf_atan(x, prec, @symnum.round_nearest)
    "Abs" | "abs" => @symnum.mpf_abs(x, prec, @symnum.round_nearest)
    "floor" => @symnum.mpf_floor(x, prec, @symnum.round_nearest)
    "ceiling" | "ceil" => @symnum.mpf_ceil(x, prec, @symnum.round_nearest)
    "frac" => @symnum.mpf_frac(x, prec, @symnum.round_nearest)
    "Si" | "si" => @symnum.mpf_si(x, prec, @symnum.round_nearest)
    "Ci" | "ci" =>
      @symnum.mpf_ci(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    "E1" | "e1" =>
      @symnum.mpf_e1(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    "zeta" =>
      @symnum.mpf_zeta(x, prec, @symnum.round_nearest) catch {
        _ => return None
      }
    _ => return None
  }
  Some(expr_from_mpf_evalf(value, prec))
}

///|
fn evalf_complex_unary_function(
  name : String,
  arg : ComplexFloat,
  prec : Int,
) -> Expr? {
  let z = arg.to_mpc()
  let value = match name {
    "sqrt" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_sqrt(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "exp" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_exp(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "log" | "ln" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_log(z, prec, @symnum.round_nearest) catch {
            _ => return None
          },
          prec,
        ),
      )
    "sin" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_sin(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "cos" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_cos(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "tan" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_tan(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "sinh" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_sinh(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "cosh" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_cosh(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "tanh" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_tanh(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "atan" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_atan(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "asin" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_asin(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "acos" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_acos(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "asinh" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_asinh(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "acosh" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_acosh(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "atanh" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_atanh(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "gamma" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_gamma(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "loggamma" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_loggamma(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "zeta" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_zeta(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "E1" | "e1" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_e1(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "Ci" | "ci" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_ci(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "Si" | "si" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_si(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "Abs" | "abs" => @symnum.mpc_abs(z, prec, @symnum.round_nearest)
    "arg" => @symnum.mpc_arg(z, prec, @symnum.round_nearest)
    "re" =>
      return Some(
        expr_from_mpf_evalf(
          @symnum.mpf_pos(z.real, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "im" =>
      return Some(
        expr_from_mpf_evalf(
          @symnum.mpf_pos(z.imag, prec, @symnum.round_nearest),
          prec,
        ),
      )
    "conjugate" | "conj" =>
      return Some(
        expr_from_mpc_evalf(
          @symnum.mpc_conjugate(z, prec, @symnum.round_nearest),
          prec,
        ),
      )
    _ => return None
  }
  Some(expr_from_mpf_evalf(value, prec))
}

///|
fn evalf_binary_function(
  name : String,
  first : Expr,
  second : Expr,
  prec : Int,
) -> Expr? {
  match name {
    "atan2" => {
      let x = match expr_to_evalf_float(first, prec) {
        Some(value) => value
        None => return None
      }
      let y = match expr_to_evalf_float(second, prec) {
        Some(value) => value
        None => return None
      }
      Some(
        expr_from_mpf_evalf(
          @symnum.mpf_atan2(x.to_mpf(), y.to_mpf(), prec, @symnum.round_nearest),
          prec,
        ),
      )
    }
    "log" =>
      match
        (expr_to_evalf_float(first, prec), expr_to_evalf_float(second, prec)) {
        (Some(x), Some(y)) => {
          let lx = @symnum.mpf_log(x.to_mpf(), prec, @symnum.round_nearest) catch {
            _ => return None
          }
          let ly = @symnum.mpf_log(y.to_mpf(), prec, @symnum.round_nearest) catch {
            _ => return None
          }
          Some(
            expr_from_mpf_evalf(
              @symnum.mpf_div(lx, ly, prec, @symnum.round_nearest) catch {
                _ => return None
              },
              prec,
            ),
          )
        }
        _ => {
          let x = match expr_to_evalf_complex(first, prec) {
            Some(value) => value
            None => return None
          }
          let y = match expr_to_evalf_complex(second, prec) {
            Some(value) => value
            None => return None
          }
          let lx = @symnum.mpc_log(x.to_mpc(), prec, @symnum.round_nearest) catch {
            _ => return None
          }
          let ly = @symnum.mpc_log(y.to_mpc(), prec, @symnum.round_nearest) catch {
            _ => return None
          }
          Some(
            expr_from_mpc_evalf(
              @symnum.mpc_div(lx, ly, prec, @symnum.round_nearest),
              prec,
            ),
          )
        }
      }
    _ => None
  }
}

///|
fn evalf_expint_function(args : Array[Expr], prec : Int) -> Expr? {
  match args {
    [order_expr, arg_expr] =>
      match
        (
          expr_to_evalf_float(order_expr, prec),
          expr_to_evalf_float(arg_expr, prec),
        ) {
        (Some(order_value), Some(arg_value)) => {
          let rational_pair = order_value.to_rational() catch {
            _ => return None
          }
          let num = rational_pair.0
          let den = rational_pair.1
          if den != 1N {
            None
          } else {
            let order_int = num.to_int()
            let value = @symnum.mpf_expint(
              order_int,
              arg_value.to_mpf(),
              prec,
              @symnum.round_nearest,
              gamma=false,
            ) catch {
              _ => return None
            }
            Some(expr_from_mpf_evalf(value, prec))
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn evalf_nary_function(name : String, args : Array[Expr], prec : Int) -> Expr? {
  if name == "expint" {
    return evalf_expint_function(args, prec)
  }
  match args {
    [arg] =>
      match expr_to_evalf_float(arg, prec) {
        Some(value) =>
          match evalf_real_unary_function(name, value, prec) {
            Some(result) => Some(result)
            None =>
              match expr_to_evalf_complex(arg, prec) {
                Some(z) => evalf_complex_unary_function(name, z, prec)
                None => None
              }
          }
        None =>
          match expr_to_evalf_complex(arg, prec) {
            Some(z) => evalf_complex_unary_function(name, z, prec)
            None => None
          }
      }
    [lhs, rhs] => evalf_binary_function(name, lhs, rhs, prec)
    _ => None
  }
}

///|
fn evalf_impl(expr : Expr, prec : Int) -> Expr {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Expr::Number(n) => Expr::Float(float_from_exact_evalf(n, prec))
    Expr::Float(f) => Expr::Float(promote_float_evalf(f, prec))
    Expr::ComplexFloat(z) => Expr::ComplexFloat(promote_complex_evalf(z, prec))
    Expr::NumberSymbol(kind) =>
      match kind {
        NumberSymbolKind::ImaginaryUnit =>
          Expr::ComplexFloat(complex_imag_unit(prec))
        _ =>
          match evalf_number_symbol_constant(kind, prec) {
            Some(value) => Expr::Float(value)
            None => expr
          }
      }
    Expr::Boolean(_) => expr
    Expr::Dummy(_, _) | Expr::Wild(_) => expr
    Expr::FunctionHead(_) => expr
    Expr::UndefinedFunction(_) => expr
    Expr::Apply(head, args) => {
      match head {
        Expr::UndefinedFunction(_) => return expr
        _ => ()
      }
      let eval_args = args.map(arg => evalf_impl(arg, prec))
      match head {
        Expr::FunctionHead(name) =>
          match evalf_nary_function(name, eval_args, prec) {
            Some(value) => value
            None =>
              match raw_apply(head, eval_args) {
                Some(applied) => applied
                None => Expr::Apply(head, eval_args)
              }
          }
        _ =>
          match raw_apply(head, eval_args) {
            Some(applied) => applied
            None => Expr::Apply(head, eval_args)
          }
      }
    }
    Expr::Symbol(name) =>
      if name == "I" {
        Expr::ComplexFloat(complex_imag_unit(prec))
      } else {
        match evalf_symbol_constant(name, prec) {
          Some(value) => Expr::Float(value)
          None => expr
        }
      }
    Expr::Add(args) => add(args.map(arg => evalf_impl(arg, prec)))
    Expr::Mul(args) => mul(args.map(arg => evalf_impl(arg, prec)))
    Expr::Pow(base, exp) => {
      let eval_base = evalf_impl(base, prec)
      let eval_exp = evalf_impl(exp, prec)
      match evalf_numeric_pow_expr(eval_base, eval_exp, prec) {
        Some(value) => value
        None => pow(eval_base, eval_exp)
      }
    }
    Expr::Mod(lhs, rhs) => {
      let lhs_eval = evalf_impl(lhs, prec)
      let rhs_eval = evalf_impl(rhs, prec)
      match (lhs_eval, rhs_eval) {
        (Expr::Float(x), Expr::Float(y)) =>
          Expr::Float(
            Float::from_mpf(
              @symnum.mpf_mod(
                x.to_mpf(),
                y.to_mpf(),
                prec,
                @symnum.round_nearest,
              ),
              prec~,
            ),
          ) catch {
            _ => mod_expr(lhs_eval, rhs_eval)
          }
        _ => mod_expr(lhs_eval, rhs_eval)
      }
    }
    Expr::Tuple(args) => Expr::Tuple(args.map(arg => evalf_impl(arg, prec)))
    Expr::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((evalf_impl(key, prec), evalf_impl(value, prec)))
      }
      Expr::Dict(out)
    }
    Expr::Relational(op, lhs, rhs) => {
      let lhs_eval = evalf_impl(lhs, prec)
      let rhs_eval = evalf_impl(rhs, prec)
      match op {
        RelOp::Eq => Expr::Relational(RelOp::Eq, lhs_eval, rhs_eval)
        RelOp::Ne => Expr::Relational(RelOp::Ne, lhs_eval, rhs_eval)
        RelOp::Lt => Expr::Relational(RelOp::Lt, lhs_eval, rhs_eval)
        RelOp::Le => Expr::Relational(RelOp::Le, lhs_eval, rhs_eval)
        RelOp::Gt => Expr::Relational(RelOp::Gt, lhs_eval, rhs_eval)
        RelOp::Ge => Expr::Relational(RelOp::Ge, lhs_eval, rhs_eval)
      }
    }
    Expr::Derivative(inner, deriv_args) => {
      let out : Array[Expr] = []
      for arg in deriv_args {
        out.push(evalf_impl(arg, prec))
      }
      Expr::Derivative(evalf_impl(inner, prec), out)
    }
    Expr::Subs(inner, variable, value) =>
      match subs_eval_env(variable, value) {
        Some(env) => evalf_impl(subst(inner, env), prec)
        None =>
          subs_expr(
            evalf_impl(inner, prec),
            evalf_impl(variable, prec),
            evalf_impl(value, prec),
          )
      }
    Expr::Lambda(vars, body) =>
      lambda_expr(evalf_impl(vars, prec), evalf_impl(body, prec))
    Expr::Function(_, _) => abort("legacy function should be normalized")
  }
}

///|
fn subs_eval_items(expr : Expr) -> Array[Expr] {
  match tuple_items(expr) {
    Some(items) => items
    None => [expr]
  }
}

///|
fn subs_eval_env(variable : Expr, value : Expr) -> Map[String, Expr]? {
  let vars = subs_eval_items(variable)
  let vals = subs_eval_items(value)
  if vars.length() != vals.length() {
    return None
  }
  let env : Map[String, Expr] = {}
  for i in 0..<vars.length() {
    match vars[i] {
      Expr::Symbol(name) => env.set(name, vals[i])
      _ => return None
    }
  }
  Some(env)
}

///|
fn evalf_numeric_constant_expr(expr : Expr, prec : Int) -> Expr? {
  let expr = normalize_legacy_expr(expr)
  match expr {
    Expr::Number(_)
    | Expr::Float(_)
    | Expr::ComplexFloat(_)
    | Expr::NumberSymbol(_) => Some(evalf_impl(expr, prec))
    Expr::Add(_)
    | Expr::Mul(_)
    | Expr::Pow(_, _)
    | Expr::Mod(_, _)
    | Expr::Apply(_, _) =>
      match expr_to_evalf_complex(expr, prec) {
        Some(value) => Some(expr_from_mpc_evalf(value.to_mpc(), prec))
        None => None
      }
    Expr::Function(_, _) => abort("legacy function should be normalized")
    _ => None
  }
}

///|
/// Evaluate exact numeric leaves and common transcendental constants/functions
/// into `Expr::Float` or `Expr::ComplexFloat` at the requested precision.
pub fn evalf(expr : Expr, prec? : Int = 53) -> Expr {
  let resolved_prec = evalf_default_prec(prec)
  let mut current = expr
  for _ in 0..<4 {
    let next = evalf_impl(current, resolved_prec)
    if compare_expr(current, next) == 0 {
      current = next
      break
    }
    current = next
  }
  match evalf_numeric_constant_expr(current, resolved_prec) {
    Some(value) => value
    None => current
  }
}
