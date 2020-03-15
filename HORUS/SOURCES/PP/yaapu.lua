#include "includes/yaapu_inc.lua"

local currentModel = nil

------------------------------
-- TELEMETRY DATA
------------------------------
local telemetry = {}
--[[
-- STATUS 
telemetry.flightMode = 0
telemetry.simpleMode = 0
telemetry.landComplete = 0
telemetry.statusArmed = 0
telemetry.battFailsafe = 0
telemetry.ekfFailsafe = 0
telemetry.imuTemp = 0
--]]
-- GPS
telemetry.numSats = 0
telemetry.gpsStatus = 0
telemetry.gpsHdopC = 100
--[[
telemetry.gpsAlt = 0
-- BATT 1
telemetry.batt1volt = 0
telemetry.batt1current = 0
telemetry.batt1mah = 0
-- BATT 2
telemetry.batt2volt = 0
telemetry.batt2current = 0
telemetry.batt2mah = 0
--]]
-- HOME
telemetry.homeDist = 0
telemetry.homeAlt = 0
telemetry.homeAngle = -1
--[[
-- VELANDYAW
telemetry.vSpeed = 0
telemetry.hSpeed = 0
--]]
telemetry.yaw = 0
--[[
-- ROLLPITCH
telemetry.roll = 0
telemetry.pitch = 0
telemetry.range = 0 
-- PARAMS
telemetry.frameType = -1
telemetry.batt1Capacity = 0
telemetry.batt2Capacity = 0
--]]
-- GPS
telemetry.lat = nil
telemetry.lon = nil
telemetry.homeLat = nil
telemetry.homeLon = nil
--[[
-- WP
telemetry.wpNumber = 0
telemetry.wpDistance = 0
telemetry.wpXTError = 0
telemetry.wpBearing = 0
telemetry.wpCommands = 0
-- RC channels
telemetry.rcchannels = {}
-- VFR
telemetry.airspeed = 0
telemetry.throttle = 0
telemetry.baroAlt = 0
-- Total distance
telemetry.totalDist = 0
--]]

-----------------------------------------------------------------
-- INAV like telemetry support
-----------------------------------------------------------------
local gpsHome = false
--------------------------------
-- STATUS DATA
--------------------------------
local status = {}
-- MAP
status.mapZoomLevel = 1

---------------------------
-- LIBRARY LOADING
---------------------------
local basePath = "/SCRIPTS/YAAPU/"
local libBasePath = basePath.."LIB/"

-- loadable modules
local drawLibFile = "mapsdraw"
local menuLibFile = "mapsconfig"

local drawLib = {}
local utils = {}

-------------------------------
-- MAP SCREEN LAYOUT
-------------------------------
local mapLayout = nil

local customSensors = nil

local backlightLastTime = 0

-- Blinking bitmap support
local bitmaps = {}
local blinktime = getTime()
local blinkon = false


#ifdef TESTMODE
-- TEST MODE
local thrOut = 0
#endif --TESTMODE
-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()
-- widget selected page
local currentPage = 0
--------------------------------------------------------------------------------
-- CONFIGURATION MENU
--------------------------------------------------------------------------------
local conf = {
  mapType = "sat_tiles",
  mapZoomLevel = -2,
  enableMapGrid = true,
  mapToggleChannelId = nil,
}

local loadCycle = 0

utils.doLibrary = function(filename)
  local f = assert(loadScript(libBasePath..filename..".lua"))
  collectgarbage()
  collectgarbage()
  return f()
end
-----------------------------
-- clears the loaded table 
-- and recovers memory
-----------------------------
utils.clearTable = function(t)
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
  menuLib = loadMenuLib()
  menuLib.loadConfig(conf)
#ifdef COMPILE
  menuLib.compileLayouts()
#endif  
  -- unload libraries
  utils.clearTable(menuLib)
  utils.clearTable(mapLayout)
  mapLayout = nil
  collectgarbage()
  collectgarbage()
end

utils.getBitmap = function(name)
  if bitmaps[name] == nil then
    bitmaps[name] = Bitmap.open("/SCRIPTS/YAAPU/IMAGES/"..name..".png")
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
  model.setGlobalVariable(BACKLIGHT_GV,0,1)
  backlightLastTime = getTime()/100 -- seconds
