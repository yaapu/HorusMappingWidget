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

--[[
  for info see https://github.com/heldersepu/GMapCatcher

  Notes:
  - tiles need to be resized down to 100x100 from original size of 256x256
  - at max zoom level (-2) 1 tile = 100px = 76.5m
]]

local customSensorXY = {
  -- horizontal
  { 78, 236, 78, 248},
  { 158, 236, 158, 248},
  { 238, 236, 238, 248},
  { 318, 236, 318, 248},
  { 398, 236, 398, 248},
  { 478, 236, 478, 248},
  -- vertical
  { 476, 25, 476, 37},
  { 476, 75, 476, 87},
  { 476, 125, 476, 137},
  { 476, 175, 476, 187},
}

-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()

-- map support
local posUpdated = false
local myScreenX, myScreenY
local homeScreenX, homeScreenY
local estimatedHomeScreenX, estimatedHomeScreenY
local tile_x,tile_y,offset_x,offset_y
local home_tile_x,home_tile_y,home_offset_x,home_offset_y
local tiles = {}
local tilesXYByPath = {}
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


local coord_to_tiles = nil
local tiles_to_path = nil
local MinLatitude = -85.05112878;
local MaxLatitude = 85.05112878;
local MinLongitude = -180;
local MaxLongitude = 180;


local TILES_X = 4
local TILES_Y = 2



local function clip(n, min, max)
  return math.min(math.max(n, min), max)
end

local function tiles_on_level(conf,level)
  if conf.mapProvider == 1 then
    return bit32.lshift(1,17 - level)
  else
    return 2^level
  end
end

--[[
  total tiles on the web mercator projection = 2^zoom*2^zoom
--]]
local function get_tile_matrix_size_pixel(level)
    local size = 2^level * 100
    return size, size
end

--[[
  https://developers.google.com/maps/documentation/javascript/coordinates
  https://github.com/judero01col/GMap.NET

  Questa funzione ritorna il pixel (assoluto) associato alle coordinate.
  La proiezione di mercatore è una matrice di pixel, tanto più grande quanto è elevato il valore dello zoom.
  zoom 1 = 1x1 tiles
  zoom 2 = 2x2 tiles
  zoom 3 = 4x4 tiles
  ...
  in cui ogni tile è di 256x256 px.
  in generale la matrice ha dimensioni 2^(zoom-1)*2^(zoom-1)
  Per risalire al singolo tile si divide per 256 (largezza del tile):

  tile_x = math.floor(x_coord/256)
  tile_y = math.floor(y_coord/256)

  Le coordinate relative all'interno del tile si calcolano con l'operatore modulo a partire dall'angolo in alto a sx

  x_offset = x_coord%256
  y_offset = y_coord%256

  Su filesystem il percorso è /tile_y/tile_x.png
--]]
local function google_coord_to_tiles(conf, lat, lng, level)
  lat = clip(lat, MinLatitude, MaxLatitude)
  lng = clip(lng, MinLongitude, MaxLongitude)

  local x = (lng + 180) / 360
  local sinLatitude = math.sin(lat * math.pi / 180)
  local y = 0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)

  local mapSizeX, mapSizeY = get_tile_matrix_size_pixel(level)

  -- absolute pixel coordinates on the mercator projection at this zoom level
  local rx = clip(x * mapSizeX + 0.5, 0, mapSizeX - 1)
  local ry = clip(y * mapSizeY + 0.5, 0, mapSizeY - 1)
  -- return tile_x, tile_y, offset_x, offset_y
  return math.floor(rx/100), math.floor(ry/100), math.floor(rx%100), math.floor(ry%100)
end

local function gmapcatcher_coord_to_tiles(conf, lat, lon, level)
  local x = world_tiles / 360 * (lon + 180)
  local e = math.sin(lat * (1/180 * math.pi))
  local y = world_tiles / 2 + 0.5 * math.log((1+e)/(1-e)) * -1 * tiles_per_radian
  return math.floor(x % world_tiles), math.floor(y % world_tiles), math.floor((x - math.floor(x)) * 100), math.floor((y - math.floor(y)) * 100)
