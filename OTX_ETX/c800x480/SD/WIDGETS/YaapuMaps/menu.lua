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


--[[

0 - menu option to select a numeric value
{description, type,name,default value,min,max,uit of measure,precision,increment step, <master name>, <master value>}
example {"batt alert level 1:", 0, "V1", 375, 0,5000,"V",PREC2,5,"L2",350 },

1 - menu option to select a value from a list
{description, type, name, default, label list, value list, <master name>, <master value>}
example {"center pane layout:", 1, "CPANE", 1, { "hud","radar" }, { 1, 2 },"CPANE",1 },

--]]
local menuItems = {
  {"GPS source:", 1, "GPS", 1, { "Auto" }, { 1 } },
  {"Heading source:", 1, "HDGT", 3, { "Hdg", "Yaw", "Auto" }, { "Hdg", "Yaw", "None" } },
  {"Heading source unit:", 1, "HDGU", 1, { "deg", "rad" }, { 1, 57.29578 } }, -- radians to degrees rad * (180/pi)
  {"enable right panel:", 1, "SBE", 2, { "yes", "no" }, { true, false } },
  {"enable bottom panel:", 1, "BBE", 2, { "yes", "no" }, { true, false } },
  {"home reset channel:", 0, "HRST", 0, 0, 32,nil,0,1 },
  {"telemetry config file:", 1, "SEN", 1, { "per model", "global profile 1", "global profile 2", "global profile 3" }, { 0, 1, 2, 3 } },
  {"air/groundspeed unit:", 1, "HSPD", 1, { "m/s", "km/h", "mph", "kn" }, { 1, 3.6, 2.23694, 1.94384} },
  {"map provider:", 1, "MAPP", 1, { "GMapCatcher", "Google", "QGIS" }, { 1, 2, 3 } },
  {"map type:", 1, "MAPT", 1, { "", "", "", "", "" }, { "", "", "", "", "" } },
  {"map grid lines:", 1, "MAPG", 1, { "yes", "no" }, { true, false } },
  {"map trail dots:", 0, "MAPTD", 10, 5, 50,nil,0,1 },
  {"emulated wheel channel:", 0, "ZTC", 0, 0, 32,nil,0,1 },
  {"emulated wheel delay(secs):", 0, "ZDMS", 1, 0, 50,"sec",PREC1, 1 },
  {"map zoom level def value:", 0, "MAPZ", -2, -2, 17,nil,0,1 },
  {"map zoom level min value:", 0, "MAPmZ", -2, -2, 17,nil,0,1 },
  {"map zoom level max value:", 0, "MAPMZ", 17, -2, 17,nil,0,1 },
}

local menu  = {
  selectedItem = 1,
  editSelected = false,
  offset = 0,
  updated = true, -- if true menu needs a call to updateMenuItems()
  wrapOffset = 0, -- changes according to enabled/disabled features and panels
}

