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
  for info see https://github.com/heldersepu/GMapCatcher
  
  Notes:
  - tiles need to be resized down to 100x100 from original size of 256x256
  - at max zoom level (-2) 1 tile = 100px = 76.5m
]]
--------------------------
-- MINI HUD
--------------------------

--------------------------
-- MAP properties
--------------------------


--#define SAMPLES 10



--------------------------
-- CUSTOM SENSORS SUPPORT
--------------------------

local customSensorXY = {
  -- horizontal
  { 80, 220, 80, 232},
  { 160, 220, 160, 232},
  { 240, 220, 240, 232},
  { 320, 220, 320, 232},
  { 400, 220, 400, 232},
  { 478, 220, 478, 232},
  -- vertical
  { 478, 25, 478, 37},
  { 478, 75, 478, 87},
  { 478, 125, 478, 137},
  { 478, 175, 478, 187},
}

-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()

-- map support
local posUpdated = false
local myScreenX, myScreenY
local homeScreenX, homeScreenY
local estimatedHomeScreenX, estimatedHomeScreenY
local tile_x,tile_y,offset_x,offset_y
local tiles = {}
local mapBitmapByPath = {}
local nomap = nil
local world_tiles
local tiles_per_radian
local tile_dim
local scaleLen
local scaleLabel
local posHistory = {}
local homeNeedsRefresh = true
local sample = 0
local sampleCount = 0
local lastPosUpdate = getTime()
local lastPosSample = getTime()
local lastHomePosUpdate = getTime()
local lastZoomLevel = -99
local estimatedHomeGps = {
  lat = nil,
  lon = nil
}

local lastProcessCycle = getTime()
local processCycle = 0

local avgDistSamples = {}
local avgDist = 0;
local avgDistSum = 0;
local avgDistSample = 0;
local avgDistSampleCount = 0;
local avgDistLastSampleTime = getTime();
avgDistSamples[0] = 0





local function tiles_on_level(level)
 return bit32.lshift(1,17 - level)
end

local function coord_to_tiles(lat,lon)
  local x = world_tiles / 360 * (lon + 180)
  local e = math.sin(lat * (1/180 * math.pi))
  local y = world_tiles / 2 + 0.5 * math.log((1+e)/(1-e)) * -1 * tiles_per_radian
  return math.floor(x % world_tiles), math.floor(y % world_tiles), math.floor((x - math.floor(x)) * 100), math.floor((y - math.floor(y)) * 100)
end

local function tiles_to_path(tile_x, tile_y, level)
  local path = string.format("/%d/%d/%d/%d/s_%d.png", level, tile_x/1024, tile_x%1024, tile_y/1024, tile_y%1024)
  collectgarbage()
  collectgarbage()
  return path
end

local function getTileBitmap(conf,tilePath)
  local fullPath = "/SCRIPTS/YAAPU/MAPS/"..conf.mapType..tilePath
  -- check cache
  if mapBitmapByPath[tilePath] ~= nil then
    return mapBitmapByPath[tilePath]
  end
  
  local bmp = Bitmap.open(fullPath)
  local w,h = Bitmap.getSize(bmp)
  
  if w > 0 then
    mapBitmapByPath[tilePath] = bmp
    return bmp
  else
    if nomap == nil then
      nomap = Bitmap.open("/SCRIPTS/YAAPU/MAPS/nomap.png")
    end
    mapBitmapByPath[tilePath] = nomap
    return nomap
  end
end

local function loadAndCenterTiles(conf,tile_x,tile_y,offset_x,offset_y,width,level)
  -- determine if upper or lower center tile
  local yy = 2
  if offset_y > 100/2 then
    yy = 1
  end
  for x=1,4
  do
    for y=1,2
    do
      local tile_path = tiles_to_path(tile_x+x-2, tile_y+y-yy, level)
      local idx = width*(y-1)+x
      
      if tiles[idx] == nil then
        tiles[idx] = tile_path
      else
        if tiles[idx] ~= tile_path then
          tiles[idx] = nil
          collectgarbage()
          collectgarbage()
          tiles[idx] = tile_path
        end
      end
    end
  end
  -- release unused cached images
  for path, bmp in pairs(mapBitmapByPath) do
    local remove = true
    for i=1,#tiles
    do
      if tiles[i] == path then
        remove = false
      end
    end
    if remove then
      mapBitmapByPath[path]=nil
    end
  end
  -- force a call to destroyBitmap()
  collectgarbage()
  collectgarbage()
