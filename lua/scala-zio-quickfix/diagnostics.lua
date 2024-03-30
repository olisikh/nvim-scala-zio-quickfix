local parsers = require('nvim-treesitter.parsers')
local async = require('plenary.async')
local utils = require('scala-zio-quickfix.utils')
local query = require('scala-zio-quickfix.query')
local constants = require('scala-zio-quickfix.constants')

local source = constants.source

local M = {}

local function make_diagnostic(result)
  local diagnostic = result.diagnostic
  return {
    row = diagnostic.row + 1,
    col = diagnostic.start_col + 1,
    end_col = diagnostic.end_col + 1,
    message = result.title,
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
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
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'or_else_fail',
        start_line = start_line,
        end_line = end_line,
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'or_else_fail2',
        start_line = start_line,
        end_line = end_line,
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'zio_type',
        start_line = start_line,
        end_line = end_line,
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
        end,
      }),
      1
    ),

    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'zlayer_type',
        start_line = start_line,
        end_line = end_line,
        handler = function(diagnostics, result)
          table.insert(diagnostics, make_diagnostic(result))
        end,
      }),
      1
    ),
  })

  if ok then
    done(utils.flatten_array(diagnostics))
  else
    -- failed to run diagnostics collection, will retry next time when triggered
    vim.notify('Failed to collect diagnostics: ' .. diagnostics)
    done(nil)
  end
end

return M
