--
-- An EdgeTx/OpenTX offline mapping widget
--
-- Copyright (C) 2018-2026. Alessandro Apostoli
-- https://github.com/yaapu
--
local unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
local unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
local unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
local unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"

local layout = {}

local status
local telemetry
local conf
local utils
local libs

local MAP_X = 0
local MAP_Y = 20
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
local ver, radio, maj, minor, rev = getVersion()

function layout.drawCustomSensors(x,customSensors)
    local label,data,prec,mult,flags,sensorConfig
    local sensorStart = 1
    lcd.setColor(CUSTOM_COLOR,utils.colors.black)
    local sensorEnd = 10
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
        local sensorInfo = getFieldInfo(sensorConfig[2])
        -- check if sensor is a timer
        if sensorConfig[4] == "" or sensorConfig[4] == nil then
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
          -- check for UNIT_TEXT
          mult =  (sensorInfo ~= nil and sensorInfo.unit == UNIT_TEXT) and 1 or (sensorConfig[3] == 0 and 1 or ( sensorConfig[3] == 1 and 10 or 100 ))
          prec =  mult == 1 and 0 or (mult == 10 and 32 or 48)

          local sensorName = sensorConfig[2]..(status.showMinMaxValues == true and sensorConfig[6] or "")
          local sensorValue = getValue(sensorName)
          local value = (sensorInfo ~= nil and sensorInfo.unit == UNIT_TEXT) and sensorValue or ((sensorValue+(mult == 100 and 0.005 or 0))*mult*sensorConfig[5])

          -- default font size
          flags = sensorConfig[7] == 1 and 0 or MIDSIZE

          local color = utils.colors.white
          local sign = (sensorInfo ~= nil and sensorInfo.unit == UNIT_TEXT) and 1 or (sensorConfig[6] == "+" and 1 or -1)
          -- max tracking, high values are critical
          if (sensorInfo ~= nil and sensorInfo.unit ~= UNIT_TEXT) then
            -- for sensor 3,4,5,6 reduce font if necessary
            if math.abs(value)*mult > 99999 then
              flags = 0
            end

            if math.abs(value) ~= 0 and status.showMinMaxValues == false then
              color = ( sensorValue*sign > sensorConfig[9]*sign and lcd.RGB(255,70,0) or (sensorValue*sign > sensorConfig[8]*sign and utils.colors.yellow or utils.colors.white))
            end
          end
          lcd.setColor(CUSTOM_COLOR,color)

          local voffset = flags==0 and 6 or 0
          -- if a lookup table exists use it!
          if customSensors.lookups[i] ~= nil and customSensors.lookups[i][value] ~= nil then
            lcd.drawText(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, customSensors.lookups[i][value] or value, flags+RIGHT+CUSTOM_COLOR)
          else
            if sensorInfo ~= nil and sensorInfo.unit == UNIT_TEXT then
              lcd.drawText(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, value, flags+RIGHT+prec+CUSTOM_COLOR)
            else
              lcd.drawNumber(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, value, flags+RIGHT+prec+CUSTOM_COLOR)
            end
          end
        end
      end
    end
end

local function drawMiniHud(x,y)
  libs.drawLib.drawArtificialHorizon(x, y, 48, 36, nil, lcd.RGB(0x7B, 0x9D, 0xFF), lcd.RGB(0x63, 0x30, 0x00), 6, 6.5, 1.3)
  lcd.drawBitmap(utils.getBitmap("hud_48x48a"), 3-1, 48-10)
end

function layout.draw(widget,battery,alarms,frame,customSensors,gpsStatuses,leftPanel,centerPanel,rightPanel)
  local mapX = MAP_X
  local mapY = MAP_Y
  local cols = 4
  local rows = 3
  local w = 400
  local h = mapY + 200

  if conf.bottombarEnable == false then
    rows = 3
    h = LCD_H
  end

  if conf.sidebarEnable == false then
    cols = 5
    w = LCD_W
  end
  libs.mapLib.drawMap(widget,mapX,mapY,w,h,status.mapZoomLevel,cols,rows)
  utils.drawTopBar(widget)

  if conf.sidebarEnable == true then
    lcd.setColor(CUSTOM_COLOR, utils.colors.darkgrey)
    lcd.drawFilledRectangle(LCD_W-80, 20, 80, LCD_H, CUSTOM_COLOR)
  end

  if conf.bottombarEnable == true then
    lcd.setColor(CUSTOM_COLOR, utils.colors.darkgrey)
    lcd.drawFilledRectangle(0, LCD_H-36, LCD_W, 36, CUSTOM_COLOR)
  end

  -- custom sensors
  if customSensors ~= nil then
    layout.drawCustomSensors(0, customSensors)
  end

end

function layout.background(widget)
end

function layout.init(param_status, param_telemetry, param_conf, param_utils, param_libs)
  status = param_status
  telemetry = param_telemetry
  conf = param_conf
  utils = param_utils
  libs = param_libs
end

return layout