end

local function drawTiles(conf,drawLib,utils,width,xmin,xmax,ymin,ymax,color,level)
  for x=1,4
  do
    for y=1,2
    do
      local idx = width*(y-1)+x
      if tiles[idx] ~= nil then
        lcd.drawBitmap(getTileBitmap(conf,tiles[idx]), xmin+(x-1)*100, ymin+(y-1)*100)
      end
    end
  end
  if conf.enableMapGrid then
    -- draw grid
    for x=1,4-1
    do
      lcd.drawLine(xmin+x*100,ymin,xmin+x*100,ymax,DOTTED,color)
    end
    
    for y=1,2-1
    do
      lcd.drawLine(xmin,ymin+y*100,xmax,ymin+y*100,DOTTED,color)
    end
  end
  -- map overlay
  lcd.drawBitmap(utils.getBitmap("maps_box_380x20"),5,ymin+2*100-20) --160x90  
  -- draw 50m or 150ft line at max zoom
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
  lcd.drawLine(xmin+5,ymin+2*100-7,xmin+5+scaleLen,ymin+2*100-7,SOLID,CUSTOM_COLOR)
  lcd.drawText(xmin+5,ymin+2*100-21,scaleLabel,SMLSIZE+CUSTOM_COLOR)
end

local function getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
  -- is this tile on screen ?
  local tile_path = tiles_to_path(tile_x,tile_y,level)
  local onScreen = false
  
  for x=1,4
  do
    for y=1,2
    do
      local idx = 4*(y-1)+x
      if tiles[idx] == tile_path then
        -- ok it's on screen
        return minX + (x-1)*100 + offset_x, minY + (y-1)*100 + offset_y
      end
    end
  end
  -- force offscreen up
  return LCD_W/2, -10
end

