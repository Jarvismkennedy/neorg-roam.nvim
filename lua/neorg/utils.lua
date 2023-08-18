local M = {}

local neorg_is_loaded = pcall(require, "neorg.core")

assert(neorg_is_loaded, "Neorg is not loaded")

M.get_current_workspace = function()
    local dirman = require("neorg.core").modules.get_module("core.dirman")
    local curr_wksp = dirman.get_current_workspace()
    return curr_wksp
end
M.get_files = function(workspace)
    local files = dirman.get_norg_files(workspace)
    return files
end
return M
