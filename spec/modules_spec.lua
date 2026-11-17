local wezterm = require "wezterm"

local theme = dofile("spec/support/scenarios.lua").theme

---@param p? table pane overrides
local function pane(p)
  p = p or {}
  return {
    get_domain_name = function()
      return p.domain or "local"
    end,
    get_foreground_process_name = function()
      return p.process
    end,
    get_user_vars = function()
      return p.vars or {}
    end,
    get_title = function()
      return p.title
    end,
    get_current_working_dir = function()
      return p.cwd
    end,
  }
end

---@param w? table window overrides
local function window(w)
  w = w or {}
  return {
    active_key_table = function()
      return w.key_table
    end,
    mux_window = function()
      return {
        tabs_with_info = function()
          return w.tabs or {}
        end,
      }
    end,
  }
end

local function text_of(spec)
  return spec.text and spec.text.value
end

describe("built-in modules", function()
  local modules

  before_each(function()
    wezterm._reset()
    for k in pairs(package.loaded) do
      if k:match "^mosaic" then
        package.loaded[k] = nil
      end
    end
    modules = require "mosaic.modules"
  end)

  local function call(name, w, p)
    return modules[name](w or window(), p or pane(), theme, {})
  end

  it("loads every registered builtin", function()
    for _, name in ipairs {
      "battery",
      "clock",
      "cpu",
      "cwd",
      "disk",
      "domain",
      "hints",
      "hostname",
      "leader",
      "mode",
      "network",
      "parent",
      "process",
      "ram",
      "ssh",
      "tabs",
      "title",
      "username",
      "workspace",
      "zoomed",
    } do
      assert.is_not_nil(modules[name], name)
    end
  end)

  it("warns once for unknown names", function()
    assert.is_nil(modules.nope)
    assert.is_nil(modules.nope)
    local warns = 0
    for _, c in ipairs(wezterm._calls) do
      if c.fn == "log_warn" and tostring(c.args[1]):find("nope", 1, true) then
        warns = warns + 1
      end
    end
    assert.is_true(warns <= 1)
  end)

  it("mode names the active key table", function()
    assert.is_false(call("mode").enabled)
    assert.equal("COPY", text_of(call("mode", window { key_table = "copy_mode" })))
    assert.equal("RESIZE PANE", text_of(call("mode", window { key_table = "resize_pane" })))
  end)

  it("domain hides the local domain", function()
    assert.is_false(call("domain").enabled)
    assert.equal("WSL:Ubuntu", text_of(call("domain", nil, pane { domain = "WSL:Ubuntu" })))
  end)

  it("process shows the foreground basename", function()
    assert.is_false(call("process").enabled)
    assert.equal("nvim", text_of(call("process", nil, pane { process = "/usr/bin/nvim" })))
  end)

  it("tabs shows position and count", function()
    local tabs = {
      { index = 0, is_active = false },
      { index = 1, is_active = true },
      { index = 2, is_active = false },
    }
    assert.equal("2/3", text_of(call("tabs", window { tabs = tabs })))
    assert.is_false(call("tabs").enabled)
  end)

  it("username prefers the WEZTERM_USER user var", function()
    assert.equal(
      "remote",
      text_of(call("username", nil, pane { vars = { WEZTERM_USER = "remote" } }))
    )
    local env = os.getenv "USER" or os.getenv "USERNAME"
    if env then
      assert.equal(env, text_of(call "username"))
    end
  end)

  it("ssh shows for ssh domains and ssh processes", function()
    assert.is_false(call("ssh").enabled)
    assert.equal("box", text_of(call("ssh", nil, pane { domain = "SSH:box" })))
    assert.equal("box", text_of(call("ssh", nil, pane { domain = "SSHMUX:box" })))
    assert.equal("ssh", text_of(call("ssh", nil, pane { process = "/usr/bin/ssh" })))
    assert.is_nil(call("ssh", nil, pane { domain = "SSH:box" }).update)
  end)

  it("cwd caches its git-root walk per pane directory", function()
    local spec = call("cwd", nil, pane { cwd = "file://host/srv/a" })
    assert.equal(5, spec.update.interval)
    assert.equal("/srv/a", spec.update.key(nil, pane { cwd = "file://host/srv/a" }))
    assert.equal("/srv/b", spec.update.key(nil, pane { cwd = "file://host/srv/b" }))
  end)

  it("parent shows the parent directory name", function()
    assert.equal(
      "source",
      text_of(call("parent", nil, pane { cwd = "file://host/srv/source/project" }))
    )
    assert.equal("/", text_of(call("parent", nil, pane { cwd = "file://host/srv" })))
    assert.is_false(call("parent", nil, pane {}).enabled)
  end)

  it("title shows the pane title", function()
    assert.equal("vim", text_of(call("title", nil, pane { title = "vim" })))
    assert.is_false(call("title").enabled)
  end)

  describe("system modules", function()
    local system

    before_each(function()
      system = require "mosaic.engine.system"
    end)

    it("declare refresh intervals", function()
      system.os = "linux"
      system.read_file = function()
        return nil
      end
      assert.same({ interval = 3 }, call("cpu").update)
      assert.same({ interval = 3 }, call("ram").update)
      assert.same({ interval = 2 }, call("network").update)
      assert.same({ interval = 30 }, call("disk").update)
      assert.equal("--%", text_of(call "cpu"))
    end)

    it("hide on windows", function()
      system.os = "windows"
      for _, name in ipairs { "cpu", "ram", "network", "disk" } do
        assert.is_false(call(name).enabled, name)
      end
    end)
  end)
end)
