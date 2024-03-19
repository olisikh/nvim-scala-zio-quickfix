local ts = vim.treesitter
local lang = 'scala'

return {
  map_unit = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @_1 (#eq? @_1 "map")
  )
  (arguments
    (lambda_expression parameters: (wildcard) (unit))
  ) @end
)]]
  ),
  zip_right_unit = ts.query.parse(
    lang,
    [[
(infix_expression
  left: (_) @start
  operator: (operator_identifier) @_1 (#eq? @_1 "*>")
  right: (_) @end (#any-of? @end "ZIO.unit" "ZIO.succeed(())")
)
]]
  ),
  as_unit = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @_1 (#eq? @_1 "as")
  )
  arguments: (arguments (unit)) @end
)]]
  ),
  as_value = ts.query.parse(
    lang,

    [[
(infix_expression
  left: (_) @start
  operator: (operator_identifier) @_1 (#eq? @_1 "*>")
  right: (call_expression
    function: ((field_expression) @_2 (#eq? @_2 "ZIO.succeed"))
    arguments: (arguments (_) @value (#not-eq? @value "()"))
  ) @end
)]]
  ),
  map_value = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @_1 (#eq? @_1 "map")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (_) @value)
  ) @end
)]]
  ),
  fold_cause_ignore = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @_1 (#eq? @_1 "foldCause")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (unit)
    )
    (lambda_expression parameters: (wildcard) (unit))
  ) @end
)]]
  ),
  unit_catch_all_unit = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (field_expression
      value: (_) @start
      field: (identifier) @_1 (#eq? @_1 "unit")
    )	
    field: (identifier) @_2 (#eq? @_2 "catchAll")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (field_expression) @_3 (#eq? @_3 "ZIO.unit")
    )
  ) @end
)]]
  ),
  map_error_bimap = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (call_expression
      function: (field_expression
        value: (_) @start
        field: (identifier) @_1 (#eq? @_1 "map")
      )
      arguments: (arguments
        (lambda_expression parameters: (wildcard) (_) @value)
      )
    )	
    field: (identifier) @_2 (#eq? @_2 "mapError")
  )
  arguments: (arguments
    (lambda_expression parameters: (wildcard) (_) @err )
  ) @end
)]]
  ),
}
