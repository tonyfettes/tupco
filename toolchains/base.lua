tup.include('../utils/array.lua')
tup.include('../utils/table.lua')
tup.include('../utils/extype.lua')

-- toolchains = {}

function toolchain (content)
  assert(type(content) == "table",
    "toolchain should be specified using table")
  assert(content.profiles ~= nil and content.profiles.base ~= nil,
    "toolchain should at least contains a base profile")
  assert(content.recipes ~= nil and content.profiles.base ~= nil,
    "toolchain should at least contains some recipes")
  return content
end

profile = {}

profile.extend = extype.extend
profile.none = extype.empty
profile.base = function (config)
  config.build_dir = 'build/' .. config.build_dir
  return config
end

recipe = {}

recipe.extend = extype.extend
recipe.none = extype.empty
recipe.base = function (config)
  config.sources = config.sources or {}
  return config
end
