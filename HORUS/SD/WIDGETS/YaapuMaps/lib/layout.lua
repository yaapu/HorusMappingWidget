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

local function draw(widget,mapLib,drawLib,conf,telemetry,status,battery,alarms,frame,utils,customSensors,gpsStatuses,leftPanel,centerPanel,rightPanel)
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
  mapLib.drawMap(widget,0,18,cols,rows,w,h,drawLib,conf,telemetry,status,utils,status.mapZoomLevel)

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

