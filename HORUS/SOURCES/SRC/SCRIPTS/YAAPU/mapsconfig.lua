--
-- An FRSKY S.Port <passthrough protocol> based Telemetry script for the Horus X10 and X12 radios
--
-- Copyright (C) 2018-2019. Alessandro Apostoli
-- https://github.com/yaapu
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
--

---------------------
-- MAIN CONFIG
-- 480x272 LCD_W x LCD_H
---------------------

---------------------
-- VERSION
---------------------
-- load and compile of lua files
--#define LOADSCRIPT
-- uncomment to force compile of all chunks, comment for release
--#define COMPILE
-- fix for issue OpenTX 2.2.1 on X10/X10S - https://github.com/opentx/opentx/issues/5764

---------------------
-- FEATURE CONFIG
---------------------
-- enable splash screen for no telemetry data
--#define SPLASH
-- enable battery percentage based on voltage
--#define BATTPERC_BY_VOLTAGE
-- enable code to draw a compass rose vs a compass ribbon
--#define COMPASS_ROSE
-- enable support for FNV hash based sound files

---------------------
-- DEV FEATURE CONFIG
---------------------
-- enable memory debuging 
-- enable dev code
--#define DEV
-- uncomment haversine calculation routine
--#define HAVERSINE
-- enable telemetry logging to file (experimental)
--#define LOGTELEMETRY
-- use radio channels imputs to generate fake telemetry data
--#define TESTMODE
-- enable debug of generated hash or short hash string
--#define HASHDEBUG

---------------------
-- DEBUG REFRESH RATES
---------------------
-- calc and show hud refresh rate
--#define HUDRATE
-- calc and show telemetry process rate
--#define BGTELERATE

---------------------
-- SENSOR IDS
---------------------
















-- Throttle and RC use RPM sensor IDs

---------------------
-- BATTERY DEFAULTS
---------------------
---------------------------------
-- BACKLIGHT SUPPORT
-- GV is zero based, GV 8 = GV 9 in OpenTX
---------------------------------
---------------------------------
-- CONF REFRESH GV
---------------------------------

---------------------------------
-- ALARMS
---------------------------------
--[[
 ALARM_TYPE_MIN needs arming (min has to be reached first), value below level for grace, once armed is periodic, reset on landing
 ALARM_TYPE_MAX no arming, value above level for grace, once armed is periodic, reset on landing
 ALARM_TYPE_TIMER no arming, fired periodically, spoken time, reset on landing
 ALARM_TYPE_BATT needs arming (min has to be reached first), value below level for grace, no reset on landing
{ 
  1 = notified, 
  2 = alarm start, 
  3 = armed, 
  4 = type(0=min,1=max,2=timer,3=batt), 
  5 = grace duration
  6 = ready
  7 = last alarm
}  
--]]--
--
--

--

----------------------
-- COMMON LAYOUT
----------------------
-- enable vertical bars HUD drawing (same as taranis)
--#define HUD_ALGO1
-- enable optimized hor bars HUD drawing
--#define HUD_ALGO2
-- enable hor bars HUD drawing






--------------------------------------------------------------------------------
-- MENU VALUE,COMBO
--------------------------------------------------------------------------------

--------------------------
-- UNIT OF MEASURE
--------------------------
local unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
local unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
local unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
local unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"


-----------------------
-- BATTERY 
-----------------------
-- offsets are: 1 celm, 4 batt, 7 curr, 10 mah, 13 cap, indexing starts at 1
-- 

-----------------------
-- LIBRARY LOADING
-----------------------

----------------------
--- COLORS
----------------------

--#define COLOR_LABEL 0x7BCF
--#define COLOR_BG 0x0169
--#define COLOR_BARSEX 0x10A3


--#define COLOR_SENSORS 0x0169

-----------------------------------
-- STATE TRANSITION ENGINE SUPPORT
-----------------------------------


--------------------------
-- CLIPPING ALGO DEFINES
--------------------------









--[[

TYPEVALUE - menu option to select a numeric value
{description, type,name,default value,min,max,uit of measure,precision,increment step, <master name>, <master value>}
example {"batt alert level 1:", TYPEVALUE, "V1", 375, 0,5000,"V",PREC2,5,"L2",350 },

TYPECOMBO - menu option to select a value from a list
{description, type, name, default, label list, value list, <master name>, <master value>}
example {"center pane layout:", TYPECOMBO, "CPANE", 1, { "hud","radar" }, { 1, 2 },"CPANE",1 },

--]]--
local menuItems = {
  {"map zoom level 1:", 0, "MAPZ", -2, -2, 17,nil,0,1 },
  {"map zoom level 2:", 0, "MAPZ-MID", -2, -2, 17,nil,0,1 },
  {"map zoom level 3:", 0, "MAPZ-HIGH", -2, -2, 17,nil,0,1 },
  {"map type:", 1, "MAPT", 1, { "satellite", "map", "terrain" }, { "sat_tiles", "tiles", "ter_tiles" } },
  {"map grid lines:", 1, "MAPG", 1, { "yes", "no" }, { true, false } },
  {"map trail dots:", 0, "MAPTD", 10, 5, 50,nil,0,1 },
  {"map zoom channel:", 0, "ZTC", 0, 0, 32,nil,0,1 },
}

