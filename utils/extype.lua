extype = {}

function extype.extend (base_type)
  return function (extension)
    return function (config)
      for attr, f in pairs(extension) do
        config[attr] = f(config)
      end
      return base_type(config)
    end
  end
end

extype.empty = function (config)
  return config
end
