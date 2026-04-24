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

local drawLib = {}

local status
local telemetry
local conf
local utils
local libs

-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()

local drawLine = nil

if string.find(radio, "x10") and tonumber(maj..minor..rev) < 222 then
  drawLib.drawLine = function(x1,y1,x2,y2,flags1,flags2) lcd.drawLine(LCD_W-x1,LCD_H-y1,LCD_W-x2,LCD_H-y2,flags1,flags2) end
else
  drawLib.drawLine = function(x1,y1,x2,y2,flags1,flags2) lcd.drawLine(x1,y1,x2,y2,flags1,flags2) end
end

function drawLib.drawHomeIcon(x,y)
  lcd.drawBitmap(utils.getBitmap("minihomeorange"),x,y)
end

function drawLib.computeOutCode(x,y,xmin,ymin,xmax,ymax)
    local code = 0; --initialised as being inside of hud
    --
    if x < xmin then --to the left of hud
        code = bit32.bor(code,1);
    elseif x > xmax then --to the right of hud
        code = bit32.bor(code,2);
    end
    if y < ymin then --below the hud
        code = bit32.bor(code,8);
    elseif y > ymax then --above the hud
        code = bit32.bor(code,4);
    end
    return code;
end

local function etxDrawLineWithClipping(x1,y1,x2,y2,style,xmin,xmax,ymin,ymax,color)
  lcd.drawLineWithClipping(x1,y1,x2,y2,xmin,xmax,ymin,ymax,style,color)
end

local function otxDrawLineWithClipping(x1,y1,x2,y2,style,xmin,xmax,ymin,ymax,color)
  local x= {}
  local y = {}
  if not(x1 < xmin and x2 < xmin) and not(x1 > xmax and x2 > xmax) then
    if not(y1 < ymin and y2 < ymin) and not(y1 > ymax and y2 > ymax) then
      x[1]=x1
      y[1]=y1
      x[2]=x2
      y[2]=y2
      for i=1,2
      do
        if x[i] < xmin then
          x[i] = xmin
          y[i] = ((y2-y1)/(x2-x1))*(xmin-x1)+y1
        elseif x[i] > xmax then
          x[i] = xmax
          y[i] = ((y2-y1)/(x2-x1))*(xmax-x1)+y1
        end

        if y[i] < ymin then
          y[i] = ymin
          x[i] = ((x2-x1)/(y2-y1))*(ymin-y1)+x1
        elseif y[i] > ymax then
          y[i] = ymax
          x[i] = ((x2-x1)/(y2-y1))*(ymax-y1)+x1
        end
      end
      if not(x[1] < xmin and x[2] < xmin) and not(x[1] > xmax and x[2] > xmax) then
        drawLib.drawLine(x[1],y[1],x[2],y[2], style, color)
      end
    end
  end
end

if lcd.drawLineWithClipping == nil then
  drawLib.drawLineWithClippingXY = otxDrawLineWithClipping
else
  drawLib.drawLineWithClippingXY = etxDrawLineWithClipping
end

function drawLib.drawLineWithClipping(ox,oy,angle,len,style,xmin,xmax,ymin,ymax,color,radio,rev)
  local xx = math.cos(math.rad(angle)) * len * 0.5
  local yy = math.sin(math.rad(angle)) * len * 0.5

  local x0 = ox - xx
  local x1 = ox + xx
  local y0 = oy - yy
  local y1 = oy + yy

  drawLib.drawLineWithClippingXY(x0,y0,x1,y1,style,xmin,xmax,ymin,ymax,color,radio,rev)
end

function drawLib.drawRArrow(x,y,r,angle,color)
  local ang = math.rad(angle - 90)
  local x1 = x + r * math.cos(ang)
  local y1 = y + r * math.sin(ang)

  ang = math.rad(angle - 90 + 150)
  local x2 = x + r * math.cos(ang)
  local y2 = y + r * math.sin(ang)

  ang = math.rad(angle - 90 - 150)
  local x3 = x + r * math.cos(ang)
  local y3 = y + r * math.sin(ang)
  ang = math.rad(angle - 270)
  local x4 = x + r * 0.5 * math.cos(ang)
  local y4 = y + r * 0.5 *math.sin(ang)

  drawLib.drawLine(x1,y1,x2,y2,SOLID,color)
  drawLib.drawLine(x1,y1,x3,y3,SOLID,color)
  drawLib.drawLine(x2,y2,x4,y4,SOLID,color)
  drawLib.drawLine(x3,y3,x4,y4,SOLID,color)
end

function drawLib.drawNoTelemetryData(telemetryEnabled)
  if (not telemetryEnabled()) then
    lcd.setColor(CUSTOM_COLOR,utils.colors.white)
    lcd.drawFilledRectangle(20,185, 280, 110, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,utils.colors.red)
    lcd.drawFilledRectangle(20+2,185+2, 280-4, 110-4, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,utils.colors.white)
    lcd.drawText(math.floor(LCD_W/2), 185+25, "no telemetry data", DBLSIZE+CUSTOM_COLOR+CENTER)
    lcd.drawText(math.floor(LCD_W/2), 185+80, "Yaapu Mapping Widget 2.2.0 dev".."( "..'2ffdaf8'..")", SMLSIZE+CUSTOM_COLOR+CENTER)
  end
