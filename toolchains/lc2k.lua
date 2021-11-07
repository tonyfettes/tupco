tup.include('base.lua')

local toolchain_path = 'build/release/'

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

local simulate = {}

simulate.pipeline = function (args)
  local pipeline_simulator = toolchain_path .. 'pipeline'
  local command = {
    pipeline_simulator,
    args.input,
    '>',
    args.output,
  }
  tup.definerule {
    inputs = {pipeline_simulator, args.input},
    command = table.concat(command, ' '),
    outputs = {args.output}
  }
end

local build = {}

build.executable = function (self)
  local out = {
    executables = {}
  }
  local target = self.target
  for _, profile in ipairs(self.profiles) do
    local target_dir = profile.build_dir
    local objects = table.clone(self.objects) or {}
    local executable = target_dir .. target
    for _, source in ipairs(self.sources) do
      local object_dir = executable .. '.p/'
      local object = object_dir .. tup.base(source) .. '.obj'
      table.insert(objects, object)
      compile {
        input = source,
        output = object,
      }
    end
    link {
      inputs = objects,
      output = executable,
    }
    table.insert(out.executables, executable)
  end
  return out
end

build.object = function (self)
  local out = {
    objects = {}
  }
  local target = self.target
  for _, profile in ipairs(self.profiles) do
    local target_dir = profile.build_dir
    local object = target_dir .. target
    compile {
      input = self.sources[1],
      output = object
    }
    table.insert(out.objects, object)
  end
  return out
end

build.simulate = {}
build.simulate.pipeline = function (self)
  local out = {
    plains = {}
  }
  local target = self.target
  self.target = tup.base(target) .. '.mc'
  local _profiles = self.profiles
  for _, profile in ipairs(_profiles) do
    self.profiles = { profile }
    local executables = build.executable(self).executables
    local target_dir = profile.build_dir
    for _, executable in ipairs(executables) do
      local stdout = target_dir .. target
      simulate.pipeline {
        input = executable,
        output = stdout
      }
      table.insert(out.plains, stdout)
    end
  end
  return out
end

local recipes = {}

recipes.object = recipe.extend(recipe.none) {
  sources = function (config)
    local sources_in = config.sources
    assert(sources_in ~= nil and #sources_in == 1 and type(sources_in[1]) == "string")
    return sources_in
  end,
  build = function (config)
    return config.build or build.object
  end
}

recipes.executable = recipe.extend(recipe.base) {
  objects = function (config)
    return config.objects or {}
  end,
  build = function (config)
    return config.build or build.executable
  end
}

recipes.simulate = {}
recipes.simulate.pipeline = recipe.extend(recipes.executable) {
  build = function (config)
    return config.build or build.simulate.pipeline
  end
}

toolchains.lc2k = toolchain {
  profiles = profiles,
  recipes = recipes,
}
