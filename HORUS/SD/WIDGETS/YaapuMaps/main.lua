--
-- An FRSKY S.Port <passthrough protocol> based Telemetry script for the Horus X10 and X12 radios
--
-- Copyright (C) 2018-2021. Alessandro Apostoli
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
--]]
local unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
local unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
local unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
local unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"



local currentModel = nil

------------------------------
-- TELEMETRY DATA
------------------------------
local telemetry = {
  -- GPS
  numSats = 0,
  gpsStatus = 0,
  gpsHdopC = 100,
  -- HOME
  homeDist = 0,
  homeAlt = 0,
  homeAngle = -1,
  -- VELANDYAW
  yaw = 0,
  -- GPS
  lat = nil,
  lon = nil,
  homeLat = nil,
  homeLon = nil,
  groundSpeed = 0,
  cog = 0,
}

--------------------------------
-- STATUS DATA
--------------------------------
local status = {
  -- MAP
  mapZoomLevel = nil,
  lastLat = nil,
  lastLon = nil,
  homeSet = false,
  avgSpeed = {
    lastSampleTime = nil,
    avgTravelDist = 0,
    avgTravelTime = 0,
    travelDist = 0,
    prevLat = nil,
    prevLon = nil,
    value = 0,
  },
}
---------------------------
-- LIBRARY LOADING
---------------------------
local basePath = "/WIDGETS/YaapuMaps/"
local libBasePath = basePath.."lib/"

-- loadable modules
local drawLibFile = "drawlib"
local mapLibFile = "maplib"
local menuLibFile = "menu"

local drawLib = {}
local mapLib = {}
local utils = {}
utils.colors = {}
utils.degSymbol = "\64"

-------------------------------
-- MAP SCREEN LAYOUT
-------------------------------
local layout = nil

local customSensors = nil

local backlightLastTime = 0

-- Blinking bitmap support
local bitmaps = {}
local blinktime = getTime()
local blinkon = false


-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()
-- widget selected page
local currentPage = 0
--------------------------------------------------------------------------------
-- CONFIGURATION MENU
--------------------------------------------------------------------------------
local conf = {
  mapType = "sat_tiles",
  enableMapGrid = true,
  homeResetChannelId = nil,
  mapWheelChannelId = nil, -- used as wheel emulator
  mapWheelChannelDelay = 20,
  mapTrailDots = 10,
  mapZoomLevel = -2, -- deprecated
  mapZoomMax = 17,
  mapZoomMin = -2,
  mapProvider = 1, -- 1 GMapCatcher, 2 Google
  headingSensor = "Hdg",
  headingSensorUnitScale = 1,
  sensorsConfigFileType = 0, -- model
  sidebarEnable = false,
  bottombarEnable = false,
  horSpeedMultiplier=1,
  horSpeedLabel = "m/s",
  gpsSource = 1,
}

local loadCycle = 0
local gpsLockTimer = nil

utils.doLibrary = function(filename)
  local f = assert(loadScript(libBasePath..filename..".lua","c"))
  collectgarbage()
  collectgarbage()
  return f()
end

