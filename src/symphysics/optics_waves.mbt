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
  n? : Expr = symbol("n"),
) -> TWave raise PhysicsError {
  match (frequency, time_period) {
    (None, None) =>
      raise PhysicsError::ValueError(
        "Either frequency or time period is needed.",
      )
    (Some(freq), Some(period)) => {
      guard freq == (period ^ int(-1)) else {
        raise PhysicsError::ValueError(
          "frequency and time_period should be consistent.",
        )
      }
      TWave::{ amplitude, frequency: freq, phase, time_period: period, n }
    }
    (Some(freq), None) =>
      TWave::{
        amplitude,
        frequency: freq,
        phase,
        time_period: freq ^ int(-1),
        n,
      }
    (None, Some(period)) =>
      TWave::{
        amplitude,
        frequency: period ^ int(-1),
        phase,
        time_period: period,
        n,
      }
  }
}

///|
fn twave_render_arg(expr : Expr) -> String {
  match expr {
    Expr::Pow(base, Expr::Number(n)) if n.is_integral() &&
      n.numerator() == BigInt::from_int(-1) => {
      let base_txt = @symprint.to_string(base)
      match base {
        Expr::Add(_) | Expr::Mul(_) => "1/(\{base_txt})"
        _ => "1/\{base_txt}"
      }
    }
    _ => @symprint.to_string(expr)
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
pub fn TWave::to_string(self : TWave) -> String {
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
    raise PhysicsError::ValueError(
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
pub fn TWave::scale(
  self : TWave,
  factor : Expr,
) -> TWave raise PhysicsError {
  match factor {
    Expr::Number(_) =>
      TWave::{ ..self, amplitude: self.amplitude * factor }
    _ =>
      raise PhysicsError::ValueError(
        "Only scalar numeric factors are supported.",
      )
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
    self.wavenumber() * symbol("x") -
    self.angular_velocity() * symbol("t") +
    self.phase +
    pi_expr() * rational_expr(1, 2),
  )
}

///|
pub fn TWave::rewrite_as_cos(self : TWave) -> Expr {
  self.amplitude *
  @symelem.cos(
    self.wavenumber() * symbol("x") -
    self.angular_velocity() * symbol("t") +
    self.phase,
  )
}

///|
pub fn TWave::rewrite_as_exp(self : TWave) -> Expr {
  self.amplitude *
  @symelem.exp(
    i_expr() *
    (
      self.wavenumber() * symbol("x") -
      self.angular_velocity() * symbol("t") +
      self.phase
    ),
  )
}

///|
pub fn TWave::rewrite_as_pde(self : TWave) -> Expr {
  ignore(self)
  let mu = symbol("mu")
  let epsilon = symbol("epsilon")
  let x = symbol("x")
  let t = symbol("t")
  let e = @symcore.raw_function("E", [x, t])
  @symcore.raw_add([
    @symcore.raw_function("Derivative", [e, x, int(2)]),
    mu * epsilon * @symcore.raw_function("Derivative", [e, t, int(2)]),
  ])
}
