///|
/// Circuit-diagram helpers aligned with `sympy.physics.quantum.circuitplot`.
///
/// SymPy's plotting backend is matplotlib-based and object-oriented. In
/// MoonBit we keep the same logical surface as pure data: label rendering,
/// mock measurement gates, dynamic custom-gate constructors, and a
/// `CircuitPlot` record that captures the layout metadata SymPy computes
/// before drawing.

///|
pub struct CircuitPlot {
  circuit : @symcore.Expr
  ngates : Int
  nqubits : Int
  labels : Array[String]
  inits : Map[String, String]
  scale : Double
  fontsize : Double
  linewidth : Double
  control_radius : Double
  not_radius : Double
  swap_delta : Double
  label_buffer : Double
  wire_grid : Array[Double]
  gate_grid : Array[Double]
  gates : Array[@symcore.Expr]
  measurements : Map[Int, Int]
}

///|
fn circuitplot_expr_arg_count(expr : @symcore.Expr) -> Int {
  match expr {
    @symcore.Expr::Add(args) => args.length()
    @symcore.Expr::Mul(args) => args.length()
    @symcore.Expr::Pow(_, _) => 2
    @symcore.Expr::Function(_, args) => args.length()
    _ => 0
  }
}

///|
fn circuitplot_integral_arg(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn circuitplot_is_measurement(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Function("Mz", _) => true
    @symcore.Expr::Function("Mx", _) => true
    @symcore.Expr::Function("CGate", args) if args.length() == 2 =>
      circuitplot_is_measurement(args[1])
    _ => false
  }
}

///|
fn circuitplot_targets(expr : @symcore.Expr) -> Array[Int]? {
  match gate_from_expr(expr) {
    Some(gate) => Some(gate.args.copy())
    None =>
      match expr {
        @symcore.Expr::Function("Mz", args) if args.length() == 1 =>
          match circuitplot_integral_arg(args[0]) {
            Some(target) => Some([target])
            None => None
          }
        @symcore.Expr::Function("Mx", args) if args.length() == 1 =>
          match circuitplot_integral_arg(args[0]) {
            Some(target) => Some([target])
            None => None
          }
        @symcore.Expr::Function("CGate", args) if args.length() == 2 =>
          match (gate_tuple_ints(args[0]), circuitplot_targets(args[1])) {
            (Some(controls), Some(targets)) => Some(controls + targets)
            _ => None
          }
        @symcore.Expr::Function(_, args) if args.length() == 1 =>
          match circuitplot_integral_arg(args[0]) {
            Some(target) => Some([target])
            None => None
          }
        _ => None
      }
  }
}

///|
fn circuitplot_is_gate(expr : @symcore.Expr) -> Bool {
  match circuitplot_targets(expr) {
    Some(_) => true
    None => false
  }
}

///|
fn circuitplot_extract_gates(expr : @symcore.Expr) -> Array[@symcore.Expr] {
  match expr {
    @symcore.Expr::Mul(args) => {
      let out : Array[@symcore.Expr] = []
      for idx in 0..<args.length() {
        let gate = args[args.length() - idx - 1]
        if circuitplot_is_gate(gate) {
          out.push(gate)
        }
      }
      out
    }
    _ => if circuitplot_is_gate(expr) { [expr] } else { [] }
  }
}

///|
fn circuitplot_grid(count : Int, scale : Double) -> Array[Double] {
  let out : Array[Double] = []
  for idx in 0..<count {
    out.push(Double::from_int(idx) * scale)
  }
  out
}

///|
fn circuitplot_measurements(gates : Array[@symcore.Expr]) -> Map[Int, Int] {
  let out : Map[Int, Int] = Map::new()
  for gate_idx in 0..<gates.length() {
    let gate = gates[gate_idx]
    if circuitplot_is_measurement(gate) {
      match circuitplot_targets(gate) {
        Some(targets) =>
          for target in targets {
            match out.get(target) {
              Some(prev_gate_idx) =>
                if gate_idx < prev_gate_idx {
                  out[target] = gate_idx
                }
              None => out[target] = gate_idx
            }
          }
        None => ()
      }
    }
  }
  out
}

