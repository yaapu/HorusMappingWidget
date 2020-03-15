#include "includes/yaapu_inc.lua"

-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()

#ifdef X10_OPENTX_221
local drawLine = nil

if string.find(radio, "x10") and tonumber(maj..minor..rev) < 222 then
  drawLine = function(x1,y1,x2,y2,flags1,flags2) lcd.drawLine(LCD_W-x1,LCD_H-y1,LCD_W-x2,LCD_H-y2,flags1,flags2) end
else
  drawLine = function(x1,y1,x2,y2,flags1,flags2) lcd.drawLine(x1,y1,x2,y2,flags1,flags2) end
end
#endif --X10_OPENTX_221

local function drawHomeIcon(x,y,utils)
  lcd.drawBitmap(utils.getBitmap("minihomeorange"),x,y)
end

local function computeOutCode(x,y,xmin,ymin,xmax,ymax)
    local code = CS_INSIDE; --initialised as being inside of hud
    --
    if x < xmin then --to the left of hud
        code = bit32.bor(code,CS_LEFT);
    elseif x > xmax then --to the right of hud
        code = bit32.bor(code,CS_RIGHT);
    end
    if y < ymin then --below the hud
        code = bit32.bor(code,CS_TOP);
    elseif y > ymax then --above the hud
        code = bit32.bor(code,CS_BOTTOM);
    end
    --
    return code;
end

-- Cohen–Sutherland clipping algorithm
-- https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
local function drawLineWithClippingXY(x0,y0,x1,y1,style,xmin,xmax,ymin,ymax,color,radio,rev)
  -- compute outcodes for P0, P1, and whatever point lies outside the clip rectangle
  local outcode0 = computeOutCode(x0, y0, xmin, ymin, xmax, ymax);
  local outcode1 = computeOutCode(x1, y1, xmin, ymin, xmax, ymax);
  local accept = false;

  while (true) do
    if ( bit32.bor(outcode0,outcode1) == CS_INSIDE) then
      -- bitwise OR is 0: both points inside window; trivially accept and exit loop
      accept = true;
      break;
    elseif (bit32.band(outcode0,outcode1) ~= CS_INSIDE) then
      -- bitwise AND is not 0: both points share an outside zone (LEFT, RIGHT, TOP, BOTTOM)
      -- both must be outside window; exit loop (accept is false)
      break;
    else
      -- failed both tests, so calculate the line segment to clip
      -- from an outside point to an intersection with clip edge
      local x = 0
      local y = 0
      -- At least one endpoint is outside the clip rectangle; pick it.
      local outcodeOut = outcode0 ~= CS_INSIDE and outcode0 or outcode1
      -- No need to worry about divide-by-zero because, in each case, the
      -- outcode bit being tested guarantees the denominator is non-zero
      if bit32.band(outcodeOut,CS_BOTTOM) ~= CS_INSIDE then --point is above the clip window
        x = x0 + (x1 - x0) * (ymax - y0) / (y1 - y0)
        y = ymax
      elseif bit32.band(outcodeOut,CS_TOP) ~= CS_INSIDE then --point is below the clip window
        x = x0 + (x1 - x0) * (ymin - y0) / (y1 - y0)
        y = ymin
      elseif bit32.band(outcodeOut,CS_RIGHT) ~= CS_INSIDE then --point is to the right of clip window
        y = y0 + (y1 - y0) * (xmax - x0) / (x1 - x0)
        x = xmax
      elseif bit32.band(outcodeOut,CS_LEFT) ~= CS_INSIDE then --point is to the left of clip window
        y = y0 + (y1 - y0) * (xmin - x0) / (x1 - x0)
        x = xmin
      end
      -- Now we move outside point to intersection point to clip
      -- and get ready for next pass.
      if outcodeOut == outcode0 then
        x0 = x
        y0 = y
        outcode0 = computeOutCode(x0, y0, xmin, ymin, xmax, ymax)
      else
        x1 = x
        y1 = y
        outcode1 = computeOutCode(x1, y1, xmin, ymin, xmax, ymax)
      end
    end
  end
  if accept then
#ifdef X10_OPENTX_221
    drawLine(x0,y0,x1,y1, style,color)
#else
    lcd.drawLine(x0,y0,x1,y1, style,color)
#endif
  end
end

local function drawLineWithClipping(ox,oy,angle,len,style,xmin,xmax,ymin,ymax,color,radio,rev)
  local xx = math.cos(math.rad(angle)) * len * 0.5
  local yy = math.sin(math.rad(angle)) * len * 0.5
  
  local x0 = ox - xx
  local x1 = ox + xx
  local y0 = oy - yy
  local y1 = oy + yy    
  
  drawLineWithClippingXY(x0,y0,x1,y1,style,xmin,xmax,ymin,ymax,color,radio,rev)
end

local function drawRArrow(x,y,r,angle,color)
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
  --
#ifdef X10_OPENTX_221
  drawLine(x1,y1,x2,y2,SOLID,color)
  drawLine(x1,y1,x3,y3,SOLID,color)
  drawLine(x2,y2,x4,y4,SOLID,color)
  drawLine(x3,y3,x4,y4,SOLID,color)
#else
  lcd.drawLine(x1,y1,x2,y2,SOLID,color)
  lcd.drawLine(x1,y1,x3,y3,SOLID,color)
  lcd.drawLine(x2,y2,x4,y4,SOLID,color)
  lcd.drawLine(x3,y3,x4,y4,SOLID,color)
#endif
end

local function drawNoTelemetryData(status,telemetry,utils,telemetryEnabled)
  -- no telemetry data
  if (not telemetryEnabled()) then
    lcd.setColor(CUSTOM_COLOR,COLOR_WHITE)
    lcd.drawFilledRectangle(88,74, 304, 84, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,COLOR_NOTELEM)
    lcd.drawFilledRectangle(90,76, 300, 80, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,COLOR_TEXT)
    lcd.drawText(110, 85, "no telemetry data", DBLSIZE+CUSTOM_COLOR)
    lcd.drawText(130, 120, VERSION, SMLSIZE+CUSTOM_COLOR)
  end
end

local function drawFilledRectangle(x,y,w,h,flags)
    if w > 0 and h > 0 then
      lcd.drawFilledRectangle(x,y,w,h,flags)
    end
end

return {
  drawHomeIcon=drawHomeIcon,
  drawRArrow=drawRArrow,
  computeOutCode=computeOutCode,
  drawLineWithClippingXY=drawLineWithClippingXY,
  drawLineWithClipping=drawLineWithClipping,
  drawNoTelemetryData=drawNoTelemetryData,
  drawFilledRectangle=drawFilledRectangle,
}
