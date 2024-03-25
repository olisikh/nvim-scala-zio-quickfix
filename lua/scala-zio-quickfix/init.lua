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

        local bufnr = context.bufnr
        local range = context.lsp_params.range

        local start_row = range['start'].line
        local start_col = range['start'].character
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
        -- vim.print(context)

        local bufnr = context.bufnr
        -- local method = context.lsp_method -- textDocument/didOpen
        -- local content = context.lsp_params.textDocument.text

        local metals = utils.ensure_metals(bufnr, 0)
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
      query.run_query({
        bufnr = bufnr,
        root = root,
        query_name = 'succeed_unit',
        start_line = start_line,
        end_line = end_line,
        handler = function(actions, start_row, start_col, end_row, end_col)
          table.insert(
            actions,
            utils.make_code_action('ZIO: Replace ZIO.succeed(()) with ZIO.unit', function()
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
            utils.make_code_action('ZIO: Replace with .unit smart constructor', function()
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
            utils.make_code_action('ZIO: Replace ' .. replaced .. ' with .unit', function()
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
            utils.make_code_action('ZIO: Replace .as(()) with .unit', function()
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
            utils.make_code_action(
              "ZIO: Replace '*> ZIO.succeed(" .. value .. ")' with '.as(" .. value .. ")'",
              function()
                vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { '.as(' .. value .. ')' })
              end
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
        handler = function(actions, start_row, start_col, end_row, end_col, value)
          table.insert(
            actions,
            utils.make_code_action('ZIO: replace .map(_ => ' .. value .. ') with .as(' .. value .. ')', function()
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
            utils.make_code_action('ZIO: replace .foldCause(_ => ()), _ => ()) with .ignore', function()
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

M.collect_diagnostics = function(bufnr, done)
  local root = parsers.get_tree_root(bufnr)

  local start_line = 0
  local end_line = vim.api.nvim_buf_line_count(bufnr)

  local diagnostics = async.util.join({
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
            utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace ZIO.succeed(()) with ZIO.unit')
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
            utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace .map(_ => ()) with .unit')
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
            utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace *> ' .. replaced .. ' with .unit')
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
          table.insert(
            diagnostics,
            utils.make_diagnostic(source, end_row, start_col, end_col, 'ZIO: replace .as(()) with .unit')
          )
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
            utils.make_diagnostic(
              source,
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
            utils.make_diagnostic(
              source,
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
            utils.make_diagnostic(
              source,
              end_row,
              start_col,
              end_col,
              'ZIO: replace .foldCause(_ => (), _ => ()) with .ignore'
            )
          )
        end,
      }),
      1
    ),
  })

  done(utils.flatten_array(diagnostics))
end

return M
