tup.include('base.lua')

local gcc_profiles = {
  ["base"] = {
    flags = {
      compile = {},
      link = {},
    },
    build_dir = 'build/',
    artifacts = {
      compile = function (_, _)
        return {}
      end,
      link = function (_, _)
        return {}
      end
    }
  },
}

local gcc_profile = profile.extend(profile.base) {
  flags = function (config)
    local flags_in = config.flags
    local base = gcc_profiles.base
    local out
    if flags_in == nil then
      out = table.clone(base.flags)
    else
      out = {}
      for stage_name, stage_flags in pairs(base.flags) do
        out[stage_name] = array.concat(stage_flags, flags_in[stage_name] or {})
      end
      for _, flag in ipairs(flags_in) do
        for _, stage_flags in pairs(out) do
          table.insert(stage_flags, flag)
        end
      end
    end
    return out
  end,
  artifacts = function (config)
    local artifacts_in = config.artifacts
    local base = gcc_profiles.base
    local out
    if artifacts_in == nil then
      out = table.clone(base.artifacts)
    elseif type(artifacts_in) == "table" then
      out = {}
      for stage_name, cb in pairs(base.artifacts) do
        out[stage_name] = artifacts_in[stage_name] or cb
      end
    end
    return out
  end
}

table.append(gcc_profiles, {
  ["debug"] = gcc_profile {
    flags = {
      '-ggdb',
      '-Og',
    },
    build_dir = 'debug/',
  },

  ["release"] = gcc_profile {
    flags = {
      '-O3',
      '-flto',
    },
    build_dir = 'release/',
  },
  ["profile"] = gcc_profile {
    flags = {
      '-g',
      '-pg',
      '-O3',
      '-flto',
      '--coverage',
    },
    build_dir = 'profile/',
    artifacts = {
      compile = function (build_dir, source)
        return {
          build_dir .. tup.base(source) .. '.gcno',
        }
      end,
      link = function (build_dir, executable)
        return {
          build_dir .. executable .. '.wpa.gcno',
          build_dir .. executable .. '.ltrans0.ltrans.gcno',
        }
      end
    }
  }
})

local function compile (args)
  -- args = {
  --   flags = { '-g', '-O3', ... },
  --   inputs = { 'example.c', ... },
  --   output = 'example.o',
  --   extras = { 'example.gcno', ... },
  -- }
  local command = {
    'gcc',
    table.concat(args.flags, ' '),
    '-c',
    table.concat(args.inputs, ' '),
    '-o',
    args.output,
  }
  tup.definerule {
    inputs = args.inputs,
    command = table.concat(command, ' ');
    outputs = array.concat({args.output}, args.extras)
  }
end

local function link (args)
  -- args = {
  --   flags = { '-flto', ... },
  --   inputs = {
  --     objects = { 'example.o', ... },
  --     libraries = { 'libexample.a', ... },
  --   },
  --   output = 'example'
  --   extras = { 'example.wpa.gcno' },
  -- }
  local lib_flags = {}
  local libraries = args.inputs.libraries or {}
  local inputs = table.clone(args.inputs.objects)
  for _, library in ipairs(libraries) do
    table.insert(lib_flags, '-L ' .. library[1])
    table.insert(lib_flags, '-l:' .. library[2])
  end
  local command = {
    'gcc',
    table.concat(args.flags, ' '),
    table.concat(inputs, ' '),
    table.concat(lib_flags, ' '),
    '-o',
    args.output,
  }
  for _, library in ipairs(libraries) do
    table.insert(inputs, library[1] .. library[2])
  end
  tup.definerule {
    inputs = inputs,
    command = table.concat(command, ' '),
    outputs = array.concat({args.output}, args.extras),
  }
end