local menu  = {
  selectedItem = 1,
  editSelected = false,
  offset = 0,
  updated = true, -- if true menu needs a call to updateMenuItems()
  wrapOffset = 0, -- changes according to enabled/disabled features and panels
}

local basePath = "/SCRIPTS/YAAPU/"
local libBasePath = basePath.."LIB/"

------------------------------------------
-- returns item's VALUE,LABEL,IDX
------------------------------------------
local function getMenuItemByName(items,name)
  for idx=1,#items
  do
    -- items[idx][3] is the menu item's name as it appears in the config file
    if items[idx][3] == name then
      if items[idx][2] ==  1 then
        -- return item's value, label, index
        return items[idx][6][items[idx][4]], items[idx][5][items[idx][4]], idx
      else
        -- return item's value, label, index
        return items[idx][4], name, idx
      end
    end
  end
  return nil
end

local function updateMenuItems()
  if menu.updated == true then
    -- no dynamic menus yet
    menu.updated = false
    collectgarbage()
    collectgarbage()
  end
end

local
function getConfigFilename()
  local info = model.getInfo()
  return "/SCRIPTS/YAAPU/CFG/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "").."_maps.cfg")
end

local function applyConfigValues(conf)
  if menu.updated == true then
    updateMenuItems()
    menu.updated = false
  end
  
  conf.mapZoomLevel = getMenuItemByName(menuItems,"MAPZ")
  conf.mapZoomLevelMid = getMenuItemByName(menuItems,"MAPZ-MID")
  conf.mapZoomLevelHigh = getMenuItemByName(menuItems,"MAPZ-HIGH")
  conf.mapType = getMenuItemByName(menuItems,"MAPT")
  conf.mapTrailDots = getMenuItemByName(menuItems,"MAPTD")
  
  local chInfo = getFieldInfo("ch"..getMenuItemByName(menuItems,"ZTC"))
  conf.mapToggleChannelId = (chInfo == nil and -1 or chInfo['id'])
  
  conf.enableMapGrid = getMenuItemByName(menuItems,"MAPG")
  
  menu.editSelected = false
  collectgarbage()
  collectgarbage()
end

local function loadConfig(conf)
  local cfg = io.open(getConfigFilename(),"r")
  if cfg ~= nil then
    local str = io.read(cfg,500)
    io.close(cfg)
    if string.len(str) > 0 then
      for i=1,#menuItems
      do
        local value = string.match(str, menuItems[i][3]..":([-%d]+)")
        collectgarbage()
        if value ~= nil then
          menuItems[i][4] = tonumber(value)
          -- check if the value read from file is compatible with available options
          if menuItems[i][2] == 1 and tonumber(value) > #menuItems[i][5] then
            --if not force default
            menuItems[i][4] = 1
          end
        end
      end
    end
  end
  -- menu was loaded apply required changes
  menu.updated = true
  -- when run standalone there's nothing to update :-)
  if conf ~= nil then
    applyConfigValues(conf)
  end
end

local function saveConfig(conf)
  local myConfig = ""
  for i=1,#menuItems
  do
    myConfig = myConfig..menuItems[i][3]..":"..menuItems[i][4]
    if i < #menuItems then
      myConfig = myConfig..","
    end
  end
  local cfg = assert(io.open(getConfigFilename(),"w"))
  if cfg ~= nil then
    io.write(cfg,myConfig)
    io.close(cfg)
  end
  myConfig = nil
  collectgarbage()
  collectgarbage()
  -- when run standalone there's nothing to update :-)
  if conf ~= nil then
    applyConfigValues(conf)
  end
  model.setGlobalVariable(8,7,1)
end

