array = {}

function array.concat (first, last)
  local result = {}
  for _, element in ipairs(first) do
    table.insert(result, element)
  end
  for _, element in ipairs(last) do
    table.insert(result, element)
  end
  return result
end

function array.append(first, last)
  for _, element in ipairs(last) do
    table.insert(first, element)
  end
end

array.insert = table.insert