local function drawMap(myWidget,drawLib,conf,telemetry,status,utils,level)
  local minY = 18
  local maxY = minY+2*100
  
  local minX = 0 
  local maxX = minX+4*100
  
  if telemetry.lat ~= nil and telemetry.lon ~= nil then
    -- position update
    if getTime() - lastPosUpdate > 50 then
      posUpdated = true
      lastPosUpdate = getTime()
      -- current vehicle tile coordinates
      tile_x,tile_y,offset_x,offset_y = coord_to_tiles(telemetry.lat,telemetry.lon)
      -- viewport relative coordinates
      myScreenX,myScreenY = getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
      -- check if offscreen, and increase border on X axis
      local myCode = drawLib.computeOutCode(myScreenX, myScreenY, minX+50, minY+50, maxX-50, maxY-50);
      
      -- center vehicle on screen
      if myCode > 0 then
        loadAndCenterTiles(conf, tile_x, tile_y, offset_x, offset_y, 4, level)
        -- after centering screen position needs to be computed again
        tile_x,tile_y,offset_x,offset_y = coord_to_tiles(telemetry.lat,telemetry.lon)
        myScreenX,myScreenY = getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
      end
    end
    
    -- home position update
    if getTime() - lastHomePosUpdate > 50 and posUpdated then
      lastHomePosUpdate = getTime()
      if homeNeedsRefresh then
        -- update home, schedule estimated home update
        homeNeedsRefresh = false
        if telemetry.homeLat ~= nil then
          -- current vehicle tile coordinates
          tile_x,tile_y,offset_x,offset_y = coord_to_tiles(telemetry.homeLat,telemetry.homeLon)
          -- viewport relative coordinates
          homeScreenX,homeScreenY = getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
        end
      else
        -- update estimated home, schedule home update
        homeNeedsRefresh = true
        estimatedHomeGps.lat,estimatedHomeGps.lon = utils.getHomeFromAngleAndDistance(telemetry)
        if estimatedHomeGps.lat ~= nil then
          local t_x,t_y,o_x,o_y = coord_to_tiles(estimatedHomeGps.lat,estimatedHomeGps.lon)
          -- viewport relative coordinates
          estimatedHomeScreenX,estimatedHomeScreenY = getScreenCoordinates(minX,minY,t_x,t_y,o_x,o_y,level)        
        end
      end
      collectgarbage()
      collectgarbage()
    end
    
    -- position history sampling
    if getTime() - lastPosSample > 50 and posUpdated then
        lastPosSample = getTime()
        posUpdated = false
        -- points history
        local path = tiles_to_path(tile_x, tile_y, level)
        posHistory[sample] = { path, offset_x, offset_y }
        collectgarbage()
        collectgarbage()
        sampleCount = sampleCount+1
        sample = sampleCount%conf.mapTrailDots
    end
    
    -- draw map tiles
    lcd.setColor(CUSTOM_COLOR,0xFE60)
    drawTiles(conf,drawLib,utils,4,minX,maxX,minY,maxY,CUSTOM_COLOR,level)
    -- draw home
    if telemetry.homeLat ~= nil and telemetry.homeLon ~= nil and homeScreenX ~= nil then
      local homeCode = drawLib.computeOutCode(homeScreenX, homeScreenY, minX+11, minY+10, maxX-11, maxY-10);
      if homeCode == 0 then
        lcd.drawBitmap(utils.getBitmap("homeorange"),homeScreenX-11,homeScreenY-10)
      end
    end
    
    --[[
    -- draw estimated home (debug info)
    if estimatedHomeGps.lat ~= nil and estimatedHomeGps.lon ~= nil and estimatedHomeScreenX ~= nil then
      local homeCode = drawLib.computeOutCode(estimatedHomeScreenX, estimatedHomeScreenY, minX+11, minY+10, maxX-11, maxY-10);
      if homeCode == 0 then
        lcd.setColor(CUSTOM_COLOR,COLOR_RED)
        lcd.drawRectangle(estimatedHomeScreenX-11,estimatedHomeScreenY-11,20,20,CUSTOM_COLOR)
      end
    end
    --]]    
    -- draw vehicle
    if myScreenX ~= nil then
      lcd.setColor(CUSTOM_COLOR,0xFFFF)
      drawLib.drawRArrow(myScreenX,myScreenY,17-5,telemetry.yaw,CUSTOM_COLOR)
      lcd.setColor(CUSTOM_COLOR,0x0000)
      drawLib.drawRArrow(myScreenX,myScreenY,17,telemetry.yaw,CUSTOM_COLOR)
    end
    -- draw gps trace
    lcd.setColor(CUSTOM_COLOR,0xFE60)
    for p=0, math.min(sampleCount-1,conf.mapTrailDots-1)
    do
      if p ~= (sampleCount-1)%conf.mapTrailDots then
        for x=1,4
        do
          for y=1,2
          do
            local idx = 4*(y-1)+x
            -- check if tile is on screen
            if tiles[idx] == posHistory[p][1] then
              lcd.drawFilledRectangle(minX + (x-1)*100 + posHistory[p][2]-1, minY + (y-1)*100 + posHistory[p][3]-1,3,3,CUSTOM_COLOR)
            end
          end
        end
      end
    end
    -- DEBUG
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawText(0+5,18+5,string.format("zoom:%d",level),SMLSIZE+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
  end
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
end

local function drawCustomSensors(x,customSensors,utils,status)
    --lcd.setColor(CUSTOM_COLOR,lcd.RGB(0,75,128))
    --[[
    lcd.setColor(CUSTOM_COLOR,COLOR_SENSORS)
    lcd.drawFilledRectangle(0,194,LCD_W,35,CUSTOM_COLOR)
    --]]
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawRectangle(400,18,80,201,CUSTOM_COLOR)
    for l=1,3
    do
      lcd.drawLine(400,18+(l*50),479,18+(l*50),SOLID,CUSTOM_COLOR)
    end
    local label,data,prec,mult,flags,sensorConfig
    for i=1,10
    do
      if customSensors.sensors[i] ~= nil then 
        sensorConfig = customSensors.sensors[i]
        
        -- check if sensor is a timer
        if sensorConfig[4] == "" then
          label = string.format("%s",sensorConfig[1])
        else
          label = string.format("%s(%s)",sensorConfig[1],sensorConfig[4])
        end
        -- draw sensor label
        lcd.setColor(CUSTOM_COLOR,0x8C71)
        lcd.drawText(x+customSensorXY[i][1], customSensorXY[i][2],label, SMLSIZE+RIGHT+CUSTOM_COLOR)
        
        local timerId = string.match(string.lower(sensorConfig[2]), "timer(%d+)")
        if timerId ~= nil then
          lcd.setColor(CUSTOM_COLOR,0xFFFF)
          -- lua timers are zero based
          if tonumber(timerId) > 0 then
            timerId = tonumber(timerId) -1
          end
          -- default font size
          flags = sensorConfig[7] == 1 and 0 or MIDSIZE
          local voffset = flags==0 and 6 or 0
          lcd.drawTimer(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, model.getTimer(timerId).value, flags+CUSTOM_COLOR+RIGHT)
        else
          mult =  sensorConfig[3] == 0 and 1 or ( sensorConfig[3] == 1 and 10 or 100 )
          prec =  mult == 1 and 0 or (mult == 10 and 32 or 48)
          
          local sensorName = sensorConfig[2]..(status.showMinMaxValues == true and sensorConfig[6] or "")
          local sensorValue = getValue(sensorName) 
          local value = (sensorValue+(mult == 100 and 0.005 or 0))*mult*sensorConfig[5]        
          
          -- default font size
          flags = sensorConfig[7] == 1 and 0 or MIDSIZE
          
          -- for sensor 3,4,5,6 reduce font if necessary
          if math.abs(value)*mult > 99999 then
            flags = 0
          end
          
          local color = 0xFFFF
          local sign = sensorConfig[6] == "+" and 1 or -1
          -- max tracking, high values are critical
          if math.abs(value) ~= 0 and status.showMinMaxValues == false then
            color = ( sensorValue*sign > sensorConfig[9]*sign and lcd.RGB(255,70,0) or (sensorValue*sign > sensorConfig[8]*sign and 0xFE60 or 0xFFFF))
          end
          
          lcd.setColor(CUSTOM_COLOR,color)
          
          local voffset = flags==0 and 6 or 0
          -- if a lookup table exists use it!
          if customSensors.lookups[i] ~= nil and customSensors.lookups[i][value] ~= nil then
            lcd.drawText(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, customSensors.lookups[i][value] or value, flags+RIGHT+CUSTOM_COLOR)
          else
            lcd.drawNumber(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, value, flags+RIGHT+prec+CUSTOM_COLOR)
          end
        end
      end
    end
end

local initDone = false

local function init(utils,level)
  if level ~= lastZoomLevel then
    utils.clearTable(tiles)
    
    utils.clearTable(mapBitmapByPath)
    
    utils.clearTable(posHistory)
    sample = 0
    sampleCount = 0    
    
    world_tiles = tiles_on_level(level)
    tiles_per_radian = world_tiles / (2 * math.pi)
    tile_dim = (40075017/world_tiles) * unitScale -- m or ft
  
    scaleLen = ((unitScale==1 and 1 or 3)*50*(level+3)/tile_dim)*100
    scaleLabel = tostring((unitScale==1 and 1 or 3)*50*(level+3))..unitLabel
    
    lastZoomLevel = level
  end
end

local function changeZoomLevel(level)
end

local function draw(myWidget,drawLib,conf,telemetry,status,battery,alarms,frame,utils,customSensors,gpsStatuses,leftPanel,centerPanel,rightPanel)
  -- initialize maps
  init(utils,status.mapZoomLevel)
  drawMap(myWidget,drawLib,conf,telemetry,status,utils,status.mapZoomLevel)
  --drawHud(myWidget,drawLib,conf,telemetry,status,battery,utils)
  utils.drawTopBar()
  -- bottom bar
  lcd.setColor(CUSTOM_COLOR,0x0000)
  lcd.drawFilledRectangle(0,200+18,480,LCD_H-(200+18),CUSTOM_COLOR)
  -- gps status, draw coordinatyes if good at least once
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
  if telemetry.lon ~= nil and telemetry.lat ~= nil then
    lcd.drawText(280,200+18-21,utils.decToDMSFull(telemetry.lat),SMLSIZE+CUSTOM_COLOR+RIGHT)
    lcd.drawText(380,200+18-21,utils.decToDMSFull(telemetry.lon,telemetry.lat),SMLSIZE+CUSTOM_COLOR+RIGHT)
  end
  -- custom sensors
  if customSensors ~= nil then
    drawCustomSensors(0,customSensors,utils,status)
  end
end

local function background(myWidget,conf,telemetry,status,utils)
end

return {draw=draw,background=background,changeZoomLevel=changeZoomLevel}

