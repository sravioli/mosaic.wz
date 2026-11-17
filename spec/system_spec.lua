local wezterm = require "wezterm"

local PROC_STAT = [[
cpu  4705 356 584 3699 23 23 0 0 0 0
cpu0 1393280 32966 572056 13343292 6130 0 17875 0 23933 0
intr 114930548 113199788 3 0 5 263 0 4 [... lots more numbers ...]
]]

local MEMINFO = [[
MemTotal:       16000000 kB
MemFree:         1000000 kB
MemAvailable:    4000000 kB
Buffers:          200000 kB
]]

local NET_DEV = [[
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 9999999    1000    0    0    0     0          0         0  9999999    1000    0    0    0     0       0          0
  eth0: 1000000    2000    0    0    0     0          0         0   500000    1500    0    0    0     0       0          0
 wlan0:    2000      20    0    0    0     0          0         0     1000      10    0    0    0     0       0          0
]]

local NETSTAT = [[
Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0        16384 <Link#1>                        100     0       5000      100     0       5000     0
en0        1500  <Link#6>    a4:83:e7:00:00:01    2000     0    3000000     1500     0     700000     0
en0        1500  192.168.1     192.168.1.20       2000     -    3000000     1500     -     700000     -
utun0      1380  <Link#16>                          10     0        800       12     0        900     0
]]

local VM_STAT = [[
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               10000.
Pages active:                            200000.
Pages inactive:                          190000.
Pages wired down:                        100000.
Pages occupied by compressor:             50000.
]]

local DF = [[
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   488281250 122070312 366210938      25% /
]]

