# 🫵 blame.nvim
**blame.nvim** is a [fugitive.vim](https://github.com/tpope/vim-fugitive) style git blame visualizer for Neovim.


Window:
<img width="1499" alt="window_blame_cut" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/68669b29-923e-48ee-9c75-39b096e98ede">


Virtual:
<img width="1489" alt="virtual_blame_cut" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/ea70061c-09a4-45d9-9eec-41881646ae25">


_Same commits are highlighted in the same color_

## Installation

```lua
return {
  {
    "FabijanZulj/blame.nvim",
    lazy = false,
    config = function()
      require('blame').setup {}
    end,
  },
}
```

### Activating additional blame options
```lua
return {
  {
    "FabijanZulj/blame.nvim",
    lazy = false,
    config = function()
      require('blame').setup {}
    end,
    opts = {
      blame_options = { '-w' },
    },
  },
}
```

## Usage
The following commands are used:
- `BlameToggle [view] [options]` - Toggle the blame with provided view and options.
    - If no view is provided, it opens the `default` (window) view.
    - If no options are provided, it fall back to `blame_options`.

There are two built-in views:
- `window` - fugitive style window to the left of the current window
- `virtual` - blame shown in a virtual text floated to the right

## Configuration

Default config:
```lua
{
    date_format = "%d.%m.%Y",
    virtual_style = "right_align",
    relative_date_if_recent = true -- this is relative only for the latest month
    views = {
        window = window_view,
        virtual = virtual_view,
        default = window_view,
    },
    focus_blame = true,
    merge_consecutive = false,
    max_summary_width = 30,
    colors = nil,
    blame_options = nil,
    commit_detail_view = "vsplit",
    format_fn = formats.commit_date_author_fn,
    mappings = {
        commit_info = "i",
        stack_push = "<TAB>",
        stack_pop = "<BS>",
        show_commit = "<CR>",
        close = { "<esc>", "q" },
        copy_hash = "y",
        open_in_browser = "o",
    }
}
```

These are the fields you can configure by passing them to the `require('blame').setup({})` function:
- `date_format` - string - Pattern for the date, '%r' for relative date
- `virtual_style` - "right_align" or "float" - Float moves the virtual text close to the content of the file.
- `views` - views that can be used when toggling blame
- `focus_blame` - boolean - Focus on the blame window when it's opened as well as blame stack push/pop
- `merge_consecutive` - boolean - Merge consecutive blames that are from the same commit
- `max_summary_width` - If date_message is used, cut the summary if it excedes this number of characters
- `colors` - list of RGB strings to use instead of randomly generated RGBs for highlights
- `blame_options` - list of blame options to use for git blame. If nil, then no options are used
- `commit_detail_view` - string | function - "tab"|"split"|"vsplit"|"current" - Open commit details in a new tab, split, vsplit or current buffer
  `function(commit_hash, row, file_pat) ... end` - Calls function and passes commit hash, caller current row and file path
- `format_fn` - format function that is used for processing of porcelain lines. See below for details
  ( built-in: `("blame.formats.default_formats").date_message` and `("blame.formats.default_formats").commit_date_author_fn` )
- `mappings` - custom mappings for various actions, you can pass in single or multiple mappings for an action.

### Features

####  Blame stack
You can see the state of the file prior to selected commit using `stack_push`(default: `<TAB>`) and `stack_pop` (default: `<BS>`) mappings.
In the pop-up on the right the stack is shown and you can go back and forward through the history of the file.

<details open>
    <summary>Details</summary>

https://github.com/FabijanZulj/blame.nvim/assets/38249221/f91bf22b-7bbe-4cdb-acac-f1c7fc993aab
</details>

#### Commit info
To see the full commit info pop-up press the `commit_info`(default: 'i') mapping on the specific commit line. (press `i` again to move into the popup window, or move cursor to close the popup)

<details open>
    <summary>Details</summary>
    <img width="1495" alt="commit_info_popup" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/3ece577d-3e40-457c-9457-5ccce58f94ff">
</details>

#### Full commit info
To see the full commit data press the `show_commit`(default `<CR>`) mapping on the commit line

<details open>
    <summary>Details</summary>
    <img width="1495" alt="commit_info_full" src="https://github.com/FabijanZulj/blame.nvim/assets/38249221/84aad831-0c0d-44fe-a38f-6a4d027070c3">
</details>

#### Copy commit hash
Press `copy_hash` (default: `y`) on a commit line to copy the full commit hash to the clipboard (both `+` and `"` registers).

#### Open commit in browser
Press `open_in_browser` (default: `o`) on a commit line to open the commit in your default browser. Supports GitHub, GitLab, and Bitbucket.

## Advanced

### Custom format function
You can provide custom format functions that get executed for every blame line and are shown in a view.
By default highlight is created for each commit hash so it can be used in hl field.

Signature of the function:

`FormatFn fun(line_porcelain: Porcelain, config:Config, idx:integer):LineWithHl`

where LineWithHl is:
```lua
---@class LineWithHl
---@field idx integer
---@field values {textValue: string, hl: string}[]
---@field format string
```

And Porcelain being:
```lua
---@class Porcelain
---@field author string
---@field author_email string
---@field author_time number
---@field author_tz string
---@field committer string
---@field committer_mail string
---@field committer_time number
---@field committer_tz string
---@field filename string
---@field hash string
---@field previous string
---@field summary string
---@field content string
```

Built in format functions are:

`("blame.formats.default_formats").date_message`
- {commit date} {summary}

`("blame.formats.default_formats").commit_date_author_fn`
- {commit hash} {commit date} {author}

Your function must return a list of values ({textValue: string, hl: string}). Those text fragments will be formatted with provided `format` field and highlighted with the HiglightGroup given in `hl`

*for more info check the implementations for 'date_message' or 'commit_date_author_fn'*


### Custom views
It is also possible to implement your custom view. To implement a custom view you need to implement this interface:
``` lua
---@class BlameView
---@field new fun(self, config: Config) : BlameView
---@field open fun(self, lines: Porcelain[])
---@field is_open fun(): boolean
---@field close fun(cleanup: boolean)
```
And add it to the config field table `views`
See 'blame.views.window_view' and 'blame.views.virtual_view' for examples

### Events
These user events are emitted
- BlameViewOpened
- BlameViewClosed

So you can do something like this:
*there are some conflicts with some winbar plugins, in this case barbecue is toggled*
```lua
vim.api.nvim_create_autocmd("User", {
    pattern = "BlameViewOpened",
    callback = function(event)
        local blame_type = event.data
        if blame_type == "window" then
            require("barbecue.ui").toggle(false)
        end
    end,
})

vim.api.nvim_create_autocmd("User", {
    pattern = "BlameViewClosed",
    callback = function(event)
        local blame_type = event.data
        if blame_type == "window" then
            require("barbecue.ui").toggle(true)
        end
    end,
})
```
