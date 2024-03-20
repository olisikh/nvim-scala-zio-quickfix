local null_ls = require('null-ls')
local parsers = require('nvim-treesitter.parsers')

local utils = require('scala-zio-quickfix.utils')
local query = require('scala-zio-quickfix.query')
local async = require('plenary.async')

local lang = 'scala'
local source = 'null-ls-scala'

local M = {}

M.setup = function()
  null_ls.register({
    name = source,
    method = null_ls.methods.CODE_ACTION,
    filetypes = { lang },
    generator = {
      async = true,
      fn = function(context, done)
        -- vim.print(context)
        local bufnr = vim.api.nvim_get_current_buf()

        local range = context.lsp_params.range

        local start_row = range.start.line
        local start_col = range.start.character
        local end_row = range['end'].line
        local end_col = range['end'].character

        M.resolve_actions(bufnr, start_row, end_row, done)
      end,
    },
  })

  null_ls.register({
    name = source,
    method = null_ls.methods.DIAGNOSTICS,
    filetypes = { lang },
    generator = {
      async = true,
      fn = function(context, done)
        local bufnr = vim.api.nvim_get_current_buf()

        if context.lsp_method == 'textDocument/didOpen' then
          -- vim.print('sleep for a bit, until metals is ready')
          async.util.sleep(5000)
        end

        local metals = vim.lsp.get_active_clients({
          bufnr = bufnr,
          name = 'metals',
        })[1]

        if metals == nil then
          vim.notify('Metals is not ready, will check in later')
          return { {} }
        end

        M.collect_diagnostics(bufnr, done)
      end,
    },
  })
end

function M.resolve_actions(bufnr, start_line, end_line, done)
  local root = parsers.get_tree_root(bufnr)

  local actions = async.util.join({
    async.wrap(
      query.fix_map_unit(bufnr, root, start_line, end_line, function(actions, start_row, start_col, end_row, end_col)
        table.insert(
          actions,
          utils.make_code_action('ZIO: Replace with .unit smart constructor', function()
            vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
          end)
        )
      end),
      1
    ),
    async.wrap(
      query.fix_map_zip_right(
        bufnr,
        root,
        start_line,
        end_line,
        function(actions, start_row, start_col, end_row, end_col)
          table.insert(
            actions,
            utils.make_code_action('ZIO: Replace *> ZIO.unit with .unit', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
            end)
          )
        end
      ),
      1
    ),
    async.wrap(
      query.fix_as_unit(bufnr, root, start_line, end_line, function(actions, start_row, start_col, end_row, end_col)
        table.insert(
          actions,
          utils.make_code_action('ZIO: Replace .as(()) with .unit', function()
            vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.unit' })
          end)
        )
      end),
      1
    ),
    async.wrap(
      query.fix_as_value(
        bufnr,
        root,
        start_line,
        end_line,
        function(actions, start_row, start_col, end_row, end_col, value)
          table.insert(
            actions,
            utils.make_code_action('ZIO: Replace *> ZIO.succeed(' .. value .. ') with .as(' .. value .. ')', function()
              vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. value .. ')' })
            end)
          )
        end
      ),
      1
    ),
  })

  done(utils.flatten_array(actions))
end

M.collect_diagnostics = function(bufnr, done)
  local root = parsers.get_tree_root(bufnr)
  local start_line = 0
  local end_line = vim.api.nvim_buf_line_count(bufnr)

  local diagnostics = async.util.join({
    async.wrap(
      query.fix_map_unit(bufnr, root, start_line, end_line, function(diagnostics, _, start_col, end_row, end_col)
        table.insert(
          diagnostics,
          utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace .map(_ => ()) with .unit')
        )
      end),
      1
    ),
    async.wrap(
      query.fix_map_zip_right(bufnr, root, start_line, end_line, function(diagnostics, _, start_col, end_row, end_col)
        table.insert(
          diagnostics,
          utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace *> ZIO.succeed(()) with .unit')
        )
      end),
      1
    ),
    async.wrap(
      query.fix_as_unit(bufnr, root, start_line, end_line, function(diagnostics, _, start_col, end_row, end_col)
        table.insert(
          diagnostics,
          utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace .as(()) with .unit')
        )
      end),
      1
    ),
    async.wrap(
      query.fix_as_value(bufnr, root, start_line, end_line, function(diagnostics, _, start_col, end_row, end_col, value)
        table.insert(
          diagnostics,
          utils.make_diagnostic(
            source,
            end_row,
            start_col,
            end_col,
            'ZIO: replace *> ZIO.succeed(' .. value .. ') with .as(' .. value .. ')'
          )
        )
      end),
      1
    ),
  })

  done(utils.flatten_array(diagnostics))
end

return M
