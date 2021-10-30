tup.include('toolchains/toolchains.lua')

function unit (config)
  assert(type(config) == "table",
    "unit should be specified using table")
  assert(config.recipes ~= nil and type(config.recipes) == "table",
    "unit should at least contains recipes as table")
  local toolchain
  if type(config.toolchain) == "string" then
    toolchain = toolchains[config.toolchain]
  elseif type(config.toolchain) == "table" then
    toolchain = config.toolchain
  else
    assert(false, "unit should specify toolchain using string or table")
  end
  config.profiles = config.profiles or {toolchain.profiles.base}
  config.dependencies = config.dependencies or {}
  local function build (self)
    for _, profile in ipairs(self.profiles) do
      local dep_files = {}
      for _, dependency in ipairs(self.dependencies) do
        local target = dependency[2]
        local recipe = dependency[1].recipes[target]
        local dep_outputs = recipe:build {
          target = target,
          profile = profile,
        }
        for ty, list in pairs(dep_outputs) do
          if dep_files[ty] == nil then
            dep_files[ty] = {}
          end
          array.append(dep_files[ty], list)
        end
      end
      for target, recipe in pairs(self.recipes) do
        for ty, list in pairs(dep_files) do
          if recipe[ty] == nil then
            recipe[ty] = {}
          end
          array.append(recipe[ty], list)
        end
        recipe:build {
          target = target,
          profile = profile,
        }
      end
    end
  end
  return {
    toolchain = toolchain,
    dependencies = config.dependencies,
    recipes = config.recipes,
    profiles = config.profiles,
    build = build,
  }
end
