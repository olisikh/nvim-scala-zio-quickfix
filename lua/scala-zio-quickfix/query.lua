local async = require('plenary.async')
local utils = require('scala-zio-quickfix.utils')
local ts = vim.treesitter

local zio_predicate = function(value)
  return string.find(value, 'ZIO') ~= nil -- TODO: match part of markdown?
end

local function parse_query(query)
  return ts.query.parse('scala', query)
end

local queries = {

  -- ZIO.succeed(()) ~> ZIO.unit
  succeed_unit = {
    query = parse_query([[
(call_expression
  function: (field_expression 
    value: (_) @start (#eq? @start "ZIO")
    field: (identifier) @target (#eq? @target "succeed")
  )
  arguments: (arguments (unit)) @finish
) @capture
]]),
    handler = function(results, bufnr, matches, callback)
      local target = matches[2]
      local finish = matches[3]

      local start_row, start_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      -- if is_zio then
      callback(results, {
        diagnostic = {
          row = start_row,
          start_col = start_col,
          end_col = end_col,
        },
        action = {
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
        },
        replacement = 'unit',
        title = 'ZIO: replace ZIO.succeed(()) with ZIO.unit',
      })
      -- end
    end,
  },

  -- x.map(_ => ()) ~> x.unit
  map_unit = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @target (#eq? @target "map")
  )
  (arguments
    (lambda_expression parameters: (wildcard) (unit))
  ) @finish
)
]]),
    handler = function(results, bufnr, matches, callback)
      -- local start = matches[1]
      local target = matches[2]
      local finish = matches[3]

      -- local _, _, start_row, start_col = start:range()
      local tstart_row, tstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      if is_zio then
        callback(results, {
          diagnostic = {
            row = tstart_row,
            start_col = tstart_col,
            end_col = end_col,
          },
          action = {
            start_row = tstart_row,
            start_col = tstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = 'unit',
          title = 'ZIO: replace .map(_ => ()) with .unit',
        })
        -- handler(results, start_row, start_col, end_row, end_col)
      end
    end,
  },

  -- *> ZIO.succeed(()) ~> .unit
  -- *> ZIO.unit        ~> .unit
  -- TODO: if ZIO.succeed(()) is on the next line, treesitter renders it as a sibling to the function definition
  -- example: def func = effect *>
  --   ZIO.succeed(())
  -- TODO: also need to support .zipRight(_ => ()), can be replaced with .unit
  zip_right_unit = {
    query = parse_query([[
(infix_expression
  left: (_) @start
  operator: (operator_identifier) @_1 (#eq? @_1 "*>")
  right: (_) @finish (#any-of? @finish "ZIO.unit" "ZIO.succeed(())")
)
]]),
    handler = function(results, bufnr, matches, callback)
      local start = matches[1]
      -- local target = matches[2]
      local finish = matches[3]

      local _, _, start_row, start_col = start:range()
      -- local astart_row, astart_col, _, _ = target:range()
      local dstart_row, dstart_col, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, finish, zio_predicate, tx)
      -- local is_zio = rx()

      local replaced = utils.get_node_text(bufnr, finish)
      local title = 'ZIO: replace *> ' .. replaced .. ' with .unit'

      -- if is_zio then
      callback(results, {
        diagnostic = {
          row = dstart_row,
          start_col = dstart_col,
          end_col = end_col,
        },
        action = {
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
        },
        replacement = '.unit',
        title = title,
      })

      -- handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, finish))
      -- end
    end,
  },

  -- x.as(()) ~> x.unit
  as_unit = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @target (#eq? @target "as")
  )
  arguments: (arguments (unit)) @finish
)
]]),
    handler = function(results, bufnr, matches, callback)
      -- local start = matches[1]
      local target = matches[2]
      local finish = matches[3]

      -- local _, _, start_row, start_col = start:range()
      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      -- if is_zio then
      callback(results, {
        diagnostic = {
          row = dstart_row,
          start_col = dstart_col,
          end_col = end_col,
        },
        action = {
          start_row = dstart_row,
          start_col = dstart_col,
          end_row = end_row,
          end_col = end_col,
        },
        replacement = 'unit',
        title = 'ZIO: replace .as(()) with .unit',
      })
      -- handler(results, start_row, start_col, end_row, end_col)
      -- end
    end,
  },

  -- *> ZIO.succeed(value) ~> .as(value)
  as_value = {
    query = parse_query([[
(infix_expression
  left: (_) @start
  operator: (operator_identifier) @_1 (#eq? @_1 "*>")
  right: (call_expression
    function: ((field_expression) @_2 (#eq? @_2 "ZIO.succeed"))
    arguments: (arguments (_) @value (#not-eq? @value "()"))
  ) @finish
)
]]),
    handler = function(results, bufnr, matches, callback)
      -- local start = matches[1]
      local target = matches[3]
      local value = matches[4]
      local finish = matches[5]

      -- local _, _, start_row, start_col = start:range()
      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      -- if is_zio then
      local value_text = utils.get_node_text(bufnr, value)
      local title = 'ZIO: replace *> ZIO.succeed(' .. value_text .. ') with .as(' .. value_text .. ')'
      local replacement = 'as(' .. value_text .. ')'

      callback(results, {
        diagnostic = {
          row = dstart_row,
          start_col = dstart_col,
          end_col = end_col,
        },
        action = {
          start_row = dstart_row,
          start_col = dstart_col,
          end_row = end_row,
          end_col = end_col,
        },
        replacement = replacement,
        title = title,
      })
      -- handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, value))
      -- end
    end,
  },

  -- x.map(_ => value) ~> x.as(value)
  map_value = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @target (#eq? @target "map")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (_) @value (#not-eq? @value "()")
    )
  ) @finish
)
]]),
    handler = function(results, bufnr, matches, callback)
      -- local start = matches[1]
      local target = matches[2]
      local value = matches[3]
      local finish = matches[4]

      -- local _, _, start_row, start_col = start:range()
      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      local tx, rx = async.control.channel.oneshot()
      utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      local is_zio = rx()

      if is_zio then
        local value_text = utils.get_node_text(bufnr, value)
        local title = 'ZIO: replace .map(_ => ' .. value_text .. ') with .as(' .. value_text .. ')'
        local replacement = 'as(' .. value_text .. ')'

        callback(results, {
          diagnostic = {
            row = dstart_row,
            start_col = dstart_col,
            end_col = end_col,
          },
          action = {
            start_row = dstart_row,
            start_col = dstart_col,
            end_row = end_row,
            end_col = end_col,
          },
          replacement = replacement,
          title = title,
        })
        -- handler(results, start_row, start_col, end_row, end_col, utils.get_node_text(bufnr, value))
      end
    end,
  },

  -- x.foldCause(_ => (), _ => ()) ~> .ignore
  fold_cause_ignore = {
    query = parse_query([[
(call_expression
  function: (field_expression
    value: (_) @start
    field: (identifier) @target (#eq? @target "foldCause")
  )
  arguments: (arguments
    (lambda_expression
      parameters: (wildcard) (unit)
    )
    (lambda_expression parameters: (wildcard) (unit))
  ) @finish
)
]]),
    handler = function(results, bufnr, matches, callback)
      -- local start = matches[1]
      local target = matches[2]
      local finish = matches[3]

      -- local _, _, start_row, start_col = start:range()
      local dstart_row, dstart_col, _, _ = target:range()
      local _, _, end_row, end_col = finish:range()

      -- local tx, rx = async.control.channel.oneshot()
      -- utils.hover_node_and_match(bufnr, target, zio_predicate, tx)
      -- local is_zio = rx()

      local title = 'ZIO: replace .foldCause(_ => (), _ => ()) with .ignore'

      -- if is_zio then
      callback(results, {
        diagnostic = {
          row = dstart_row,
          start_col = dstart_col,
          end_col = end_col,
        },
        action = {
          start_row = dstart_row,
          start_col = dstart_col,
          end_row = end_row,
          end_col = end_col,
        },
        replacement = 'ignore',
        title = title,
      })
      -- handler(results, start_row, start_col, end_row, end_col)
      -- end
    end,
  },

  -- x.unit.catchAll(_ => ()) ~> .ignore
  unit_catch_all_unit = {
    query = parse_query([[
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
  ) @finish
)
]]),
    handler = function(bufnr, matches, results, handler) end,
  },

  -- x.map(x => y).mapError(z => g) ~> .bimap(x => y, z => g)
  map_error_bimap = {
    query = parse_query([[
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
  ) @finish
)
]]),
    handler = function(bufnr, matches, results, handler) end,
  },

  zio_type = {
    query = parse_query([[
(
  generic_type (
    (
     (type_identifier) @start (#eq? @start "ZIO")
    )
    type_arguments: (
      type_arguments 
      (type_identifier) @R_id 
      (type_identifier) @E_id 
      (type_identifier) @A_id 
    ) @finish
  )
)
]]),

    handler = function(results, bufnr, matches, callback)
      local start = matches[1]
      local finish = matches[5]

      local r_value = utils.get_node_text(bufnr, matches[2])
      local e_value = utils.get_node_text(bufnr, matches[3])
      local a_value = utils.get_node_text(bufnr, matches[4])

      local start_row, start_col, _, _ = start:range()
      local _, _, end_row, end_col = finish:range()

      -- stylua: ignore start
      local lookup = {
        { "Any",   "Nothing",   'UIO['.. a_value .. ']' },
        { "Any",   "Throwable", 'Task[' .. a_value .. ']'  },
        { "Any",   e_value,     'IO[' .. e_value .. ', ' .. a_value .. ']'  },
        { r_value, "Nothing",   'URIO['.. r_value ..', ' .. a_value .. ']' },
        { r_value, "Throwable", 'RIO[' .. r_value ..', ' .. a_value .. ']' }
      }
      -- stylua: ignore end

      for _, m in ipairs(lookup) do
        if r_value == m[1] and e_value == m[2] then
          local replacement = m[3]

          callback(results, {
            diagnostic = {
              row = start_row,
              start_col = start_col,
              end_col = end_col,
            },
            action = {
              start_row = start_row,
              start_col = start_col,
              end_row = end_row,
              end_col = end_col,
            },
            replacement = replacement,
            title = 'ZIO: replace ZIO[' .. r_value .. ', ' .. e_value .. ', ' .. a_value .. '] with ' .. replacement,
          })
        end
      end
    end,
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
--- @return function callback
function M.run_query(opts)
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local start_line = opts.start_line or 0
  local end_line = opts.end_line or vim.api.nvim_buf_line_count(bufnr)

  local root = opts.root
  local handler = opts.handler

  return function(callback)
    --- @type table
    ---   - query (vim.treesitter.Query) - compiled treesitter query
    ---   - handler (function) - function that knows how to collect results of the match
    local query = queries[opts.query_name]
    if query == nil then
      return callback({})
    end

    local ok, query_results = pcall(function()
      return query.query:iter_matches(root, bufnr, start_line, end_line + 1)
    end)

    local results = {}

    if ok then
      for _, matches, _ in query_results do
        query.handler(results, bufnr, matches, handler)
      end
    else
      vim.notify('Query ' .. opts.query_name .. ' failed ' .. query_results, vim.log.levels.WARN)
    end

    return callback(results)
  end
end

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
