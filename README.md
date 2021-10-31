# Tupco

Collection of Tupfiles

## Usage

1. Clone this repository or add it as a submodule
2. Write Tupfile.lua.

```lua
-- Example Tupfile.lua
tup.include('tupco/unit.lua')

local gcc = toolchains.gcc
local executable = gcc.executable

all = unit {
  recipes = {
    ["main"] = executable {
      sources = { 'src/main.c' },
    }
  },
  profiles = {
    gcc.profiles.debug,
  }
}
```

3. Run tup.
