local M = {}

function M.make_code_action(message, fn)
  return { title = message, action = fn }
end

function M.make_diagnostic(row, start_col, end_col, message)
  return {
    row = row + 1,
    col = start_col + 1,
    end_col = end_col + 1,
    message = message,
    source = 'zio-diagnostic',
    severity = vim.diagnostic.severity.HINT,
  }
end

M.verify_type_is_zio = function(bufnr, parent, cb)
  if parent ~= nil then
    -- M.print_ts_node(parent)

    local p_start_row, p_start_col, p_end_row, p_end_col = parent:range()
    local responses = vim.lsp.buf_request_sync(
      bufnr,
      'textDocument/hover',
      vim.lsp.util.make_given_range_params({ p_start_row, p_start_col }, { p_end_row, p_end_col }),
      5000
    )

    if responses ~= nil then
      for _, response in ipairs(responses) do
        if response.err ~= nil then
          vim.print(response.err)
        else
          -- TODO: this is unreliable... learn how to do better
          local starts_with_zio = '**Expression type**:\n```scala\nZIO'

          local result = response.result
          -- vim.print(result)

          if
            result ~= nil
            and result.contents ~= nil
            and result.contents.value ~= nil
            and M.starts_with(result.contents.value, starts_with_zio)
          then
            cb()
          end
        end
      end
    end
  end
end

function M.find_call_expression(node)
  local current_node = node
  while current_node do
    if current_node:type() == 'call_expression' then
      return current_node
    else
      current_node = current_node:parent()
    end
  end
  return nil -- Return nil if 'call_expression' is not found in any parent
end

function M.print_ts_node(node, bufnr)
  print('Type:', node:type())
  print('Start:', node:start())
  print('End:', node:end_()) -- Note the underscore appended to 'end' because 'end' is a reserved keyword in Lua

  vim.print(vim.treesitter.get_node_text(node, bufnr or vim.api.nvim_get_current_buf()))
end

function M.starts_with(str, start)
  return str:sub(1, #start) == start
end

return M