end

local function google_tiles_to_path(conf, tile_x, tile_y, level)
  return string.format("/%d/%d/s_%d.jpg", level, tile_y, tile_x)
end

local function gmapcatcher_tiles_to_path(conf, tile_x, tile_y, level)
  return string.format("/%d/%d/%d/%d/s_%d.png", level, tile_x/1024, tile_x%1024, tile_y/1024, tile_y%1024)
end

local function getTileBitmap(conf,tilePath)
  local fullPath = "/IMAGES/yaapu/maps/"..conf.mapType..tilePath
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
      nomap = Bitmap.open("/IMAGES/yaapu/maps/nomap.png")
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
  for x=1,TILES_X
  do
    for y=1,TILES_Y
    do
      local tile_path = tiles_to_path(conf, tile_x+x-2, tile_y+y-yy, level)
      local idx = width*(y-1)+x

      if tiles[idx] == nil then
        tiles[idx] = {tile_path, x, y}
      else
        if tiles[idx][1] ~= tile_path then
          tiles[idx] = nil
          collectgarbage()
          collectgarbage()
          tiles[idx] = {tile_path, x, y}
        end
        -- update this tile position on screen
        tiles[idx][2] = x
        tiles[idx][3] = y
      end
      tilesXYByPath[tile_path] = {x,y}
    end
  end
  -- release unused cached images
  for path, bmp in pairs(mapBitmapByPath) do
    local remove = true
    for i=1,#tiles
    do
      if tiles[i][1] == path then
        remove = false
      end
    end
    if remove then
      mapBitmapByPath[path]=nil
      tilesXYByPath[path] = nil
    end
  end
  -- force a call to destroyBitmap()
  collectgarbage()
  collectgarbage()
end

local function drawTiles(conf,drawLib,utils,telemetry,width,xmin,xmax,ymin,ymax,color,level)
  for x=1,TILES_X
  do
    for y=1,TILES_Y
    do
      local idx = width*(y-1)+x
      if tiles[idx] ~= nil then
        lcd.drawBitmap(getTileBitmap(conf,tiles[idx][1]), xmin+(x-1)*100, ymin+(y-1)*100)
      end
    end
  end
  if conf.enableMapGrid then
    -- draw grid
    for x=1,TILES_X-1
    do
      lcd.drawLine(xmin+x*100,ymin,xmin+x*100,ymax,DOTTED,color)
    end

    for y=1,TILES_Y-1
    do
      lcd.drawLine(xmin,ymin+y*100,xmax,ymin+y*100,DOTTED,color)
    end
  end
  -- map overlay
  if conf.sidebarEnable == true then
    lcd.drawBitmap(utils.getBitmap("maps_box_390x16"),5,ymax-21)
  else
    lcd.drawBitmap(utils.getBitmap("maps_box_476x16"),5,ymax-21)
  end
  -- draw 50m or 150ft line at max zoom
  lcd.setColor(CUSTOM_COLOR,utils.colors.white)
  lcd.drawLine(xmin+7,ymax-8,xmin+5+scaleLen,ymax-8,SOLID,CUSTOM_COLOR)
  lcd.drawText(xmin+7,ymax-24,string.format("%s (%d)",scaleLabel,level),SMLSIZE+CUSTOM_COLOR)
  -- gps status, draw coordinatyes if good at least once
  if telemetry.lon ~= nil and telemetry.lat ~= nil then
    if getRSSI() == 0 then
      lcd.setColor(CUSTOM_COLOR,utils.colors.red)
    else
      lcd.setColor(CUSTOM_COLOR,utils.colors.white)
    end
    lcd.drawText(xmax-10, ymax-24, utils.decToDMSFull(telemetry.lat).." "..utils.decToDMSFull(telemetry.lon,telemetry.lat),CUSTOM_COLOR+RIGHT)
  end
end