-- for better performance we cache lcd.RGB()
utils.initColors = function()
  -- check if we have lcd.RGB() at init time
  local color = lcd.RGB(0,0,0)
  if color == nil then
    utils.colors.black = BLACK
    utils.colors.darkgrey = 0x18C3
    utils.colors.white = WHITE
    utils.colors.green = 0x1FEA
    utils.colors.blue = BLUE
    utils.colors.darkblue = 0x2A2B
    utils.colors.darkyellow = 0xFE60
    utils.colors.yellow = 0xFFE0
    utils.colors.orange = 0xFB60
    utils.colors.red = 0xF800
    utils.colors.lightgrey = 0x8C71
    utils.colors.grey = 0x7BCF
    --utils.colors.darkgrey = 0x5AEB
    utils.colors.lightred = 0xF9A0
    utils.colors.bars2 = 0x10A3
    utils.colors.bg = conf.theme == 1 and utils.colors.darkblue or 0x3186
    utils.colors.hudTerrain = conf.theme == 1 and 0x6225 or 0x65CB
    utils.colors.hudFgColor = conf.theme == 1 and utils.colors.darkyellow or utils.colors.black
    utils.colors.bars = conf.theme == 1 and utils.colors.darkgrey or utils.colors.black
  else
    -- EdgeTX
    utils.colors.black = BLACK
    utils.colors.darkgrey = lcd.RGB(27,27,27)
    utils.colors.white = WHITE
    utils.colors.green = lcd.RGB(00, 0xED, 0x32)
    utils.colors.blue = BLUE
    --utils.colors.darkblue = lcd.RGB(8,84,136)
    utils.colors.darkblue = lcd.RGB(43,70,90)
    utils.colors.darkyellow = lcd.RGB(255,206,0)
    utils.colors.yellow = lcd.RGB(255, 0xCE, 0)
    utils.colors.orange = lcd.RGB(248,109,0)
    utils.colors.red = RED
    utils.colors.lightgrey = lcd.RGB(188,188,188)
    utils.colors.grey = lcd.RGB(120,120,120)
    --utils.colors.darkgrey = lcd.RGB(90,90,90)
    utils.colors.lightred = lcd.RGB(255,53,0)
    utils.colors.bars2 = lcd.RGB(16,20,25)
    utils.colors.bg = conf.theme == 1 and utils.colors.darkblue or lcd.RGB(50, 50, 50)
    utils.colors.hudSky = lcd.RGB(123,157,255)
    utils.colors.hudTerrain = conf.theme == 1 and lcd.RGB(102, 71, 42) or lcd.RGB(100,185,95)
    utils.colors.hudFgColor = conf.theme == 1 and utils.colors.darkyellow or utils.colors.black
    utils.colors.bars = conf.theme == 1 and utils.colors.darkgrey or utils.colors.black
  end
end
-----------------------------
-- clears the loaded table
-- and recovers memory
-----------------------------
function utils.clearTable(t)
  if type(t)=="table" then
    for i,v in pairs(t) do
      if type(v) == "table" then
        utils.clearTable(v)
      end
      t[i] = nil
    end
  end
  t = nil
  collectgarbage()
  collectgarbage()
  maxmem = 0
end

local function loadConfig()
  -- load menu library
  menuLib = utils.doLibrary("../menu")
  menuLib.loadConfig(conf)
  -- unload libraries
  utils.clearTable(menuLib)
  utils.clearTable(layout)
  layout = nil
  utils.clearTable(customSensors)
    -- load custom sensors
  utils.loadCustomSensors()
  collectgarbage()
  collectgarbage()
end

utils.getBitmap = function(name)
  if bitmaps[name] == nil then
    bitmaps[name] = Bitmap.open("/WIDGETS/YaapuMaps/images/"..name..".png")
  end
  return bitmaps[name],Bitmap.getSize(bitmaps[name])
end

utils.unloadBitmap = function(name)
  if bitmaps[name] ~= nil then
    bitmaps[name] = nil
    -- force call to luaDestroyBitmap()
    collectgarbage()
    collectgarbage()
  end
end

utils.lcdBacklightOn = function()
  model.setGlobalVariable(8,0,1)
  backlightLastTime = getTime()/100 -- seconds
end

function utils.haversine(lat1, lon1, lat2, lon2)
    lat1 = lat1 * math.pi / 180
    lon1 = lon1 * math.pi / 180
    lat2 = lat2 * math.pi / 180
    lon2 = lon2 * math.pi / 180

    lat_dist = lat2-lat1
    lon_dist = lon2-lon1
    lat_hsin = math.pow(math.sin(lat_dist/2),2)
    lon_hsin = math.pow(math.sin(lon_dist/2),2)

    a = lat_hsin + math.cos(lat1) * math.cos(lat2) * lon_hsin
    return 2 * 6372.8 * math.asin(math.sqrt(a)) * 1000
end

function utils.getAngleFromLatLon(lat1, lon1, lat2, lon2)
  local la1 = math.rad(lat1)
  local lo1 = math.rad(lon1)
  local la2 = math.rad(lat2)
  local lo2 = math.rad(lon2)

  local y = math.sin(lo2-lo1) * math.cos(la2);
  local x = math.cos(la1)*math.sin(la2) - math.sin(la1)*math.cos(la2)*math.cos(lo2-lo1);
  local a = math.atan2(y, x);

  return (a*180/math.pi + 360) % 360 -- in degrees
