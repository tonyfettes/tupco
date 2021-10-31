tup.include('toolchains/toolchains.lua')

function unit (config)
  assert(type(config) == "table",
    "unit should be specified using table")
  assert(config.recipes ~= nil and type(config.recipes) == "table",
    "unit should at least contains recipes as table")
  config.profiles = config.profiles or {}
  for key, value in pairs(config) do
    if key ~= "recipes" then
      for _, recipe in pairs(config.recipes) do
        recipe[key] = recipe[key] or {}
        table.append(recipe[key], value)
      end
    end
  end
  for target, recipe in pairs(config.recipes) do
    recipe.target = recipe.target or target
    recipe.out = recipe:build()
  end
  return config
end