local function getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
  -- is this tile on screen ?
  local tile_path = tiles_to_path(conf, tile_x, tile_y, level)
  local onScreen = false

  for x=1,TILES_X
  do
    for y=1,TILES_Y
    do
      local idx = TILES_X*(y-1)+x
      if tiles[idx] ~= nil and tiles[idx][1] == tile_path then
        -- ok it's on screen
        return minX + (x-1)*100 + offset_x, minY + (y-1)*100 + offset_y
      end
    end
  end
  -- force offscreen up
  return LCD_W/2, -10
end

local function drawMap(widget,cols,rows,w,h,drawLib,conf,telemetry,status,utils,level)
  TILES_X=cols
  TILES_Y=rows
  if tiles_to_path == nil or coord_to_tiles == nil then
    return
  end
  local minY = math.max(0, 18)
  local maxY = math.min(LCD_H, math.min(18+h, minY+TILES_Y*100))

  local minX = math.max(0, 0)
  local maxX = math.min(LCD_W, math.min(0+w, minX+TILES_X*100))

  if telemetry.lat ~= nil and telemetry.lon ~= nil then
    -- position update
    if getTime() - lastPosUpdate > 50 then
      posUpdated = true
      lastPosUpdate = getTime()
      -- current vehicle tile coordinates
      tile_x,tile_y,offset_x,offset_y = coord_to_tiles(conf,telemetry.lat,telemetry.lon,level)
      -- viewport relative coordinates
      myScreenX,myScreenY = getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
      -- check if offscreen, and increase border on X axis
      local myCode = drawLib.computeOutCode(myScreenX, myScreenY, minX+25, minY+25, maxX-25, maxY-25);

      -- center vehicle on screen
      if myCode > 0 then
        loadAndCenterTiles(conf, tile_x, tile_y, offset_x, offset_y, TILES_X, level)
        -- after centering screen position needs to be computed again
        tile_x,tile_y,offset_x,offset_y = coord_to_tiles(conf,telemetry.lat,telemetry.lon,level)
        myScreenX,myScreenY = getScreenCoordinates(minX,minY,tile_x,tile_y,offset_x,offset_y,level)
      end
    end
    -- home position update
    if getTime() - lastHomePosUpdate > 25 and posUpdated then
      lastHomePosUpdate = getTime()
      if homeNeedsRefresh then
        -- update home, schedule estimated home update
        homeNeedsRefresh = false
        if telemetry.homeLat ~= nil then
          -- current vehicle tile coordinates
          home_tile_x,home_tile_y,home_offset_x,home_offset_y = coord_to_tiles(conf,telemetry.homeLat,telemetry.homeLon,level)
          -- viewport relative coordinates
          homeScreenX,homeScreenY = getScreenCoordinates(minX,minY,home_tile_x,home_tile_y,home_offset_x,home_offset_y,level)
        end
      else
        -- update estimated home, schedule home update
        homeNeedsRefresh = true
      end
      collectgarbage()
      collectgarbage()
    end
    
    -- position history sampling
    if getTime() - lastPosSample > 25 and posUpdated then
        lastPosSample = getTime()
        posUpdated = false
        -- points history
        local path = tiles_to_path(conf, tile_x, tile_y, level)
        posHistory[sample] = { path, offset_x, offset_y }
        collectgarbage()
        collectgarbage()
        sampleCount = sampleCount+1
        sample = sampleCount%conf.mapTrailDots
    end

    -- draw map tiles
    lcd.setColor(CUSTOM_COLOR,utils.colors.yellow)
    drawTiles(conf,drawLib,utils,telemetry,TILES_X,minX,maxX,minY,maxY,CUSTOM_COLOR,level)

    -- draw home
    if telemetry.homeLat ~= nil and telemetry.homeLon ~= nil and homeScreenX ~= nil then
      local homeCode = drawLib.computeOutCode(homeScreenX, homeScreenY, minX+11, minY+10, maxX-11, maxY-10);
      if homeCode == 0 then
        lcd.drawBitmap(utils.getBitmap("homeorange"),homeScreenX-11,homeScreenY-10)
      end
    end

    -- draw vehicle
    if myScreenX ~= nil then
      lcd.setColor(CUSTOM_COLOR,utils.colors.white)
      drawLib.drawRArrow(myScreenX,myScreenY,22-5,telemetry.yaw,CUSTOM_COLOR)
      lcd.setColor(CUSTOM_COLOR,utils.colors.black)
      drawLib.drawRArrow(myScreenX,myScreenY,22,telemetry.yaw,CUSTOM_COLOR)
    end
    
    -- draw gps trace
    lcd.setColor(CUSTOM_COLOR,utils.colors.yellow)
    for p=0, math.min(sampleCount-1,conf.mapTrailDots-1)
    do
      if p ~= (sampleCount-1)%conf.mapTrailDots then
        -- check if on screen
        if tilesXYByPath[posHistory[p][1]] ~= nil then
          local x = tilesXYByPath[posHistory[p][1]][1]
          local y = tilesXYByPath[posHistory[p][1]][2]
          lcd.drawFilledRectangle(minX + (x-1)*100 + posHistory[p][2]-1, minY + (y-1)*100 + posHistory[p][3]-1,3,3,CUSTOM_COLOR)
        end
      end
    end
  end

  --[[
  UNIT_ALT_SCALE unitScale
  UNIT_DIST_SCALE unitScale
  UNIT_DIST_LONG_SCALE unitLongScale
  UNIT_ALT_LABEL unitLabel
  UNIT_DIST_LABEL unitLabel
  UNIT_DIST_LONG_LABEL unitLongLabel
  UNIT_HSPEED_SCALE conf.horSpeedMultiplier
  UNIT_VSPEED_SCALE conf.vertSpeedMultiplier
  UNIT_HSPEED_LABEL conf.horSpeedLabel
  UNIT_VSPEED_LABEL conf.vertSpeedLabel
  --]]
  if telemetry.lat ~= nil and telemetry.lon ~= nil then
    if conf.sidebarEnable == true then
      lcd.drawBitmap(utils.getBitmap("maps_box_390x16"), 2, minY+7)
    else
      lcd.drawBitmap(utils.getBitmap("maps_box_476x16"), 2, minY+7)
    end

    lcd.setColor(CUSTOM_COLOR,lcd.RGB(170, 170, 170))
    lcd.drawText(minX+5,minY+8,"hdg",SMLSIZE+CUSTOM_COLOR)
    lcd.drawText(minX+74,minY+8,"gspd",SMLSIZE+CUSTOM_COLOR)
    lcd.drawText(minX+186,minY+8,"home",SMLSIZE+CUSTOM_COLOR)
    lcd.drawText(maxX-120,minY+8,"travel",SMLSIZE+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,utils.colors.white)
    lcd.drawText(minX+33,minY+5,string.format("%d%s",telemetry.yaw,utils.degSymbol),CUSTOM_COLOR)
    lcd.drawText(minX+109,minY+5,status.avgSpeed.value*conf.horSpeedMultiplier >=10 and string.format("%.0f%s",status.avgSpeed.value*conf.horSpeedMultiplier, conf.horSpeedLabel) or string.format("%.01f%s",status.avgSpeed.value*conf.horSpeedMultiplier, conf.horSpeedLabel) ,CUSTOM_COLOR)
    lcd.drawText(minX+224,minY+5,string.format("%.0f%s",telemetry.homeDist*unitScale, unitLabel),CUSTOM_COLOR)
    lcd.drawText(maxX-75,minY+5,string.format("%.01f%s",status.avgSpeed.travelDist*unitLongScale, unitLongLabel),CUSTOM_COLOR)
    -- home
    lcd.setColor(CUSTOM_COLOR,utils.colors.yellow)
    drawLib.drawRArrow(maxX-35,maxY-60,23,math.floor(telemetry.homeAngle - telemetry.yaw),CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,utils.colors.black)
    drawLib.drawRArrow(maxX-35,maxY-60,28,math.floor(telemetry.homeAngle - telemetry.yaw),CUSTOM_COLOR)
  end