local function archive (args)
  local command = {
    'gcc-ar',
    table.concat(args.flags, ' '),
    'rcs',
    args.output,
    table.concat(args.inputs, ' '),
  }
  tup.definerule {
    inputs = args.inputs,
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
  local include_dirs = self.include_dirs
  local sources = self.sources
  local libraries = self.libraries
  for _, profile in ipairs(self.profiles) do
    local objects = table.clone(self.objects)
    local target_dir = profile.build_dir
    local compile_flags = profile.flags.compile
    if #include_dirs > 0 then
      table.append(compile_flags, {
        '-I ' .. table.concat(include_dirs, ' -I ')
      })
    end
    for _, source in ipairs(sources) do
      local object = target_dir .. target .. '.p/' .. tup.base(source) .. '.o'
      table.insert(objects, object)
      compile {
        flags = compile_flags,
        inputs = {source},
        output = object,
        extras = profile.artifacts.compile(target_dir, source),
      }
    end
    local link_flags = profile.flags.link
    local executable = target_dir .. target
    link {
      flags = link_flags,
      inputs = {
        objects = objects,
        libraries = libraries,
      },
      output = executable,
      extras = profile.artifacts.link(target_dir, target)
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
    local compile_flags = profile.flags.compile
    if #self.include_dirs > 0 then
      table.append(compile_flags, {
        '-I ' .. table.concat(self.include_dirs, ' -I ')
      })
    end
    local source = self.sources[1]
    local object = target_dir .. target
    compile {
      flags = compile_flags,
      inputs = {source},
      output = object,
      extras = profile.artifacts.compile(target_dir, object),
    }
    table.insert(out.objects, object)
  end
  return out
end

build.static_library = function (self)
  local out = {
    libraries = {}
  }
  local target = self.target
  local include_dirs = self.include_dirs
  local sources = self.sources
  for _, profile in ipairs(self.profiles) do
    local target_dir = profile.build_dir
    local objects = table.clone(self.objects)
    local compile_flags = profile.flags.compile
    if #include_dirs > 0 then
      table.append(compile_flags, {
        '-I ' .. table.concat(include_dirs, ' -I ')
      })
    end
    for _, source in ipairs(sources) do
      local object = target_dir .. target .. '.p/' .. tup.base(source) .. '.o'
      table.insert(objects, object)
      compile {
        flags = compile_flags,
        inputs = {source},
        output = object,
        extras = profile.artifacts.compile(target_dir, source),
      }
    end
    local archive_flags = profile.flags.archive or {}
    archive {
      flags = archive_flags,
      inputs = objects,
      output = target_dir .. target,
    }
    table.insert(out.libraries, {target_dir, target})
  end
  return out
end

build.shared_library = function (args)
end

local gcc_recipes = {}

local function dependencies_init(config)
  local dependencies_in = config.dependencies or {}
  for _, dependency in ipairs(dependencies_in) do
    local out = dependency.out
    assert(type(out) == "table", "invalid output of dependency " .. dependency.target)
    for ty, dep_list in pairs(out) do
      config[ty] = config[ty] or {}
      table.append(config[ty], dep_list)
    end
  end
  return dependencies_in
end

local function extend_dep(base)
  return recipe.extend(base) {
    dependencies = dependencies_init
  }
end

gcc_recipes.common = recipe.extend(recipe.none) {
  sources = function (config)
    return config.sources or {}
  end,
  target = function (config)
    return config.target
  end,
  include_dirs = function (config)
    return config.include_dirs or {}
  end,
  profiles = function(config)
    return config.profiles or {gcc_profiles.base}
  end,
}

gcc_recipes.object = extend_dep (
  recipe.extend(gcc_recipes.common) {
    sources = function (config)
      local sources_in = config.sources
      assert(sources_in ~= nil and #sources_in == 1 and type(sources_in[1]) == "string",
        "sources in object recipe sould only be one array of string with length 1")
      return sources_in
    end,
    build = function (_)
      return build.object
    end
  }
)

gcc_recipes.executable = extend_dep(
  recipe.extend(gcc_recipes.common) {
    objects = function (config)
      return config.objects or {}
    end,
    libraries = function (config)
      return config.libraries or {}
    end,
    build = function (_)
      return build.executable
    end
  }
)

gcc_recipes.static_library = extend_dep(
  recipe.extend(gcc_recipes.common) {
    objects = function (config)
      return config.objects or {}
    end,
    build = function (_)
      return build.static_library
    end
  }
)

gcc_recipes.base = nil

toolchains.gcc = toolchain {
  profiles = gcc_profiles,
  recipes = gcc_recipes,
}
