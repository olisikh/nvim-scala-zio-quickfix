local async = require('plenary.async')
local parsers = require('nvim-treesitter.parsers')
local query = require('scala-zio-quickfix.query')
local utils = require('scala-zio-quickfix.utils')

local M = {}

local function make_code_action(message, fn)
  return { title = message, action = fn }
end

function M.resolve_actions(bufnr, start_line, end_line, done)
  local root = parsers.get_tree_root(bufnr)

  local actions = async.util.join({
    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'succeed_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col)
          table.insert(
            actions,
            make_code_action('ZIO: Replace ZIO.succeed(()) with ZIO.unit', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { 'ZIO.unit' })
            end)
          )
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'map_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col)
          table.insert(
            actions,
            make_code_action('ZIO: Replace with .unit smart constructor', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
            end)
          )
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'zip_right_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col, replaced)
          table.insert(
            actions,
            make_code_action('ZIO: Replace ' .. replaced .. ' with .unit', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
            end)
          )
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'as_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col)
          table.insert(
            actions,
            make_code_action('ZIO: Replace .as(()) with .unit', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
            end)
          )
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'as_value',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col, value)
          table.insert(
            actions,
            make_code_action("ZIO: Replace '*> ZIO.succeed(" .. value .. ")' with '.as(" .. value .. ")'", function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. value .. ')' })
            end)
          )
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'map_value',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col, value)
          table.insert(
            actions,
            make_code_action('ZIO: replace .map(_ => ' .. value .. ') with .as(' .. value .. ')', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. value .. ')' })
            end)
          )
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'fold_cause_ignore',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col)
          table.insert(
            actions,
            make_code_action('ZIO: replace .foldCause(_ => ()), _ => ()) with .ignore', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.ignore' })
            end)
          )
        end,
      }),
      1
    ),
  })

  done(utils.flatten_array(actions))
end

return M
