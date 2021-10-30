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
  flags = function (flags_in)
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
  artifacts = function (artifacts_in)
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
  --   inputs = { 'example.o', ... },
  --   output = 'example'
  --   extras = { 'example.wpa.gcno' },
  -- }
  local command = {
    'gcc',
    table.concat(args.flags, ' '),
    table.concat(args.inputs, ' '),
    '-o',
    args.output,
  }
  tup.definerule {
    inputs = args.inputs,
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

build.executable = function (self, args)
  -- args {
  --   target = ...,
  --   profile = ...,
  -- }
  local target = args.target
  local profile = args.profile
  local target_dir = profile.build_dir
  local objects = table.clone(self.objects)
  local compile_flags = profile.flags.compile
  if #self.include_dirs > 0 then
    table.append(compile_flags, {
      '-I ' .. table.concat(self.include_dirs, ' -I ')
    })
  end
  for _, source in ipairs(self.sources) do
    local object = target_dir .. tup.base(source) .. '.o'
    table.insert(objects, object)
    compile {
      flags = compile_flags,
      inputs = {source},
      output = object,
      extras = profile.artifacts.compile(target_dir, source),
    }
  end
  local link_flags = profile.flags.link
  if #self.librarys > 0 then
    table.append(link_flags, {
      '-l' .. table.concat(self.librarys, ' -l')
    })
  end
  link {
    flags = link_flags,
    inputs = objects,
    output = target_dir .. target,
    extras = profile.artifacts.link(target_dir, target)
  }
  return {
    executables = {target_dir .. target}
  }
end

build.object = function (self, args)
  -- args {
  --   target = ...,
  --   profile = ...,
  -- }
  local target = args.target
  local profile = args.profile
  local target_dir = profile.build_dir
  local objects = {}
  local compile_flags = profile.flags.compile
  if #self.include_dirs > 0 then
    table.append(compile_flags, {
      '-I ' .. table.concat(self.include_dirs, ' -I ')
    })
  end
  local source = self.sources[1]
  local object = target_dir .. target
  table.insert(objects, object)
  compile {
    flags = compile_flags,
    inputs = {source},
    output = object,
    extras = profile.artifacts.compile(target_dir, object),
  }
  return {
    objects = objects
  }
end

build.static_library = function (self, args)
  -- args {
  --   target = ...,
  --   profile = ...,
  -- }
  local target = args.target
  local profile = args.profile
  local target_dir = profile.build_dir
  local objects = table.clone(self.objects)
  local compile_flags = profile.flags.compile
  if #self.include_dirs > 0 then
    table.append(compile_flags, {
      '-I ' .. table.concat(self.include_dirs, ' -I ')
    })
  end
  for _, source in ipairs(self.sources) do
    local object = target_dir .. tup.base(source) .. '.o'
    table.insert(objects, object)
    compile {
      flags = compile_flags,
      inputs = {source},
      output = object,
      extras = profile.artifacts.compile(target_dir, source),
    }
  end
  local archive_flags = profile.flags.archive
  archive {
    flags = archive_flags,
    inputs = objects,
    output = target_dir .. target,
  }
  return {
    static_librarys = {target_dir .. target}
  }
end

build.shared_library = function (args)
end

local recipes = {}

recipes.base = recipe.extend(recipe.base) {
  include_dirs = function (include_dirs)
    return include_dirs or {}
  end,
}

recipes.object = recipe.extend(recipes.base) {
  sources = function (sources_in)
    assert(sources_in ~= nil and #sources_in == 1 and type(sources_in))
    return sources_in
  end,
  build = function (_)
    return build.object
  end
}

recipes.executable = recipe.extend(recipes.base) {
  objects = function (objects_in)
    return objects_in or {}
  end,
  static_librarys = function (static_in)
    return static_in or {}
  end,
  shared_librarys = function (shared_in)
    return shared_in or {}
  end,
  librarys = function (lib_in)
    return lib_in or {}
  end,
  build = function (_)
    return build.executable
  end
}

recipes.static_library = recipe.extend(recipes.base) {
  objects = function (objects_in)
    return objects_in or {}
  end,
  build = function (_)
    return build.static_library
  end
}

recipes.base = nil

toolchains.gcc = toolchain {
  profiles = gcc_profiles,
  recipes = recipes,
}
