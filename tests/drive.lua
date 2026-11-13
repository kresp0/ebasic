-- Drives the EBASIC cartridge in headless MAME: types text on the emulated key matrix,
-- dumps the 4x20 shadow screen (RAM at SCR, D880) and takes snapshots.
-- env: BB_SCRIPT = script file, BB_LOG = output log, BB_SCR = address of SCR (hex).
-- Script lines: "wait <s>", "type <text>" (\n = INTRO, \e = RESPUESTA), "press <field>[+<field>]",
-- "hold <field> <s>", "dump", "snap", "peek <hex addr> <n>", "quit".
-- Copyright (C) 2026 Santiago Crespo
-- SPDX-License-Identifier: 0BSD
local machine = manager.machine
local mem = machine.devices[":maincpu"].spaces["program"]
local out = io.open(os.getenv("BB_LOG") or "drive.log", "w")
out:setvbuf("line")
local SCR = tonumber(os.getenv("BB_SCR") or "D880", 16)
local HOLD, GAP = 0.05, 0.05

local fields = {}
for _, port in pairs(machine.ioport.ports) do
  for name, f in pairs(port.fields) do fields[name] = f end
end

local SH, AL = "MAYUSCULAS (der.)", "ALT"
local keys = {[" "] = {"ESPACIO"}, ["\n"] = {"INTRO"}, ["\27"] = {"RESPUESTA"}, ["\8"] = {"REPETIR / BORRAR"},
  [","] = {","}, ["."] = {"."}, [";"] = {";"}, ["'"] = {"'"}, ["^"] = {"PAUSA"},
  ["#"] = {SH, "3"}, ["$"] = {SH, "4"}, ["%"] = {SH, "5"}, ["/"] = {SH, "6"}, ["&"] = {SH, "7"},
  ["*"] = {SH, "8"}, ["("] = {SH, "9"}, [")"] = {SH, "0"}, ["?"] = {SH, ","}, ["!"] = {SH, "."},
  ['"'] = {SH, "'"}, [":"] = {SH, ";"}, ["<"] = {SH, "RETROCESO"}, [">"] = {SH, "AVANCE"},
  ["\\"] = {AL, "1"}, ["@"] = {AL, "2"}, ["-"] = {AL, "3"}, ["_"] = {AL, "4"}, ["+"] = {AL, "5"},
  ["["] = {AL, "6"}, ["]"] = {AL, "7"}, ["="] = {AL, "8"}, ["|"] = {AL, "9"}, ["~"] = {AL, "0"}}
for c = 0, 9 do keys[tostring(c)] = {tostring(c)} end
-- Spanish characters (UTF-8 in the script); with caps lock on, SHIFT gives the lower case
local u = {["á"] = {SH, AL, "A"}, ["é"] = {SH, AL, "E"}, ["í"] = {SH, AL, "I"}, ["ó"] = {SH, AL, "O"}, ["ú"] = {SH, AL, "U"},
  ["Á"] = {AL, "A"}, ["É"] = {AL, "E"}, ["Í"] = {AL, "I"}, ["Ó"] = {AL, "O"}, ["Ú"] = {AL, "U"},
  ["ñ"] = {SH, "Ñ"}, ["Ñ"] = {"Ñ"}, ["ü"] = {SH, "Ü"}, ["Ü"] = {"Ü"}, ["¡"] = {SH, "1"}, ["¿"] = {SH, "2"}}
for k, v in pairs(u) do keys[k] = v end
for c = 65, 90 do
  local ch = string.char(c)
  keys[ch] = {ch}                         -- caps lock is on after start-up
  keys[string.lower(ch)] = {SH, ch}
end