///|
pub fn render_label(
  label : String,
  inits? : Map[String, String] = Map::new(),
) -> String {
  match inits.get(label) {
    Some(init) =>
      "$\\\\left|\{label}\\\\right\\\\rangle=\\\\left|\{init}\\\\right\\\\rangle$"
    None => "$\\\\left|\{label}\\\\right\\\\rangle$"
  }
}

///|
pub fn labeller(n : Int, symbol? : String = "q") -> Array[String] {
  let out : Array[String] = []
  for idx in 0..<n {
    out.push("\{symbol}_\{n - idx - 1}")
  }
  out
}

///|
pub fn mz(target : Int) -> @symcore.Expr {
  @symcore.raw_function("Mz", [@symcore.int(target)])
}

///|
pub fn mx(target : Int) -> @symcore.Expr {
  @symcore.raw_function("Mx", [@symcore.int(target)])
}

///|
pub fn create_one_qubit_gate(
  name : String,
  _latexname? : String? = None,
) -> (Int) -> @symcore.Expr {
  target => @symcore.raw_function(name, [@symcore.int(target)])
}

///|
pub fn create_cgate(
  name : String,
  _latexname? : String? = None,
) -> (Array[Int], Int) -> @symcore.Expr {
  let builder = create_one_qubit_gate(name)
  (controls, target) => cgate(controls, builder(target))
}

///|
pub fn CircuitPlot::new(
  circuit : @symcore.Expr,
  nqubits : Int,
  labels? : Array[String] = [],
  inits? : Map[String, String] = Map::new(),
  scale? : Double = 1.0,
  fontsize? : Double = 20.0,
  linewidth? : Double = 1.0,
  control_radius? : Double = 0.05,
  not_radius? : Double = 0.15,
  swap_delta? : Double = 0.05,
  label_buffer? : Double = 0.5,
) -> CircuitPlot {
  let gates = circuitplot_extract_gates(circuit)
  CircuitPlot::{
    circuit,
    ngates: circuitplot_expr_arg_count(circuit),
    nqubits,
    labels: labels.copy(),
    inits,
    scale,
    fontsize,
    linewidth,
    control_radius,
    not_radius,
    swap_delta,
    label_buffer,
    wire_grid: circuitplot_grid(nqubits, scale),
    gate_grid: circuitplot_grid(circuitplot_expr_arg_count(circuit), scale),
    gates,
    measurements: circuitplot_measurements(gates),
  }
}

///|
pub fn circuit_plot(
  circuit : @symcore.Expr,
  nqubits : Int,
  labels? : Array[String] = [],
  inits? : Map[String, String] = Map::new(),
  scale? : Double = 1.0,
  fontsize? : Double = 20.0,
  linewidth? : Double = 1.0,
  control_radius? : Double = 0.05,
  not_radius? : Double = 0.15,
  swap_delta? : Double = 0.05,
  label_buffer? : Double = 0.5,
) -> CircuitPlot {
  CircuitPlot::new(
    circuit,
    nqubits,
    labels~,
    inits~,
    scale~,
    fontsize~,
    linewidth~,
    control_radius~,
    not_radius~,
    swap_delta~,
    label_buffer~,
  )
}

///|
pub fn circuitplot_summary(plot : CircuitPlot) -> String {
  let measurement_keys = plot.measurements.keys().to_array()
  measurement_keys.sort()
  let labels_summary = plot.labels.join(",")
  let measurement_summary = if measurement_keys.is_empty() {
    "-"
  } else {
    measurement_keys.map(key => "\{key}:\{plot.measurements[key]}").join(",")
  }
  [
    "ngates=\{plot.ngates}",
    "nqubits=\{plot.nqubits}",
    "gate_count=\{plot.gates.length()}",
    "measurements=\{measurement_summary}",
    "labels=\{labels_summary}",
  ].join(";")
}