local basePath = "/WIDGETS/YaapuMaps/"
local libBasePath = basePath.."lib/"

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
    value, name, idx = getMenuItemByName(menuItems,"MAPP")

    if value == nil then
      return
    end

    local value2, name2, idx2 = getMenuItemByName(menuItems,"MAPT")


    if value2 ~= nil then
      if value == 1 then --GMapCatcher
        menuItems[idx2][5] = { "satellite", "map", "terrain" }
        menuItems[idx2][6] = { "sat_tiles", "tiles", "ter_tiles" }
      elseif value == 2 then -- Google
        menuItems[idx2][5] = { "GoogleSatelliteMap", "GoogleHybridMap", "GoogleMap", "GoogleTerrainMap" }
        menuItems[idx2][6] = { "GoogleSatelliteMap", "GoogleHybridMap", "GoogleMap", "GoogleTerrainMap" }
      elseif value == 3 then -- QGIS
        menuItems[idx2][5] = { "default", "layer1", "layer2", "layer3" }
        menuItems[idx2][6] = { "qgis_default", "qgis_layer1", "qgis_layer2", "qgis_layer3" }
      end

      if menuItems[idx2][4] > #menuItems[idx2][5] then
        menuItems[idx2][4] = 1
      end
    end

    value2, name2, idx2 = getMenuItemByName(menuItems,"MAPmZ")
    local idxzmin = idx2
    if value2 ~= nil then
      if value == 1 then        -- GMapCatcher
        menuItems[idx2][5] = -2
        menuItems[idx2][6] = 17
        menuItems[idx2][4] = math.max(value2,-2)
      elseif value == 2 then    -- Google
        menuItems[idx2][5] = 1
        menuItems[idx2][6] = 20
        menuItems[idx2][4] = math.max(value2,1)
      else                      -- QGIS
        menuItems[idx2][5] = 1
        menuItems[idx2][6] = 25
        menuItems[idx2][4] = math.max(value2,1)
      end
    end

    value2, name2, idx2 = getMenuItemByName(menuItems,"MAPMZ")
    local idxzmax = idx2
    if value2 ~= nil then
      if value == 1 then        -- GMapCatcher
        menuItems[idx2][5] = -2
        menuItems[idx2][6] = 17
        menuItems[idx2][4] = math.min(value2,17)
      elseif value == 2 then    -- Google
        menuItems[idx2][5] = 1
        menuItems[idx2][6] = 20
        menuItems[idx2][4] = math.min(value2,20)
      else                      -- QGIS
        menuItems[idx2][5] = 1
        menuItems[idx2][6] = 25
        menuItems[idx2][4] = math.min(value2,25)
      end
    end

    value2, name2, idx2 = getMenuItemByName(menuItems,"MAPZ")

    if value2 ~= nil then
      menuItems[idx2][5] = menuItems[idxzmin][4]
      menuItems[idx2][6] = menuItems[idxzmax][4]
      menuItems[idx2][4] = math.min(math.max(value2,menuItems[idxzmin][4]),menuItems[idxzmax][4])
    end

    menu.updated = false
  end
end

local function getConfigFilename()
  local info = model.getInfo()
  return "/WIDGETS/YaapuMaps/cfg/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "").."_maps.cfg")
end

local function getConfigTriggerFilename()
  local info = model.getInfo()
  return "/WIDGETS/YaapuMaps/cfg/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "").."_maps.reload")
end

local function applyConfigValues(conf)
  if menu.updated == true then
    updateMenuItems()
    menu.updated = false
  end

  conf.mapType = getMenuItemByName(menuItems,"MAPT")
  conf.mapTrailDots = getMenuItemByName(menuItems,"MAPTD")

  conf.mapZoomLevel = getMenuItemByName(menuItems,"MAPZ")
  conf.mapZoomMin = getMenuItemByName(menuItems,"MAPmZ")
  conf.mapZoomMax = getMenuItemByName(menuItems,"MAPMZ")

  local chInfo = getFieldInfo("ch"..getMenuItemByName(menuItems,"ZTC"))
  conf.mapWheelChannelId = (chInfo == nil and -1 or chInfo['id'])

  chInfo = getFieldInfo("ch"..getMenuItemByName(menuItems,"HRST"))
  conf.homeResetChannelId = (chInfo == nil and -1 or chInfo['id'])

  conf.mapWheelChannelDelay = getMenuItemByName(menuItems,"ZDMS")

  conf.enableMapGrid = getMenuItemByName(menuItems,"MAPG")
  conf.mapProvider = getMenuItemByName(menuItems,"MAPP")

  conf.headingSensor = getMenuItemByName(menuItems,"HDGT")
  conf.headingSensorUnitScale = getMenuItemByName(menuItems,"HDGU")

  conf.sensorsConfigFileType = getMenuItemByName(menuItems,"SEN")
  conf.sidebarEnable = getMenuItemByName(menuItems,"SBE")
  conf.bottombarEnable = getMenuItemByName(menuItems,"BBE")

  conf.horSpeedMultiplier, conf.horSpeedLabel = getMenuItemByName(menuItems,"HSPD")

  conf.gpsSource = getMenuItemByName(menuItems,"GPS")
  conf.enableHud = getMenuItemByName(menuItems,"HUD")

  menu.editSelected = false
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
        if value ~= nil then
          menuItems[i][4] = tonumber(value)
          -- check if the value read from file is compatible with available options
          if menuItems[i][2] == 1 and tonumber(value) > #menuItems[i][5] then
            -- if not force default
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

local function triggerConfigReload()
  local cfg = assert(io.open(getConfigTriggerFilename(),"w"))
  if cfg ~= nil then
    io.write(cfg, "1")
    io.close(cfg)
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
  -- when run standalone there's nothing to update :-)
  if conf ~= nil then
    applyConfigValues(conf)
  end
  triggerConfigReload()
