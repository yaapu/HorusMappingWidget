#include "includes/yaapu_inc.lua"

--[[

TYPEVALUE - menu option to select a numeric value
{description, type,name,default value,min,max,uit of measure,precision,increment step, <master name>, <master value>}
example {"batt alert level 1:", TYPEVALUE, "V1", 375, 0,5000,"V",PREC2,5,"L2",350 },

TYPECOMBO - menu option to select a value from a list
{description, type, name, default, label list, value list, <master name>, <master value>}
example {"center pane layout:", TYPECOMBO, "CPANE", 1, { "hud","radar" }, { 1, 2 },"CPANE",1 },

--]]
--
local menuItems = {
  {"map zoom level:", TYPEVALUE, "MAPZ", -2, -2, 17,nil,0,1 },
  {"map type:", TYPECOMBO, "MAPT", 1, { "satellite", "map", "terrain" }, { "sat_tiles", "tiles", "ter_tiles" } },
  {"map grid lines:", TYPECOMBO, "MAPG", 1, { "yes", "no" }, { true, false } },
  {"map zoom channel:", TYPEVALUE, "ZTC", 0, 0, 32,nil,0,1 },
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
      if items[idx][2] ==  TYPECOMBO then
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
  conf.mapType = getMenuItemByName(menuItems,"MAPT")
  
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
          if menuItems[i][2] == TYPECOMBO and tonumber(value) > #menuItems[i][5] then
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
  model.setGlobalVariable(CONF_GV,CONF_FM_GV,1)
end

local function drawConfigMenuBars()
  lcd.setColor(CUSTOM_COLOR,COLOR_BARS)
  local itemIdx = string.format("%d/%d",menu.selectedItem,#menuItems)
  lcd.drawFilledRectangle(0,TOPBAR_Y, LCD_W, 20, CUSTOM_COLOR)
  lcd.drawRectangle(0, TOPBAR_Y, LCD_W, 20, CUSTOM_COLOR)
  lcd.drawFilledRectangle(0,BOTTOMBAR_Y, LCD_W, 20, CUSTOM_COLOR)
  lcd.drawRectangle(0, BOTTOMBAR_Y, LCD_W, 20, CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR,COLOR_TEXT)  
  lcd.drawText(2,0,VERSION,CUSTOM_COLOR)
  lcd.drawText(2,BOTTOMBAR_Y+1,getConfigFilename(),CUSTOM_COLOR)
  lcd.drawText(BOTTOMBAR_WIDTH,BOTTOMBAR_Y+1,itemIdx,CUSTOM_COLOR+RIGHT)
end

local function incMenuItem(idx)
  if menuItems[idx][2] == TYPEVALUE then
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
  if menuItems[idx][2] == TYPEVALUE then
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
  lcd.setColor(CUSTOM_COLOR,COLOR_TEXT)    
  if menuItems[idx][2] == TYPEVALUE then
    if menuItems[idx][4] == 0 and menuItems[idx][5] >= 0 then
      lcd.drawText(MENU_ITEM_X,MENU_Y + (idx-menu.offset-1)*20, "---",flags+CUSTOM_COLOR)
    else
      lcd.drawNumber(MENU_ITEM_X,MENU_Y + (idx-menu.offset-1)*20, menuItems[idx][4],flags+menuItems[idx][8]+CUSTOM_COLOR)
      if menuItems[idx][7] ~= nil then
        lcd.drawText(MENU_ITEM_X + 50,MENU_Y + (idx-menu.offset-1)*20, menuItems[idx][7],flags+CUSTOM_COLOR)
      end
    end
  else
    lcd.drawText(MENU_ITEM_X,MENU_Y + (idx-menu.offset-1)*20, menuItems[idx][5][menuItems[idx][4]],flags+CUSTOM_COLOR)
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
    if menu.selectedItem - MENU_PAGESIZE > menu.offset then
      menu.offset = menu.offset + 1
    end
  end
  --wrap
  if menu.selectedItem > #menuItems then
    menu.selectedItem = 1 
    menu.offset = 0
  elseif menu.selectedItem  < 1 then
    menu.selectedItem = #menuItems
    menu.offset =  #menuItems > MENU_PAGESIZE and #menuItems - MENU_PAGESIZE or 0
  end
  --
  for m=1+menu.offset,math.min(#menuItems,MENU_PAGESIZE+menu.offset) do
    lcd.setColor(CUSTOM_COLOR,COLOR_TEXT)   
    lcd.drawText(2,MENU_Y + (m-menu.offset-1)*20, menuItems[m][1],CUSTOM_COLOR)
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

#ifdef COMPILE
local function compileLayouts()
  local files = {
    "mapslayout"
  }
  
  -- compile all layouts for all panes
  for i=1,#files do
    loadScript(libBasePath..files[i]..".lua","c")
  end
end
#endif

--------------------------
-- RUN
--------------------------
local function run(event)
  lcd.setColor(CUSTOM_COLOR, COLOR_BG) -- hex 0x084c7b -- 073f66
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