end

function utils.updateCog()
  if status.lastLat == nil then
    status.lastLat = telemetry.lat
  end
  if status.lastLon == nil then
    status.lastLon = telemetry.lon
  end
  if status.lastLat ~= nil and status.lastLon ~= nil and status.lastLat ~= telemetry.lat and status.lastLon ~= telemetry.lon then
    local cog = utils.getAngleFromLatLon(status.lastLat, status.lastLon, telemetry.lat, telemetry.lon)
    if cog ~= nil and telemetry.groundSpeed > 1 then
      telemetry.cog = cog
    end
    -- update last GPS coords
    status.lastLat = telemetry.lat
    status.lastLon = telemetry.lon
  end
end

function utils.getHomeFromAngleAndDistance(telemetry)
--[[
  la1,lo1 coordinates of first point
  d be distance (m),
  R as radius of Earth (m),
  Ad be the angular distance i.e d/R and
  θ be the bearing in deg

  la2 =  asin(sin la1 * cos Ad  + cos la1 * sin Ad * cos θ), and
  lo2 = lo1 + atan2(sin θ * sin Ad * cos la1 , cos Ad – sin la1 * sin la2)
--]]
  if telemetry.lat == nil or telemetry.lon == nil then
    return nil,nil
  end

  local lat1 = math.rad(telemetry.lat)
  local lon1 = math.rad(telemetry.lon)
  local Ad = telemetry.homeDist/(6371000) --meters
  local lat2 = math.asin( math.sin(lat1) * math.cos(Ad) + math.cos(lat1) * math.sin(Ad) * math.cos( math.rad(telemetry.homeAngle)) )
  local lon2 = lon1 + math.atan2( math.sin( math.rad(telemetry.homeAngle) ) * math.sin(Ad) * math.cos(lat1) , math.cos(Ad) - math.sin(lat1) * math.sin(lat2))
  return math.deg(lat2), math.deg(lon2)
end


function utils.decToDMS(dec,lat)
  local D = math.floor(math.abs(dec))
  local M = (math.abs(dec) - D)*60
  local S = (math.abs((math.abs(dec) - D)*60) - M)*60
	return D .. string.format("%s%04.2f", utils.degSymbol, M) .. (lat and (dec >= 0 and "E" or "W") or (dec >= 0 and "N" or "S"))
end

function utils.decToDMSFull(dec,lat)
  local D = math.floor(math.abs(dec))
  local M = math.floor((math.abs(dec) - D)*60)
  local S = (math.abs((math.abs(dec) - D)*60) - M)*60
	return D .. string.format("%s%d'%04.1f", utils.degSymbol, M, S) .. (lat and (dec >= 0 and "E" or "W") or (dec >= 0 and "N" or "S"))
end

function utils.drawBlinkBitmap(bitmap,x,y)
  if blinkon == true then
      lcd.drawBitmap(utils.getBitmap(bitmap),x,y)
  end
end

local function isFileEmpty(filename)
  local file = io.open(filename,"r")
  if file == nil then
    return true
  end
  local str = io.read(file,10)
  io.close(file)
  if #str < 10 then
    return true
  end
  return false
end

local function getSensorsConfigFilename()
  local cfg = nil
  if conf.sensorsConfigFileType == 0 then
    local info = model.getInfo()
    cfg = "/WIDGETS/YaapuMaps/cfg/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "").."_sensors_maps.lua")
    -- help users with file name issues by creating an empty config file
    local file = io.open(cfg,"r")
    if file == nil then
      -- let's create the empty config file
      file = io.open(cfg,"w")
      io.close(file)
    else
      io.close(file)
    end

    -- we ignore empty config file
    if isFileEmpty(cfg) then
      cfg = "/WIDGETS/YaapuMaps/cfg/default_sensors_maps.lua"
    end
  else
    cfg = "/WIDGETS/YaapuMaps/cfg/profile_"..conf.sensorsConfigFileType.."_sensors_maps.lua"
  end
  return cfg
end

--------------------------
-- CUSTOM SENSORS SUPPORT
--------------------------

