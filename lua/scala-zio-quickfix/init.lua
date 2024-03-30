local null_ls = require('null-ls')
local utils = require('scala-zio-quickfix.utils')
local constants = require('scala-zio-quickfix.constants')

local lang = constants.lang
local source = constants.source

local diagnostics = require('scala-zio-quickfix.diagnostics')
local actions = require('scala-zio-quickfix.actions')

local M = {}

M.setup = function()
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
          return done(nil)
        end

        diagnostics.collect_diagnostics(bufnr, done)
      end,
    },
  })

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

        actions.resolve_actions(bufnr, start_row, end_row, done)
      end,
    },
  })
end

return M
