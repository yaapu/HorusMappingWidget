----------------------------------------
-- custom sensors configuration file
----------------------------------------
local sensors = {
  -- Sensor 1
  -- Sensor 2
[1]=  {
    "Alt",   -- label
    "Alt",     -- OpenTX sensor name
    0,          -- precision: number of decimals 0,1,2
    "m",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "+",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    50,        -- warning level (nil is do not use feature)
    100,        -- critical level (nil is do not use feature)
  },
  -- Sensor 6
[2]=  {
    "Spd",   -- label
    "GSpd",     -- OpenTX sensor name
    0,          -- precision: number of decimals 0,1,2
    "m/s",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "+",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    nil,        -- warning level (nil is do not use feature)
    nil,        -- critical level (nil is do not use feature)
  },
  -- Sensor 6
[3]=  {
    "Dist",   -- label
    "Dist",     -- OpenTX sensor name
    0,          -- precision: number of decimals 0,1,2
    "m",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "+",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    nil,        -- warning level (nil is do not use feature)
    nil,        -- critical level (nil is do not use feature)
  },
[4]=  {
    "VSpd",   -- label
    "VSpd",     -- OpenTX sensor name
    1,          -- precision: number of decimals 0,1,2
    "m/s",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    nil,        -- warning level (nil is do not use feature)
    nil,        -- critical level (nil is do not use feature)
  },
[5]=  {
    "Hdg",   -- label
    "Hdg",     -- OpenTX sensor name
    0,          -- precision: number of decimals 0,1,2
    "@",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    nil,        -- warning level (nil is do not use feature)
    nil,        -- critical level (nil is do not use feature)
  },
[6]=  {
    "Celd",   -- label
    "Celd",     -- OpenTX sensor name
    2,          -- precision: number of decimals 0,1,2
    "V",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    3.65,        -- warning level (nil is do not use feature)
    3.30,        -- critical level (nil is do not use feature)
  },
[7]=  {
    "Celm",   -- label
    "Celm",     -- OpenTX sensor name
    2,          -- precision: number of decimals 0,1,2
    "V",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    3.65,        -- warning level (nil is do not use feature)
    3.30,        -- critical level (nil is do not use feature)
  },
[8]=  {
    "Batt",   -- label
    "VFAS",     -- OpenTX sensor name
    1,          -- precision: number of decimals 0,1,2
    "V",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    nil,        -- warning level (nil is do not use feature)
    nil,        -- critical level (nil is do not use feature)
  },
[9]=  {
    "Fuel",   -- label
    "Fuel",     -- OpenTX sensor name
    0,          -- precision: number of decimals 0,1,2
    "%",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    50,        -- warning level (nil is do not use feature)
    25,        -- critical level (nil is do not use feature)
  },
[10]=  {
    "Curr",   -- label
    "CURR",     -- OpenTX sensor name
    1,          -- precision: number of decimals 0,1,2
    "A",         -- label for unit of measure
    1,          -- multiplier if < 1 than divides
    "-",        -- "+" track max values, "-" track min values with
    2,          -- font size 1=small, 2=big
    nil,        -- warning level (nil is do not use feature)
    nil,        -- critical level (nil is do not use feature)
  },
}
------------------------------------------------------
-- the script can optionally look up values here
-- for each sensor and display the corresponding text instead
-- as an example to associate a lookup table to sensor 3 declare it like
--
--local lookups = {
-- [3] = {
--     [-10] = "ERR",
--     [0] = "OK",
--     [10] = "CRIT",
--   }
-- }
-- this would display the sensor value except when the value corresponds to one
-- of entered above
-- 
local lookups = {
}

collectgarbage()

return {
  sensors=sensors,lookups=lookups
}
