# Neorg Roam

- Trying to do some of the things that org-roam does.

## Install

Install with packer
```lua 
use({"jarvismkennedy/neorgroam.nvim", 
 requires = { 
  "nvim-telescope/telescope.nvim", 
  "nvim-lua/plenary.nvim"
 }
})
```
  And then set it up as a neorg module.
```lua
require("neorg").setup({ 
ad = { 
"core.defaults"] = {},
"core.dirman"] = {
config = { 
	workspaces = { 
		notes = "~/Documents/neorg/notes"
		roam = "~/Documents/neorg/roam"
	}
	default_workspace = "roam"
}
,
"core.integrations.roam"] = { 
-- default keymaps
keymaps = {
	-- select_prompt is used to to create new note / capture from the prompt directly
	-- instead of the telescope choice.
	select_prompt = "<C-n>",
	insert_link = "<leader>ni",
	find_note = "<leader>nf",
	capture_note = "<leader>nc",
	capture_index = "<leader>nci",
	capture_cancel = "<C-q>",
	capture_save = "<C-w>",
},



```
  


## currently implemented features

- Find notes.
- Insert links to files.
- Capture notes. 
- Capture to the index file.
