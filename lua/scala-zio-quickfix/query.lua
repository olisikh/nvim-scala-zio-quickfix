local ts = vim.treesitter
local lang = 'scala'
local utils = require('scala-zio-quickfix.utils')

local queries = {
  map_unit = {
    query = utils.parse_ts_query(
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
    handler = function(bufnr, matches, results, handler)
      local field = matches[1]
      local args = matches[3]

      -- local _, _, start_row, start_col = field:range()
      local start_row, start_col, end_row, end_col = args:range()

      local parent = utils.find_parent_by_type(field, 'call_expression')
      if parent ~= nil then
        if utils.verify_type_is_zio(bufnr, parent) then
          handler(results, start_row, start_col, end_row, end_col)
        end
      end
    end,
  },

  zip_right_unit = {
    query = utils.parse_ts_query(
      lang,
      [[
(infix_expression
  left: (_) @start
  operator: (operator_identifier) @_1 (#eq? @_1 "*>")
  right: (_) @end (#any-of? @end "ZIO.unit" "ZIO.succeed(())")
)]]
    ),
    handler = function(bufnr, matches, results, handler)
      local field = matches[1]
      local args = matches[3]

      -- TODO: this might need to change, what if field and args are on differnet lines, then it would make no sense

      -- local _, _, start_row, start_col = field:range()
      local start_row, start_col, end_row, end_col = args:range()

      local parent = utils.find_parent_by_type(field, 'infix_expression')
      if parent ~= nil then
        if utils.verify_type_is_zio(bufnr, parent) then
          handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, args))
        end
      end
    end,
  },
  as_unit = {
    query = utils.parse_ts_query(
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
    handler = function(bufnr, matches, results, handler)
      local field = matches[1]
      local args = matches[3]

      -- local _, _, start_row, start_col = field:range()
      local start_row, start_col, end_row, end_col = args:range()

      local parent = utils.find_parent_by_type(field, 'call_expression')
      if parent ~= nil then
        -- TODO: figure out how to verify type, LSP returns empty response

        if utils.verify_type_is_zio(bufnr, parent) then
          handler(results, start_row, start_col, end_row, end_col)
        end
      end
    end,
  },
  as_value = {
    query = ts.query.parse(
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

    handler = function(bufnr, matches, results, handler)
      -- local start = matches[1]
      local value = matches[4]
      local finish = matches[5]

      -- local _, _, start_row, start_col = start:range()
      local start_row, start_col, end_row, end_col = finish:range()

      local parent = utils.find_parent_by_type(value, 'call_expression')
      if parent ~= nil then
        -- TODO: figure out how to verify type, LSP returns empty response

        -- if utils.verify_type_is_zio(bufnr, parent) then
        handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, value))
        -- end
      end
    end,
  },
  map_value = {
    query = ts.query.parse(
      lang,
      [[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @_1 (#eq? @_1 "map")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (_) @value (#not-eq? @value "()")
    )
  ) @end
)]]
    ),

    handler = function(bufnr, matches, results, handler)
      -- local field = matches[1]
      local value = matches[3]
      local args = matches[4]

      -- local _, _, start_row, start_col = field:range()
      local start_row, start_col, end_row, end_col = args:range()

      local parent = utils.find_parent_by_type(value, 'call_expression')
      if parent ~= nil then
        if utils.verify_type_is_zio(bufnr, parent) then
          handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, value))
        end
      end
    end,
  },
  fold_cause_ignore = {
    query = ts.query.parse(
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
    handler = function(bufnr, matches, results, handler) end,
  },
  unit_catch_all_unit = {
    query = ts.query.parse(
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
    handler = function(bufnr, matches, results, handler) end,
  },
  map_error_bimap = {
    query = ts.query.parse(
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
    handler = function(bufnr, matches, results, handler) end,
  },
}

local M = {}

---
--- Executes a query on a given buffer and returns the results.
--- @param opts (table) The options for running the query.
---   - bufnr (number, optional): The buffer number to run the query on. Defaults to the current buffer.
---   - start_line (number, optional): The starting line for the query. Defaults to 0.
---   - end_line (number, optional): The ending line for the query. Defaults to the total number of lines in the buffer.
---   - root (table): The root object for the query.
---   - handler (function): The handler function to process query results.
---   - query_name (string): The name of the query to run.
--- @return function: A function that takes a callback and executes the query, passing the results to the callback.
function M.run_query(opts)
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local start_line = opts.start_line or 0
  local end_line = opts.end_line or vim.api.nvim_buf_line_count(bufnr)

  local root = opts.root
  local handler = opts.handler

  local query = queries[opts.query_name]
  if query == nil then
    return function(cb)
      cb({})
    end
  end

  return function(cb)
    local results = {}
    for _, matches, _ in query.query:iter_matches(root, bufnr, start_line, end_line + 1) do
      query.handler(bufnr, matches, results, handler)
    end

    cb(results)
  end
end

--
-- local function fix_fold_cause_ignore()
--   local query = queries.fold_cause_ignore
--   for _, matches, _ in query:iter_matches(root, bufnr) do
--     local field = matches[1]
--     local args = matches[3]
--
--     local _, _, start_row, start_col = field:range()
--     local _, _, end_row, end_col = args:range()
--
--     table.insert(outputs, {
--       title = 'ZIO: replace .foldCause(_ => (), _ => ()) with .ignore',
--       bufnr = bufnr,
--       start_row = start_row,
--       start_col = start_col,
--       end_col = end_col,
--       end_row = end_row,
--       message = 'ZIO: Replace with .ignore smart constructor',
--       severity = vim.diagnostic.severity.HINT,
--       fn = function()
--         vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
--       end,
--     })
--   end
-- end
--
-- local function fix_unit_catch_all_unit()
--   local query = queries.unit_catch_all_unit
--   for _, matches, _ in query:iter_matches(root, bufnr) do
--     local field = matches[1]
--     local args = matches[5]
--
--     local _, _, start_row, start_col = field:range()
--     local _, _, end_row, end_col = args:range()
--
--     table.insert(outputs, {
--       title = 'ZIO: replace .unit.catchAll(_ => ()) with .ignore',
--       bufnr = bufnr,
--       start_row = start_row,
--       start_col = start_col,
--       end_col = end_col,
--       end_row = end_row,
--       message = 'ZIO: Replace with .ignore smart constructor',
--       severity = vim.diagnostic.severity.HINT,
--       fn = function()
--         vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
--       end,
--     })
--   end
-- end
--
-- local function fix_map_error_bimap()
--   local query = queries.map_error_bimap
--   for _, matches, _ in query:iter_matches(root, bufnr) do
--     local field = matches[1]
--     local value = matches[3]
--     local err = matches[5]
--     local args = matches[6]
--
--     local value_text = ts.get_node_text(value, bufnr)
--     local err_text = ts.get_node_text(err, bufnr)
--
--     local _, _, start_row, start_col = field:range()
--     local _, _, end_row, end_col = args:range()
--
--     table.insert(outputs, {
--       title = 'ZIO: replace .map(_ => ...).mapError(_ => ...) with .mapBoth',
--       bufnr = bufnr,
--       start_row = start_row,
--       start_col = start_col,
--       end_col = end_col,
--       end_row = end_row,
--       message = 'ZIO: Replace with .mapBoth function',
--       severity = vim.diagnostic.severity.HINT,
--       fn = function()
--         vim.api.nvim_buf_set_text(
--           bufnr,
--           start_row,
--           start_col,
--           end_row,
--           end_col,
--           { '.mapBoth(_ => ' .. err_text .. ', _ => ' .. value_text .. ')' }
--         )
--       end,
--     })
--   end
-- end
--
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

return M
