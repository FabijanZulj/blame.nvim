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
- `virtual_style` - "right_align" or "float" - Float moves the virtual text close to the content of the file. (default : "right_align")

