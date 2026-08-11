///|
/// Transverse-wave helpers aligned with the symbolic core of
/// `sympy.physics.optics.waves.TWave`.

///|
pub struct TWave {
  amplitude : Expr
  frequency : Expr
  phase : Expr
  time_period : Expr
  n : Expr
} derive(Eq)

///|
pub fn t_wave(
  amplitude : Expr,
  frequency? : Expr? = None,
  phase? : Expr = int(0),
  time_period? : Expr? = None,
  n? : Expr = Symbol("n"),
) -> TWave raise PhysicsError {
  match (frequency, time_period) {
    (None, None) =>
      raise ValueError("Either frequency or time period is needed.")
    (Some(freq), Some(period)) => {
      guard freq == (period ^ int(-1)) else {
        raise ValueError("frequency and time_period should be consistent.")
      }
      { amplitude, frequency: freq, phase, time_period: period, n }
    }
    (Some(freq), None) =>
      { amplitude, frequency: freq, phase, time_period: freq ^ int(-1), n }
    (None, Some(period)) =>
      { amplitude, frequency: period ^ int(-1), phase, time_period: period, n }
  }
}

///|
fn twave_render_arg(expr : Expr) -> String {
  match expr {
    Pow(base, Number(n)) if n.is_integral() &&
      n.numerator() == BigInt::from_int(-1) => {
      let base_txt = @symprint.pretty_string(base)
      match base {
        Add(_) | Mul(_) => "1/(\{base_txt})"
        _ => "1/\{base_txt}"
      }
    }
    _ => @symprint.pretty_string(expr)
  }
}

///|
pub fn TWave::as_expr(self : TWave) -> Expr {
  @symcore.raw_function("TWave", [
    self.amplitude,
    self.frequency,
    self.phase,
    self.time_period,
    self.n,
  ])
}

///|
pub impl Show for TWave with fn to_string(self) {
  [
    "TWave(",
    twave_render_arg(self.amplitude),
    ", ",
    twave_render_arg(self.frequency),
    ", ",
    twave_render_arg(self.phase),
    ", ",
    twave_render_arg(self.time_period),
    ", ",
    twave_render_arg(self.n),
    ")",
  ].join("")
}

///|
pub impl Show for TWave with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub fn TWave::amplitude_expr(self : TWave) -> Expr {
  self.amplitude
}

///|
pub fn TWave::frequency_expr(self : TWave) -> Expr {
  self.frequency
}

///|
pub fn TWave::phase_expr(self : TWave) -> Expr {
  self.phase
}

///|
pub fn TWave::time_period_expr(self : TWave) -> Expr {
  self.time_period
}

///|
pub fn TWave::refractive_index_expr(self : TWave) -> Expr {
  self.n
}

///|
pub fn TWave::wavelength(self : TWave) -> Expr {
  speed_of_light * ((self.frequency * self.n) ^ int(-1))
}

///|
pub fn TWave::speed(self : TWave) -> Expr {
  self.wavelength() * self.frequency
}

///|
pub fn TWave::angular_velocity(self : TWave) -> Expr {
  int(2) * pi_expr() * self.frequency
}

///|
pub fn TWave::wavenumber(self : TWave) -> Expr {
  int(2) * pi_expr() * (self.wavelength() ^ int(-1))
}

///|
pub fn TWave::superpose(
  self : TWave,
  other : TWave,
) -> TWave raise PhysicsError {
  guard self.frequency == other.frequency &&
    self.wavelength() == other.wavelength() else {
    raise ValueError(
      "Interference of waves with different frequencies has not been implemented.",
    )
  }
  t_wave(
    @symelem.sqrt(
      (self.amplitude ^ int(2)) +
      (other.amplitude ^ int(2)) +
      int(2) *
      self.amplitude *
      other.amplitude *
      @symelem.cos(self.phase - other.phase),
    ),
    frequency=Some(self.frequency),
    phase=@symelem.atan2(
      self.amplitude * @symelem.sin(self.phase) +
      other.amplitude * @symelem.sin(other.phase),
      self.amplitude * @symelem.cos(self.phase) +
      other.amplitude * @symelem.cos(other.phase),
    ),
    n=self.n,
  )
}

///|
pub fn TWave::scale(self : TWave, factor : Expr) -> TWave raise PhysicsError {
  match factor {
    Number(_) => { ..self, amplitude: self.amplitude * factor }
    _ => raise ValueError("Only scalar numeric factors are supported.")
  }
}

///|
pub fn TWave::neg(self : TWave) -> TWave raise PhysicsError {
  self.scale(int(-1))
}

///|
pub fn TWave::sub(self : TWave, other : TWave) -> TWave raise PhysicsError {
  self.superpose(other.neg())
}

///|
pub fn TWave::rewrite_as_sin(self : TWave) -> Expr {
  self.amplitude *
  @symelem.sin(
    self.wavenumber() * Symbol("x") -
    self.angular_velocity() * Symbol("t") +
    self.phase +
    pi_expr() * rational_expr(1, 2),
  )
}

///|
pub fn TWave::rewrite_as_cos(self : TWave) -> Expr {
  self.amplitude *
  @symelem.cos(
    self.wavenumber() * Symbol("x") -
    self.angular_velocity() * Symbol("t") +
    self.phase,
  )
}

///|
pub fn TWave::rewrite_as_exp(self : TWave) -> Expr {
  self.amplitude *
  @symelem.exp(
    i_expr() *
    (
      self.wavenumber() * Symbol("x") -
      self.angular_velocity() * Symbol("t") +
      self.phase
    ),
  )
}

///|
pub fn TWave::rewrite_as_pde(self : TWave) -> Expr {
  ignore(self)
  let mu = Expr::Symbol("mu")
  let epsilon = Expr::Symbol("epsilon")
  let x = Expr::Symbol("x")
  let t = Expr::Symbol("t")
  let e = @symcore.raw_function("E", [x, t])
  @symcore.raw_add([
    @symcore.raw_derivative(e, [x, int(2)]),
    mu * epsilon * @symcore.raw_derivative(e, [t, int(2)]),
  ])
}
