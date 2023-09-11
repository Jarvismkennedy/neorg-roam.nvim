



# Neorg Roam

Like org-roam. But for Neorg. 


## Install

Install with your plugin manager. Here is an example with packer.
```lua 
use({"jarvismkennedy/neorg-roam.nvim", 
 requires = { 
  "nvim-telescope/telescope.nvim", 
  "nvim-lua/plenary.nvim"
 }
})
```
And then set it up as a neorg module.
```lua
require("neorg").setup({ 
 load = { 
  ["core.defaults"] = {},
  ["core.dirman"] = {
   config = { 
	   workspaces = { 
		   notes = "~/Documents/neorg/notes"
		   roam = "~/Documents/neorg/roam"
	   }
	   default_workspace = "roam"
   }
  },
  ["core.integrations.roam"] = { 
   -- default keymaps
   config  = {
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
	   -- telescope theme
	   theme = "ivy",

	   capture_templates = {
		   {
			   name = "default",
			   file =  "${title}",
			   lines = { "" }, 
		   }
	   },
	   substitutions = {
		   title = function(metadata)
			   return metadata.title
		   end,
		   date = function(metadata)
			   return os.date("%Y-%m-%d")
		   end
	   }
   }
  }
 }
})
```


## Capture templates

Capture templates are defined as a list in the roam config table.
```lua	
{
 name = "new computer science note",
 file = "classes/computer_science/${title}_${date}",
 title = "${title}"
 lines = { "","* ${heading1}", "" },
}
```
Capture templates have support for substitution with the `"${substitution}"` syntax. Substitutions are functions 
defined in the config table which take a metadata table as a parameter and return a string. The
metadata table currently only supports the `title` field. The builtin substitutions are
`${title}`, and `${date}` as above. The `${title}` substitution is the `@document.meta` title if the file exists already,
or the telescope prompt if it does not exist. The file and title fields are only updated when
capturing a new file. In the above example, if you don't override the `title` field then it will
default to the filename which is `${title}_${date}`.


### Capture template fields

- **name:** identifier for the template 
- **file** the path where the file will be saved. The norg extension will be added automatically
- **title:** the metadata title to inject into the `@document.meta` tag
- **lines:** the list of lines to insert


### Capture templates to do

-  Currently capture templates always insert after the metadata. Support a target property to
      insert after any tree-sitter node.
-  Support the `narrowed` flag to capture in a blank buffer and write lines to file on save.


## currently implemented features

- Find notes.
- Insert links to norg files.
- Capture notes. 
- Capture to the index file.
- Capture templates


## TODO:

- Create sql module.
- Implement back links.
- Other types of linkables.
- Write tests.
