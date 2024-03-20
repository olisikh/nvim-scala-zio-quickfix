local ts = vim.treesitter
local lang = 'scala'
local utils = require('scala-zio-quickfix.utils')

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

local M = {}

function M.fix_map_unit(bufnr, root, start_line, end_line, handler)
  start_line = start_line or 0
  end_line = end_line or vim.api.nvim_buf_line_count(bufnr)

  return function(cb)
    local results = {}
    for _, matches, _ in queries.map_unit:iter_matches(root, bufnr, start_line, end_line + 1) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      local parent = utils.lookup_parent_node_by_type(field, 'call_expression')
      if parent ~= nil then
        if utils.verify_type_is_zio(bufnr, parent) then
          handler(results, start_row, start_col, end_row, end_col)
        end
      end
    end

    cb(results)
  end
end

function M.fix_map_zip_right(bufnr, root, start_line, end_line, handler)
  start_line = start_line or 0
  end_line = end_line or vim.api.nvim_buf_line_count(bufnr)

  return function(cb)
    local results = {}

    for _, matches, _ in queries.zip_right_unit:iter_matches(root, bufnr, start_line, end_line + 1) do
      local field = matches[1]
      local args = matches[3]

      -- TODO: this might need to change, what if field and args are on differnet lines, then it would make no sense
      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      local parent = utils.lookup_parent_node_by_type(field, 'infix_expression')
      if parent ~= nil then
        if utils.verify_type_is_zio(bufnr, parent) then
          handler(results, start_row, start_col, end_row, end_col)
        end
      end
    end

    cb(results)
  end
end

function M.fix_as_unit(bufnr, root, start_line, end_line, handler)
  start_line = start_line or 0
  end_line = end_line or vim.api.nvim_buf_line_count(bufnr)

  return function(cb)
    local results = {}

    for _, matches, _ in queries.as_unit:iter_matches(root, bufnr, start_line, end_line + 1) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      local parent = utils.lookup_parent_node_by_type(field, 'call_expression')
      if parent ~= nil then
        -- TODO: figure out how to verify type, LSP returns empty response
        -- if utils.verify_type_is_zio(bufnr, parent) then
        handler(results, start_row, start_col, end_row, end_col)
        -- end
      end

      -- table.insert(outputs, {
      --   title = 'ZIO: replace .as(()) with .unit',
      --   bufnr = bufnr,
      --   start_row = start_row,
      --   start_col = start_col,
      --   end_col = end_col,
      --   end_row = end_row,
      --   message = 'ZIO: Replace with .unit smart constructor',
      --   severity = vim.diagnostic.severity.HINT,
      --   fn = function()
      --     vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
      --   end,
      -- })
    end

    cb(results)
  end
end

--
-- local function fix_as_value()
--   local query = queries.as_value
--   for _, matches, _ in query:iter_matches(root, bufnr) do
--     local start = matches[1]
--     local value = matches[4]
--     local finish = matches[5]
--
--     local _, _, start_row, start_col = start:range()
--     local _, _, end_row, end_col = finish:range()
--
--     table.insert(outputs, {
--       title = 'ZIO: replace *> ZIO.succeed(...) with .as(...)',
--       bufnr = bufnr,
--       start_row = start_row,
--       start_col = start_col,
--       end_col = end_col,
--       end_row = end_row,
--       message = 'ZIO: Replace with .as smart constructor',
--       severity = vim.diagnostic.severity.HINT,
--       fn = function()
--         vim.api.nvim_buf_set_text(
--           bufnr,
--           start_row,
--           start_col,
--           end_row,
--           end_col,
--           { '.as(' .. ts.get_node_text(value, bufnr) .. ')' }
--         )
--       end,
--     })
--   end
-- end
--
-- local function fix_map_value()
--   local query = queries.map_value
--   for _, matches, _ in query:iter_matches(root, bufnr) do
--     local field = matches[1]
--     local target = matches[3]
--     local args = matches[4]
--
--     local target_text = ts.get_node_text(target, bufnr)
--
--     local _, _, start_row, start_col = field:range()
--     local _, _, end_row, end_col = args:range()
--
--     table.insert(outputs, {
--       title = 'ZIO: replace .map(_ => ...) with .as(...)',
--       bufnr = bufnr,
--       start_row = start_row,
--       start_col = start_col,
--       end_col = end_col,
--       end_row = end_row,
--       message = 'ZIO: Replace with .as smart constructor',
--       severity = vim.diagnostic.severity.HINT,
--       fn = function()
--         vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. target_text .. ')' })
--       end,
--     })
--   end
-- end
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

-- fix_map_unit()
-- fix_map_zip_right()
-- fix_as_unit()
-- fix_as_value()
-- fix_map_value()
-- fix_fold_cause_ignore()
-- fix_unit_catch_all_unit()
-- fix_map_error_bimap()

-- vim.print('Resolved actions:')
-- vim.print(outputs)
--
--

return M
