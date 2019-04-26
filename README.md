# Tagbuf.kak

This is a stripped down version of Andrew Orsts' [Tagbar.kak][1] script. It
displays tags for the current buffer in a new `*tagbuf*` buffer instead
of a new Kak client in a separate window or tmux pane. It also does not
automatically update, you must call the `tagbuf` command to generate a new
list of tags. It uses [ctags][2] to  generate tags for current buffer, and
[readtags][3] to display them.

## Installation

### With [plug.kak][4]
Add this snippet to your `kakrc`:

```kak
plug "mogenson/tagbuf.kak"
```

### Without Plugin Manager
Clone this repo, and place `tagbuf.kak` to your autoload directory, or source it
manually.

## Dependencies
For this plugin to function, you need working [ctags][2] and [readtags][3]
programs. Note that [readtags][3] isn't shipped with older ctags
implementations. [universal-ctags][2] is recommended.

## Configuration
Tagbuf.kak supports configuration via these options:
- `tagbuf_sort` - affects tags sorting method in sections of the tagbuf buffer
- `tagbuf_display_anon` - affects displaying of anonymous tags
- `tagbuf_ctags_cmd` - command used to generate tags file (default: `ctags`)

## Usage
Tagbuf.kak provides one command:
- `tagbuf` - create or update the `*tagbuf*` buffer

In `*tagbuf*` buffer you can use <kbd>Ret</kbd> key to jump to the definition of
the tag.

[1]: https://github.com/andreyorst/tagbar.kak
[2]: https://ctags.io/
[3]: http://docs.ctags.io/en/latest/news.html#readtags
[4]: https://github.com/andreyorst/plug.kak
