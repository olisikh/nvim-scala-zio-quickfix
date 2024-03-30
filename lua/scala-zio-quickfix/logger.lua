local M = {}

M.info = function(msg)
  M.log(msg, vim.log.levels.WARN)
end

M.warn = function(msg)
  M.log(msg, vim.log.levels.WARN)
end

M.error = function(msg)
  M.log(msg, vim.log.levels.ERROR)
end

M.log = function(msg, level)
  vim.notify(msg, level)
end

return M
