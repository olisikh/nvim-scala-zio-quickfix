local async = require('plenary.async')
local parsers = require('nvim-treesitter.parsers')
local query = require('scala-zio-quickfix.query')
local utils = require('scala-zio-quickfix.utils')

local M = {}

local function make_code_action(bufnr, result)
  return {
    title = result.title,
    action = function()
      local action = result.action

      vim.api.nvim_buf_set_text(
        bufnr,
        action.start_row,
        action.start_col,
        action.end_row,
        action.end_col,
        { result.replacement }
      )
    end,
  }
end

function M.resolve_actions(bufnr, start_line, end_line, done)
  local root = parsers.get_tree_root(bufnr)

  local ok, actions = pcall(async.util.join, {
    async.wrap(
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'succeed_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
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
        handler = function(actions, result)
          table.insert(actions, make_code_action(bufnr, result))
        end,
      }),
      1
    ),
  })

  if ok then
    done(utils.flatten_array(actions))
  else
    -- if failed, return nothing
    vim.notify('Failed to collect actions: ' .. actions)
    done(nil)
  end
end

return M
