local scenarios = dofile "spec/support/scenarios.lua"

local function lua_files(dir)
  local out = {}
  local p = io.popen('find "' .. dir .. '" -name "*.lua"')
  for line in p:lines() do
    out[#out + 1] = line
  end
  p:close()
  return out
end

describe("WezTerm contract", function()
  it("mocks Window and Pane strictly, as WezTerm does", function()
    local window, pane = scenarios.build(scenarios.list[1])
    assert.has_error(function()
      return window.no_such_method
    end, "attempt to get an unknown field 'no_such_method'")
    assert.has_error(function()
      return pane.get_lines_as_text
    end, "mock Pane lacks get_lines_as_text")
    assert.is_function(pane.get_title)
  end)

  it("reads wezterm.GLOBAL only through engine/store.lua", function()
    -- WezTerm hands stored tables back as userdata proxies; store.lua is the
    -- one place that knows.
    for _, file in ipairs(lua_files "plugin/mosaic") do
      if not file:match "engine/store%.lua$" then
        local n = 0
        for line in io.lines(file) do
          n = n + 1
          if line:find("GLOBAL", 1, true) and not line:match "^%s*%-%-" then
            error(
              ("%s:%d uses wezterm.GLOBAL directly; go through mosaic.engine.store"):format(file, n)
            )
          end
        end
      end
    end
  end)
end)
