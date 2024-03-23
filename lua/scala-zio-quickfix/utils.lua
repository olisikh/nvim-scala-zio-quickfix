local async = require('plenary.async')
local ts = vim.treesitter

local M = {}

function M.make_code_action(message, fn)
  return { title = message, action = fn }
end

function M.make_diagnostic(source, row, start_col, end_col, message)
  return {
    row = row + 1,
    col = start_col + 1,
    end_col = end_col + 1,
    message = message,
    source = source,
    severity = vim.diagnostic.severity.HINT,
  }
end

M.ensure_metals = function(bufnr, n)
  if n == 10 then
    return nil
  else
    local metals = vim.lsp.get_active_clients({
      bufnr = bufnr,
      name = 'metals',
    })[1]

    if not metals then
      async.util.sleep(1000)
      -- vim.print("metals not confirmed, sleep 1 sec")
      return M.ensure_metals(n + 1)
    else
      -- vim.print("metals confirmed")
      -- vim.print(metals)
      return metals
    end
  end
end

M.parse_ts_query = function(lang, query)
  return ts.query.parse(lang, query)
end

M.get_node_text = function(bufnr, node)
  return ts.get_node_text(node, bufnr)
end

-- TODO: make it async
M.verify_type_is_zio = function(bufnr, parent)
  local p_start_row, p_start_col, p_end_row, p_end_col = parent:range()
  local start_pos = { p_start_row, p_start_col }
  local end_pos = { p_end_row, p_end_col }

  -- TODO: use async version instead

  local params = vim.lsp.util.make_given_range_params(start_pos, end_pos)
  local responses, err = vim.lsp.buf_request_sync(bufnr, 'textDocument/hover', params, 10000)

  if err ~= nil then
    vim.print(err)
    return false
  end

  if responses == nil then
    -- vim.print('No response from LSP')
    return false
  end

  -- vim.print(responses)

  local is_zio = false
  for _, response in ipairs(responses) do
    if response.err ~= nil then
      vim.print(response.err)
    else
      -- TODO: this is unreliable... learn how to do better
      local starts_with_zio = '**Expression type**:\n```scala\nZIO'
      local result = response.result

      -- true if is zio otherwise false
      is_zio = result ~= nil
        and result.contents ~= nil
        and result.contents.value ~= nil
        and M.starts_with(result.contents.value, starts_with_zio)

      if is_zio then
        break
      end
    end
  end

  -- if not is_zio then
  --   vim.print("Couldn't verify type of expression via LSP")
  --   vim.print(M.print_ts_node(parent))
  -- end

  return is_zio
end

--- type node: @Node
function M.find_parent_by_type(node, type)
  local curr_node = node
  while curr_node do
    if curr_node:type() == type then
      return curr_node
    else
      curr_node = curr_node:parent()
    end
  end
  return nil
end

function M.print_ts_node(node, bufnr)
  print('Type:', node:type())
  print('Start:', node:start())
  print('End:', node:end_())

  vim.print(vim.treesitter.get_node_text(node, bufnr or vim.api.nvim_get_current_buf()))
end

function M.starts_with(str, start)
  return str:sub(1, #start) == start
end

function M.flatten_array(arr)
  local function is_array(t)
    local i = 0
    for _ in pairs(t) do
      i = i + 1
      if t[i] == nil then
        return false
      end
    end
    return true
  end

  local result = {}
  for _, item in ipairs(arr) do
    if is_array(item) then
      local flattenedSubArray = M.flatten_array(item)
      for _, subitem in ipairs(flattenedSubArray) do
        table.insert(result, subitem)
      end
    else
      table.insert(result, item)
    end
  end
  return result
end

return M