end

#ifdef HAVERSINE
utils.haversine = function(lat1, lon1, lat2, lon2)
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
#endif --HAVERSINE

utils.getHomeFromAngleAndDistance = function(telemetry)
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


utils.decToDMS = function(dec,lat)
  local D = math.floor(math.abs(dec))
  local M = (math.abs(dec) - D)*60
  local S = (math.abs((math.abs(dec) - D)*60) - M)*60
	return D .. string.format("\64%04.2f", M) .. (lat and (dec >= 0 and "E" or "W") or (dec >= 0 and "N" or "S"))
end

utils.decToDMSFull = function(dec,lat)
  local D = math.floor(math.abs(dec))
  local M = math.floor((math.abs(dec) - D)*60)
  local S = (math.abs((math.abs(dec) - D)*60) - M)*60
	return D .. string.format("\64%d'%04.1f", M, S) .. (lat and (dec >= 0 and "E" or "W") or (dec >= 0 and "N" or "S"))
end

utils.drawBlinkBitmap = function(bitmap,x,y)
  if blinkon == true then
      lcd.drawBitmap(utils.getBitmap(bitmap),x,y)
  end
end

local function getSensorsConfigFilename()
  local info = model.getInfo()
  return "/SCRIPTS/YAAPU/CFG/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "").."_sensors_maps.lua")
end

--------------------------
-- CUSTOM SENSORS SUPPORT
--------------------------
#define SENSOR_LABEL 1
#define SENSOR_NAME 2
#define SENSOR_PREC 3
#define SENSOR_UNIT 4
#define SENSOR_MULT 5
#define SENSOR_MAX 6
#define SENSOR_FONT 7
#define SENSOR_WARN 8
#define SENSOR_CRIT 9

utils.loadCustomSensors = function()
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
        local sign = customSensors.sensors[i][SENSOR_MAX] == "+" and 1 or -1
        if customSensors.sensors[i][SENSOR_CRIT] == nil then
          customSensors.sensors[i][SENSOR_CRIT] = math.huge*sign
        end
        if customSensors.sensors[i][SENSOR_WARN] == nil then
          customSensors.sensors[i][SENSOR_WARN] = math.huge*sign
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

local function calcHomeDirection(gpsPos)
  if gpsHome == false then
    return false
  end
  -- Formula:	θ = atan2( sin Δλ ⋅ cos φ2 , cos φ1 ⋅ sin φ2 − sin φ1 ⋅ cos φ2 ⋅ cos Δλ )
  local lat2 = math.rad(gpsHome.lat)
  local lon2 = math.rad(gpsHome.lon)
  local lat1 = math.rad(gpsPos.lat)
  local lon1 = math.rad(gpsPos.lon)
  local y = math.sin(lon2-lon1) * math.cos(lat2);
  local x = math.cos(lat1)*math.sin(lat2) - math.sin(lat1)*math.cos(lat2)*math.cos(lon2-lon1)
  local hdg = math.deg(math.atan2(y,x))
  if (hdg < 0) then
    hdg = 360 + hdg
  end
  return hdg
end

local function processTelemetry()
  -- YAW
  telemetry.yaw = getValue("Hdg")
end

#ifdef TESTMODE
local function telemetryEnabled(status)
  return true
end
#else --TESTMODE
local function telemetryEnabled()
  if getRSSI() == 0 then
    return false
  end
    return true
end
#endif --TESTMODE

local function calcMinValue(value,min)
  return min == 0 and value or math.min(value,min)
end

-- returns the actual minimun only if both are > 0
local function getNonZeroMin(v1,v2)
  return v1 == 0 and v2 or ( v2 == 0 and v1 or math.min(v1,v2))
end

