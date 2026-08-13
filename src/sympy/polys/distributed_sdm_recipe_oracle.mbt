///|
fn distributed_sdm_source() -> String {
  (
    #|def _symbit_distributed_sdm_compact(value):
    #|    if value is None:
    #|        raise ValueError("distributed-sdm-result-none")
    #|    def dense(item):
    #|        if isinstance(item, list):
    #|            return "[" + ",".join(dense(part) for part in item) + "]"
    #|        if isinstance(item, tuple):
    #|            return "(" + ",".join(dense(part) for part in item) + ")"
    #|        return str(item)
    #|    return dense(value).replace(" ", "")
  )
}

///|
priv struct DistributedSdmRecipe {
  domain_recipe : DomainRecipe
  distributed_module : @recipe.ValueRef
  integer_class : @recipe.ValueRef
  compact_renderer : @recipe.ValueRef
}

///|
fn DistributedSdmRecipe::new() -> DistributedSdmRecipe raise {
  let domain_recipe = DomainRecipe::new()
  let distributed_module = domain_recipe.builder.import_module(
    "sympy.polys.distributedmodules",
  )
  let integer_class = domain_recipe.builder.getattr(
    domain_recipe.sympy,
    "Integer",
  )
  let scope = domain_recipe.builder.exec(
    domain_recipe.scope,
    distributed_sdm_source(),
  )
  let compact_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_distributed_sdm_compact"),
  )
  { domain_recipe, distributed_module, integer_class, compact_renderer }
}

///|
fn DistributedSdmRecipe::monomial(
  self : DistributedSdmRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.domain_recipe.builder.tuple(items)
}

///|
fn DistributedSdmRecipe::domain(
  self : DistributedSdmRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.getattr(self.domain_recipe.sympy, name)
}

///|
fn DistributedSdmRecipe::coefficient(
  self : DistributedSdmRecipe,
  value : Int,
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let integer = self.domain_recipe.builder.call(self.integer_class, [
    Str(Show::to_string(value)),
  ])
  let convert = self.domain_recipe.builder.getattr(domain, "convert")
  let result = self.domain_recipe.builder.call(convert, [Ref(integer)])
  self.domain_recipe.builder.require_non_none(
    result,
    message="distributed-sdm-domain-convert-none",
  )
}

///|
fn DistributedSdmRecipe::term(
  self : DistributedSdmRecipe,
  term : (Array[Int], Int),
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.tuple([
    Ref(self.monomial(term.0)),
    Ref(self.coefficient(term.1, domain)),
  ])
}

///|
fn DistributedSdmRecipe::terms(
  self : DistributedSdmRecipe,
  terms : Array[(Array[Int], Int)],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for term in terms {
    items.push(Ref(self.term(term, domain)))
  }
  self.domain_recipe.builder.list(items)
}

///|
fn DistributedSdmRecipe::basis(
  self : DistributedSdmRecipe,
  basis : Array[Array[(Array[Int], Int)]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for terms in basis {
    items.push(Ref(self.terms(terms, domain)))
  }
  self.domain_recipe.builder.list(items)
}

///|
fn DistributedSdmRecipe::term_dict(
  self : DistributedSdmRecipe,
  terms : Array[(Array[Int], Int)],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for term in terms {
    items.push(
      (Ref(self.monomial(term.0)), Ref(self.coefficient(term.1, domain))),
    )
  }
  self.domain_recipe.builder.dict(items)
}

///|
fn DistributedSdmRecipe::order(
  self : DistributedSdmRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.getattr(self.domain_recipe.sympy, name)
}

///|
fn DistributedSdmRecipe::symbols(
  self : DistributedSdmRecipe,
  names : Array[String],
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.list(self.domain_recipe.symbols(names))
}

///|
fn DistributedSdmRecipe::expressions(
  self : DistributedSdmRecipe,
  sources : Array[String],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for source in sources {
    items.push(Ref(self.domain_recipe.sympify(source)))
  }
  self.domain_recipe.builder.list(items)
}

///|
fn DistributedSdmRecipe::normal_form(
  self : DistributedSdmRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let function_name = match name {
    "buchberger" => "sdm_nf_buchberger"
    "reduced" | "buchberger_reduced" => "sdm_nf_buchberger_reduced"
    _ => "sdm_nf_mora"
  }
  self.domain_recipe.builder.getattr(self.distributed_module, function_name)
}

///|
fn DistributedSdmRecipe::call(
  self : DistributedSdmRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.domain_recipe.builder.getattr(
    self.distributed_module,
    name,
  )
  let result = self.domain_recipe.builder.call(callable, args, kwargs~)
  self.domain_recipe.builder.require_non_none(
    result,
    message="distributed-sdm-call-none:" + name,
  )
}

///|
fn DistributedSdmRecipe::request_compact(
  self : DistributedSdmRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let rendered = self.domain_recipe.builder.call(self.compact_renderer, [
    Ref(result),
  ])
  self.domain_recipe.builder.request_str(rendered)
}

///|
fn DistributedSdmRecipe::request_int(
  self : DistributedSdmRecipe,
  result : @recipe.ValueRef,
) -> Int raise {
  parse_domain_int(self.domain_recipe.builder.request_int(result))
}

///|
fn DistributedSdmRecipe::request_bool(
  self : DistributedSdmRecipe,
  result : @recipe.ValueRef,
) -> Bool raise {
  self.domain_recipe.builder.request_bool(result)
}
