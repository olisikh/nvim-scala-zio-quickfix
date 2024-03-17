-- Treesitter quickfix

local M = {}

M.setup = function()
  local null_ls = require('null-ls')

  null_ls.register({
    name = 'zio-code-action',
    method = null_ls.methods.CODE_ACTION,
    filetypes = { 'scala' },
    generator = {
      fn = function(context)
        local actions = {}

        local outputs = {}
        -- TODO: how to avoid parsing entire file again
        M.collect_diagnostics(outputs)

        local range = context.lsp_params.range
        local row = range['start'].line
        local col = range['start'].character

        vim.print(row)
        vim.print(outputs)

        for _, o in ipairs(outputs) do
          if o.start_row == row and o.start_col <= col and o.end_col >= col then
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
    filetypes = { 'scala' },
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
            source = 'zio-map-unit',
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
  local ts = vim.treesitter
  local bufnr = vim.api.nvim_get_current_buf()
  local lang = 'scala'
  local parsers = require('nvim-treesitter.parsers')
  local root = parsers.get_tree_root(bufnr)

  local function fix_map_unit()
    local qs = [[(call_expression
  function:
    (field_expression
      value: (_) @field
      field: (identifier) @method (#eq? @method "map")
    )
    (arguments
      (lambda_expression
        parameters: (wildcard) (unit)
      )
    ) @args)]]
    local query = ts.query.parse(lang, qs)

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
        message = 'ZIO: Consider using .unit smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end,
      })
    end
  end

  local function fix_map_zip_right()
    local qs = [[(infix_expression
  left: (_) @field
  operator: (operator_identifier) @method (#eq? @method "*>")
  right: (_) @expr (#any-of? @expr "ZIO.unit" "ZIO.succeed(())")
)]]

    local query = ts.query.parse(lang, qs)
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
        message = 'ZIO: Consider using .unit smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end,
      })
    end
  end

  local function fix_as_unit()
    local qs = [[(call_expression
    function: (field_expression
      value: (_) @field
      field: (identifier) @method (#eq? @method "as")
    )
    arguments: (arguments (unit)) @args
)]]

    local query = ts.query.parse(lang, qs)
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
        message = 'ZIO: Consider using .unit smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end,
      })
    end
  end

  local function fix_as_value()
    local qs = [[(infix_expression
  left: (_) @field
  operator: (operator_identifier) @method (#eq? @method "*>")
  right: (call_expression
    function: ((field_expression) @expr (#eq? @expr "ZIO.succeed"))
    arguments: (arguments (_) @value (#not-eq? @value "()")) @args
  )
)]]

    local query = ts.query.parse(lang, qs)
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local target = matches[4]
      local args = matches[5]

      local target_text = ts.get_node_text(target, bufnr)

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace *> ZIO.succeed(<value>) with .as(<value>)',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Consider using .as(<value>) smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. target_text .. ')' })
        end,
      })
    end
  end

  local function fix_map_value()
    local qs = [[(call_expression
    function: (field_expression
      value: (_) @field
      field: (identifier) @method (#eq? @method "map")
    )
    arguments:
      (arguments
        (lambda_expression parameters: (wildcard) (_) @value)
      ) @args
)]]

    local query = ts.query.parse(lang, qs)
    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local target = matches[3]
      local args = matches[4]

      local target_text = ts.get_node_text(target, bufnr)

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      table.insert(outputs, {
        title = 'ZIO: replace .map(_ => <value>) with .as(<value>)',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Consider using .as(<value>) smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. target_text .. ')' })
        end,
      })
    end
  end

  local function fix_fold_cause_ignore()
    local qs = [[(call_expression
    function: (field_expression
      value: (_) @field
      field: (identifier) @method (#eq? @method "foldCause")
    )
    arguments:
      (arguments
        (lambda_expression parameters: (wildcard) (unit))
        (lambda_expression parameters: (wildcard) (unit))
      ) @args
)]]

    local query = ts.query.parse(lang, qs)
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
        message = 'ZIO: Consider using .ignore smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
        end,
      })
    end
  end

  local function fix_unit_catch_all_unit()
    local qs = [[(call_expression
  function: (field_expression
      value: (field_expression
        value: (_) @field
        field: (identifier) @method (#eq? @method "unit")
      )	
      field: (identifier) @method2 (#eq? @method2 "catchAll")
    )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (field_expression) @obj (#eq? @obj "ZIO.unit")
    )
  ) @args
)]]

    local query = ts.query.parse(lang, qs)
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
        message = 'ZIO: Consider using .ignore smart constructor',
        severity = vim.diagnostic.severity.HINT,
        fn = function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
        end,
      })
    end
  end

  local function fix_map_error_bimap()
    local qs = [[(call_expression
  function: (field_expression
    value: (call_expression
      function: (field_expression
	value: (_) @field
        field: (identifier) @map (#eq? @map "map")
      )
      arguments: (arguments
        (lambda_expression parameters: (wildcard) (_) @value)
      )
    )	
    field: (identifier) @method2 (#eq? @method2 "mapError")
  )
  arguments: (arguments
    (lambda_expression parameters: (wildcard) (_) @err )
  ) @args
)]]

    local query = ts.query.parse(lang, qs)
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
        title = 'ZIO: replace .map(_ => <value>).mapError(_ => <value>) with .mapBoth',
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_col = end_col,
        end_row = end_row,
        message = 'ZIO: Consider using .mapBoth function',
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
