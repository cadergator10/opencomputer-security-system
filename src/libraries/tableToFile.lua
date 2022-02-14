local serialization = require("serialization")

local tableToFile = {}

function tableToFile.load(location)
  --returns a table stored in a file.
  local tableFile = assert(io.open(location))
  return serialization.unserialize(tableFile:read("*all"))
end

function tableToFile.save(table, location)
  --saves a table to a file
  local tableFile = assert(io.open(location, "w"))
  tableFile:write(serialization.serialize(table))
  tableFile:close()
end

return tableToFile