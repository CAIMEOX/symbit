///|
fn plotting_request_lines(
  helper_source : String,
  helper_name : String,
  args : Array[@recipe.RecipeArg],
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let scope = builder.exec(scope, helper_source)
  let helper = builder.getitem(scope, Str(helper_name))
  let result = builder.call(helper, args)
  builder
  .request_str(result)
  .split("\u001f")
  .to_array()
  .map(StringView::to_owned)
}

///|
/// Return SymPy's textplot rows for an expression and interval.
pub fn oracle_textplot_lines(
  expr_text : String,
  a_text : String,
  b_text : String,
  width : Int,
  height : Int,
) -> Array[String] raise {
  let helper_source = "def _symbit_textplot_lines(expr_text, a_text, b_text, width, height):\n" +
    "    import warnings\n" +
    "    from sympy import sympify\n" +
    "    from sympy.plotting.textplot import textplot_str\n" +
    "    with warnings.catch_warnings():\n" +
    "        warnings.simplefilter('ignore')\n" +
    "        rows = textplot_str(sympify(expr_text), sympify(a_text), sympify(b_text), width, height)\n" +
    "    return chr(31).join(rows)\n"
  plotting_request_lines(helper_source, "_symbit_textplot_lines", [
    Str(expr_text),
    Str(a_text),
    Str(b_text),
    DecimalInt(width.to_string()),
    DecimalInt(height.to_string()),
  ])
}

///|
/// Return the rows printed by SymPy's text plotting backend.
pub fn oracle_plot_text_lines(
  expr_text : String,
  var_text : String,
  a_text : String,
  b_text : String,
) -> Array[String] raise {
  let helper_source = "def _symbit_plot_text_lines(expr_text, var_text, a_text, b_text):\n" +
    "    import io\n" +
    "    import warnings\n" +
    "    from contextlib import redirect_stdout\n" +
    "    from sympy import sympify\n" +
    "    from sympy.plotting import plot\n" +
    "    buffer = io.StringIO()\n" +
    "    with warnings.catch_warnings():\n" +
    "        warnings.simplefilter('ignore')\n" +
    "        with redirect_stdout(buffer):\n" +
    "            plot(sympify(expr_text), (sympify(var_text), sympify(a_text), sympify(b_text)), backend='text')\n" +
    "    return chr(31).join(buffer.getvalue().rstrip('\\n').splitlines())\n"
  plotting_request_lines(helper_source, "_symbit_plot_text_lines", [
    Str(expr_text),
    Str(var_text),
    Str(a_text),
    Str(b_text),
  ])
}