function utils.loadCustomSensors()
  local success, sensorScript = pcall(loadScript,getSensorsConfigFilename())
  if success then
    if sensorScript == nil then
      customSensors = nil
      return
    end
    collectgarbage()
    customSensors = sensorScript()
    -- handle nil values for warning and critical levels
    for i=1,10
    do
      if customSensors.sensors[i] ~= nil then
        local sign = customSensors.sensors[i][6] == "+" and 1 or -1
        if customSensors.sensors[i][9] == nil then
          customSensors.sensors[i][9] = math.huge*sign
        end
        if customSensors.sensors[i][8] == nil then
          customSensors.sensors[i][8] = math.huge*sign
        end
      end
    end
    collectgarbage()
    collectgarbage()
  else
    customSensors = nil
  end
end

local function validGps(gpsPos)
  return type(gpsPos) == "table" and gpsPos.lat ~= nil and gpsPos.lon ~= nil
end

local function processTelemetry(appId, value, now)
  if conf.headingSensor == "None" then
    telemetry.yaw = telemetry.cog
  else
    telemetry.yaw = getValue(conf.headingSensor) * conf.headingSensorUnitScale
  end
end


local function telemetryEnabled(widget)
--[[
  local rssi = widget.options["RSSI Source"] == nil and 0 or getValue(widget.options["RSSI Source"])
  if rssi == 0 then
    return false
  end
--]]
  if getRSSI() == 0 then
    return false
  end
  status.hideNoTelemetry = true
  return true
end

local function calcMinValue(value,min)
  return min == 0 and value or math.min(value,min)
end

-- returns the actual minimun only if both are > 0
local function getNonZeroMin(v1,v2)
  return v1 == 0 and v2 or ( v2 == 0 and v1 or math.min(v1,v2))
end

function utils.drawTopBar(widget)
  lcd.setColor(CUSTOM_COLOR,utils.colors.black)
  -- black bar
  lcd.drawFilledRectangle(0,0, LCD_W, 18, CUSTOM_COLOR)
  -- frametype and model name
  lcd.setColor(CUSTOM_COLOR,utils.colors.white)
  if status.modelString ~= nil then
    lcd.drawText(2, 0, status.modelString, CUSTOM_COLOR)
  end
  local time = getDateTime()
  local strtime = string.format("%02d:%02d:%02d",time.hour,time.min,time.sec)
  lcd.drawText(LCD_W, 0+4, strtime, SMLSIZE+RIGHT+CUSTOM_COLOR)
  -- RSSI
  if telemetryEnabled(widget) == false then
    lcd.setColor(CUSTOM_COLOR,utils.colors.red)
    lcd.drawText(285-23, 0, "RS:---", 0+CUSTOM_COLOR)
    utils.drawBlinkBitmap("warn",0,0)
  else
    lcd.drawText(285, 0, "RS:", 0+CUSTOM_COLOR)
    --local strRSSI = widget.options["RSSI Source"] == nil and "---" or tonumber(getValue(widget.options["RSSI Source"]))
    local strRSSI = getRSSI() == 0 and "---" or getRSSI()
    lcd.drawText(285 + 30,0, strRSSI, 0+CUSTOM_COLOR)
  end
  lcd.setColor(CUSTOM_COLOR,utils.colors.white)
  -- tx voltage
  local vtx = string.format("Tx:%.1fv",getValue(getFieldInfo("tx-voltage").id))
  lcd.drawText(350,0, vtx, 0+CUSTOM_COLOR)
end

local function reset()
  -- CONFIG
  loadConfig()

  utils.clearTable(customSensors)
  customSensors = nil
  -- TELEMETRY
  utils.clearTable(telemetry)
  -- GPS
  telemetry.numSats = 0
  telemetry.gpsStatus = 0
  telemetry.gpsHdopC = 100
  -- HOME
  telemetry.homeDist = 0
  telemetry.homeAlt = 0
  telemetry.homeAngle = -1
  -- VELANDYAW
  telemetry.yaw = 0
  -- GPS
  telemetry.lat = nil
  telemetry.lon = nil
  telemetry.homeLat = nil
  telemetry.homeLon = nil
  telemetry.groundSpeed = 0
  telemetry.cog = 0

  collectgarbage()
  collectgarbage()
  -- STATUS
  utils.clearTable(status)
  status = {
    -- MAP
    mapZoomLevel = conf.mapZoomLevel,
    lastLat = nil,
    lastLon = nil,
    homeSet = false,
    avgSpeed = {
      lastSampleTime = nil,
      avgTravelDist = 0,
      avgTravelTime = 0,
      travelDist = 0,
      prevLat = nil,
      prevLon = nil,
      value = 0,
    },
  }
  collectgarbage()
  collectgarbage()
  -- SENSORS
  utils.loadCustomSensors()
  gpsLockTimer = nil
  collectgarbage()
  collectgarbage()
