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

local function flatten(sources)
  for k, v in pairs(sources) do
    if type(k) == "string" then
      if type(v) == "table" then
        flatten(v)
        for _, vv in ipairs(v) do
          table.insert(sources, vv)
        end
      elseif type(v) == "string" then
        table.insert(sources, k .. v)
      end
      sources[k] = nil
    end
  end
end

recipe.extend = extype.extend
recipe.none = extype.empty
recipe.base = function (config)
  config.sources = config.sources or {}
  flatten(config.sources)
  return config
end