end

function drawLib.drawNoGPSData()
  if telemetry.lat == nil or telemetry.lon == nil then
    lcd.setColor(CUSTOM_COLOR,utils.colors.white)
    lcd.drawFilledRectangle(20,185, 280, 110, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,utils.colors.red)
    lcd.drawFilledRectangle(20+2,185+2, 280-4, 110-4, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,utils.colors.white)
    lcd.drawText(math.floor(LCD_W/2), 185+25, "...waiting for GPS", DBLSIZE+CUSTOM_COLOR+CENTER)
    lcd.drawText(math.floor(LCD_W/2), 185+80, "Yaapu Mapping Widget 2.2.0 dev".."( "..'2ffdaf8'..")", SMLSIZE+CUSTOM_COLOR+CENTER)
    return true
  end
  return false
end

function drawLib.drawFilledRectangle(x,y,w,h,flags)
    if w > 0 and h > 0 then
      lcd.drawFilledRectangle(x,y,w,h,flags)
    end
end
local RAD_CONST = math.pi / 180

function drawLib.drawLineByOriginAndAngle(ox, oy, angle, len, style, xmin, xmax, ymin, ymax, color, drawDiameter)
    local cos = math.cos
    local sin = math.sin
    
    local halfLen = len * 0.5
    local angleRad = angle * RAD_CONST
    
    local xx = cos(angleRad) * halfLen
    local yy = sin(angleRad) * halfLen

    local x1 = ox + xx
    local y1 = oy + yy

    if drawDiameter == false then
        drawLib.drawLineWithClippingXY(ox, oy, x1, y1, style, xmin, xmax, ymin, ymax, color)
    else
        local x0 = ox - xx
        local y0 = oy - yy
        drawLib.drawLineWithClippingXY(x0, y0, x1, y1, style, xmin, xmax, ymin, ymax, color)
    end
end

function drawLib.drawArtificialHorizon(x, y, w, h, bgBitmapName, colorSky, colorTerrain, lineCount, lineOffset, scale)
  local r = -telemetry.roll
  local cx,cy,dx,dy
  --local scale = 1.85 -- 1.85
  -- no roll ==> segments are vertical, offsets are multiples of R2
  if telemetry.roll == 0 or math.abs(telemetry.roll) == 180 then
    dx=0
    dy=telemetry.pitch * scale
    cx=0
    cy=lineOffset
  else
    -- center line offsets
    dx = math.cos(math.rad(90 - r)) * -telemetry.pitch
    dy = math.sin(math.rad(90 - r)) * telemetry.pitch * scale
    -- 1st line offsets
    cx = math.cos(math.rad(90 - r)) * lineOffset
    cy = math.sin(math.rad(90 - r)) * lineOffset
  end

  local rollX = math.floor(x+w/2) -- math.floor(HUD_X + HUD_WIDTH/2)

  local minY = y
  local maxY = y + h

  local minX = x
  local maxX = x + w

  local ox = x + w/2 + dx
  local oy = y + h/2 + dy
  local yy = 0

  if bgBitmapName == nil then
    lcd.setColor(CUSTOM_COLOR,colorSky)
    lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)
  else
    lcd.drawBitmap(utils.getBitmap(bgBitmapName),x, y)
  end

  -- HUD drawn using horizontal bars of height 2
  lcd.setColor(CUSTOM_COLOR,colorTerrain)
  lcd.drawHudRectangle(telemetry.pitch, telemetry.roll+0.001, minX, maxX, minY, maxY, CUSTOM_COLOR)

  -- parallel lines above and below horizon
  lcd.setColor(CUSTOM_COLOR, WHITE)
  -- +/- 90 deg
  for dist=1,lineCount
  do
    drawLib.drawLineByOriginAndAngle(rollX + dx - dist*cx, oy + dist*cy, r, (dist%2==0 and 80 or 40), DOTTED, minX+2, maxX-2, minY+2, maxY-2, CUSTOM_COLOR)
    drawLib.drawLineByOriginAndAngle(rollX + dx + dist*cx, oy - dist*cy, r, (dist%2==0 and 80 or 40), DOTTED, minX+2, maxX-2, minY+2, maxY-2, CUSTOM_COLOR)
  end

  --[[
  -- horizon line
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(160,160,160))
  libs.drawLib.drawLineByOriginAndAngle(rollX + dx, oy, r, 200, SOLID, minX+2, maxX-2, minY+2, maxY-2, CUSTOM_COLOR)
  --]]
end

function drawLib.init(param_status, param_telemetry, param_conf, param_utils, param_libs)
  status = param_status
  telemetry = param_telemetry
  conf = param_conf
  utils = param_utils
  libs = param_libs
end


return drawLib
