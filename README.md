# 🫵 blame.nvim
**blame.nvim** is a [fugitive.vim](https://github.com/tpope/vim-fugitive) style git blame visualizer for Neovim.


Window:
<img width="1499" alt="window_blame_cut" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/3a3c0a87-8f6b-461a-9ea7-cd849c2de326">


Virtual:
<img width="1495" alt="virtual_blame_cut" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/8c17c8ae-901e-4183-ac73-c62bb4a259dc">


_Same commits are highlighted in the same color_

## Installation

```lua
{
  "FabijanZulj/blame.nvim"
}
```

## Usage
The following commands are used:
- `ToggleBlame [mode]` - Toggle the blame window or virtual text. If no mode is provided it opens the `window` type
- `EnableBlame [mode]` - Enables the blame window or virtual text. If no mode is provided it opens the `window` type
- `DisableBlame` - Disables the blame window or virtual text whichever is currently open

There are two modes:
- `window` - fugitive style window to the left of the window
- `virtual` - blame shown in a virtual text floated to the right

## Configuration

These are the fields you can configure by passing them to the `require('blame').setup({})` function:
- `width` - number - fixed width of the window  (default: width of longest blame line + 8)
- `date_format` - string - Pattern for the date (default: "%Y/%m/%d %H:%M")
- `format` - function - A custom method to format blames. See bellow for an example.
- `virtual_style` - "right_align" or "float" - Float moves the virtual text close to the content of the file. (default : "right_align")
- `merge_consecutive` - boolean - Merge consecutive blames that are from the same commit
- `commit_detail_view` - string - "tab"|"split"|"vsplit"|"current" - Open commit details in a new tab, split, vsplit or current buffer

### Custom format example.

You can use a custom function to format blames, this function gets a table containing attributes of `git blame --lines-porcelaine` and an additional
`date` value formated using the `date_format` option. Your custom methods just needs to returns a string.

Example:

```lua
require('blame').setup({
	format = function(blame)
		return string.format("%s %s %s", blame.author, blame.date, blame.summary)
	end,
})
```

Available options:
```lua
{
  hash = "e101b2ed9cdd29a37de596b95a6ec27f1c3f82ae",
  author = "FabijanZulj",
  ["author-mail"] = "<38249221+FabijanZulj@users.noreply.github.com>",
  ["author-time"] = 1692005070,
  ["author-tz"] = "+0200",
  committer "GitHub",
  ["committer-mail"] = "<noreply@github.com>",
  ["committer-time"] = 1692005070,
  date = "2024-31-03 03:25"
  ["committer-tz"] = "+0200",
  summary = "Create README.md",
  filename = "README.md",
}
```