local lines = {}
for l in io.lines(os.getenv("BB_SCRIPT")) do lines[#lines + 1] = l end

local queue, held, t_next, li = {}, nil, 0, 1
local function dump(tag)
  out:write(string.format("--- %s t=%.2f\n", tag or "screen", machine.time:as_double()))
  for r = 0, 3 do
    local s = ""
    for c = 0, 19 do
      local b = mem:read_u8(SCR + r * 20 + c)
      s = s .. ((b >= 32 and b < 127) and string.char(b) or string.format("{%02X}", b))
    end
    out:write("|" .. s .. "|\n")
  end
end

local function step(t)
  local l = lines[li]; li = li + 1
  if not l then machine:exit() return end
  local cmd, arg = string.match(l, "^(%S+)%s?(.*)$")
  if cmd == "wait" then t_next = t + tonumber(arg)
  elseif cmd == "type" then
    arg = arg:gsub("\\n", "\n"):gsub("\\e", "\27"):gsub("\\b", "\8")
    for _, cp in utf8.codes(arg) do
      local ch = utf8.char(cp)
      local k = keys[ch]
      if not k then out:write("NO KEY FOR " .. ch .. "\n") else queue[#queue + 1] = {table.unpack(k)} end
    end
  elseif cmd == "press" then
    local k = {}
    for n in string.gmatch(arg, "[^+]+") do k[#k + 1] = n end
    queue[#queue + 1] = k
  elseif cmd == "hold" then
    local n, s = string.match(arg, "^(.-)%s+([%d%.]+)$")
    queue[#queue + 1] = {n, dur = tonumber(s)}
  elseif cmd == "dump" then dump(arg)
  elseif cmd == "snap" then machine.video:snapshot(); out:write(string.format("snap t=%.2f\n", t))
  elseif cmd == "peek" then
    local a, n = string.match(arg, "^(%x+)%s+(%d+)$")
    local s = ""
    for i = 0, tonumber(n) - 1 do s = s .. string.format("%02X ", mem:read_u8(tonumber(a, 16) + i)) end
    out:write(string.format("peek %s t=%.2f: %s\n", a, t, s))
  elseif cmd == "gdump" then
    out:write(string.format("--- picture %s t=%.2f\n", arg, t))
    for y = 15, 0, -1 do
      local r, line = 15 - y, ""
      for x = 0, 19 do
        local col = x // 5
        local byte = mem:read_u8(GBUF + col * 8 + r + (r >= 8 and 24 or 0))
        line = line .. (((byte >> (4 - x % 5)) & 1) == 1 and "#" or ".")
      end
      out:write(line .. "\n")
    end
  elseif cmd == "quit" then out:close(); machine:exit()
  elseif cmd ~= "#" then out:write("BAD LINE " .. l .. "\n") end
end

emu.register_frame_done(function()
  local t = machine.time:as_double()
  if t < t_next then return end
  if held then
    for _, n in ipairs(held) do if fields[n] then fields[n]:set_value(0) end end
    held = nil; t_next = t + GAP; return
  end
  if #queue > 0 then
    -- modifiers go down one step before the key, as a person presses them
    local k = queue[1]
    k.n = (k.n or 0) + 1
    local n = k[k.n]
    if not fields[n] then out:write("MISSING FIELD " .. n .. "\n") else fields[n]:set_value(1) end
    if k.n < #k then t_next = t + 0.02; return end
    table.remove(queue, 1)
    held = k; t_next = t + (k.dur or HOLD); return
  end
  step(t)
end)

-- Optional log of every write to port 0x12 (time, value, PC): env BB_P12 = file
if os.getenv("BB_P12") then
  local cpu = machine.devices[":maincpu"]
  local p12 = io.open(os.getenv("BB_P12"), "w")
  p12:setvbuf("full")
  P12_TAP = cpu.spaces["io"]:install_write_tap(0x12, 0x12, "p12", function(offset, data, mask)
    p12:write(string.format("%.6f %02X %04X\n", machine.time:as_double(), data, cpu.state["PC"].value))
    return data
  end)
end

-- "gdump" in a script: the 20x16 graphics picture (GBUF, env BB_GBUF) as text, "#" = pixel on
GBUF = tonumber(os.getenv("BB_GBUF") or "D999", 16)
