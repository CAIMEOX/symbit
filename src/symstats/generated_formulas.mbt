///|

/// Auto-generated formulas for symbolic stats distributions (safe subset).

///|
fn generated_density(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Arcsin", 0) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    x,
                    eval_arith(
                      @symcore.add([
                        @symcore.int(1),
                        eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      ]),
                    ),
                  ]),
                ),
                stats_exact_rational(-1, 2),
              ),
            ),
          ]),
        ),
      )
    ("Benini", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.add([
                params[0],
                eval_arith(
                  @symcore.mul([
                    @symcore.int(2),
                    params[1],
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.mul([
                          x,
                          eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.add([
                      params[0],
                      eval_arith(
                        @symcore.mul([
                          params[1],
                          @symcore.function("log", [
                            eval_arith(
                              @symcore.mul([
                                x,
                                eval_arith(
                                  @symcore.pow(params[2], @symcore.int(-1)),
                                ),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                  @symcore.function("log", [
                    eval_arith(
                      @symcore.mul([
                        x,
                        eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Beta", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(@symcore.mul([@symcore.int(-1), x])),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), params[1]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [params[0], params[1]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("BetaBinomial", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [params[1], params[2]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("binomial", [params[0], x]),
            @symcore.function("beta", [
              eval_arith(@symcore.add([params[1], x])),
              eval_arith(
                @symcore.add([
                  params[0],
                  params[2],
                  eval_arith(@symcore.mul([@symcore.int(-1), x])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("BetaPrime", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(1), x])),
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [params[0], params[1]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("BoundedPareto", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(-1),
            params[0],
            eval_arith(@symcore.pow(params[1], params[0])),
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            params[1],
                            eval_arith(
                              @symcore.pow(params[2], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        params[0],
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Cauchy", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[0],
                            eval_arith(@symcore.mul([@symcore.int(-1), x])),
                          ]),
                        ),
                        @symcore.int(2),
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Chi", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.int(2),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(x, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ChiNoncentral", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(@symcore.pow(x, params[0])),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.mul([params[1], x])),
                eval_arith(
                  @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                ),
              ),
            ),
            @symcore.function("besseli", [
              eval_arith(
                @symcore.add([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
              ),
              eval_arith(@symcore.mul([params[1], x])),
            ]),
            @symcore.function("exp", [
              eval_arith(
                @symcore.add([
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(-1, 2),
                      eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                    ]),
                  ),
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(-1, 2),
                      eval_arith(@symcore.pow(x, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ChiSquared", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.int(2),
                eval_arith(
                  @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([stats_exact_rational(-1, 2), x])),
            ]),
          ]),
        ),
      )
    ("Dagum", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    x,
                    eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                  ]),
                ),
                eval_arith(@symcore.mul([params[0], params[1]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            x,
                            eval_arith(
                              @symcore.pow(params[2], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        params[1],
                      ),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      )
    ("Davis", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], params[1])),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          params[0],
                          eval_arith(
                            @symcore.pow(
                              eval_arith(
                                @symcore.add([
                                  params[2],
                                  eval_arith(
                                    @symcore.mul([@symcore.int(-1), x]),
                                  ),
                                ]),
                              ),
                              @symcore.int(-1),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[1]]),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[1]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Erlang", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.int(-1), params[1], x])),
            ]),
          ]),
        ),
      )
    ("ExGaussian", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            params[2],
            @symcore.function("erfc", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(1, 2),
                  eval_arith(
                    @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                  ),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                  eval_arith(
                    @symcore.add([
                      params[0],
                      eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      eval_arith(
                        @symcore.mul([
                          params[2],
                          eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(1, 2),
                  params[2],
                  eval_arith(
                    @symcore.add([
                      eval_arith(@symcore.mul([@symcore.int(-2), x])),
                      eval_arith(@symcore.mul([@symcore.int(2), params[0]])),
                      eval_arith(
                        @symcore.mul([
                          params[2],
                          eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ExponentialPower", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                    ]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          @symcore.function("Abs", [
                            eval_arith(
                              @symcore.add([
                                params[0],
                                eval_arith(@symcore.mul([@symcore.int(-1), x])),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                      params[2],
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("FDistribution", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[1], params[1])),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(@symcore.mul([params[0], x])),
                        params[0],
                      ),
                    ),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[1],
                            eval_arith(@symcore.mul([params[0], x])),
                          ]),
                        ),
                        eval_arith(
                          @symcore.add([
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[1]]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                stats_exact_rational(1, 2),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("FisherZ", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(
              @symcore.pow(
                params[0],
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                params[1],
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(
                      @symcore.mul([
                        params[0],
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([@symcore.int(2), x])),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                    ),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[1]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [eval_arith(@symcore.mul([params[0], x]))]),
          ]),
        ),
      )
    ("FlorySchulz", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            x,
            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), x])),
              ),
            ),
          ]),
        ),
      )
    ("Frechet", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      x,
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("GammaInverse", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[1], params[0])),
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[1],
                  eval_arith(@symcore.pow(x, @symcore.int(-1))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("GaussianInverse", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    params[1],
                    eval_arith(@symcore.pow(x, @symcore.int(-3))),
                  ]),
                ),
                stats_exact_rational(1, 2),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  params[1],
                  eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                  eval_arith(@symcore.pow(x, @symcore.int(-1))),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                      @symcore.int(2),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Gompertz", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            @symcore.function("exp", [
              eval_arith(
                @symcore.add([
                  params[1],
                  eval_arith(@symcore.mul([params[0], x])),
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      params[1],
                      @symcore.function("exp", [
                        eval_arith(@symcore.mul([params[0], x])),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Gumbel", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                  eval_arith(
                    @symcore.add([
                      params[1],
                      eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          params[0],
                          @symcore.function("exp", [
                            eval_arith(
                              @symcore.mul([
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(-1)),
                                ),
                                eval_arith(
                                  @symcore.add([
                                    params[1],
                                    eval_arith(
                                      @symcore.mul([@symcore.int(-1), x]),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Hypergeometric", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("binomial", [params[0], params[2]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("binomial", [params[1], x]),
            @symcore.function("binomial", [
              eval_arith(
                @symcore.add([
                  params[0],
                  eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                ]),
              ),
              eval_arith(
                @symcore.add([
                  params[2],
                  eval_arith(@symcore.mul([@symcore.int(-1), x])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Kumaraswamy", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(@symcore.pow(x, params[0])),
                      ]),
                    ),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), params[1]])),
              ),
            ),
          ]),
        ),
      )
    ("Laplace", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                  @symcore.function("Abs", [
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Levy", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(@symcore.pow(params[1], stats_exact_rational(1, 2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
                stats_exact_rational(-3, 2),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(1, 2),
                  params[1],
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                      @symcore.int(-1),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("LogCauchy", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[0],
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                @symcore.function("log", [x]),
                              ]),
                            ),
                          ]),
                        ),
                        @symcore.int(2),
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("LogLogistic", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    x,
                    eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), params[1]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            x,
                            eval_arith(
                              @symcore.pow(params[0], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        params[1],
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-2),
              ),
            ),
          ]),
        ),
      )
    ("LogNormal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-2))),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              @symcore.function("log", [x]),
                            ]),
                          ),
                        ]),
                      ),
                      @symcore.int(2),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Logarithmic", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(-1),
            eval_arith(@symcore.pow(params[0], x)),
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                @symcore.function("log", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Logistic", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 4),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                @symcore.function("cosh", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
                @symcore.int(-2),
              ),
            ),
          ]),
        ),
      )
    ("LogitNormal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(-1, 2),
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                stats_exact_rational(-1, 2),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(-1), x])),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-2))),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              @symcore.function("log", [
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    x,
                                    eval_arith(
                                      @symcore.pow(
                                        eval_arith(
                                          @symcore.add([@symcore.int(-1), x]),
                                        ),
                                        @symcore.int(-1),
                                      ),
                                    ),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                      @symcore.int(2),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Lomax", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                    eval_arith(@symcore.add([params[1], x])),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      )
    ("Maxwell", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(@symcore.pow(params[0], @symcore.int(-3))),
            eval_arith(@symcore.pow(x, @symcore.int(2))),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                  eval_arith(@symcore.pow(x, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Moyal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(1, 2),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                  eval_arith(
                    @symcore.add([
                      params[0],
                      eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          params[1],
                          @symcore.function("exp", [
                            eval_arith(
                              @symcore.mul([
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(-1)),
                                ),
                                eval_arith(
                                  @symcore.add([
                                    params[0],
                                    eval_arith(
                                      @symcore.mul([@symcore.int(-1), x]),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Nakagami", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(params[0], params[0])),
            eval_arith(
              @symcore.pow(
                params[1],
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(2), params[0]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[0],
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                  eval_arith(@symcore.pow(x, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Pareto", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(@symcore.pow(params[0], params[1])),
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      )
    ("PowerFunction", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[2],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
          ]),
        ),
      )
    ("QuadraticU", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-3),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-3),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-2), x])),
                      ]),
                    ),
                    @symcore.int(2),
                  ),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[1], x]),
              @symcore.function("Le", [params[0], x]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("RaisedCosine", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.function("cos", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), x])),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [
                params[0],
                eval_arith(@symcore.add([params[1], x])),
              ]),
              @symcore.function("Ge", [
                params[0],
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Rayleigh", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            x,
            eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                  eval_arith(@symcore.pow(x, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Reciprocal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(-1),
            eval_arith(@symcore.pow(x, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("ShiftedGompertz", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.add([
                eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                eval_arith(
                  @symcore.mul([
                    params[1],
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[0], x])),
                    ]),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([params[0], x])),
                ]),
              ]),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.add([
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      params[1],
                      @symcore.function("exp", [
                        eval_arith(
                          @symcore.mul([@symcore.int(-1), params[0], x]),
                        ),
                      ]),
                    ]),
                  ),
                  eval_arith(@symcore.mul([@symcore.int(-2), params[0], x])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Skellam", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    params[0],
                    eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                  ]),
                ),
                eval_arith(@symcore.mul([stats_exact_rational(1, 2), x])),
              ),
            ),
            @symcore.function("besseli", [
              x,
              eval_arith(
                @symcore.mul([
                  @symcore.int(2),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(@symcore.mul([params[0], params[1]])),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
            ]),
            @symcore.function("exp", [
              eval_arith(
                @symcore.add([
                  eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("StudentT", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], stats_exact_rational(-1, 2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.pow(x, @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    stats_exact_rational(-1, 2),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [
                  stats_exact_rational(1, 2),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Trapezoidal", 4) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [params[0], x]),
              @symcore.function("Gt", [params[1], x]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [params[1], x]),
              @symcore.function("Gt", [params[2], x]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[2],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    params[3],
                    eval_arith(@symcore.mul([@symcore.int(-1), x])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[3], x]),
              @symcore.function("Le", [params[2], x]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Triangular", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [params[0], x]),
              @symcore.function("Gt", [params[2], x]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.function("Eq", [params[2], x]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    x,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[1], x]),
              @symcore.function("Lt", [params[2], x]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Uniform", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[1], x]),
              @symcore.function("Le", [params[0], x]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("VonMises", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                @symcore.function("besseli", [@symcore.int(0), params[1]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  params[1],
                  @symcore.function("cos", [
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Wald", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    params[1],
                    eval_arith(@symcore.pow(x, @symcore.int(-3))),
                  ]),
                ),
                stats_exact_rational(1, 2),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  params[1],
                  eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                  eval_arith(@symcore.pow(x, @symcore.int(-1))),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                      @symcore.int(2),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Weibull", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    x,
                    eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), params[1]])),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          x,
                          eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                        ]),
                      ),
                      params[1],
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("WignerSemicircle", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(@symcore.pow(x, @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                stats_exact_rational(1, 2),
              ),
            ),
          ]),
        ),
      )
    ("YuleSimon", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            @symcore.function("beta", [
              x,
              eval_arith(@symcore.add([@symcore.int(1), params[0]])),
            ]),
          ]),
        ),
      )
    ("Zeta", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                x,
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[0]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_cdf(
  name : String,
  params : Array[@symcore.Expr],
  x : @symcore.Expr,
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Arcsin", 0) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.int(0),
            @symcore.function("Lt", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1)),
                ),
                @symcore.function("asin", [
                  eval_arith(@symcore.pow(x, stats_exact_rational(1, 2))),
                ]),
              ]),
            ),
            @symcore.function("Le", [x, @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Benini", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.add([
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              params[0],
                              @symcore.function("log", [
                                eval_arith(
                                  @symcore.mul([
                                    x,
                                    eval_arith(
                                      @symcore.pow(params[2], @symcore.int(-1)),
                                    ),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              params[1],
                              eval_arith(
                                @symcore.pow(
                                  @symcore.function("log", [
                                    eval_arith(
                                      @symcore.mul([
                                        x,
                                        eval_arith(
                                          @symcore.pow(
                                            params[2],
                                            @symcore.int(-1),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ]),
                                  @symcore.int(2),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Le", [params[2], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Beta", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [params[1]]),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(@symcore.add([@symcore.int(1), params[0]])),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.pow(@symcore.int(0), params[0])),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(@symcore.pow(x, params[0])),
                        @symcore.function("hyper", [
                          @symcore.function("Tuple", [
                            params[0],
                            eval_arith(
                              @symcore.add([
                                @symcore.int(1),
                                eval_arith(
                                  @symcore.mul([@symcore.int(-1), params[1]]),
                                ),
                              ]),
                            ),
                          ]),
                          @symcore.function("Tuple", [
                            eval_arith(
                              @symcore.add([@symcore.int(1), params[0]]),
                            ),
                          ]),
                          eval_arith(
                            @symcore.mul([
                              x,
                              @symcore.function("exp_polar", [
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(2),
                                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("gamma", [
                  eval_arith(@symcore.add([params[0], params[1]])),
                ]),
              ]),
            ),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("BetaPrime", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [params[1]]),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(@symcore.add([@symcore.int(1), params[0]])),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.pow(@symcore.int(0), params[0])),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(@symcore.pow(x, params[0])),
                        @symcore.function("hyper", [
                          @symcore.function("Tuple", [
                            params[0],
                            eval_arith(@symcore.add([params[0], params[1]])),
                          ]),
                          @symcore.function("Tuple", [
                            eval_arith(
                              @symcore.add([@symcore.int(1), params[0]]),
                            ),
                          ]),
                          eval_arith(
                            @symcore.mul([
                              x,
                              @symcore.function("exp_polar", [
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("gamma", [
                  eval_arith(@symcore.add([params[0], params[1]])),
                ]),
              ]),
            ),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("BoundedPareto", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.pow(
                        x,
                        eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                      ),
                    ),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.pow(
                                eval_arith(
                                  @symcore.mul([
                                    params[1],
                                    eval_arith(
                                      @symcore.pow(params[2], @symcore.int(-1)),
                                    ),
                                  ]),
                                ),
                                params[0],
                              ),
                            ),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(@symcore.pow(params[1], params[0])),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            eval_arith(@symcore.pow(x, params[0])),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("And", [
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[0],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Gt", [params[0], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[0],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [params[0], @symcore.int(0)]),
                    @symcore.function("Lt", [params[0], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Lt", [params[0], @symcore.int(0)]),
                    @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                ]),
              ]),
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    params[0],
                    eval_arith(@symcore.pow(params[1], params[0])),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.pow(
                                eval_arith(
                                  @symcore.mul([
                                    params[1],
                                    eval_arith(
                                      @symcore.pow(params[2], @symcore.int(-1)),
                                    ),
                                  ]),
                                ),
                                params[0],
                              ),
                            ),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.function("log", [x]),
                          ]),
                        ),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("Ge", [params[0], @symcore.int(0)]),
              ]),
            ]),
            @symcore.function("Le", [params[1], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Cauchy", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(1, 2),
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("atan", [
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), x])),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("ChiSquared", 1) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("lowergamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                  eval_arith(@symcore.mul([stats_exact_rational(1, 2), x])),
                ]),
              ]),
            ),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Dagum", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            x,
                            eval_arith(
                              @symcore.pow(params[2], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ),
                    ),
                  ]),
                ),
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Erlang", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [params[0]]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("lowergamma", [
                  params[0],
                  eval_arith(@symcore.mul([params[1], x])),
                ]),
              ]),
            ),
            @symcore.function("Gt", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("ExGaussian", 3) =>
      Some(
        eval_arith(
          @symcore.add([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(-1, 2),
                @symcore.function("erf", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.pow(
                          @symcore.int(2),
                          stats_exact_rational(1, 2),
                        ),
                      ),
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    @symcore.function("erf", [
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 2),
                          eval_arith(
                            @symcore.pow(
                              @symcore.int(2),
                              stats_exact_rational(1, 2),
                            ),
                          ),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), x])),
                              eval_arith(
                                @symcore.mul([
                                  params[2],
                                  eval_arith(
                                    @symcore.pow(params[1], @symcore.int(2)),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      params[2],
                      eval_arith(
                        @symcore.add([
                          eval_arith(@symcore.mul([@symcore.int(-2), x])),
                          eval_arith(@symcore.mul([@symcore.int(2), params[0]])),
                          eval_arith(
                            @symcore.mul([
                              params[2],
                              eval_arith(
                                @symcore.pow(params[1], @symcore.int(2)),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("ExponentialPower", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            stats_exact_rational(1, 2),
            @symcore.function("Eq", [params[0], x]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("Abs", [
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.add([
                          @symcore.int(1),
                          eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                        ]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        x,
                        @symcore.function("lowergamma", [
                          eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                          eval_arith(
                            @symcore.pow(
                              eval_arith(
                                @symcore.mul([
                                  eval_arith(
                                    @symcore.pow(params[1], @symcore.int(-1)),
                                  ),
                                  @symcore.function("Abs", [
                                    eval_arith(
                                      @symcore.add([
                                        params[0],
                                        eval_arith(
                                          @symcore.mul([@symcore.int(-1), x]),
                                        ),
                                      ]),
                                    ),
                                  ]),
                                ]),
                              ),
                              params[2],
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        params[0],
                        @symcore.function("lowergamma", [
                          eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                          eval_arith(
                            @symcore.pow(
                              eval_arith(
                                @symcore.mul([
                                  eval_arith(
                                    @symcore.pow(params[1], @symcore.int(-1)),
                                  ),
                                  @symcore.function("Abs", [
                                    eval_arith(
                                      @symcore.add([
                                        params[0],
                                        eval_arith(
                                          @symcore.mul([@symcore.int(-1), x]),
                                        ),
                                      ]),
                                    ),
                                  ]),
                                ]),
                              ),
                              params[2],
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        params[2],
                        @symcore.function("Abs", [
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), x])),
                            ]),
                          ),
                        ]),
                        @symcore.function("gamma", [
                          eval_arith(
                            @symcore.add([
                              @symcore.int(1),
                              eval_arith(
                                @symcore.pow(params[2], @symcore.int(-1)),
                              ),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("FlorySchulz", 1) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            @symcore.function("floor", [x]),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    params[0],
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            @symcore.function("floor", [x]),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            @symcore.function("floor", [x]),
                          ]),
                        ),
                      ),
                    ),
                    @symcore.function("floor", [x]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    params[0],
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            @symcore.function("floor", [x]),
                          ]),
                        ),
                      ),
                    ),
                    @symcore.function("floor", [x]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Ge", [x, @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Frechet", 1) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      x,
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ),
                  ),
                ]),
              ),
            ]),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("GammaInverse", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [params[0]]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("uppergamma", [
                  params[0],
                  eval_arith(
                    @symcore.mul([
                      params[1],
                      eval_arith(@symcore.pow(x, @symcore.int(-1))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("Gt", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("GaussianInverse", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(-1, 2),
                @symcore.function("erf", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.pow(
                          @symcore.int(2),
                          stats_exact_rational(1, 2),
                        ),
                      ),
                      eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                      eval_arith(
                        @symcore.pow(
                          eval_arith(
                            @symcore.mul([
                              params[1],
                              eval_arith(@symcore.pow(x, @symcore.int(-1))),
                            ]),
                          ),
                          stats_exact_rational(1, 2),
                        ),
                      ),
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("erf", [
                          eval_arith(
                            @symcore.mul([
                              stats_exact_rational(1, 2),
                              eval_arith(
                                @symcore.pow(
                                  @symcore.int(2),
                                  stats_exact_rational(1, 2),
                                ),
                              ),
                              eval_arith(
                                @symcore.pow(params[0], @symcore.int(-1)),
                              ),
                              eval_arith(
                                @symcore.pow(
                                  eval_arith(
                                    @symcore.mul([
                                      params[1],
                                      eval_arith(
                                        @symcore.pow(x, @symcore.int(-1)),
                                      ),
                                    ]),
                                  ),
                                  stats_exact_rational(1, 2),
                                ),
                              ),
                              eval_arith(@symcore.add([params[0], x])),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      params[1],
                      eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Gompertz", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            @symcore.int(1),
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.add([
                      params[1],
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          params[1],
                          @symcore.function("exp", [
                            eval_arith(@symcore.mul([params[0], x])),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Gumbel", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              @symcore.function("exp", [
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                    eval_arith(
                      @symcore.add([
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), x])),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      )
    ("Kumaraswamy", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.int(0),
            @symcore.function("Lt", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                eval_arith(@symcore.pow(x, params[0])),
                              ]),
                            ),
                          ]),
                        ),
                        params[1],
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Le", [x, @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Laplace", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                      eval_arith(
                        @symcore.add([
                          x,
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[0]]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("Gt", [params[0], x]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(-1, 2),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), x])),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("Levy", 2) =>
      Some(
        @symcore.function("erfc", [
          eval_arith(
            @symcore.mul([
              stats_exact_rational(1, 2),
              eval_arith(
                @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
              ),
              eval_arith(
                @symcore.pow(
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      params[1],
                      eval_arith(
                        @symcore.pow(
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), x])),
                            ]),
                          ),
                          @symcore.int(-1),
                        ),
                      ),
                    ]),
                  ),
                  stats_exact_rational(1, 2),
                ),
              ),
            ]),
          ),
        ]),
      )
    ("LogCauchy", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1))),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(1, 2),
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("atan", [
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(
                                @symcore.mul([
                                  @symcore.int(-1),
                                  @symcore.function("log", [x]),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("LogLogistic", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    x,
                    eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                  ]),
                ),
                params[1],
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            x,
                            eval_arith(
                              @symcore.pow(params[0], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        params[1],
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("LogNormal", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                stats_exact_rational(1, 2),
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(-1, 2),
                    @symcore.function("erf", [
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 2),
                          eval_arith(
                            @symcore.pow(
                              @symcore.int(2),
                              stats_exact_rational(1, 2),
                            ),
                          ),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(
                                @symcore.mul([
                                  @symcore.int(-1),
                                  @symcore.function("log", [x]),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Gt", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Logistic", 2) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.int(-1),
          ),
        ),
      )
    ("LogitNormal", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(-1, 2),
                @symcore.function("erf", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.pow(
                          @symcore.int(2),
                          stats_exact_rational(1, 2),
                        ),
                      ),
                      eval_arith(
                        @symcore.pow(
                          eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                          stats_exact_rational(-1, 2),
                        ),
                      ),
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              @symcore.function("log", [
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    x,
                                    eval_arith(
                                      @symcore.pow(
                                        eval_arith(
                                          @symcore.add([@symcore.int(-1), x]),
                                        ),
                                        @symcore.int(-1),
                                      ),
                                    ),
                                  ]),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Lomax", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        eval_arith(
                          @symcore.pow(
                            eval_arith(
                              @symcore.add([
                                @symcore.int(1),
                                eval_arith(
                                  @symcore.mul([
                                    x,
                                    eval_arith(
                                      @symcore.pow(params[1], @symcore.int(-1)),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("And", [
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[0],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Gt", [params[0], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[0],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [params[0], @symcore.int(0)]),
                    @symcore.function("Lt", [params[0], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Lt", [params[0], @symcore.int(0)]),
                    @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                ]),
              ]),
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    params[0],
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(@symcore.add([params[1], x])),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("Ge", [params[0], @symcore.int(0)]),
              ]),
            ]),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Maxwell", 1) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                x,
                eval_arith(
                  @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    stats_exact_rational(-1, 2),
                  ),
                ),
                eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(-1, 2),
                      eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                      eval_arith(@symcore.pow(x, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("erf", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(1, 2),
                  x,
                  eval_arith(
                    @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                  ),
                  eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Nakagami", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [params[0]]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("lowergamma", [
                  params[0],
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                      eval_arith(@symcore.pow(x, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("Gt", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Pareto", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(@symcore.pow(params[0], params[1])),
                    eval_arith(
                      @symcore.pow(
                        x,
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Le", [params[0], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("PowerFunction", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[2],
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[1]]),
                            ),
                          ]),
                        ),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.pow(
                            eval_arith(
                              @symcore.add([
                                x,
                                eval_arith(
                                  @symcore.mul([@symcore.int(-1), params[1]]),
                                ),
                              ]),
                            ),
                            params[0],
                          ),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            eval_arith(@symcore.pow(@symcore.int(0), params[0])),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("And", [
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[0],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Gt", [params[0], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[0],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [params[0], @symcore.int(0)]),
                    @symcore.function("Lt", [params[0], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Lt", [params[0], @symcore.int(0)]),
                    @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                ]),
              ]),
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    params[0],
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[2],
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[1]]),
                            ),
                          ]),
                        ),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
                            @symcore.function("Abs", [
                              eval_arith(
                                @symcore.mul([
                                  eval_arith(
                                    @symcore.pow(params[0], @symcore.int(-1)),
                                  ),
                                  eval_arith(
                                    @symcore.pow(
                                      eval_arith(
                                        @symcore.mul([
                                          @symcore.int(-1),
                                          eval_arith(
                                            @symcore.add([
                                              params[1],
                                              eval_arith(
                                                @symcore.mul([
                                                  @symcore.int(-1),
                                                  params[2],
                                                ]),
                                              ),
                                            ]),
                                          ),
                                        ]),
                                      ),
                                      params[0],
                                    ),
                                  ),
                                ]),
                              ),
                            ]),
                          ]),
                        ),
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.add([
                              x,
                              eval_arith(
                                @symcore.mul([@symcore.int(-1), params[1]]),
                              ),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("Ge", [params[0], @symcore.int(0)]),
              ]),
            ]),
            @symcore.function("Le", [params[1], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("QuadraticU", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            eval_arith(@symcore.pow(params[0], @symcore.int(3))),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(3)),
                                ),
                              ]),
                            ),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-3),
                                params[1],
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(2)),
                                ),
                              ]),
                            ),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(3),
                                params[0],
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(2)),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-4),
                            eval_arith(
                              @symcore.pow(
                                @symcore.function("Min", [
                                  x,
                                  @symcore.function("Max", [
                                    params[0],
                                    params[1],
                                  ]),
                                ]),
                                @symcore.int(3),
                              ),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(4),
                            eval_arith(@symcore.pow(params[0], @symcore.int(3))),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-6),
                            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                            eval_arith(@symcore.add([params[0], params[1]])),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-3),
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(2),
                                    params[0],
                                    params[1],
                                  ]),
                                ),
                              ]),
                            ),
                            @symcore.function("Min", [
                              x,
                              @symcore.function("Max", [params[0], params[1]]),
                            ]),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(3),
                            params[0],
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(2),
                                    params[0],
                                    params[1],
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(6),
                            eval_arith(
                              @symcore.pow(
                                @symcore.function("Min", [
                                  x,
                                  @symcore.function("Max", [
                                    params[0],
                                    params[1],
                                  ]),
                                ]),
                                @symcore.int(2),
                              ),
                            ),
                            eval_arith(@symcore.add([params[0], params[1]])),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("Lt", [params[0], x]),
              ]),
              @symcore.function("Tuple", [
                @symcore.int(0),
                @symcore.Expr::Boolean(true),
              ]),
            ]),
            @symcore.function("Le", [params[0], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("RaisedCosine", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(1, 2),
                    eval_arith(
                      @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-1)),
                    ),
                    eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            eval_arith(
                              @symcore.add([
                                params[1],
                                eval_arith(
                                  @symcore.mul([@symcore.int(-1), params[0]]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.function("Min", [
                              x,
                              @symcore.function("Max", [
                                eval_arith(@symcore.add([params[0], params[1]])),
                                eval_arith(
                                  @symcore.add([
                                    params[0],
                                    eval_arith(
                                      @symcore.mul([@symcore.int(-1), params[1]]),
                                    ),
                                  ]),
                                ),
                              ]),
                            ]),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            params[1],
                            @symcore.function("sin", [
                              eval_arith(
                                @symcore.mul([
                                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                  eval_arith(
                                    @symcore.pow(params[1], @symcore.int(-1)),
                                  ),
                                  eval_arith(
                                    @symcore.add([
                                      params[0],
                                      eval_arith(
                                        @symcore.mul([
                                          @symcore.int(-1),
                                          @symcore.function("Min", [
                                            x,
                                            @symcore.function("Max", [
                                              eval_arith(
                                                @symcore.add([
                                                  params[0],
                                                  params[1],
                                                ]),
                                              ),
                                              eval_arith(
                                                @symcore.add([
                                                  params[0],
                                                  eval_arith(
                                                    @symcore.mul([
                                                      @symcore.int(-1),
                                                      params[1],
                                                    ]),
                                                  ),
                                                ]),
                                              ),
                                            ]),
                                          ]),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                ]),
                              ),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("Lt", [
                  params[0],
                  eval_arith(@symcore.add([params[1], x])),
                ]),
              ]),
              @symcore.function("Tuple", [
                @symcore.int(0),
                @symcore.Expr::Boolean(true),
              ]),
            ]),
            @symcore.function("Le", [
              params[0],
              eval_arith(@symcore.add([params[1], x])),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Rayleigh", 1) =>
      Some(
        eval_arith(
          @symcore.add([
            @symcore.int(1),
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(-1, 2),
                      eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                      eval_arith(@symcore.pow(x, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Reciprocal", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.function("log", [params[1]]),
                          ]),
                        ),
                        @symcore.function("log", [params[0]]),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [x]),
                      ]),
                    ),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Le", [params[0], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("ShiftedGompertz", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[0], x])),
                    ]),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.add([
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0], x])),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          params[1],
                          @symcore.function("exp", [
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0], x]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("StudentT", 1) =>
      Some(
        eval_arith(
          @symcore.add([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                x,
                eval_arith(
                  @symcore.pow(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    stats_exact_rational(-1, 2),
                  ),
                ),
                eval_arith(@symcore.pow(params[0], stats_exact_rational(1, 2))),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.add([
                          @symcore.int(1),
                          eval_arith(
                            @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                          ),
                        ]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.add([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                  ),
                ]),
                @symcore.function("hyper", [
                  @symcore.function("Tuple", [
                    stats_exact_rational(1, 2),
                    eval_arith(
                      @symcore.add([
                        stats_exact_rational(1, 2),
                        eval_arith(
                          @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                        ),
                      ]),
                    ),
                  ]),
                  @symcore.function("Tuple", [stats_exact_rational(3, 2)]),
                  eval_arith(
                    @symcore.mul([
                      eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                      eval_arith(@symcore.pow(x, @symcore.int(2))),
                      @symcore.function("exp_polar", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Triangular", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                            eval_arith(@symcore.mul([params[1], params[2]])),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                params[0],
                                params[1],
                              ]),
                            ),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                params[0],
                                params[2],
                              ]),
                            ),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(2)),
                                ),
                              ]),
                            ),
                            eval_arith(@symcore.mul([params[0], params[1]])),
                            eval_arith(@symcore.mul([params[1], params[2]])),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                params[0],
                                params[2],
                              ]),
                            ),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.pow(
                                    @symcore.function("Min", [
                                      x,
                                      @symcore.function("Max", [
                                        params[0],
                                        params[2],
                                      ]),
                                    ]),
                                    @symcore.int(2),
                                  ),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-2),
                                    params[0],
                                    @symcore.function("Min", [
                                      x,
                                      @symcore.function("Max", [
                                        params[0],
                                        params[2],
                                      ]),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ),
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    eval_arith(
                                      @symcore.pow(params[1], @symcore.int(2)),
                                    ),
                                  ]),
                                ),
                                eval_arith(@symcore.mul([params[0], params[1]])),
                                eval_arith(@symcore.mul([params[1], params[2]])),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    params[0],
                                    params[2],
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(2)),
                                ),
                                eval_arith(@symcore.mul([params[1], params[2]])),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    params[0],
                                    params[1],
                                  ]),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    params[0],
                                    params[2],
                                  ]),
                                ),
                              ]),
                            ),
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.pow(
                                    @symcore.function("Min", [
                                      x,
                                      @symcore.function("Max", [
                                        params[0],
                                        params[1],
                                        params[2],
                                      ]),
                                    ]),
                                    @symcore.int(2),
                                  ),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    eval_arith(
                                      @symcore.pow(
                                        @symcore.function("Min", [
                                          x,
                                          @symcore.function("Max", [
                                            params[0],
                                            params[2],
                                          ]),
                                        ]),
                                        @symcore.int(2),
                                      ),
                                    ),
                                  ]),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-2),
                                    params[1],
                                    @symcore.function("Min", [
                                      x,
                                      @symcore.function("Max", [
                                        params[0],
                                        params[1],
                                        params[2],
                                      ]),
                                    ]),
                                  ]),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(2),
                                    params[1],
                                    @symcore.function("Min", [
                                      x,
                                      @symcore.function("Max", [
                                        params[0],
                                        params[2],
                                      ]),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("Lt", [params[0], x]),
              ]),
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(2)),
                                ),
                              ]),
                            ),
                            eval_arith(@symcore.mul([params[0], params[1]])),
                            eval_arith(@symcore.mul([params[1], params[2]])),
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(-1),
                                params[0],
                                params[2],
                              ]),
                            ),
                          ]),
                        ),
                        @symcore.int(-1),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.pow(
                            @symcore.function("Min", [
                              params[0],
                              @symcore.function("Max", [params[2], x]),
                            ]),
                            @symcore.int(2),
                          ),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.pow(
                                @symcore.function("Min", [
                                  params[0],
                                  @symcore.function("Max", [
                                    params[1],
                                    params[2],
                                    x,
                                  ]),
                                ]),
                                @symcore.int(2),
                              ),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-2),
                            params[1],
                            @symcore.function("Min", [
                              params[0],
                              @symcore.function("Max", [params[2], x]),
                            ]),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(2),
                            params[1],
                            @symcore.function("Min", [
                              params[0],
                              @symcore.function("Max", [params[1], params[2], x]),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.Expr::Boolean(true),
              ]),
            ]),
            @symcore.function("Le", [params[0], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Uniform", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.int(0),
            @symcore.function("Gt", [params[0], x]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), x])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Ge", [params[1], x]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Wald", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(-1, 2),
                @symcore.function("erf", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.pow(
                          @symcore.int(2),
                          stats_exact_rational(1, 2),
                        ),
                      ),
                      eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                      eval_arith(
                        @symcore.pow(
                          eval_arith(
                            @symcore.mul([
                              params[1],
                              eval_arith(@symcore.pow(x, @symcore.int(-1))),
                            ]),
                          ),
                          stats_exact_rational(1, 2),
                        ),
                      ),
                      eval_arith(
                        @symcore.add([
                          params[0],
                          eval_arith(@symcore.mul([@symcore.int(-1), x])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("erf", [
                          eval_arith(
                            @symcore.mul([
                              stats_exact_rational(1, 2),
                              eval_arith(
                                @symcore.pow(
                                  @symcore.int(2),
                                  stats_exact_rational(1, 2),
                                ),
                              ),
                              eval_arith(
                                @symcore.pow(params[0], @symcore.int(-1)),
                              ),
                              eval_arith(
                                @symcore.pow(
                                  eval_arith(
                                    @symcore.mul([
                                      params[1],
                                      eval_arith(
                                        @symcore.pow(x, @symcore.int(-1)),
                                      ),
                                    ]),
                                  ),
                                  stats_exact_rational(1, 2),
                                ),
                              ),
                              eval_arith(@symcore.add([params[0], x])),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(2),
                      params[1],
                      eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Weibull", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              eval_arith(
                                @symcore.pow(
                                  eval_arith(
                                    @symcore.mul([
                                      x,
                                      eval_arith(
                                        @symcore.pow(
                                          params[0],
                                          @symcore.int(-1),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  params[1],
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          eval_arith(@symcore.pow(@symcore.int(0), params[1])),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("And", [
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[1],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Gt", [params[1], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [
                      params[1],
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                    ]),
                    @symcore.function("Lt", [params[1], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Gt", [params[1], @symcore.int(0)]),
                    @symcore.function("Lt", [params[1], @symcore.int(0)]),
                  ]),
                  @symcore.function("Or", [
                    @symcore.function("Lt", [params[1], @symcore.int(0)]),
                    @symcore.function("Lt", [params[1], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                  ]),
                ]),
              ]),
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    params[1],
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
                            eval_arith(
                              @symcore.pow(
                                @symcore.function("Abs", [params[1]]),
                                @symcore.int(-1),
                              ),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.function("exp", [@symcore.int(-1)]),
                            @symcore.function("log", [x]),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("Ge", [params[1], @symcore.int(0)]),
              ]),
            ]),
            @symcore.function("Ge", [x, @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("YuleSimon", 1) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("beta", [
                      @symcore.function("floor", [x]),
                      eval_arith(@symcore.add([@symcore.int(1), params[0]])),
                    ]),
                    @symcore.function("floor", [x]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Ge", [x, @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    _ => None
  }
}

///|
fn generated_pmf(
  name : String,
  params : Array[@symcore.Expr],
  k : @symcore.Expr,
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Beta", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(@symcore.mul([@symcore.int(-1), k])),
                  ]),
                ),
                eval_arith(@symcore.add([@symcore.int(-1), params[1]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [params[0], params[1]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("BetaBinomial", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [params[1], params[2]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("binomial", [params[0], k]),
            @symcore.function("beta", [
              eval_arith(@symcore.add([params[1], k])),
              eval_arith(
                @symcore.add([
                  params[0],
                  params[2],
                  eval_arith(@symcore.mul([@symcore.int(-1), k])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("BetaPrime", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(1), k])),
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [params[0], params[1]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Chi", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.int(2),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(k, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ChiSquared", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.int(2),
                eval_arith(
                  @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([stats_exact_rational(-1, 2), k])),
            ]),
          ]),
        ),
      )
    ("Davis", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], params[1])),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [
                          eval_arith(
                            @symcore.mul([
                              params[0],
                              eval_arith(
                                @symcore.pow(
                                  eval_arith(
                                    @symcore.add([
                                      params[2],
                                      eval_arith(
                                        @symcore.mul([@symcore.int(-1), k]),
                                      ),
                                    ]),
                                  ),
                                  @symcore.int(-1),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    k,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[1]]),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[1]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  params[0],
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.add([
                          params[2],
                          eval_arith(@symcore.mul([@symcore.int(-1), k])),
                        ]),
                      ),
                      @symcore.int(-1),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Erlang", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.int(-1), params[1], k])),
            ]),
          ]),
        ),
      )
    ("ExponentialPower", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
                    ]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          @symcore.function("Abs", [
                            eval_arith(
                              @symcore.add([
                                params[0],
                                eval_arith(@symcore.mul([@symcore.int(-1), k])),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                      params[2],
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("FDistribution", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(k, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[1], params[1])),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(@symcore.mul([params[0], k])),
                        params[0],
                      ),
                    ),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.add([
                            params[1],
                            eval_arith(@symcore.mul([params[0], k])),
                          ]),
                        ),
                        eval_arith(
                          @symcore.add([
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[0]]),
                            ),
                            eval_arith(
                              @symcore.mul([@symcore.int(-1), params[1]]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                stats_exact_rational(1, 2),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("FisherZ", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(
              @symcore.pow(
                params[0],
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                params[1],
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(
                      @symcore.mul([
                        params[0],
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([@symcore.int(2), k])),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                    ),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[1]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [eval_arith(@symcore.mul([params[0], k]))]),
          ]),
        ),
      )
    ("GammaInverse", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[1], params[0])),
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[1],
                  eval_arith(@symcore.pow(k, @symcore.int(-1))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Hypergeometric", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("binomial", [params[0], params[2]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("binomial", [params[1], k]),
            @symcore.function("binomial", [
              eval_arith(
                @symcore.add([
                  params[0],
                  eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                ]),
              ),
              eval_arith(
                @symcore.add([
                  params[2],
                  eval_arith(@symcore.mul([@symcore.int(-1), k])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Nakagami", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(params[0], params[0])),
            eval_arith(
              @symcore.pow(
                params[1],
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(@symcore.mul([@symcore.int(2), params[0]])),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[0],
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                  eval_arith(@symcore.pow(k, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("QuadraticU", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-3),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-3),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-2), k])),
                      ]),
                    ),
                    @symcore.int(2),
                  ),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[1], k]),
              @symcore.function("Le", [params[0], k]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("RaisedCosine", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.function("cos", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[0],
                              eval_arith(@symcore.mul([@symcore.int(-1), k])),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [
                params[0],
                eval_arith(@symcore.add([params[1], k])),
              ]),
              @symcore.function("Ge", [
                params[0],
                eval_arith(
                  @symcore.add([
                    k,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("StudentT", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], stats_exact_rational(-1, 2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.pow(k, @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.add([
                    stats_exact_rational(-1, 2),
                    eval_arith(
                      @symcore.mul([stats_exact_rational(-1, 2), params[0]]),
                    ),
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("beta", [
                  stats_exact_rational(1, 2),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Trapezoidal", 4) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    k,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [params[0], k]),
              @symcore.function("Gt", [params[1], k]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [params[1], k]),
              @symcore.function("Gt", [params[2], k]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[2],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                        eval_arith(@symcore.mul([@symcore.int(-1), params[3]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    params[3],
                    eval_arith(@symcore.mul([@symcore.int(-1), k])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[3], k]),
              @symcore.function("Le", [params[2], k]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Triangular", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    k,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Le", [params[0], k]),
              @symcore.function("Gt", [params[2], k]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.function("Eq", [params[2], k]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    k,
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[1], k]),
              @symcore.function("Lt", [params[2], k]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Uniform", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Ge", [params[1], k]),
              @symcore.function("Le", [params[0], k]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("YuleSimon", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            @symcore.function("beta", [
              k,
              eval_arith(@symcore.add([@symcore.int(1), params[0]])),
            ]),
          ]),
        ),
      )
    ("Zeta", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                k,
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[0]]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_mean(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Arcsin", 0) => Some(stats_exact_rational(1, 2))
    ("Beta", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([params[0], params[1]])),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("BoundedPareto", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                params[0],
                eval_arith(
                  @symcore.pow(
                    eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        @symcore.int(-1),
                        eval_arith(
                          @symcore.pow(
                            eval_arith(
                              @symcore.mul([
                                params[1],
                                eval_arith(
                                  @symcore.pow(params[2], @symcore.int(-1)),
                                ),
                              ]),
                            ),
                            params[0],
                          ),
                        ),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.pow(params[1], params[0])),
                        eval_arith(
                          @symcore.pow(
                            params[2],
                            eval_arith(
                              @symcore.add([
                                @symcore.int(1),
                                eval_arith(
                                  @symcore.mul([@symcore.int(-1), params[0]]),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Or", [
                @symcore.function("Gt", [
                  params[0],
                  @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                ]),
                @symcore.function("Gt", [params[0], @symcore.int(1)]),
              ]),
              @symcore.function("Or", [
                @symcore.function("Gt", [
                  params[0],
                  @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                ]),
                @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
              ]),
              @symcore.function("Or", [
                @symcore.function("Gt", [params[0], @symcore.int(1)]),
                @symcore.function("Lt", [params[0], @symcore.int(1)]),
              ]),
              @symcore.function("Or", [
                @symcore.function("Lt", [params[0], @symcore.int(1)]),
                @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
              ]),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                params[0],
                eval_arith(@symcore.pow(params[1], params[0])),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        @symcore.int(-1),
                        eval_arith(
                          @symcore.pow(
                            eval_arith(
                              @symcore.mul([
                                params[1],
                                eval_arith(
                                  @symcore.pow(params[2], @symcore.int(-1)),
                                ),
                              ]),
                            ),
                            params[0],
                          ),
                        ),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[2]]),
                      ]),
                    ),
                    @symcore.function("log", [params[1]]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Ge", [params[0], @symcore.int(1)]),
          ]),
        ]),
      )
    ("Chi", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("gamma", [
              eval_arith(
                @symcore.add([
                  stats_exact_rational(1, 2),
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ChiSquared", 1) => Some(params[0])
    ("Erlang", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
          ]),
        ),
      )
    ("ExGaussian", 3) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(@symcore.pow(params[2], @symcore.int(-1))),
          ]),
        ),
      )
    ("FlorySchulz", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
            eval_arith(
              @symcore.add([
                @symcore.int(2),
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ]),
            ),
          ]),
        ),
      )
    ("GaussianInverse", 2) => Some(params[0])
    ("Gompertz", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(-1),
            eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
            @symcore.function("exp", [params[1]]),
            @symcore.function("meijerg", [
              @symcore.function("Tuple", [
                @symcore.function("Tuple", []),
                @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)]),
              ]),
              @symcore.function("Tuple", [
                @symcore.function("Tuple", [
                  @symcore.int(0),
                  @symcore.int(0),
                  @symcore.int(1),
                ]),
                @symcore.function("Tuple", []),
              ]),
              params[1],
            ]),
          ]),
        ),
      )
    ("Gumbel", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[1],
            eval_arith(
              @symcore.mul([params[0], @symcore.function("EulerGamma", [])]),
            ),
          ]),
        ),
      )
    ("Hermite", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(@symcore.mul([@symcore.int(2), params[1]])),
          ]),
        ),
      )
    ("Laplace", 2) => Some(params[0])
    ("LogLogistic", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
            @symcore.function("Le", [params[1], @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                params[0],
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("sin", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                        ]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("Logarithmic", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("log", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Logistic", 2) => Some(params[0])
    ("Moyal", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(
              @symcore.mul([params[1], @symcore.function("EulerGamma", [])]),
            ),
            eval_arith(
              @symcore.mul([
                params[1],
                @symcore.function("log", [@symcore.int(2)]),
              ]),
            ),
          ]),
        ),
      )
    ("PowerFunction", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.function("Piecewise", [
              @symcore.function("Tuple", [
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
                @symcore.function("Eq", [
                  eval_arith(
                    @symcore.mul([
                      params[1],
                      eval_arith(
                        @symcore.add([
                          params[2],
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[1]]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  @symcore.int(0),
                ]),
              ]),
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.add([
                        params[2],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
                            params[1],
                            eval_arith(
                              @symcore.pow(
                                @symcore.function("Abs", [
                                  eval_arith(
                                    @symcore.mul([
                                      params[1],
                                      eval_arith(
                                        @symcore.add([
                                          params[1],
                                          eval_arith(
                                            @symcore.mul([
                                              @symcore.int(-1),
                                              params[2],
                                            ]),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                ]),
                                @symcore.int(-1),
                              ),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.pow(
                                eval_arith(
                                  @symcore.add([
                                    params[2],
                                    eval_arith(
                                      @symcore.mul([@symcore.int(-1), params[1]]),
                                    ),
                                  ]),
                                ),
                                @symcore.int(-1),
                              ),
                            ),
                            eval_arith(
                              @symcore.add([
                                params[1],
                                eval_arith(
                                  @symcore.mul([
                                    params[1],
                                    @symcore.function("log", [
                                      eval_arith(
                                        @symcore.add([
                                          params[2],
                                          eval_arith(
                                            @symcore.mul([
                                              @symcore.int(-1),
                                              params[1],
                                            ]),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                  ]),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    params[2],
                                    @symcore.function("log", [
                                      eval_arith(
                                        @symcore.add([
                                          params[2],
                                          eval_arith(
                                            @symcore.mul([
                                              @symcore.int(-1),
                                              params[1],
                                            ]),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
                @symcore.Expr::Boolean(true),
              ]),
            ]),
            @symcore.function("Eq", [params[0], @symcore.int(-1)]),
          ]),
          @symcore.function("Tuple", [
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
            @symcore.function("Eq", [params[0], @symcore.int(0)]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(
                  @symcore.pow(
                    eval_arith(@symcore.add([@symcore.int(1), params[0]])),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(@symcore.mul([params[0], params[2]])),
                  ]),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("QuadraticU", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                ),
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[1]]),
                ),
              ]),
            ),
            @symcore.function("Lt", [params[0], params[1]]),
          ]),
          @symcore.function("Tuple", [@symcore.int(0), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("RaisedCosine", 2) => Some(params[0])
    ("Rayleigh", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            params[0],
            eval_arith(
              @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(1, 2)),
            ),
          ]),
        ),
      )
    ("Reciprocal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                params[0],
                eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
              ]),
            ),
          ]),
        ),
      )
    ("Skellam", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
          ]),
        ),
      )
    ("Triangular", 3) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(@symcore.mul([stats_exact_rational(1, 3), params[0]])),
            eval_arith(@symcore.mul([stats_exact_rational(1, 3), params[1]])),
            eval_arith(@symcore.mul([stats_exact_rational(1, 3), params[2]])),
          ]),
        ),
      )
    ("Uniform", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(@symcore.mul([stats_exact_rational(1, 2), params[0]])),
            eval_arith(@symcore.mul([stats_exact_rational(1, 2), params[1]])),
          ]),
        ),
      )
    ("UniformSum", 1) =>
      Some(eval_arith(@symcore.mul([stats_exact_rational(1, 2), params[0]])))
    ("Wald", 2) => Some(params[0])
    ("WignerSemicircle", 1) => Some(@symcore.int(0))
    ("YuleSimon", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Zeta", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("zeta", [
              eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
            ]),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_variance(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Beta", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            params[1],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                    eval_arith(@symcore.pow(params[0], @symcore.int(3))),
                    eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                    eval_arith(@symcore.pow(params[1], @symcore.int(3))),
                    eval_arith(
                      @symcore.mul([@symcore.int(2), params[0], params[1]]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(3),
                        params[0],
                        eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                      ]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(3),
                        params[1],
                        eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
          ]),
        ),
      )
    ("Chi", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                  ),
                ]),
                @symcore.int(-2),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        @symcore.function("gamma", [
                          eval_arith(
                            @symcore.add([
                              stats_exact_rational(1, 2),
                              eval_arith(
                                @symcore.mul([
                                  stats_exact_rational(1, 2),
                                  params[0],
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                        @symcore.int(2),
                      ),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.add([
                          @symcore.int(1),
                          eval_arith(
                            @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("ChiSquared", 1) =>
      Some(eval_arith(@symcore.mul([@symcore.int(2), params[0]])))
    ("Erlang", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(@symcore.pow(params[1], @symcore.int(-2))),
          ]),
        ),
      )
    ("ExGaussian", 3) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(@symcore.pow(params[1], @symcore.int(2))),
            eval_arith(@symcore.pow(params[2], @symcore.int(-2))),
          ]),
        ),
      )
    ("FlorySchulz", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
              ]),
            ),
          ]),
        ),
      )
    ("GaussianInverse", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], @symcore.int(3))),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
          ]),
        ),
      )
    ("Gompertz", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("meijerg", [
                      @symcore.function("Tuple", [
                        @symcore.function("Tuple", []),
                        @symcore.function("Tuple", [
                          @symcore.int(1),
                          @symcore.int(1),
                        ]),
                      ]),
                      @symcore.function("Tuple", [
                        @symcore.function("Tuple", [
                          @symcore.int(0),
                          @symcore.int(0),
                          @symcore.int(1),
                        ]),
                        @symcore.function("Tuple", []),
                      ]),
                      params[1],
                    ]),
                    @symcore.int(2),
                  ),
                ),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([@symcore.int(2), params[1]])),
                ]),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(@symcore.pow(params[0], @symcore.int(-2))),
                @symcore.function("exp", [params[1]]),
                @symcore.function("meijerg", [
                  @symcore.function("Tuple", [
                    @symcore.function("Tuple", []),
                    @symcore.function("Tuple", [
                      @symcore.int(1),
                      @symcore.int(1),
                      @symcore.int(1),
                    ]),
                  ]),
                  @symcore.function("Tuple", [
                    @symcore.function("Tuple", [
                      @symcore.int(0),
                      @symcore.int(0),
                      @symcore.int(0),
                      @symcore.int(1),
                    ]),
                    @symcore.function("Tuple", []),
                  ]),
                  params[1],
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Gumbel", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 6),
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
          ]),
        ),
      )
    ("Hermite", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(@symcore.mul([@symcore.int(4), params[1]])),
          ]),
        ),
      )
    ("Laplace", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(params[1], @symcore.int(2))),
          ]),
        ),
      )
    ("LogLogistic", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
            @symcore.function("Le", [params[1], @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                params[0],
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("sin", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                        ]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("Logarithmic", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                    eval_arith(@symcore.mul([@symcore.int(-2), params[0]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("log", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ]),
                  ),
                ]),
                @symcore.int(-2),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.add([
                          @symcore.int(1),
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[0]]),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("Logistic", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 3),
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
            eval_arith(@symcore.pow(params[1], @symcore.int(2))),
          ]),
        ),
      )
    ("Moyal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
            eval_arith(@symcore.pow(params[1], @symcore.int(2))),
          ]),
        ),
      )
    ("RaisedCosine", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 3),
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(-2))),
            eval_arith(@symcore.pow(params[1], @symcore.int(2))),
            eval_arith(
              @symcore.add([
                @symcore.int(-6),
                eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
              ]),
            ),
          ]),
        ),
      )
    ("Rayleigh", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
            eval_arith(
              @symcore.add([
                @symcore.int(4),
                eval_arith(
                  @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("Reciprocal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.pow(
                        @symcore.function("log", [params[0]]),
                        @symcore.int(2),
                      ),
                    ),
                    eval_arith(
                      @symcore.pow(
                        @symcore.function("log", [params[1]]),
                        @symcore.int(2),
                      ),
                    ),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-2),
                        @symcore.function("log", [params[0]]),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-2),
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-2),
                    eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                    @symcore.function("log", [params[1]]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                    @symcore.function("log", [params[1]]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([@symcore.int(4), params[0], params[1]]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("Skellam", 2) => Some(eval_arith(@symcore.add([params[0], params[1]])))
    ("Triangular", 3) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 18),
                eval_arith(@symcore.pow(params[0], @symcore.int(2))),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 18),
                eval_arith(@symcore.pow(params[1], @symcore.int(2))),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 18),
                eval_arith(@symcore.pow(params[2], @symcore.int(2))),
              ]),
            ),
            eval_arith(
              @symcore.mul([stats_exact_rational(-1, 18), params[0], params[1]]),
            ),
            eval_arith(
              @symcore.mul([stats_exact_rational(-1, 18), params[0], params[2]]),
            ),
            eval_arith(
              @symcore.mul([stats_exact_rational(-1, 18), params[1], params[2]]),
            ),
          ]),
        ),
      )
    ("Uniform", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 12),
                eval_arith(@symcore.pow(params[0], @symcore.int(2))),
              ]),
            ),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 12),
                eval_arith(@symcore.pow(params[1], @symcore.int(2))),
              ]),
            ),
            eval_arith(
              @symcore.mul([stats_exact_rational(-1, 6), params[0], params[1]]),
            ),
          ]),
        ),
      )
    ("UniformSum", 1) =>
      Some(eval_arith(@symcore.mul([stats_exact_rational(1, 12), params[0]])))
    ("Wald", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], @symcore.int(3))),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
          ]),
        ),
      )
    ("WignerSemicircle", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 4),
            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
          ]),
        ),
      )
    ("Zeta", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[0]]),
                @symcore.int(-2),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        @symcore.function("zeta", [
                          eval_arith(
                            @symcore.add([@symcore.int(-1), params[0]]),
                          ),
                        ]),
                        @symcore.int(2),
                      ),
                    ),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.function("zeta", [params[0]]),
                    @symcore.function("zeta", [
                      eval_arith(@symcore.add([@symcore.int(-2), params[0]])),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_mgf(
  name : String,
  params : Array[@symcore.Expr],
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Beta", 2) =>
      Some(
        @symcore.function("hyper", [
          @symcore.function("Tuple", [params[0]]),
          @symcore.function("Tuple", [
            eval_arith(@symcore.add([params[0], params[1]])),
          ]),
          t,
        ]),
      )
    ("BoundedPareto", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(@symcore.pow(params[1], params[0])),
            eval_arith(@symcore.pow(t, params[0])),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            params[1],
                            eval_arith(
                              @symcore.pow(params[2], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        params[0],
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("lowergamma", [
                      eval_arith(
                        @symcore.mul([
                          params[0],
                          @symcore.function("exp_polar", [
                            eval_arith(
                              @symcore.mul([
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                      eval_arith(
                        @symcore.mul([
                          params[2],
                          t,
                          @symcore.function("exp_polar", [
                            eval_arith(
                              @symcore.mul([
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("lowergamma", [
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.function("exp_polar", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                  eval_arith(
                    @symcore.mul([
                      params[1],
                      t,
                      @symcore.function("exp_polar", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                  params[0],
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Chi", 1) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                t,
                eval_arith(
                  @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.add([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                  ),
                ]),
                @symcore.function("hyper", [
                  @symcore.function("Tuple", [
                    eval_arith(
                      @symcore.add([
                        stats_exact_rational(1, 2),
                        eval_arith(
                          @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                        ),
                      ]),
                    ),
                  ]),
                  @symcore.function("Tuple", [stats_exact_rational(3, 2)]),
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(@symcore.pow(t, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("hyper", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                ),
              ]),
              @symcore.function("Tuple", [stats_exact_rational(1, 2)]),
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(1, 2),
                  eval_arith(@symcore.pow(t, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ChiSquared", 1) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(@symcore.mul([@symcore.int(-2), t])),
              ]),
            ),
            eval_arith(@symcore.mul([stats_exact_rational(-1, 2), params[0]])),
          ),
        ),
      )
    ("Erlang", 2) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(@symcore.mul([@symcore.int(-1), t])),
                  ]),
                ),
              ]),
            ),
            eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
          ),
        ),
      )
    ("ExGaussian", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[2],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[2],
                    eval_arith(@symcore.mul([@symcore.int(-1), t])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  t,
                  eval_arith(
                    @symcore.add([
                      params[0],
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 2),
                          t,
                          eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("FlorySchulz", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
                        @symcore.function("exp", [t]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-2),
              ),
            ),
            @symcore.function("exp", [t]),
          ]),
        ),
      )
    ("GaussianInverse", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              params[1],
              eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
              eval_arith(
                @symcore.add([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[1],
                              eval_arith(
                                @symcore.mul([
                                  @symcore.int(-2),
                                  t,
                                  eval_arith(
                                    @symcore.pow(params[0], @symcore.int(2)),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      )
    ("Gompertz", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            @symcore.function("exp", [params[1]]),
            @symcore.function("expint", [
              eval_arith(
                @symcore.mul([
                  t,
                  eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                ]),
              ),
              params[1],
            ]),
          ]),
        ),
      )
    ("Gumbel", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.function("exp", [eval_arith(@symcore.mul([params[1], t]))]),
            @symcore.function("gamma", [
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  eval_arith(@symcore.mul([@symcore.int(-1), params[0], t])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Hermite", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[0],
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.function("exp", [t]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[1],
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.function("exp", [
                            eval_arith(@symcore.mul([@symcore.int(2), t])),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      )
    ("Laplace", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(-1),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        eval_arith(@symcore.pow(t, @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [eval_arith(@symcore.mul([params[0], t]))]),
          ]),
        ),
      )
    ("Logarithmic", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("log", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("log", [
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      params[0],
                      @symcore.function("exp", [t]),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Logistic", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.function("beta", [
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  eval_arith(@symcore.mul([@symcore.int(-1), params[1], t])),
                ]),
              ),
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  eval_arith(@symcore.mul([params[1], t])),
                ]),
              ),
            ]),
            @symcore.function("exp", [eval_arith(@symcore.mul([params[0], t]))]),
          ]),
        ),
      )
    ("Moyal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.int(2),
                eval_arith(@symcore.mul([@symcore.int(-1), params[1], t])),
              ),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            @symcore.function("exp", [eval_arith(@symcore.mul([params[0], t]))]),
            @symcore.function("gamma", [
              eval_arith(
                @symcore.add([
                  stats_exact_rational(1, 2),
                  eval_arith(@symcore.mul([@symcore.int(-1), params[1], t])),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Pareto", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.mul([@symcore.int(-1), params[0], t])),
                params[1],
              ),
            ),
            @symcore.function("uppergamma", [
              eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
              eval_arith(@symcore.mul([@symcore.int(-1), params[0], t])),
            ]),
          ]),
        ),
      )
    ("QuadraticU", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(3),
            eval_arith(@symcore.pow(t, @symcore.int(-2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
                @symcore.int(-3),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        @symcore.int(4),
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            t,
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(-1),
                                    eval_arith(
                                      @symcore.pow(
                                        eval_arith(
                                          @symcore.add([params[0], params[1]]),
                                        ),
                                        @symcore.int(2),
                                      ),
                                    ),
                                  ]),
                                ),
                                eval_arith(
                                  @symcore.mul([@symcore.int(4), params[1]]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[1], t])),
                    ]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.add([
                        @symcore.int(4),
                        eval_arith(
                          @symcore.mul([
                            t,
                            eval_arith(
                              @symcore.add([
                                eval_arith(
                                  @symcore.pow(params[0], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.pow(params[1], @symcore.int(2)),
                                ),
                                eval_arith(
                                  @symcore.mul([
                                    @symcore.int(2),
                                    params[0],
                                    eval_arith(
                                      @symcore.add([@symcore.int(-2), params[1]]),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[0], t])),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("RaisedCosine", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
            eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
            eval_arith(@symcore.pow(t, @symcore.int(-1))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2)),
                    ),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        eval_arith(@symcore.pow(t, @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [eval_arith(@symcore.mul([params[0], t]))]),
            @symcore.function("sinh", [eval_arith(@symcore.mul([params[1], t]))]),
          ]),
        ),
      )
    ("Rayleigh", 1) =>
      Some(
        eval_arith(
          @symcore.add([
            @symcore.int(1),
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                params[0],
                t,
                eval_arith(
                  @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                    stats_exact_rational(1, 2),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    @symcore.function("erf", [
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(1, 2),
                          params[0],
                          t,
                          eval_arith(
                            @symcore.pow(
                              @symcore.int(2),
                              stats_exact_rational(1, 2),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                      eval_arith(@symcore.pow(t, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Reciprocal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("Ei", [
                      eval_arith(@symcore.mul([params[1], t])),
                    ]),
                  ]),
                ),
                @symcore.function("Ei", [
                  eval_arith(@symcore.mul([params[0], t])),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Skellam", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              eval_arith(
                @symcore.add([
                  params[1],
                  eval_arith(
                    @symcore.mul([
                      eval_arith(
                        @symcore.add([
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[0]]),
                          ),
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[1]]),
                          ),
                          eval_arith(
                            @symcore.mul([
                              params[0],
                              @symcore.function("exp", [t]),
                            ]),
                          ),
                        ]),
                      ),
                      @symcore.function("exp", [t]),
                    ]),
                  ),
                ]),
              ),
              @symcore.function("exp", [
                eval_arith(@symcore.mul([@symcore.int(-1), t])),
              ]),
            ]),
          ),
        ]),
      )
    ("Triangular", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(t, @symcore.int(-2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[2], t])),
                    ]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[0], t])),
                    ]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        params[2],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[1], t])),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("Uniform", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([params[1], t])),
                        ]),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(@symcore.mul([params[0], t])),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Or", [
              @symcore.function("Gt", [t, @symcore.int(0)]),
              @symcore.function("Lt", [t, @symcore.int(0)]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("UniformSum", 1) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [t]),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            params[0],
          ),
        ),
      )
    ("Wald", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              params[1],
              eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
              eval_arith(
                @symcore.add([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[1],
                              eval_arith(
                                @symcore.mul([
                                  @symcore.int(-2),
                                  t,
                                  eval_arith(
                                    @symcore.pow(params[0], @symcore.int(2)),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      )
    ("WignerSemicircle", 1) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                @symcore.function("besseli", [
                  @symcore.int(1),
                  eval_arith(@symcore.mul([params[0], t])),
                ]),
              ]),
            ),
            @symcore.function("Or", [
              @symcore.function("Gt", [t, @symcore.int(0)]),
              @symcore.function("Lt", [t, @symcore.int(0)]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("YuleSimon", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(1), params[0]])),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [t]),
            @symcore.function("hyper", [
              @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)]),
              @symcore.function("Tuple", [
                eval_arith(@symcore.add([@symcore.int(2), params[0]])),
              ]),
              @symcore.function("exp", [t]),
            ]),
          ]),
        ),
      )
    ("Zeta", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("polylog", [
              params[0],
              @symcore.function("exp", [t]),
            ]),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_cf(
  name : String,
  params : Array[@symcore.Expr],
  t : @symcore.Expr,
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Beta", 2) =>
      Some(
        @symcore.function("hyper", [
          @symcore.function("Tuple", [params[0]]),
          @symcore.function("Tuple", [
            eval_arith(@symcore.add([params[0], params[1]])),
          ]),
          eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
        ]),
      )
    ("BoundedPareto", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(@symcore.pow(params[1], params[0])),
            eval_arith(@symcore.pow(t, params[0])),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        eval_arith(
                          @symcore.mul([
                            params[1],
                            eval_arith(
                              @symcore.pow(params[2], @symcore.int(-1)),
                            ),
                          ]),
                        ),
                        params[0],
                      ),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("lowergamma", [
                      eval_arith(
                        @symcore.mul([
                          params[0],
                          @symcore.function("exp_polar", [
                            eval_arith(
                              @symcore.mul([
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                      eval_arith(
                        @symcore.mul([
                          params[2],
                          t,
                          @symcore.function("exp_polar", [
                            eval_arith(
                              @symcore.mul([
                                stats_exact_rational(-1, 2),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("lowergamma", [
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      @symcore.function("exp_polar", [
                        eval_arith(
                          @symcore.mul([
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                  eval_arith(
                    @symcore.mul([
                      params[1],
                      t,
                      @symcore.function("exp_polar", [
                        eval_arith(
                          @symcore.mul([
                            stats_exact_rational(-1, 2),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                  params[0],
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Cauchy", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[1],
                  @symcore.function("Abs", [t]),
                ]),
              ),
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t])),
            ]),
          ),
        ]),
      )
    ("Chi", 1) =>
      Some(
        eval_arith(
          @symcore.add([
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                t,
                eval_arith(
                  @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                ),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("gamma", [
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("gamma", [
                  eval_arith(
                    @symcore.add([
                      stats_exact_rational(1, 2),
                      eval_arith(
                        @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                      ),
                    ]),
                  ),
                ]),
                @symcore.function("hyper", [
                  @symcore.function("Tuple", [
                    eval_arith(
                      @symcore.add([
                        stats_exact_rational(1, 2),
                        eval_arith(
                          @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                        ),
                      ]),
                    ),
                  ]),
                  @symcore.function("Tuple", [stats_exact_rational(3, 2)]),
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(-1, 2),
                      eval_arith(@symcore.pow(t, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("hyper", [
              @symcore.function("Tuple", [
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                ),
              ]),
              @symcore.function("Tuple", [stats_exact_rational(1, 2)]),
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(t, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("ChiSquared", 1) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.add([
                @symcore.int(1),
                eval_arith(
                  @symcore.mul([@symcore.int(-2), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t]),
                ),
              ]),
            ),
            eval_arith(@symcore.mul([stats_exact_rational(-1, 2), params[0]])),
          ),
        ),
      )
    ("Erlang", 2) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t]),
                    ),
                  ]),
                ),
              ]),
            ),
            eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
          ),
        ),
      )
    ("ExGaussian", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[2],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[2],
                    eval_arith(
                      @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  t,
                  eval_arith(
                    @symcore.add([
                      eval_arith(
                        @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0]]),
                      ),
                      eval_arith(
                        @symcore.mul([
                          stats_exact_rational(-1, 2),
                          t,
                          eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("FlorySchulz", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(@symcore.pow(params[0], @symcore.int(2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.add([@symcore.int(-1), params[0]])),
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-2),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
            ]),
          ]),
        ),
      )
    ("GammaInverse", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                    params[1],
                    t,
                  ]),
                ),
                eval_arith(
                  @symcore.mul([stats_exact_rational(1, 2), params[0]]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(
                @symcore.function("gamma", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("besselk", [
              params[0],
              eval_arith(
                @symcore.mul([
                  @symcore.int(2),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          params[1],
                          t,
                        ]),
                      ),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("GaussianInverse", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              params[1],
              eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
              eval_arith(
                @symcore.add([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[1],
                              eval_arith(
                                @symcore.mul([
                                  @symcore.int(-2),
                                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                                  t,
                                  eval_arith(
                                    @symcore.pow(params[0], @symcore.int(2)),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      )
    ("Gumbel", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[1], t])),
            ]),
            @symcore.function("gamma", [
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                      params[0],
                      t,
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Hermite", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[0],
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.function("exp", [
                            eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  params[1],
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.function("exp", [
                            eval_arith(
                              @symcore.mul([
                                @symcore.int(2),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                                t,
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      )
    ("Laplace", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                        eval_arith(@symcore.pow(t, @symcore.int(2))),
                      ]),
                    ),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t])),
            ]),
          ]),
        ),
      )
    ("Levy", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.add([
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                  ),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          params[1],
                          t,
                        ]),
                      ),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t])),
            ]),
          ),
        ]),
      )
    ("Logarithmic", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("log", [
                  eval_arith(
                    @symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                    ]),
                  ),
                ]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("log", [
              eval_arith(
                @symcore.add([
                  @symcore.int(1),
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      params[0],
                      @symcore.function("exp", [
                        eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Logistic", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                params[1],
                t,
                eval_arith(
                  @symcore.pow(
                    @symcore.function("sinh", [
                      eval_arith(
                        @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), params[1], t]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t])),
                ]),
              ]),
            ),
            @symcore.function("Or", [
              @symcore.function("Gt", [t, @symcore.int(0)]),
              @symcore.function("Lt", [t, @symcore.int(0)]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("Moyal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.int(2),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                    params[1],
                    t,
                  ]),
                ),
              ),
            ),
            eval_arith(
              @symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), stats_exact_rational(-1, 2)),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t])),
            ]),
            @symcore.function("gamma", [
              eval_arith(
                @symcore.add([
                  stats_exact_rational(1, 2),
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                      params[1],
                      t,
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Pareto", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[1],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                    params[0],
                    t,
                  ]),
                ),
                params[1],
              ),
            ),
            @symcore.function("uppergamma", [
              eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                  params[0],
                  t,
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("QuadraticU", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(3),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
            eval_arith(@symcore.pow(t, @symcore.int(-2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
                @symcore.int(-3),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([@symcore.int(-4), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)]),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    t,
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.pow(
                                eval_arith(@symcore.add([params[0], params[1]])),
                                @symcore.int(2),
                              ),
                            ),
                          ]),
                        ),
                        eval_arith(@symcore.mul([@symcore.int(4), params[1]])),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                  params[0],
                  t,
                  @symcore.function("exp", [
                    eval_arith(
                      @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[1], t]),
                    ),
                  ]),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("RaisedCosine", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                      params[0],
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("Eq", [
              t,
              eval_arith(
                @symcore.mul([
                  @symcore.int(-1),
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                ]),
              ),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                stats_exact_rational(1, 2),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                      @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                      params[0],
                      eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("Eq", [
              t,
              eval_arith(
                @symcore.mul([
                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                  eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                ]),
              ),
            ]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                eval_arith(@symcore.pow(@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), @symcore.int(2))),
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.pow(
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                @symcore.int(2),
                              ),
                            ),
                          ]),
                        ),
                        eval_arith(
                          @symcore.mul([
                            eval_arith(@symcore.pow(params[1], @symcore.int(2))),
                            eval_arith(@symcore.pow(t, @symcore.int(2))),
                          ]),
                        ),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                @symcore.function("exp", [
                  eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t])),
                ]),
                @symcore.function("sin", [
                  eval_arith(@symcore.mul([params[1], t])),
                ]),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("Rayleigh", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    stats_exact_rational(-1, 2),
                    params[0],
                    t,
                    eval_arith(
                      @symcore.pow(@symcore.int(2), stats_exact_rational(1, 2)),
                    ),
                    eval_arith(
                      @symcore.pow(
                        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                        stats_exact_rational(1, 2),
                      ),
                    ),
                    eval_arith(
                      @symcore.add([
                        eval_arith(
                          @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)]),
                        ),
                        @symcore.function("erfi", [
                          eval_arith(
                            @symcore.mul([
                              stats_exact_rational(1, 2),
                              params[0],
                              t,
                              eval_arith(
                                @symcore.pow(
                                  @symcore.int(2),
                                  stats_exact_rational(1, 2),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                @symcore.function("exp", [
                  eval_arith(
                    @symcore.mul([
                      stats_exact_rational(1, 2),
                      eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                      eval_arith(@symcore.pow(t, @symcore.int(2))),
                    ]),
                  ),
                ]),
              ]),
            ),
            @symcore.function("exp", [
              eval_arith(
                @symcore.mul([
                  stats_exact_rational(-1, 2),
                  eval_arith(@symcore.pow(params[0], @symcore.int(2))),
                  eval_arith(@symcore.pow(t, @symcore.int(2))),
                ]),
              ),
            ]),
          ]),
        ),
      )
    ("Reciprocal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("Ei", [
                      eval_arith(
                        @symcore.mul([
                          params[1],
                          t,
                          @symcore.function("exp_polar", [
                            eval_arith(
                              @symcore.mul([
                                stats_exact_rational(1, 2),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                @symcore.function("Ei", [
                  eval_arith(
                    @symcore.mul([
                      params[0],
                      t,
                      @symcore.function("exp_polar", [
                        eval_arith(
                          @symcore.mul([
                            stats_exact_rational(1, 2),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("Skellam", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              eval_arith(
                @symcore.add([
                  params[1],
                  eval_arith(
                    @symcore.mul([
                      eval_arith(
                        @symcore.add([
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[0]]),
                          ),
                          eval_arith(
                            @symcore.mul([@symcore.int(-1), params[1]]),
                          ),
                          eval_arith(
                            @symcore.mul([
                              params[0],
                              @symcore.function("exp", [
                                eval_arith(
                                  @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t]),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                      @symcore.function("exp", [
                        eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
                      ]),
                    ]),
                  ),
                ]),
              ),
              @symcore.function("exp", [
                eval_arith(
                  @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t]),
                ),
              ]),
            ]),
          ),
        ]),
      )
    ("Triangular", 3) =>
      Some(
        eval_arith(
          @symcore.mul([
            @symcore.int(2),
            eval_arith(@symcore.pow(t, @symcore.int(-2))),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    params[1],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[2]])),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[1], t]),
                      ),
                    ]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        params[1],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[2], t]),
                      ),
                    ]),
                  ]),
                ),
                eval_arith(
                  @symcore.mul([
                    eval_arith(
                      @symcore.add([
                        params[2],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    ("Uniform", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        params[0],
                        eval_arith(@symcore.mul([@symcore.int(-1), params[1]])),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [
                          eval_arith(
                            @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[0], t]),
                          ),
                        ]),
                      ]),
                    ),
                    @symcore.function("exp", [
                      eval_arith(
                        @symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), params[1], t]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            @symcore.function("Or", [
              @symcore.function("Gt", [t, @symcore.int(0)]),
              @symcore.function("Lt", [t, @symcore.int(0)]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("UniformSum", 1) =>
      Some(
        eval_arith(
          @symcore.pow(
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                eval_arith(
                  @symcore.add([
                    @symcore.int(1),
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("exp", [
                          eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            params[0],
          ),
        ),
      )
    ("Wald", 2) =>
      Some(
        @symcore.function("exp", [
          eval_arith(
            @symcore.mul([
              @symcore.int(-1),
              params[1],
              eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
              eval_arith(
                @symcore.add([
                  @symcore.int(-1),
                  eval_arith(
                    @symcore.pow(
                      eval_arith(
                        @symcore.mul([
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                          eval_arith(
                            @symcore.add([
                              params[1],
                              eval_arith(
                                @symcore.mul([
                                  @symcore.int(-2),
                                  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit),
                                  t,
                                  eval_arith(
                                    @symcore.pow(params[0], @symcore.int(2)),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      stats_exact_rational(1, 2),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      )
    ("WignerSemicircle", 1) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.int(2),
                eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                eval_arith(@symcore.pow(t, @symcore.int(-1))),
                @symcore.function("besselj", [
                  @symcore.int(1),
                  eval_arith(@symcore.mul([params[0], t])),
                ]),
              ]),
            ),
            @symcore.function("Or", [
              @symcore.function("Gt", [t, @symcore.int(0)]),
              @symcore.function("Lt", [t, @symcore.int(0)]),
            ]),
          ]),
          @symcore.function("Tuple", [@symcore.int(1), @symcore.Expr::Boolean(true)]),
        ]),
      )
    ("YuleSimon", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(@symcore.add([@symcore.int(1), params[0]])),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("exp", [
              eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
            ]),
            @symcore.function("hyper", [
              @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)]),
              @symcore.function("Tuple", [
                eval_arith(@symcore.add([@symcore.int(2), params[0]])),
              ]),
              @symcore.function("exp", [
                eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
              ]),
            ]),
          ]),
        ),
      )
    ("Zeta", 1) =>
      Some(
        eval_arith(
          @symcore.mul([
            eval_arith(
              @symcore.pow(
                @symcore.function("zeta", [params[0]]),
                @symcore.int(-1),
              ),
            ),
            @symcore.function("polylog", [
              params[0],
              @symcore.function("exp", [
                eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit), t])),
              ]),
            ]),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_quantile(
  name : String,
  params : Array[@symcore.Expr],
  q : @symcore.Expr,
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("Cauchy", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                params[1],
                @symcore.function("cot", [
                  eval_arith(@symcore.mul([@symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi), q])),
                ]),
              ]),
            ),
          ]),
        ),
      )
    ("LogLogistic", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            params[0],
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    q,
                    eval_arith(
                      @symcore.pow(
                        eval_arith(@symcore.add([@symcore.int(-1), q])),
                        @symcore.int(-1),
                      ),
                    ),
                  ]),
                ),
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
              ),
            ),
          ]),
        ),
      )
    ("Logistic", 2) =>
      Some(
        eval_arith(
          @symcore.add([
            params[0],
            eval_arith(
              @symcore.mul([
                @symcore.int(-1),
                params[1],
                @symcore.function("log", [
                  eval_arith(
                    @symcore.mul([
                      eval_arith(@symcore.pow(q, @symcore.int(-1))),
                      eval_arith(
                        @symcore.add([
                          @symcore.int(1),
                          eval_arith(@symcore.mul([@symcore.int(-1), q])),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      )
    _ => None
  }
}

///|
fn generated_entropy(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr? {
  match (name, params.length()) {
    ("BoundedPareto", 3) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    params[2],
                    eval_arith(@symcore.mul([@symcore.int(-1), params[0]])),
                  ),
                ),
                eval_arith(
                  @symcore.pow(
                    eval_arith(
                      @symcore.add([
                        @symcore.int(-1),
                        eval_arith(
                          @symcore.pow(
                            eval_arith(
                              @symcore.mul([
                                params[1],
                                eval_arith(
                                  @symcore.pow(params[2], @symcore.int(-1)),
                                ),
                              ]),
                            ),
                            params[0],
                          ),
                        ),
                      ]),
                    ),
                    @symcore.int(-1),
                  ),
                ),
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.pow(params[1], params[0])),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(1),
                            eval_arith(
                              @symcore.mul([
                                params[0],
                                eval_arith(
                                  @symcore.add([
                                    @symcore.int(1),
                                    eval_arith(
                                      @symcore.mul([
                                        @symcore.int(-1),
                                        @symcore.function("log", [
                                          eval_arith(
                                            @symcore.mul([
                                              @symcore.int(-1),
                                              params[0],
                                              eval_arith(
                                                @symcore.pow(
                                                  params[1],
                                                  params[0],
                                                ),
                                              ),
                                              eval_arith(
                                                @symcore.pow(
                                                  params[2],
                                                  eval_arith(
                                                    @symcore.add([
                                                      @symcore.int(-1),
                                                      eval_arith(
                                                        @symcore.mul([
                                                          @symcore.int(-1),
                                                          params[0],
                                                        ]),
                                                      ),
                                                    ]),
                                                  ),
                                                ),
                                              ),
                                              eval_arith(
                                                @symcore.pow(
                                                  eval_arith(
                                                    @symcore.add([
                                                      @symcore.int(-1),
                                                      eval_arith(
                                                        @symcore.pow(
                                                          eval_arith(
                                                            @symcore.mul([
                                                              params[1],
                                                              eval_arith(
                                                                @symcore.pow(
                                                                  params[2],
                                                                  @symcore.int(
                                                                    -1,
                                                                  ),
                                                                ),
                                                              ),
                                                            ]),
                                                          ),
                                                          params[0],
                                                        ),
                                                      ),
                                                    ]),
                                                  ),
                                                  @symcore.int(-1),
                                                ),
                                              ),
                                            ]),
                                          ),
                                        ]),
                                      ]),
                                    ),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    eval_arith(
                      @symcore.mul([
                        eval_arith(@symcore.pow(params[2], params[0])),
                        eval_arith(
                          @symcore.add([
                            @symcore.int(-1),
                            eval_arith(
                              @symcore.mul([
                                params[0],
                                eval_arith(
                                  @symcore.add([
                                    @symcore.int(-1),
                                    @symcore.function("log", [
                                      eval_arith(
                                        @symcore.mul([
                                          @symcore.int(-1),
                                          params[0],
                                          eval_arith(
                                            @symcore.pow(
                                              params[1],
                                              @symcore.int(-1),
                                            ),
                                          ),
                                          eval_arith(
                                            @symcore.pow(
                                              eval_arith(
                                                @symcore.add([
                                                  @symcore.int(-1),
                                                  eval_arith(
                                                    @symcore.pow(
                                                      eval_arith(
                                                        @symcore.mul([
                                                          params[1],
                                                          eval_arith(
                                                            @symcore.pow(
                                                              params[2],
                                                              @symcore.int(-1),
                                                            ),
                                                          ),
                                                        ]),
                                                      ),
                                                      params[0],
                                                    ),
                                                  ),
                                                ]),
                                              ),
                                              @symcore.int(-1),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            @symcore.function("And", [
              @symcore.function("Or", [
                @symcore.function("Gt", [
                  params[0],
                  @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                ]),
                @symcore.function("Gt", [params[0], @symcore.int(0)]),
              ]),
              @symcore.function("Or", [
                @symcore.function("Gt", [
                  params[0],
                  @symcore.mul([@symcore.int(-1), @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
                ]),
                @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
              ]),
              @symcore.function("Or", [
                @symcore.function("Gt", [params[0], @symcore.int(0)]),
                @symcore.function("Lt", [params[0], @symcore.int(0)]),
              ]),
              @symcore.function("Or", [
                @symcore.function("Lt", [params[0], @symcore.int(0)]),
                @symcore.function("Lt", [params[0], @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)]),
              ]),
            ]),
          ]),
          @symcore.function("Tuple", [
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
            @symcore.function("Ge", [params[0], @symcore.int(0)]),
          ]),
        ]),
      )
    ("LogLogistic", 2) =>
      Some(
        @symcore.function("Piecewise", [
          @symcore.function("Tuple", [
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::NaN),
            @symcore.function("Le", [params[1], @symcore.int(1)]),
          ]),
          @symcore.function("Tuple", [
            eval_arith(
              @symcore.mul([
                @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                params[0],
                eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                eval_arith(
                  @symcore.pow(
                    @symcore.function("sin", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
                          eval_arith(@symcore.pow(params[1], @symcore.int(-1))),
                        ]),
                      ),
                    ]),
                    @symcore.int(-1),
                  ),
                ),
              ]),
            ),
            @symcore.Expr::Boolean(true),
          ]),
        ]),
      )
    ("Reciprocal", 2) =>
      Some(
        eval_arith(
          @symcore.mul([
            stats_exact_rational(1, 2),
            eval_arith(
              @symcore.pow(
                eval_arith(
                  @symcore.add([
                    eval_arith(
                      @symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [params[1]]),
                      ]),
                    ),
                    @symcore.function("log", [params[0]]),
                  ]),
                ),
                @symcore.int(-1),
              ),
            ),
            eval_arith(
              @symcore.add([
                eval_arith(
                  @symcore.pow(
                    @symcore.function("log", [
                      eval_arith(
                        @symcore.mul([
                          @symcore.int(-1),
                          eval_arith(@symcore.pow(params[0], @symcore.int(-1))),
                          eval_arith(
                            @symcore.pow(
                              eval_arith(
                                @symcore.add([
                                  eval_arith(
                                    @symcore.mul([
                                      @symcore.int(-1),
                                      @symcore.function("log", [params[1]]),
                                    ]),
                                  ),
                                  @symcore.function("log", [params[0]]),
                                ]),
                              ),
                              @symcore.int(-1),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                    @symcore.int(2),
                  ),
                ),
                eval_arith(
                  @symcore.mul([
                    @symcore.int(-1),
                    eval_arith(
                      @symcore.pow(
                        @symcore.function("log", [
                          eval_arith(
                            @symcore.mul([
                              @symcore.int(-1),
                              eval_arith(
                                @symcore.pow(params[1], @symcore.int(-1)),
                              ),
                              eval_arith(
                                @symcore.pow(
                                  eval_arith(
                                    @symcore.add([
                                      eval_arith(
                                        @symcore.mul([
                                          @symcore.int(-1),
                                          @symcore.function("log", [params[1]]),
                                        ]),
                                      ),
                                      @symcore.function("log", [params[0]]),
                                    ]),
                                  ),
                                  @symcore.int(-1),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                        @symcore.int(2),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      )
    _ => None
  }
}