utils.drawTopBar = function()
  lcd.setColor(CUSTOM_COLOR,COLOR_BARS)  
  -- black bar
  lcd.drawFilledRectangle(0,0, LCD_W, 18, CUSTOM_COLOR)
  -- frametype and model name
  lcd.setColor(CUSTOM_COLOR,COLOR_TEXT)
  if status.modelString ~= nil then
    lcd.drawText(2, RSSI_Y, status.modelString, CUSTOM_COLOR)
  end
  local time = getDateTime()
  local strtime = string.format("%02d:%02d:%02d",time.hour,time.min,time.sec)
  lcd.drawText(LCD_W, RSSI_Y+4, strtime, SMLSIZE+RIGHT+CUSTOM_COLOR)
  -- RSSI
  if telemetryEnabled() == false then
    lcd.setColor(CUSTOM_COLOR,COLOR_RED)    
    lcd.drawText(RSSI_X-23, RSSI_Y, "NO TELEM", RSSI_FLAGS+CUSTOM_COLOR)
  else
    lcd.drawText(RSSI_X, RSSI_Y, "RS:", RSSI_FLAGS+CUSTOM_COLOR)
#ifdef DEMO
    lcd.drawText(RSSI_X + 30,RSSI_Y, 87, RSSI_FLAGS+CUSTOM_COLOR)  
#else --DEMO
    lcd.drawText(RSSI_X + 30,RSSI_Y, getRSSI(), RSSI_FLAGS+CUSTOM_COLOR)  
#endif --DEMO
  end
  lcd.setColor(CUSTOM_COLOR,COLOR_TEXT)    
  -- tx voltage
  local vtx = string.format("Tx:%.1fv",getValue(getFieldInfo("tx-voltage").id))
  lcd.drawText(TXVOLTAGE_X,TXVOLTAGE_Y, vtx, TXVOLTAGE_FLAGS+CUSTOM_COLOR)
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------
--
local bgclock = 0
#ifdef BGTELERATE
local bgtelecounter = 0
local bgtelerate = 0
local bgtelestart = 0
#endif --BGTELERATE

-------------------------------
-- running at 20Hz (every 50ms)
-------------------------------
local timer2Hz = getTime()

local function backgroundTasks(myWidget)
  processTelemetry()
  
  -- SLOW: this runs around 2.5Hz
  if bgclock % 2 == 1 then
    -- update gps telemetry data
    local gpsData = getValue("GPS")
    
    if type(gpsData) == "table" and gpsData.lat ~= nil and gpsData.lon ~= nil then
      telemetry.lat = gpsData.lat
      telemetry.lon = gpsData.lon
    end
    
    if getTime() - timer2Hz > 50 then
      status.mapZoomLevel = utils.getMapZoomLevel(myWidget,conf,status)
      timer2Hz = getTime()
    end
    
    if status.modelString == nil then
      local info = model.getInfo()
      status.modelString = info.name
    end
 end
  
  -- SLOWER: this runs around 1.25Hz but not when the previous block runs
  -- because bgclock%4 == 0 is always different than bgclock%2==1
  if bgclock % 4 == 0 then
    -- reset backlight panel
    if (model.getGlobalVariable(BACKLIGHT_GV,0) > 0 and getTime()/100 - backlightLastTime > BACKLIGHT_DURATION) then
      model.setGlobalVariable(BACKLIGHT_GV,0,0)
    end
    
    -- reload config
    if (model.getGlobalVariable(CONF_GV,CONF_FM_GV) > 0) then
      loadConfig()
      model.setGlobalVariable(CONF_GV,CONF_FM_GV,0)
    end    
        
    bgclock = 0
  end
  bgclock = bgclock+1
  
  -- blinking support
  if (getTime() - blinktime) > 65 then
    blinkon = not blinkon
    blinktime = getTime()
  end
  
  collectgarbage()
  collectgarbage()
  return 0
end

local function init()
#ifdef COMPILE
  loadScript("/SCRIPTS/YAAPU/mapsconfig.lua","c")
  loadScript(libBasePath..drawLibFile..".lua","c")
#endif  

#ifdef TESTMODE
  telemetry.lat = -35.362864
  telemetry.lon = 149.165491
#else
  model.setTimer(2,{value=0})
#endif
-- load configuration at boot and only refresh if GV(8,8) = 1
  loadConfig()
  -- load draw library
  drawLib = utils.doLibrary(drawLibFile)

  currentModel = model.getInfo().name
  -- load custom sensors
  utils.loadCustomSensors()
  -- fix for generalsettings lazy loading...
  unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
  unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
  
  unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
  unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"
end

--------------------------------------------------------------------------------

