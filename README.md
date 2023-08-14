# 🫵 blame.nvim
**blame.nvim** is a [fugitive.vim](https://github.com/tpope/vim-fugitive) style git blame visualizer for Neovim.


Window:
<img width="1495" alt="window_blame_cut" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/6c00542a-1d4f-41fd-90da-ae54806bd998">

Virtual:
<img width="1495" alt="virtual_blame_cut" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/c8cc5966-a384-45d0-bc34-99752734f745">

_Same commits are highlighted in the same color_

## Installation

```lua
{
  "FabijanZulj/blame.nvim"
}
```

## Usage
The following command is used:
- `ToggleBlame [mode]` - Toggle the blame window or virtual text. If no mode is provided it opens the `window` type

There are two modes:
- `window` - fugitive style window to the left of the window
- `virtual` - blame shown in a virtual text floated to the right

## Configuration

There are 2 fields you can configure by passing them to the `require('blame').setup({})` function:
- `width` - number - fixed width of the window  (default: width of longest blame line + 8)
- `date_format` - string - Pattern for the date (default: "%Y/%m/%d %H:%M")

