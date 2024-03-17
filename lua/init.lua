-- add relative lua folder to paths lua looks modules in
package.path = package.path .. ';./lua/lua/?.lua'

-- ZIO quickfix
--
package.loaded['quickfix'] = nil

local quickfix = require('quickfix')
quickfix.setup()

-- run this with :lua
-- vim.keymap.set("n", "<leader>,,", ":luafile ./lua/init.lua<cr>", { silent = true, noremap = true })
