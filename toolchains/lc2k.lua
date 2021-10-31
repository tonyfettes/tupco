tup.include('base.lua')

local toolchain_path = 'flick/'

local profiles = {
  ["base"] = {
    build_dir = 'build/'
  }
}

local function compile (args)
  local compiler = toolchain_path .. 'assembler'
  local command = {
    compiler,
    args.input,
    args.output,
  }
  tup.definerule {
    inputs = {compiler, args.input},
    command = table.concat(command, ' ');
    outputs = {args.output}
  }
end

local function link (args)
  local linker = toolchain_path .. 'linker'
  local command = {
    linker,
    table.concat(args.inputs, ' '),
    args.output,
  }
  tup.definerule {
    inputs = array.concat({linker}, args.inputs),
    command = table.concat(command, ' '),
    outputs = {args.output}
  }
end

local build = {}

build.executable = function (self, args)
  local profile = args.profile
  local target_dir = profile.build_dir
  local objects = table.clone(self.objects) or {}
  local target = target_dir .. args.target
  for _, source in ipairs(self.sources) do
    local object = target_dir .. tup.base(source) .. '.obj'
    table.insert(objects, object)
    compile {
      input = source,
      output = object,
    }
  end
  link {
    inputs = objects,
    output = target,
  }
  return {
    executables = { target }
  }
end

build.object = function (self, args)
  local target_dir = args.profile.build_dir
  local object = target_dir .. args.target
  compile {
    input = self.sources[1],
    output = object
  }
  return {
    objects = { object }
  }
end

local recipes = {}

recipes.object = recipe.extend(recipe.none) {
  sources = function (config)
    local sources_in = config.sources
    assert(sources_in ~= nil and #sources_in == 1 and type(sources_in[1]) == "string")
    return sources_in
  end,
  build = function (_)
    return build.object
  end
}

recipes.executable = recipe.extend(recipe.base) {
  objects = function (config)
    return config.objects or {}
  end,
  build = function (_)
    return build.executable
  end
}

toolchains.lc2k = toolchain {
  profiles = profiles,
  recipes = recipes,
}