end

local function drawCustomSensors(x,customSensors,utils,status,conf)
    local label,data,prec,mult,flags,sensorConfig
    local sensorStart = 1
    local sensorEnd = 10

    lcd.setColor(CUSTOM_COLOR,utils.colors.black)
    if conf.sidebarEnable == false then
      sensorEnd = 6
    end
    if conf.bottombarEnable == false then
      sensorStart = 6
    end
    if sensorStart == sensorEnd then
      return
    end
    for i=sensorStart,sensorEnd
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
        lcd.setColor(CUSTOM_COLOR,utils.colors.lightgrey)
        lcd.drawText(x+customSensorXY[i][1], customSensorXY[i][2],label, SMLSIZE+RIGHT+CUSTOM_COLOR)

        local timerId = string.match(string.lower(sensorConfig[2]), "timer(%d+)")
        if timerId ~= nil then
          lcd.setColor(CUSTOM_COLOR,utils.colors.white)
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

          local color = utils.colors.white
          local sign = sensorConfig[6] == "+" and 1 or -1
          -- max tracking, high values are critical
          if math.abs(value) ~= 0 and status.showMinMaxValues == false then
            color = ( sensorValue*sign > sensorConfig[9]*sign and lcd.RGB(255,70,0) or (sensorValue*sign > sensorConfig[8]*sign and utils.colors.yellow or utils.colors.white))
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

