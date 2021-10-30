function table.append(first, last)
  for k, v in pairs(last) do
    first[k] = v
  end
end

function table.clone(from)
  local ret = {}
  for k, v in pairs(from) do
    ret[k] = v
  end
  return ret
end
