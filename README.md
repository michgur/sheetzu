# sheetzu
sheets tui 🐶

## ideas (random order)
- Next on the agenda: fix strings, make them immutable cause they're causing a mess
- Same subject: consider removing this shizz altogether, just use byte arrays, so many fucking bugs
### UI
- visual selection
- command mode
- csv read/write
- virtual cursor in insert mode
- infinite sheet (how does this work? chunks?)
- custom file type with styling etc.
### Design
- how should motions work? specifically long-text cells
    - this is not a text editor, maybe leave that part bare-bones
