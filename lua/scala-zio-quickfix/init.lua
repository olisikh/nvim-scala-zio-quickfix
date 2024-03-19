local null_ls = require('null-ls')
local parsers = require('nvim-treesitter.parsers')

local utils = require('scala-zio-quickfix.utils')
local queries = require('scala-zio-quickfix.query')

local lang = 'scala'

local nio = require('nio')

local M = {}

M.setup = function()
  null_ls.register({
    name = 'zio-code-action',
    method = null_ls.methods.CODE_ACTION,
    filetypes = { lang },
    generator = {
      fn = function(context)
        local bufnr = vim.api.nvim_get_current_buf()
        -- local total_lines = vim.api.nvim_buf_line_count(bufnr)
        --
        -- local client = nio.lsp.get_clients({ name = 'scala' })[1]

        -- if client == nil then
        -- if client is not ready, don't do anything
        --   return { {} }
        -- end

        local range = context.lsp_params.range

        local start_row = range.start.line
        local start_col = range.start.character
        local end_row = range['end'].line
        local end_col = range['end'].character

        -- vim.print(context)

        return M.resolve_actions(bufnr, start_row, end_row)
      end,
    },
  })

  null_ls.register({
    name = 'zio-diagnostic',
    method = null_ls.methods.DIAGNOSTICS,
    filetypes = { lang },
    generator = {
      fn = function(context)
        -- local client = nio.lsp.get_clients({ name = 'scala' })[1]

        -- if client == nil then
        -- if client is not ready, don't do anything
        --   return { {} }
        -- end

        return M.collect_diagnostics(vim.api.nvim_get_current_buf())
      end,
    },
  })
end

function M.resolve_actions(bufnr, start_line, end_line)
  local root = parsers.get_tree_root(bufnr)
  local outputs = {}

  local query = queries.map_unit

  for _, matches, _ in query:iter_matches(root, bufnr, start_line, end_line + 1) do
    local field = matches[1]
    local args = matches[3]

    local _, _, start_row, start_col = field:range()
    local _, _, end_row, end_col = args:range()

    local parent = utils.find_call_expression(field)

    utils.verify_type_is_zio(bufnr, parent, function()
      -- vim.print('Our dude!')

      table.insert(
        outputs,
        utils.make_code_action('ZIO: Replace with .unit smart constructor', function()
          vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
        end)
      )
    end)
  end

  -- vim.print('Resolved actions:')
  -- vim.print(outputs)

  return outputs
end

M.collect_diagnostics = function(bufnr)
  -- TODO: take it from the null-ls event?
  local root = parsers.get_tree_root(bufnr)
  local outputs = {}

  local function fix_map_unit()
    local query = queries.map_unit

    for _, matches, _ in query:iter_matches(root, bufnr) do
      local field = matches[1]
      local args = matches[3]

      local _, _, start_row, start_col = field:range()
      local _, _, end_row, end_col = args:range()

      local parent = utils.find_call_expression(field)

      utils.verify_type_is_zio(bufnr, parent, function()
        -- vim.print('Made a diagnostic!')
        table.insert(
          outputs,
          utils.make_diagnostic(end_row, start_col, end_col, 'ZIO: replace .map(_ => ()) with .unit')
        )
      end)
    end
  end

  -- local function fix_map_zip_right()
  --   local query = queries.zip_right_unit
  --   for _, matches, _ in query:iter_matches(root, bufnr) do
  --     local field = matches[1]
  --     local args = matches[3]
  --
  --     local _, _, start_row, start_col = field:range()
  --     local _, _, end_row, end_col = args:range()
  --
  --     table.insert(outputs, {
  --       title = 'ZIO: replace *> ZIO.unit with .unit',
  --       bufnr = bufnr,
  --       start_row = start_row,
  --       start_col = start_col,
  --       end_col = end_col,
  --       end_row = end_row,
  --       message = 'ZIO: Replace with .unit smart constructor',
  --       severity = vim.diagnostic.severity.HINT,
  --       fn = function()
  --         vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
  --       end,
  --     })
  --   end
  -- end
  --
  -- local function fix_as_unit()
  --   local query = queries.as_unit
  --   for _, matches, _ in query:iter_matches(root, bufnr) do
  --     local field = matches[1]
  --     local args = matches[3]
  --
  --     local _, _, start_row, start_col = field:range()
  --     local _, _, end_row, end_col = args:range()
  --
  --     table.insert(outputs, {
  --       title = 'ZIO: replace .as(()) with .unit',
  --       bufnr = bufnr,
  --       start_row = start_row,
  --       start_col = start_col,
  --       end_col = end_col,
  --       end_row = end_row,
  --       message = 'ZIO: Replace with .unit smart constructor',
  --       severity = vim.diagnostic.severity.HINT,
  --       fn = function()
  --         vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
  --       end,
  --     })
  --   end
  -- end
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

  fix_map_unit()
  -- fix_map_zip_right()
  -- fix_as_unit()
  -- fix_as_value()
  -- fix_map_value()
  -- fix_fold_cause_ignore()
  -- fix_unit_catch_all_unit()
  -- fix_map_error_bimap()

  -- vim.print('Resolved actions:')
  -- vim.print(outputs)

  return outputs
end

return M