local function init(conf,utils,level)
  if level == nil then
    return
  end

  if level ~= lastZoomLevel then
    utils.clearTable(tiles)

    utils.clearTable(mapBitmapByPath)

    utils.clearTable(posHistory)
    sample = 0
    sampleCount = 0

    world_tiles = tiles_on_level(conf, level)
    tiles_per_radian = world_tiles / (2 * math.pi)

    if conf.mapProvider == 1 then
      coord_to_tiles = gmapcatcher_coord_to_tiles
      tiles_to_path = gmapcatcher_tiles_to_path
      tile_dim = (40075017/world_tiles) * unitScale -- m or ft
      scaleLabel = tostring((unitScale==1 and 1 or 3)*50*2^(level+2))..unitLabel
      scaleLen = ((unitScale==1 and 1 or 3)*50*2^(level+2)/tile_dim)*100
    elseif conf.mapProvider == 2 then
      coord_to_tiles = google_coord_to_tiles
      tiles_to_path = google_tiles_to_path
      tile_dim = (40075017/world_tiles) * unitScale -- m or ft
      scaleLabel = tostring((unitScale==1 and 1 or 3)*50*2^(20-level))..unitLabel
      scaleLen = ((unitScale==1 and 1 or 3)*50*2^(20-level)/tile_dim)*100
    end
    lastZoomLevel = level
  end
end

local function draw(widget,drawLib,conf,telemetry,status,battery,alarms,frame,utils,customSensors,gpsStatuses,leftPanel,centerPanel,rightPanel)
  local rows = 3
  local cols = 4
  local w = 400
  local h = 18 + 200

  if conf.bottombarEnable == false then
    rows = 3
    coordsY = LCD_H-21
    h = LCD_H
  end

  if conf.sidebarEnable == false then
    cols = 5
    coordsX = 365
    w = LCD_W
  end
  -- initialize maps
  init(conf, utils, status.mapZoomLevel)

  drawMap(widget,cols,rows,w,h,drawLib,conf,telemetry,status,utils,status.mapZoomLevel)

  utils.drawTopBar(widget)

  if conf.bottombarEnable == true then
    lcd.setColor(CUSTOM_COLOR, utils.colors.darkgrey)
    lcd.drawFilledRectangle(0, LCD_H-36, LCD_W, 36, CUSTOM_COLOR)
  end

  -- custom sensors
  if customSensors ~= nil then
    drawCustomSensors(0,customSensors,utils,status,conf)
  end
end

local function background(widget,conf,telemetry,status,utils)
end

return {draw=draw,background=background}