end

local function getConfigTriggerFilename()
  local info = model.getInfo()
  return "/WIDGETS/YaapuMaps/cfg/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "").."_maps.reload")
end

local function checkConfig()
  local cfg = io.open(getConfigTriggerFilename(),"r")
  if cfg ~= nil then
    local str = io.read(cfg,1)
    io.close(cfg)

    if str == "1" then
      cfg = io.open(getConfigTriggerFilename(),"w")
      if cfg ~= nil then
        io.write(cfg, "0")
        io.close(cfg)
      end
      loadConfig()
    end
  end
  collectgarbage()
  collectgarbage()
end

local function task5HzA(widget, now)
  status.mapZoomLevel = utils.getMapZoomLevel(widget,conf,status,customSensors)
  utils.checkHomeResetChannel(widget)
end

local function task5HzB(widget, now)
  -- update gps telemetry data
  local gpsdata = nil
  if conf.gpsSource == 1 then
    gpsData = getValue("GPS")
  else
    if widget.options["GPS Source"] ~= nil then
      gpsData = getValue(widget.options["GPS Source"])
    end
  end

  if type(gpsData) == "table" and gpsData.lat ~= nil and gpsData.lon ~= nil then
    telemetry.lat = gpsData.lat
    telemetry.lon = gpsData.lon
  end
  -- cog
  utils.updateCog()
end

local function resetHome()
  telemetry.homeLat = telemetry.lat
  telemetry.homeLon = telemetry.lon
  status.avgSpeed.avgTravelDist = 0
  status.avgSpeed.avgTravelTime = 0
  status.avgSpeed.travelDist = 0
  status.avgSpeed.value = 0
end


local function task2Hz(widget, now)
  -- frametype and model name
  local info = model.getInfo()
  -- model change event
  if currentModel ~= info.name then
    currentModel = info.name
    -- force a model string reset
    status.modelString = info.name
    -- trigger reset
    reset()
  end

  setTelemetryValue(0x084F, 0, 0, math.floor(telemetry.yaw), 20 , 0 , "Hdg")
  setTelemetryValue(0x083F, 0, 0, telemetry.groundSpeed, 5 , 0 , "GSpd")

  -- wait 10 seconds before auto setting home
  if telemetry.homeLat == nil and telemetry.homeLon == nil and telemetry.lat ~= nil and telemetry.lon ~= nil and telemetry.groundSpeed < 1 then
    if gpsLockTimer == nil then
      gpsLockTimer = getTime()
    end
    if getTime() - gpsLockTimer > 1000 then
      resetHome()
    end
  end


end

local function taskAvgSpeed2Hz(widget, now)
  if telemetry.lat ~= nil and telemetry.lon ~= nil then
    -- PROCESS GPS DATA
    if status.avgSpeed.lastLat == nil or status.avgSpeed.lastLon == nil then
      status.avgSpeed.lastLat = telemetry.lat
      status.avgSpeed.lastLon = telemetry.lon
      status.avgSpeed.lastSampleTime = now
    end

    if now - status.avgSpeed.lastSampleTime > 100 then
      local travelDist = utils.haversine(telemetry.lat, telemetry.lon, status.avgSpeed.lastLat, status.avgSpeed.lastLon)
      local travelTime = now - status.avgSpeed.lastSampleTime
      local speed = travelDist/travelTime
      -- discard sampling errors
      if travelDist < 10000 then
        -- 5 point moving average, about 10 seconds data
        status.avgSpeed.avgTravelDist = status.avgSpeed.avgTravelDist * 0.8 + travelDist*0.2
        status.avgSpeed.avgTravelTime = status.avgSpeed.avgTravelTime * 0.8 + 0.01 * travelTime * 0.2
        status.avgSpeed.value = status.avgSpeed.avgTravelDist/status.avgSpeed.avgTravelTime
        status.avgSpeed.travelDist = status.avgSpeed.travelDist + travelDist
        telemetry.groundSpeed = status.avgSpeed.value
      end
      status.avgSpeed.lastLat = telemetry.lat
      status.avgSpeed.lastLon = telemetry.lon
      status.avgSpeed.lastSampleTime = now
      -- home distance
      if telemetry.homeLat ~= nil and telemetry.homeLon ~= nil then
        telemetry.homeDist = utils.haversine(telemetry.lat, telemetry.lon, telemetry.homeLat, telemetry.homeLon)
        telemetry.homeAngle = utils.getAngleFromLatLon(telemetry.lat, telemetry.lon, telemetry.homeLat, telemetry.homeLon)
      end
    end
  end
