local null_ls = require('null-ls')
local parsers = require('nvim-treesitter.parsers')
local ts = vim.treesitter
local lang = 'scala'

local queries = {
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
)
]]
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
)
]]
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
) @end
]]
  ),
  map_value = ts.query.parse(
    lang,
    [[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @method (#eq? @method "map")
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

local M = {}

M.setup = function()
  null_ls.register({
    name = 'zio-code-action',
    method = null_ls.methods.CODE_ACTION,
    filetypes = { lang },
    generator = {
      fn = function(context)
        local actions = {}

        local outputs = {}
        -- TODO: how to avoid parsing entire file again
        M.collect_diagnostics(outputs)

        local range = context.lsp_params.range
        local row = range['start'].line
        local col = range['start'].character

        for _, o in ipairs(outputs) do
          if o.end_row == row and o.start_col <= col and o.end_col >= col then
            table.insert(actions, {
              title = o.message,
              action = o.fn,
            })
          end
        end

        return actions
      end,
    },
  })

  null_ls.register({
    name = 'zio-diagnostic',
    method = null_ls.methods.DIAGNOSTICS,
    filetypes = { lang },
    generator = {
      fn = function(context)
        local outputs = {}
        -- TODO: how to avoid parsing entire file again
        M.collect_diagnostics(outputs)

        local diagnostics = {}
        for _, o in ipairs(outputs) do
          table.insert(diagnostics, {
            row = o.start_row + 1,
            col = o.start_col + 1,
            end_col = o.end_col + 1,
            source = 'zio-diagnostic',
            message = o.message,
            severity = o.severity,
          })
        end

        return diagnostics
      end,
    },
  })
end

M.collect_diagnostics = function(outputs)
  -- TODO: take it from the null-ls event?
  local bufnr = vim.api.nvim_get_current_buf()
  local root = parsers.get_tree_root(bufnr)

  local function fix_map_unit()
    local query = queries.map_unit
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .map(_ => ()) with .unit',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .unit smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end,
      })
    end
  end

  local function fix_map_zip_right()
    local query = queries.zip_right_unit
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace *> ZIO.unit with .unit',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .unit smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end,
      })
    end
  end

  local function fix_as_unit()
    local query = queries.as_unit
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .as(()) with .unit',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .unit smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end,
      })
    end
  end

  local function fix_as_value()
    local query = queries.as_value
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local start = matches[1]
      local value = matches[4]
      local finish = matches[5]

      local target_text = ts.get_node_text(value, bufnr)

      local _, _, start_row, start_col = start:range()
      local _, _, end_row, end_col = finish:range()

      table.insert(outputs, {
        title = 'ZIO: replace *> ZIO.succeed(...) with .as(...)',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .as smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. target_text .. ')' })
        end,
      })
    end
  end

  local function fix_map_value()
    local query = queries.map_value
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local target = matches[3]
      local args = matches[4]

      local target_text = ts.get_node_text(target, bufnr)

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .map(_ => ...) with .as(...)',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .as smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. target_text .. ')' })
        end,
      })
    end
  end

  local function fix_fold_cause_ignore()
    local query = queries.fold_cause_ignore
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .foldCause(_ => (), _ => ()) with .ignore',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .ignore smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
        end,
      })
    end
  end

  local function fix_unit_catch_all_unit()
    local query = queries.unit_catch_all_unit
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local args = matches[5]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .unit.catchAll(_ => ()) with .ignore',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .ignore smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
        end,
      })
    end
  end

  local function fix_map_error_bimap()
    local query = queries.map_error_bimap
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local value = matches[3]
      local err = matches[5]
      local args = matches[6]

      local value_text = ts.get_node_text(value, bufnr)
      local err_text = ts.get_node_text(err, bufnr)

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .map(_ => ...).mapError(_ => ...) with .mapBoth',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Replace with .mapBoth function',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(
            bufnr,
            start_row,
            start_col,
            end_row,
            end_col,
            { '.mapBoth(_ => ' .. err_text .. ', _ => ' .. value_text .. ')' }
          )
        end,
      })
    end
  end

  -- local function fix_if_when()
  --   local qs = [[ [
  -- (if_expression
  --   condition: (_) @cond1 (#not-match? @cond1 "^\!.*")
  --   consequence: (_) @cons1
  --   alternative: (_) @alt1 (#eq? @alt1 "ZIO.unit")
  -- )
  -- (if_expression
  --   condition: (_) @cond2 (#match? @cond2 "^\!.*")
  --   consequence: (_) @alt2 (#eq? @alt2 "ZIO.unit")
  --   alternative: (_) @cons2
  -- )
  -- (if_expression
  --   condition: (parenthesized_expression (_) @cond3 (#not-match? @cond1 "^\!.*"))
  --   consequence: (_) @cons3
  --   alternative: (_) @alt3 (#eq? @alt3 "ZIO.unit")
  -- )
  -- (if_expression
  --   condition: (parenthesized_expression (_) @cond4 (#match? @cond4 "^\!.*"))
  --   consequence: (_) @alt4 (#eq? @alt4 "ZIO.unit")
  --   alternative: (_) @cons4
  -- )] ]]
  --
  --   local query = ts.query.parse(lang, qs)
  --   for _, matches, _ in query:iter_matches(node, bufnr) do
  --     local field = matches[1]
  --     local args = matches[5]
  --
  --     local _, _, start_row, start_col = field:range()
  --     local _, _, end_row, end_col = args:range()
  --
  --     vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
  --   end
  -- end

  fix_map_unit()
  fix_map_zip_right()
  fix_as_unit()
  fix_as_value()
  fix_map_value()
  fix_fold_cause_ignore()
  fix_unit_catch_all_unit()
  fix_map_error_bimap()
end

return M