describe("mosaic.engine.system", function()
  local system

  before_each(function()
    wezterm._reset()
    package.loaded["mosaic.engine.system"] = nil
    system = require "mosaic.engine.system"
  end)

  describe("parsers", function()
    it("reads busy and total jiffies from /proc/stat", function()
      local busy, total = system.parse_proc_stat(PROC_STAT)
      assert.equal(4705 + 356 + 584 + 23 + 0 + 0, busy)
      assert.equal(4705 + 356 + 584 + 3699 + 23 + 23, total)
    end)

    it("reads used memory from /proc/meminfo", function()
      assert.near(0.75, system.parse_meminfo(MEMINFO), 1e-9)
    end)

    it("sums non-loopback interfaces from /proc/net/dev", function()
      local rx, tx = system.parse_net_dev(NET_DEV)
      assert.equal(1002000, rx)
      assert.equal(501000, tx)
    end)

    it("leaves out interfaces the caller marks virtual", function()
      local rx = system.parse_net_dev(NET_DEV, function(name)
        return name == "wlan0"
      end)
      assert.equal(1000000, rx)
    end)

    it("sums physical link rows of netstat -ibn, not tunnels or bridges", function()
      local rx, tx = system.parse_netstat(NETSTAT)
      assert.equal(3000000, rx)
      assert.equal(700000, tx)
      local text = NETSTAT .. "bridge0    1500  <Link#9>  a:b:c:d:e:f  5 0  777  5 0  777  0\n"
      assert.equal(3000000, (system.parse_netstat(text)))
    end)

    it("reads used memory from vm_stat", function()
      local memsize = 16384 * 1000000
      assert.near(350000 / 1000000, system.parse_vm_stat(VM_STAT, memsize), 1e-9)
    end)

    it("sums ps cpu percentages", function()
      assert.near(42.5, system.parse_ps_cpu "%CPU\n 12.0\n 30.5\n  0.0\n", 1e-9)
    end)

    it("reads used space from df -kP", function()
      -- df's own Use%: used / (used + available), not used / size
      assert.near(122070312 / (122070312 + 366210938), system.parse_df(DF), 1e-9)
    end)

    it("returns nil for missing or garbled input", function()
      assert.is_nil(system.parse_proc_stat(nil))
      assert.is_nil(system.parse_proc_stat "garbage")
      assert.is_nil(system.parse_meminfo "MemTotal: 0 kB\nMemAvailable: 0 kB")
      assert.is_nil(system.parse_net_dev "header only\n")
      assert.is_nil(system.parse_netstat(nil))
      assert.is_nil(system.parse_vm_stat(VM_STAT, 0))
      assert.is_nil(system.parse_ps_cpu "%CPU\n")
      assert.is_nil(system.parse_df "Filesystem\n")
    end)
  end)

  describe("samplers on linux", function()
    local files, clock

    before_each(function()
      system.os = "linux"
      files, clock = {}, 100
      system.read_file = function(path)
        return files[path]
      end
      system.now = function()
        return clock
      end
    end)

    it("needs two cpu samples, then reports the delta", function()
      files["/proc/stat"] = "cpu  100 0 100 800 0 0 0 0\n"
      assert.is_nil(system.cpu())
      files["/proc/stat"] = "cpu  150 0 150 900 0 0 0 0\n"
      assert.near(0.5, system.cpu(), 1e-9)
    end)

    it("keeps cpu samples in wezterm.GLOBAL across reloads", function()
      files["/proc/stat"] = "cpu  100 0 100 800 0 0 0 0\n"
      system.cpu()
      package.loaded["mosaic.engine.system"] = nil
      local reloaded = require "mosaic.engine.system"
      reloaded.os = "linux"
      reloaded.read_file = system.read_file
      files["/proc/stat"] = "cpu  200 0 200 800 0 0 0 0\n"
      assert.near(1, reloaded.cpu(), 1e-9)
    end)

    it("reports network rates per second", function()
      files["/proc/net/dev"] = "h\nh\n eth0: 1000 0 0 0 0 0 0 0 500 0 0 0 0 0 0 0\n"
      assert.is_nil(system.network())
      clock = 102
      files["/proc/net/dev"] = "h\nh\n eth0: 5000 0 0 0 0 0 0 0 2500 0 0 0 0 0 0 0\n"
      local down, up = system.network()
      assert.equal(2000, down)
      assert.equal(1000, up)
    end)

    it("gives a second window sampling in the same second the same readings", function()
      files["/proc/net/dev"] = "h\nh\n eth0: 1000 0 0 0 0 0 0 0 500 0 0 0 0 0 0 0\n"
      files["/proc/stat"] = "cpu  100 0 100 800 0 0 0 0\n"
      system.network()
      system.cpu()
      clock = 102
      files["/proc/net/dev"] = "h\nh\n eth0: 5000 0 0 0 0 0 0 0 2500 0 0 0 0 0 0 0\n"
      files["/proc/stat"] = "cpu  150 0 150 900 0 0 0 0\n"
      assert.equal(2000, (system.network())) -- window A
      assert.near(0.5, system.cpu(), 1e-9)
      files["/proc/net/dev"] = "h\nh\n eth0: 5100 0 0 0 0 0 0 0 2600 0 0 0 0 0 0 0\n"
      files["/proc/stat"] = "cpu  151 0 150 901 0 0 0 0\n"
      local down, up = system.network() -- window B, same second
      assert.equal(2000, down)
      assert.equal(1000, up)
      assert.near(0.5, system.cpu(), 1e-9)
    end)

    it("restarts the delta when counters go backwards", function()
      files["/proc/net/dev"] = "h\nh\n eth0: 5000 0 0 0 0 0 0 0 2500 0 0 0 0 0 0 0\n"
      system.network()
      clock = 101
      files["/proc/net/dev"] = "h\nh\n eth0: 10 0 0 0 0 0 0 0 10 0 0 0 0 0 0 0\n"
      assert.is_nil(system.network())
    end)

    it("returns nil when /proc is unreadable", function()
      assert.is_nil(system.cpu())
      assert.is_nil(system.ram())
      assert.is_nil(system.network())
    end)

    it("runs df for disk usage", function()
      wezterm._child = { ok = true, stdout = DF, stderr = "" }
      assert.near(0.25, system.disk(), 1e-6)
      local argv = wezterm._child_calls[1]
      assert.matches("df$", argv[1]) -- warp resolves it to an absolute path
      assert.same({ "-kP", "/" }, { argv[2], argv[3] })
    end)
  end)

  describe("samplers on macos", function()
    before_each(function()
      system.os = "macos"
    end)

    it("uses argument lists, never a shell", function()
      wezterm._child = function(argv)
        if argv[1]:find "sysctl$" then
          return true, "8\n", ""
        end
        return true, "%CPU\n 200.0\n 200.0\n", ""
      end
      assert.near(0.5, system.cpu(), 1e-9)
      for _, argv in ipairs(wezterm._child_calls) do
        local name = argv[1]:match "[^/\\]+$"
        assert.is_true(name == "sysctl" or name == "ps", argv[1])
        assert.is_nil(argv[1]:find "sh$")
      end
    end)

    it("returns nil when a command fails", function()
      assert.is_nil(system.cpu())
      assert.is_nil(system.ram())
      assert.is_nil(system.disk())
    end)
  end)

  it("is unsupported on windows", function()
    system.os = "windows"
    assert.is_false(system.supported())
    assert.is_nil(system.cpu())
    assert.is_nil(system.disk())
  end)

  it("formats percentages and rates", function()
    assert.equal("--%", system.percent(nil))
    assert.equal("43%", system.percent(0.427))
    assert.equal("--", system.rate(nil))
    assert.equal("512B", system.rate(512))
    assert.equal("1.5K", system.rate(1536))
    assert.equal("20K", system.rate(20480))
    assert.equal("2.0M", system.rate(2 * 1024 * 1024))
  end)
end)