local options = {}
-- shared init flag
local initDone = 0

-- This function is runned once at the creation of the widget
local function create(zone, options)
  -- this vars are widget scoped, each instance has its own set
  local vars = {
    #ifdef HUDRATE
    hudcounter = 0,
    hudrate = 0,
    hudstart = 0,
    #endif --HUDRATE
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
local function update(myWidget, options)
  myWidget.options = options
  -- reload menu settings
  loadConfig()
end

local function fullScreenRequired(myWidget)
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(255, 0, 0))
  lcd.drawText(myWidget.zone.x,myWidget.zone.y,"YaapuMaps requires",SMLSIZE+CUSTOM_COLOR)
  lcd.drawText(myWidget.zone.x,myWidget.zone.y+16,"full screen",SMLSIZE+CUSTOM_COLOR)
end


utils.getMapZoomLevel = function(myWidget,conf,status)
  local chValue = getValue(conf.mapToggleChannelId)
  
  if conf.mapToggleChannelId > -1 then
    if chValue >= 600 then
      return conf.mapZoomLevel + 2
    end
    
    if chValue > - 600 and chValue < 600 then
      return conf.mapZoomLevel + 1
    end
  end
  return conf.mapZoomLevel
end

-- Called when script is hidden @20Hz
local function background(myWidget)
  backgroundTasks(myWidget)
end

local slowTimer = getTime()

-- Called when script is visible
local function drawFullScreen(myWidget)
#ifdef HUDRATE
  ------------------------
  -- CALC HUD REFRESH RATE
  ------------------------
  -- skip first iteration
  local hudnow = getTime()
  
  if myWidget.vars.hudcounter == 0 then
    myWidget.vars.hudstart = hudnow
  else
    myWidget.vars.hudrate = myWidget.vars.hudrate*0.8 + 100*(myWidget.vars.hudcounter/(hudnow - myWidget.vars.hudstart + 1))*0.2
  end
  --
  myWidget.vars.hudcounter=myWidget.vars.hudcounter+1
  
  if hudnow - myWidget.vars.hudstart + 1 > 1000 then
    myWidget.vars.hudcounter = 0
  end
#endif --HUDRATE  
  if getTime() - slowTimer > 50 then
    -- check if current widget page changed
    slowTimer = getTime()
  end
  
  backgroundTasks(myWidget)
  
  lcd.setColor(CUSTOM_COLOR, COLOR_BG)
  lcd.clear(CUSTOM_COLOR)
    
  if mapLayout ~= nil then
    mapLayout.draw(myWidget,drawLib,conf,telemetry,status,battery,alarms,frame,utils,customSensors,gpsStatuses,leftPanel,centerPanel,rightPanel)
  else
  -- Layout start
    if loadCycle == 3 then
      mapLayout = utils.doLibrary("mapslayout")
    end
  end
  
  -- no telemetry/minmax outer box
  if telemetryEnabled() == false then
    -- no telemetry inner box
    if not status.hideNoTelemetry then
      drawLib.drawNoTelemetryData(status,telemetry,utils,telemetryEnabled)
    end
    utils.drawBlinkBitmap("warn",0,0)  
  end
  
  loadCycle=(loadCycle+1)%8
#ifdef HUDRATE    
  lcd.setColor(CUSTOM_COLOR,COLOR_YELLOW)
  local hudrateTxt = string.format("%.1ffps",myWidget.vars.hudrate)
  lcd.drawText(212,3,hudrateTxt,SMLSIZE+CUSTOM_COLOR+RIGHT)
#endif --HUDRATE
#ifdef MEMDEBUG
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(255,0,0))
  maxmem = math.max(maxmem,collectgarbage("count")*1024)
  -- test with absolute coordinates
  lcd.drawNumber(480,LCD_H-14,maxmem,SMLSIZE+MENU_TITLE_COLOR+RIGHT)
#endif
  collectgarbage()
  collectgarbage()
end

function refresh(myWidget)
  
  if myWidget.zone.h < 250 then 
    fullScreenRequired(myWidget)
    return
  end
  drawFullScreen(myWidget)
end

return { name="YaapuMaps", options=options, create=create, update=update, background=background, refresh=refresh }