end

local function task1Hz(widget, now)
  if status.modelString == nil then
    local info = model.getInfo()
    status.modelString = info.name
  end
end

local function task05Hz(widget, now)
  -- reload config
  checkConfig()

  collectgarbage()
  collectgarbage()
end


local tasks = {
  {0, 20,   task5HzA},
  {0, 20,   task5HzB},
  {0, 50,   task2Hz},
  {0, 50,   taskAvgSpeed2Hz},
  {0, 100,  task1Hz},
  {0, 200,  task05Hz},
}

local function checkTaskTimeConstraints(now, task_id)
  return (now - tasks[task_id][1]) >= tasks[task_id][2]
end

function utils.runScheduler(widget, tasks)
  local now = getTime()
  local maxDelayTaskId = -1
  local maxDelay = 0
  local delay = 0

  for taskId=1,#tasks
  do
    delay = (now - (tasks[taskId][1]))/tasks[taskId][2]
    if (delay >= maxDelay and checkTaskTimeConstraints(now, taskId)) then
      maxDelay = delay
      maxDelayTaskId = taskId
    end
  end
  if maxDelayTaskId < 0 then
    return maxDelayTaskId
  end
  tasks[maxDelayTaskId][1] = now;
  tasks[maxDelayTaskId][3](widget, getTime())
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------
local function backgroundTasks(widget)
  local now = getTime()
  processTelemetry(nil, nil, now)

  utils.runScheduler(widget, tasks)

  -- blinking support
  if (now - blinktime) > 65 then
    blinkon = not blinkon
    blinktime = now
  end
  return 0
end

local function init()


-- load configuration at boot and only refresh if GV(8,8) = 1
  loadConfig()
  utils.initColors()
  -- zoom initialize
  status.mapZoomLevel = conf.mapZoomLevel
  -- load draw library
  drawLib = utils.doLibrary(drawLibFile)
  mapLib = utils.doLibrary(mapLibFile)

  currentModel = model.getInfo().name
  -- load custom sensors
  utils.loadCustomSensors()
  -- fix for generalsettings lazy loading...
  unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
  unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"

  unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
  unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"

  -- check if EdgeTx >= 2.8
  local ver, radio, maj, minor, rev, osname = getVersion()
  if osname == 'EdgeTX' and maj >= 2 and minor >= 8 then
    utils.degSymbol = '°'
  end
end

--------------------------------------------------------------------------------

local options = {
--[[
  { "GPS Source", SOURCE, 1 },
  { "RSSI Source", SOURCE, 1 },
--]]
}
-- shared init flag
local initDone = 0

-- This function is runned once at the creation of the widget
local function create(zone, options)
  -- this vars are widget scoped, each instance has its own set
  local vars = {
  }
  -- all local vars are shared between widget instances
  -- init() needs to be called only once!
  if initDone == 0 then
    init()
    initDone = 1
  end
  --
  return { zone=zone, options=options, vars=vars }
end

-- This function allow updates when you change widgets settings
local function update(widget, options)
  widget.options = options
  -- reload menu settings
  loadConfig()
end

local function fullScreenRequired(widget)
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(255, 0, 0))
  lcd.drawText(widget.zone.x,widget.zone.y,"YaapuMaps requires",SMLSIZE+CUSTOM_COLOR)
  lcd.drawText(widget.zone.x,widget.zone.y+16,"full screen",SMLSIZE+CUSTOM_COLOR)
end

