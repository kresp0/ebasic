-- Drives the EBASIC cartridge in headless MAME: types text on the emulated key matrix,
-- dumps the 4x20 shadow screen (RAM at SCR, D880) and takes snapshots. It also models what MAME lacks for
-- the Super Memoria tests: the 32 KiB SRAM cartridge (read and written through taps on 8000-BFFF, the half
-- chosen by bit 0 of the port 0x03 selector) and swapping cartridges while the program runs.
-- env: BB_SCRIPT = script file, BB_LOG = output log, BB_SCR = address of SCR (hex),
--      SM_INIT = blank | fmt | <file of 32768 bytes> (the Super Memoria's contents; default blank).
-- Script lines: "wait <s>", "type <text>" (\n = INTRO, \e = RESPUESTA), "press <field>[+<field>]",
-- "hold <field> <s>", "dump", "snap", "peek <hex addr> <n>", "quit";
-- "cart rom|none|sm|smro" (what is in the slot; smro ignores writes), "poke <hex offset> <hex byte>" (into the SRAM),
-- "sram <file>" (save the SRAM next to the log), "expect <row> <text>" (LCD row from the HD44780's DDRAM,
-- trailing spaces ignored: the Super Memoria dialogues), "expectscr <row> <text>" (row of EBASIC's shadow
-- screen), "waitfor <row> <text> <s>" (LCD), "expectoff 0|1" (whether the unit was switched off: OUT 12h
-- with bit 0 set), "expectfw" (the Super Memoria code has written nothing to DB00-DFFF, the firmware's RAM;
-- the trampolines at DA80, which use EBASIC's start-up stack at DFF0, do not count), "expectblink" (it changed
-- the caps LED at least 3 times since the last check), "expectp12 <hex>" (the last value written to port 0x12).
-- The log ends with "RESULT pass=<n> fail=<n>"; the SRAM is saved as sram_before.bin and sram_after.bin.
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
local dir = string.match(os.getenv("BB_LOG") or "./drive.log", "^(.*)/[^/]*$") or "."

-- ---------------------------------------------------------------- the Super Memoria
local sram, init = {}, os.getenv("SM_INIT") or "blank"
if init == "blank" or init == "fmt" then
  for i = 0, 0x7FFF do sram[i] = 0 end
  if init == "fmt" then sram[0], sram[1], sram[2], sram[6], sram[7] = 0x55, 0xAA, 0xEE, 0xBB, 0x46 end
else
  local f = assert(io.open(init, "rb"))
  local d = f:read("a")
  f:close()
  for i = 0, 0x7FFF do sram[i] = d:byte(i + 1) end
end
local function save_sram(name)
  local f = io.open(dir .. "/" .. name, "wb")
  for i = 0, 0x7FFF do f:write(string.char(sram[i])) end
  f:close()
end
save_sram("sram_before.bin")
local cpu = machine.devices[":maincpu"]
local cart, p03, offreq = "rom", 0x80, 0
TAPS = {}   -- global: a collected tap makes MAME crash
TAPS[1] = cpu.spaces["io"]:install_write_tap(0x03, 0x03, "page", function(offset, data, mask)
  p03 = data
  return data
end)
TAPS[2] = mem:install_read_tap(0x8000, 0xBFFF, "smread", function(offset, data, mask)
  if p03 & 0x80 == 0 or cart == "rom" then return data end
  if cart == "none" then return 0xFF end   -- "sm" and "smro" (a Super Memoria that ignores writes)
  return sram[(p03 & 1) * 0x4000 + offset - 0x8000]
end)
TAPS[3] = mem:install_write_tap(0x8000, 0xBFFF, "smwrite", function(offset, data, mask)
  if p03 & 0x80 ~= 0 and cart == "sm" then sram[(p03 & 1) * 0x4000 + offset - 0x8000] = data & 0xFF end   -- "smro": no writes
  return data
end)
local fwram = 0   -- writes to the firmware's RAM (DB00-DFFF) by code in RAM other than the trampolines
TAPS[5] = mem:install_write_tap(0xDB00, 0xDFFF, "fwram", function(offset, data, mask)
  local pc = cpu.state["PC"].value
  if pc >= 0xC000 and (pc < 0xDA80 or pc >= 0xDB00) then
    fwram = fwram + 1
    if fwram <= 5 then out:write(string.format("write %02X to %04X from PC %04X\n", data, offset, cpu.state["PC"].value)) end
  end
  return data
end)
local blinks, p12 = 0, nil   -- writes to port 0x12 by the Super Memoria code (PC in RAM), and the last value
TAPS[4] = cpu.spaces["io"]:install_write_tap(0x12, 0x12, "off", function(offset, data, mask)
  if data & 1 == 1 then offreq = offreq + 1 end
  if cpu.state["PC"].value >= 0xC000 then blinks = blinks + 1 end
  p12 = data
  return data
end)

-- ---------------------------------------------------------------- the LCD (HD44780 DDRAM, gl4000 map)
local ddram
for tag, dev in pairs(machine.devices) do
  if string.find(tag, "hd44780") then
    for name, idx in pairs(dev.items) do if string.find(name, "m_ddram") then ddram = emu.item(idx) end end
  end
end
local ROWADR = {{0, 4, 12}, {64, 68, 76}, {4, 12, 20}, {68, 76, 84}}
local function lcdrow(r)
  local s = ""
  for c = 0, 19 do
    local v = ddram:read(c + ROWADR[r + 1][c < 4 and 1 or c < 12 and 2 or 3])
    s = s .. ((v >= 0x20 and v < 0x7F) and string.char(v) or "?")
  end
  return (string.gsub(s, "%s+$", ""))
end
local npass, nfail, waiting = 0, 0, nil
local function result(ok, what)
  if ok then npass = npass + 1 else nfail = nfail + 1 end
  out:write(string.format("%s %s t=%.2f\n", ok and "PASS" or "FAIL", what, machine.time:as_double()))
  if not ok then for r = 0, 3 do out:write("  |" .. lcdrow(r) .. "|\n") end end
end
local function finish()
  save_sram("sram_after.bin")
  out:write(string.format("RESULT pass=%d fail=%d\n", npass, nfail))
  out:close()
  machine:exit()
end

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
  if not l then finish() return end
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
  elseif cmd == "cart" then cart = arg; out:write(string.format("cart %s t=%.2f\n", arg, t))
  elseif cmd == "poke" then
    local o, v = string.match(arg, "^(%x+)%s+(%x+)$")
    sram[tonumber(o, 16)] = tonumber(v, 16)
  elseif cmd == "sram" then save_sram(arg)
  elseif cmd == "expect" then
    local r, text = string.match(arg, "^(%d)%s?(.*)$")
    result(lcdrow(tonumber(r)) == text, string.format("expect %s '%s'", r, text))
  elseif cmd == "expectscr" then
    local r, text = string.match(arg, "^(%d)%s?(.*)$")
    local s = ""
    for c = 0, 19 do
      local b = mem:read_u8(SCR + tonumber(r) * 20 + c)
      s = s .. ((b >= 32 and b < 127) and string.char(b) or string.format("{%02X}", b))
    end
    s = string.gsub(s, "%s+$", "")
    result(s == text, string.format("expectscr %s '%s'%s", r, text, s == text and "" or " got '" .. s .. "'"))
  elseif cmd == "waitfor" then
    local r, text, s = string.match(arg, "^(%d) (.-) (%S+)$")
    waiting = {r = tonumber(r), text = text, from = t, limit = t + tonumber(s)}
  elseif cmd == "expectblink" then
    result(blinks >= 3, "caps LED blinking: " .. blinks .. " changes")
    blinks = 0
  elseif cmd == "expectp12" then
    result(p12 == tonumber(arg, 16), string.format("port 0x12 = %s: %s", arg, p12 and string.format("%02X", p12) or "-"))
  elseif cmd == "expectfw" then result(fwram == 0, "no writes to DB00-DFFF from RAM code: " .. fwram)
  elseif cmd == "expectoff" then result((offreq > 0) == (arg == "1"), "switched off: " .. offreq)
  elseif cmd == "quit" then finish()
  elseif cmd ~= "#" then out:write("BAD LINE " .. l .. "\n") end
end

emu.register_frame_done(function()
  local t = machine.time:as_double()
  if waiting and not held and #queue == 0 then
    if lcdrow(waiting.r) == waiting.text then
      result(true, string.format("waitfor %d '%s' (%.1f s)", waiting.r, waiting.text, t - waiting.from))
      waiting = nil
    elseif t > waiting.limit then
      result(false, string.format("waitfor %d '%s'", waiting.r, waiting.text))
      waiting = nil
    end
    return
  end
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
