local parsers = require('nvim-treesitter.parsers')
local async = require('plenary.async')
local utils = require('scala-zio-quickfix.utils')
local query = require('scala-zio-quickfix.query')
local constants = require('scala-zio-quickfix.constants')

local source = constants.source

local M = {}

local function make_diagnostic(row, start_col, end_col, message)
  return {
    row = row + 1,
    col = start_col + 1,
    end_col = end_col + 1,
    message = message,
    source = source,
    severity = vim.diagnostic.severity.HINT,
  }
end

function M.collect_diagnostics(bufnr, done)
  local root = parsers.get_tree_root(bufnr)

  local start_line = 0
  local end_line = vim.api.nvim_buf_line_count(bufnr)

  local ok, diagnostics = pcall(async.util.join, {
    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'succeed_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(diagnostics, _, start_col, end_row, end_col)
          table.insert(
            diagnostics,
            make_diagnostic(end_row, start_col, end_col, 'ZIO: replace ZIO.succeed(()) with ZIO.unit')
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
        handler = function(diagnostics, _, start_col, end_row, end_col)
          table.insert(
            diagnostics,
            make_diagnostic(end_row, start_col, end_col, 'ZIO: replace .map(_ => ()) with .unit')
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
        handler = function(diagnostics, _, start_col, end_row, end_col, replaced)
          table.insert(
            diagnostics,
            make_diagnostic(end_row, start_col, end_col, 'ZIO: replace *> ' .. replaced .. ' with .unit')
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
        handler = function(diagnostics, _, start_col, end_row, end_col)
          table.insert(diagnostics, make_diagnostic(end_row, start_col, end_col, 'ZIO: replace .as(()) with .unit'))
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bunfr = bufnr,
        root = root,
        query_name = 'as_value',
        start_line = start_line,
        end_line = end_line,
        handler = function(diagnostics, _, start_col, end_row, end_col, value)
          table.insert(
            diagnostics,
            make_diagnostic(
              end_row,
              start_col,
              end_col,
              'ZIO: replace *> ZIO.succeed(' .. value .. ') with .as(' .. value .. ')'
            )
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
        handler = function(diagnostics, _, start_col, end_row, end_col, value)
          table.insert(
            diagnostics,
            make_diagnostic(
              end_row,
              start_col,
              end_col,
              'ZIO: replace .map(_ => ' .. value .. ') with .as(' .. value .. ')'
            )
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
        handler = function(diagnostics, _, start_col, end_row, end_col)
          table.insert(
            diagnostics,
            make_diagnostic(end_row, start_col, end_col, 'ZIO: replace .foldCause(_ => (), _ => ()) with .ignore')
          )
        end,
      }),
      1
    ),
  })

  if ok then
    done(utils.flatten_array(diagnostics))
  else
    -- failed to run diagnostics collection, will retry next time when triggered
    done(nil)
  end
end

return M