function utils.validateZoomLevel(newZoom,conf,status,zoomLevels)
  -- no valid zoom table, all levels are allowed
  if zoomLevels == nil then
    return newZoom
  end
  -- check against valid zoom levels table
  if zoomLevels ~= nil then
    if zoomLevels[newZoom] == true then
      -- ok this level is allowed
      return newZoom
    end
  end
  -- not allowed, stick with current zoom
  return status.mapZoomLevel
end

local zoomDelayStart = getTime()

function utils.decZoomLevel(conf,status,zoomLevels)
  if getTime() - zoomDelayStart < conf.mapWheelChannelDelay*10 then
    return status.mapZoomLevel
  end
  zoomDelayStart = getTime()
  local newZoom = status.mapZoomLevel == nil and conf.mapZoomLevel or status.mapZoomLevel
  while newZoom > conf.mapZoomMin
  do
    newZoom = newZoom - 1
    if zoomLevels ~= nil then
      if zoomLevels[newZoom] == true then
        return newZoom
      end
    else
      return newZoom
    end
  end
  return utils.validateZoomLevel(newZoom,conf,status,zoomLevels)
end

function utils.incZoomLevel(conf,status,zoomLevels)
  if getTime() - zoomDelayStart < conf.mapWheelChannelDelay*10 then
    return status.mapZoomLevel
  end
  zoomDelayStart = getTime()
  local newZoom = status.mapZoomLevel == nil and conf.mapZoomLevel or status.mapZoomLevel
  while newZoom < conf.mapZoomMax
  do
    newZoom = newZoom + 1
    if zoomLevels ~= nil then
      if zoomLevels[newZoom] == true then
        return newZoom
      end
    else
      return newZoom
    end
  end
  return utils.validateZoomLevel(newZoom,conf,status,zoomLevels)
end

function utils.checkHomeResetChannel(widget)
  local chValue = getValue(conf.homeResetChannelId)
  if conf.homeResetChannelId > -1 then
    if chValue > 600 then
      resetHome()
    end
  end
end

function utils.getMapZoomLevel(widget,conf,status,customSensors)
  local chValue = getValue(conf.mapWheelChannelId)
  local newZoom = status.mapZoomLevel == nil and conf.mapZoomLevel or status.mapZoomLevel
  local zoomLevels = nil
  if customSensors ~= nil then
    zoomLevels = customSensors.zoomLevels
  end
  if conf.mapWheelChannelId > -1 then
    -- SW up (increase zoom detail)
    if chValue < -600 then
      if conf.mapProvider == 1 then
        return utils.decZoomLevel(conf,status,zoomLevels)
      else
        return utils.incZoomLevel(conf,status,zoomLevels)
      end
    end
    -- SW down (decrease zoom detail)
    if chValue > 600 then
      if conf.mapProvider == 1 then
        return utils.incZoomLevel(conf,status,zoomLevels)
      else
        return utils.decZoomLevel(conf,status,zoomLevels)
      end
    end
    -- switch is idle, force timer expire
    zoomDelayStart = getTime() - conf.mapWheelChannelDelay*10
  end
  return status.mapZoomLevel
end

-- Called when script is hidden @20Hz
local function background(widget)
  backgroundTasks(widget)
end

local slowTimer = getTime()

-- Called when script is visible
local function drawFullScreen(widget)
  if getTime() - slowTimer > 50 then
    -- check if current widget page changed
    slowTimer = getTime()
  end

  backgroundTasks(widget)

  lcd.setColor(CUSTOM_COLOR, utils.colors.darkgrey)
  lcd.clear(CUSTOM_COLOR)

  if layout ~= nil then
    layout.draw(widget,mapLib,drawLib,conf,telemetry,status,battery,alarms,frame,utils,customSensors,gpsStatuses,leftPanel,centerPanel,rightPanel)
  else
  -- Layout start
    if loadCycle == 3 then
      layout = utils.doLibrary("layout")
    end
  end

  drawLib.drawNoGPSData(status, telemetry, utils)
  loadCycle=(loadCycle+1)%8
  collectgarbage()
  collectgarbage()
end

function refresh(widget)
  if widget.zone.h < 250 then
    fullScreenRequired(widget)
    return
  end
  drawFullScreen(widget)
end

return { name="YaapuMaps", options=options, create=create, update=update, background=background, refresh=refresh }