local function drawConfigMenuBars()
  lcd.setColor(CUSTOM_COLOR,0x0000)
  local itemIdx = string.format("%d/%d",menu.selectedItem,#menuItems)
  lcd.drawFilledRectangle(0,0, LCD_W, 20, CUSTOM_COLOR)
  lcd.drawRectangle(0, 0, LCD_W, 20, CUSTOM_COLOR)
  lcd.drawFilledRectangle(0,LCD_H-20, LCD_W, 20, CUSTOM_COLOR)
  lcd.drawRectangle(0, LCD_H-20, LCD_W, 20, CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR,0xFFFF)  
  lcd.drawText(2,0,"Yaapu Mapping Widget 1.1-dev",CUSTOM_COLOR)
  lcd.drawText(2,LCD_H-20+1,getConfigFilename(),CUSTOM_COLOR)
  lcd.drawText(LCD_W,LCD_H-20+1,itemIdx,CUSTOM_COLOR+RIGHT)
end

local function incMenuItem(idx)
  if menuItems[idx][2] == 0 then
    menuItems[idx][4] = menuItems[idx][4] + menuItems[idx][9]
    if menuItems[idx][4] > menuItems[idx][6] then
      menuItems[idx][4] = menuItems[idx][6]
    end
  else
    menuItems[idx][4] = menuItems[idx][4] + 1
    if menuItems[idx][4] > #menuItems[idx][5] then
      menuItems[idx][4] = 1
    end
  end
end

local function decMenuItem(idx)
  if menuItems[idx][2] == 0 then
    menuItems[idx][4] = menuItems[idx][4] - menuItems[idx][9]
    if menuItems[idx][4] < menuItems[idx][5] then
      menuItems[idx][4] = menuItems[idx][5]
    end
  else
    menuItems[idx][4] = menuItems[idx][4] - 1
    if menuItems[idx][4] < 1 then
      menuItems[idx][4] = #menuItems[idx][5]
    end
  end
end

local function drawItem(idx,flags)
  lcd.setColor(CUSTOM_COLOR,0xFFFF)    
  if menuItems[idx][2] == 0 then
    if menuItems[idx][4] == 0 and menuItems[idx][5] >= 0 then
      lcd.drawText(300,25 + (idx-menu.offset-1)*20, "---",flags+CUSTOM_COLOR)
    else
      lcd.drawNumber(300,25 + (idx-menu.offset-1)*20, menuItems[idx][4],flags+menuItems[idx][8]+CUSTOM_COLOR)
      if menuItems[idx][7] ~= nil then
        lcd.drawText(300 + 50,25 + (idx-menu.offset-1)*20, menuItems[idx][7],flags+CUSTOM_COLOR)
      end
    end
  else
    lcd.drawText(300,25 + (idx-menu.offset-1)*20, menuItems[idx][5][menuItems[idx][4]],flags+CUSTOM_COLOR)
  end
end

local function drawConfigMenu(event)
  drawConfigMenuBars()
  updateMenuItems()
  if event == EVT_ENTER_BREAK then
    if menu.editSelected == true then
      -- confirm modified value
      saveConfig()
    end
    menu.editSelected = not menu.editSelected
    menu.updated = true
  elseif menu.editSelected and (event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_PLUS_REPT) then
    incMenuItem(menu.selectedItem)
  elseif menu.editSelected and (event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_MINUS_REPT) then
    decMenuItem(menu.selectedItem)
  elseif not menu.editSelected and (event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT) then
    menu.selectedItem = (menu.selectedItem - 1)
    if menu.offset >=  menu.selectedItem then
      menu.offset = menu.offset - 1
    end
  elseif not menu.editSelected and (event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT) then
    menu.selectedItem = (menu.selectedItem + 1)
    if menu.selectedItem - 11 > menu.offset then
      menu.offset = menu.offset + 1
    end
  end
  --wrap
  if menu.selectedItem > #menuItems then
    menu.selectedItem = 1 
    menu.offset = 0
  elseif menu.selectedItem  < 1 then
    menu.selectedItem = #menuItems
    menu.offset =  #menuItems > 11 and #menuItems - 11 or 0
  end
  --
  for m=1+menu.offset,math.min(#menuItems,11+menu.offset) do
    lcd.setColor(CUSTOM_COLOR,0xFFFF)   
    lcd.drawText(2,25 + (m-menu.offset-1)*20, menuItems[m][1],CUSTOM_COLOR)
    if m == menu.selectedItem then
      if menu.editSelected then
        drawItem(m,INVERS+BLINK)
      else
        drawItem(m,INVERS)
      end
    else
      drawItem(m,0)
    end
  end
end


--------------------------
-- RUN
--------------------------
local function run(event)
  lcd.setColor(CUSTOM_COLOR, 0x0AB1) -- hex 0x084c7b -- 073f66
  lcd.clear(CUSTOM_COLOR)
  ---------------------
  -- CONFIG MENU
  ---------------------  
  drawConfigMenu(event)
  return 0
end

local function init()
  loadConfig()
end

--------------------------------------------------------------------------------
-- SCRIPT END
--------------------------------------------------------------------------------
return {run=run, init=init, loadConfig=loadConfig, compileLayouts=compileLayouts, menuItems=menuItems}