end

local function drawConfigMenuBars()
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(16,20,25))
  local itemIdx = string.format("%d/%d",menu.selectedItem,#menuItems)
  lcd.drawFilledRectangle(0,0, LCD_W, 28, CUSTOM_COLOR)
  lcd.drawRectangle(0, 0, LCD_W, 28, CUSTOM_COLOR)
  lcd.drawFilledRectangle(0,LCD_H-28, LCD_W, 28, CUSTOM_COLOR)
  lcd.drawRectangle(0, LCD_H-28, LCD_W, 28, CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR,WHITE)
  lcd.drawText(0,0, model.getInfo().name, CUSTOM_COLOR)
  lcd.drawText(LCD_W,2,"Yaapu Mapping Widget 2.2.0 dev".."( "..'300cb39'..")",SMLSIZE+CUSTOM_COLOR+RIGHT)
  lcd.drawText(2,LCD_H-28+1,getConfigFilename(),CUSTOM_COLOR)
  lcd.drawText(LCD_W,LCD_H-28+1,itemIdx,CUSTOM_COLOR+RIGHT)
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
  lcd.setColor(CUSTOM_COLOR,WHITE)
  if menuItems[idx][2] == 0 then
    if menuItems[idx][4] == 0 and menuItems[idx][5] >= 0 then
      lcd.drawText(500,32 + (idx-menu.offset-1)*28, "---",flags+CUSTOM_COLOR)
    else
      lcd.drawNumber(500,32 + (idx-menu.offset-1)*28, menuItems[idx][4],flags+menuItems[idx][8]+CUSTOM_COLOR)
      if menuItems[idx][7] ~= nil then
        lcd.drawText(500 + 50,32 + (idx-menu.offset-1)*28, menuItems[idx][7],flags+CUSTOM_COLOR)
      end
    end
  else
    lcd.drawText(500,32 + (idx-menu.offset-1)*28, menuItems[idx][5][menuItems[idx][4]],flags+CUSTOM_COLOR)
  end
end

local bitmaps = {}

local function getBitmap(name)
  if bitmaps[name] == nil then
    bitmaps[name] = Bitmap.open("/WIDGETS/Yaapu/images/"..name..".png")
  end
  return bitmaps[name],Bitmap.getSize(bitmaps[name])
end

local function drawConfigMenu(event)
  drawConfigMenuBars()
  updateMenuItems()
  if event == EVT_ENTER_BREAK or event == EVT_VIRTUAL_ENTER then
    if menu.editSelected == true then
      -- confirm modified value
      saveConfig()
    end
    menu.editSelected = not menu.editSelected
    menu.updated = true
  elseif menu.editSelected and (event == EVT_VIRTUAL_NEXT or event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT) then
    incMenuItem(menu.selectedItem)
  elseif menu.editSelected and (event == EVT_VIRTUAL_PREV or event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT) then
    decMenuItem(menu.selectedItem)
  elseif not menu.editSelected and (event == EVT_VIRTUAL_PREV or event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT) then
    menu.selectedItem = (menu.selectedItem - 1)
    if menu.offset >=  menu.selectedItem then
      menu.offset = menu.offset - 1
    end
  elseif not menu.editSelected and (event == EVT_VIRTUAL_NEXT or event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT) then
    menu.selectedItem = (menu.selectedItem + 1)
    if menu.selectedItem - 15 > menu.offset then
      menu.offset = menu.offset + 1
    end
  end
  --wrap
  if menu.selectedItem > #menuItems then
    menu.selectedItem = 1
    menu.offset = 0
  elseif menu.selectedItem  < 1 then
    menu.selectedItem = #menuItems
    --menu.offset =  #menuItems - 15
    menu.offset = #menuItems > 15 and #menuItems - 15 or 0
  end
  --
  for m=1+menu.offset,math.min(#menuItems,15+menu.offset) do
    lcd.setColor(CUSTOM_COLOR,WHITE)
    lcd.drawText(2,32 + (m-menu.offset-1)*28, menuItems[m][1],CUSTOM_COLOR)
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
local function run(event, touchState)
  lcd.setColor(CUSTOM_COLOR, lcd.RGB(50, 50, 50))
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
