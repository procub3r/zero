# Zero
Zero is a static site generator written in Zig. It will be used to generate my personal site!

## How to use
- Setup a site root that looks like this
    ```
    site_root
    ├── layouts
    │  ├── post.html
    │  └── ...
    └── src
       ├── index.md
       └── ...
    ```
- All layouts (templates) must be in the `layouts/` folder. Write your layout file as regular html with variables being `<!--{variable name here}-->`.
- All variables are replaced with their value specified in the frontmatter of the markdown source while rendering. The `content` variable is special and is replaced with the html content generated from the markdown source.
- All posts must be in the `src/` folder. Write your posts in markdown with a yaml frontmatter section. The format is as follows:
    ```markdown
    ---
    title: Title Of The Post
    desc: Description Of The Post
    layout: post
    any arbitrary key: any arbitrary value
    you can have: how many ever you wish
    ---
    
    # Your post's markdown here
    It's quite straightforward innit?
    ```
    All the `key: value` pairs in the frontmatter are used to populate variables used in the layout file while rendering. Any variables not used in the layout file will simply be ignored.
- `cd` into your site root and run the `zero` binary for profit :D

## Build
- Clone this repo with `--recurse-submodules` to get the md4c dependency
- Run `zig build` to build. The executable can be found at `zig-out/bin/zero`

## TODO
- [x] Markdown rendering
- [x] Frontmatter parsing
- [x] Templating
- [ ] Improve README
- [ ] Tags
- [ ] Incremental builds
