---- #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
-----#                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################


--###############################################################################
-- Multi buffer for Config description
-- To start operation:
--   Write 0xFF at address 4 will request the buffer to be cleared
--   Write "Conf" at address 0..3
-- Read
--   Read at address 12 gives the current config page
--   Read at address 13..172 gives the current data of the page = 8 lines * 20 caracters
-- Write
--   Write at address 5..11 the command
--   Write 0x01 at address 4 will send the command to the module
-- !! Before exiting the script must write 0 at address 0 for normal operation !!
--###############################################################################

local Focus = -1
local Page = 0
local Edit = -1
local Edit_pos = 1
local Menu = { {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""},
               {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""},
               {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""},
               {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""},
               {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""},
               {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""},
               {text = "", field_type = 0, field_len = 0, field_value = {}, field_text = ""} }
local Menu_value = {}

function bitand(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
          result = result + bitval      -- set the current bit
      end
      bitval = bitval * 2 -- shift left
      a = math.floor(a/2) -- shift right
      b = math.floor(b/2)
    end
    return result
end

local function Config_Send(page, line, value)
  local i
  i = (page*16) + line
  multiBuffer( 5, i )
  for i = 1 , 6 , 1 do
    multiBuffer( 5+i, value[i] )
  end
  multiBuffer( 4, 1 )
end

local function Config_Release()
  local i
  for i = 3 , 0 , -1 do
    multiBuffer( i, 0 )
  end
end

local function Config_Page( )
  Config_Send(Page, 0, { 0, 0, 0, 0, 0, 0 })
end

local function Config_Draw_Edit( event )
  local i
  local text
  if Menu[Focus].field_type == 0xD0 then
    if Edit == -1 then
      Edit = 0
      Edit_pos = 1
      for i = 1, Menu[Focus].field_len, 1 do
        Menu_value[i] = Menu[Focus].field_value[i]
      end
    end
    if Edit == 0 then
      if event == EVT_VIRTUAL_ENTER then
        if Edit_pos > Menu[Focus].field_len then
          Edit = -1
          if Edit_pos == Menu[Focus].field_len + 1 then
            --Config_Send(Page, Focus, Menu_value)
            Config_Send(Page, Focus, Menu_value)
          end
          return
        else
          Edit = 1
        end
      elseif event == EVT_VIRTUAL_PREV and Edit_pos > 1 then
        Edit_pos = Edit_pos - 1
      elseif event == EVT_VIRTUAL_NEXT and Edit_pos < Menu[Focus].field_len + 2 then
        Edit_pos = Edit_pos + 1
      end
    else
      if event == EVT_VIRTUAL_ENTER then
        Edit = 0
      elseif event == EVT_VIRTUAL_PREV then
        Menu_value[Edit_pos] = Menu_value[Edit_pos] - 1
      elseif event == EVT_VIRTUAL_NEXT then
        Menu_value[Edit_pos] = Menu_value[Edit_pos] + 1
      end
    end
    lcd.drawRectangle(160-1, 100-1, 160+2, 55+2, TEXT_COLOR)
    lcd.drawFilledRectangle(160, 100, 160, 55, TEXT_BGCOLOR)
    for i = 1, Menu[Focus].field_len, 1 do
      if i==Edit_pos then
        attrib = INVERS
      else
        attrib = 0
      end
      lcd.drawText(170+12*2*(i-1), 110, string.format('%02X', Menu_value[i]), attrib)
    end
    if Edit_pos == Menu[Focus].field_len + 1 then
      attrib = INVERS
    else
      attrib = 0
    end
    lcd.drawText(170, 130, "Save", attrib)
    if Edit_pos == Menu[Focus].field_len + 2 then
      attrib = INVERS
    else
      attrib = 0
    end
    lcd.drawText(260, 130, "Cancel", attrib)
  elseif Menu[Focus].field_type == 0x90 then
    if Edit == -1 then
      Edit = 0
      Edit_pos = 2
    end
    if event == EVT_VIRTUAL_ENTER then
      Edit = -1
      if Edit_pos == 1 then
        Config_Send(Page, Focus, { 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA } )
      end
      return
    elseif event == EVT_VIRTUAL_PREV and Edit_pos > 1 then
      Edit_pos = Edit_pos - 1
    elseif event == EVT_VIRTUAL_NEXT and Edit_pos < 2 then
      Edit_pos = Edit_pos + 1
    end
    lcd.drawRectangle(160-1, 100-1, 160+2, 55+2, TEXT_COLOR)
    lcd.drawFilledRectangle(160, 100, 160, 55, TEXT_BGCOLOR)
    lcd.drawText(170, 110, Menu[Focus].field_text .. "?")
    if Edit_pos == 1 then
      attrib = INVERS
    else
      attrib = 0
    end
    lcd.drawText(170, 130, "Yes", attrib)
    if Edit_pos == 2 then
      attrib = INVERS
    else
      attrib = 0
    end
    lcd.drawText(260, 130, "No", attrib)
  end
end

local function Config_Next_Prev( event )
  local line
  if event == EVT_VIRTUAL_PREV then
    for line = Focus - 1, 1, -1 do
      if Menu[line].field_type >= 0x80 and Menu[line].field_type ~= 0xA0 and Menu[line].field_type ~= 0xC0 then
        Focus = line
        break
      end
    end
  elseif event == EVT_VIRTUAL_NEXT then
    for line = Focus + 1, 7, 1 do
      if Menu[line].field_type >= 0x80 and Menu[line].field_type ~= 0xA0 and Menu[line].field_type ~= 0xC0 then
        Focus = line
        break
      end
    end
  end
end

local function Config_Draw_Menu()
  local i
  local value
  local line
  local length
  local text
  
  lcd.clear()

  if LCD_W == 480 then
    --Draw title
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
    lcd.drawText(1, 5, "Multi Config v0.1", MENU_TITLE_COLOR)
    if multiBuffer(13) == 0x00 then
      lcd.drawText(10,50,"No Config telemetry...", BLINK)
    else
      --Draw firmware version and channels order
      local ch_order = multiBuffer(17)
      local channel_names = {}
      channel_names[bitand(ch_order,3)+1] = "A"
      ch_order = math.floor(ch_order/4)
      channel_names[bitand(ch_order,3)+1] = "E"
      ch_order = math.floor(ch_order/4)
      channel_names[bitand(ch_order,3)+1] = "T"
      ch_order = math.floor(ch_order/4)
      channel_names[bitand(ch_order,3)+1] = "R"
      lcd.drawText(150, 5, "Firmware v" .. multiBuffer(13) .. "." .. multiBuffer(14) .. "." .. multiBuffer(15) .. "." .. multiBuffer(16) .. " " .. channel_names[1] .. channel_names[2] .. channel_names[3] .. channel_names[4], MENU_TITLE_COLOR)

      --Draw Menu
      for line = 1, 7, 1 do
        --Clear line info
        Menu[line].text = ""
        Menu[line].field_type = 0
        Menu[line].field_len = 0
        for i = 1, 7, 1 do
          Menu[line].field_value[i] = 0
        end
        Menu[line].field_text = ""
        length = 0
        --Read line from buffer
        for i = 0, 20-1, 1 do
          value=multiBuffer( line*20+13+i )
          if value == 0 then
            break   -- end of line
          end
          if value > 0x80 and Menu[line].field_type == 0 then
            Menu[line].field_type = bitand(value, 0xF0)
            Menu[line].field_len = bitand(value, 0x0F)
            length = Menu[line].field_len
            if Menu[line].field_type ~= 0xA0 and Menu[line].field_type ~= 0xC0 and Focus == -1 then
              Focus = line;
            end
          else
            if Menu[line].field_type == 0 then
              Menu[line].text = Menu[line].text .. string.char(value)
            else
              length = length - 1
              if Menu[line].field_type == 0x80 or Menu[line].field_type == 0x90 then
                Menu[line].field_text = Menu[line].field_text .. string.char(value)
              else
                Menu[line].field_value[Menu[line].field_len-length] = value
              end
              if length == 0 then
                break
              end
            end
          end
        end
        if Menu[line].text ~= "" then
          if Menu[line].field_type == 0xA0 or Menu[line].field_type == 0xB0 or Menu[line].field_type == 0xC0 or Menu[line].field_type == 0xD0 then
            Menu[line].text = Menu[line].text .. ":"
          end
          lcd.drawText(10,32+20*line,Menu[line].text )
        end
        if line == Focus then
          attrib = INVERS
        else
          attrib = 0
        end
        if Menu[line].field_type == 0x80 or Menu[line].field_type == 0x90 then
          lcd.drawText(10+9*#Menu[line].text, 32+20*line, Menu[line].field_text, attrib)
        elseif Menu[line].field_type == 0xA0 or Menu[line].field_type == 0xB0 then
          value = 0
          for i = 1, Menu[line].field_len, 1 do
            value = value*256 + value
          end
          lcd.drawText(10+9*#Menu[line].text, 32+20*line, value, attrib)
        elseif Menu[line].field_type == 0xC0 or Menu[line].field_type == 0xD0 then
          text=""
          for i = 1, Menu[line].field_len, 1 do
            text = text .. string.format('%02X ', Menu[line].field_value[i])
          end
          lcd.drawText(10+9*#Menu[line].text, 32+20*line, text, attrib)
        end
      end
    end
  else
    --Draw RX Menu on LCD_W=128
    -- if multiBuffer( 4 ) == 0xFF then
      -- lcd.drawText(2,17,"No Config telemetry...",SMLSIZE)
    -- else
      -- if Timer_128 ~= 0 then
        --Intro page
        -- Timer_128 = Timer_128 - 1
        -- lcd.drawScreenTitle("Graupner Hott",0,0)
        -- lcd.drawText(2,17,"Configuration of RX" .. sensor_name[Config_Sensor+1] ,SMLSIZE)
        -- lcd.drawText(2,37,"Press menu to cycle Sensors" ,SMLSIZE)
      -- else
        --Menu page
        -- for line = 0, 7, 1 do
          -- for i = 0, 21-1, 1 do
            -- value=multiBuffer( line*21+6+i )
            -- if value > 0x80 then
              -- value = value - 0x80
              -- lcd.drawText(2+i*6,1+8*line,string.char(value).." ",SMLSIZE+INVERS)
            -- else
              -- lcd.drawText(2+i*6,1+8*line,string.char(value),SMLSIZE)
            -- end
          -- end
        -- end
      -- end
    -- end
  end
end

-- Init
local function Config_Init()
  --Set protocol to talk to
  multiBuffer( 0, string.byte('C') )
  --test if value has been written
  if multiBuffer( 0 ) ~=  string.byte('C') then
    error("Not enough memory!")
    return 2
  end
  --Request init of the buffer
  multiBuffer( 4, 0xFF )
  --Continue buffer init
  multiBuffer( 1, string.byte('o') )
  multiBuffer( 2, string.byte('n') )
  multiBuffer( 3, string.byte('f') )

  -- Test set
  -- multiBuffer( 12, 0 )
  -- multiBuffer( 13, 1 )
  -- multiBuffer( 14, 3 )
  -- multiBuffer( 15, 2 )
  -- multiBuffer( 16, 62 )
  -- multiBuffer( 17, 0 + 1*4 + 2*16 + 3*64)

  -- multiBuffer( 33, string.byte('G') )
  -- multiBuffer( 34, string.byte('l') )
  -- multiBuffer( 35, string.byte('o') )
  -- multiBuffer( 36, string.byte('b') )
  -- multiBuffer( 37, string.byte('a') )
  -- multiBuffer( 38, string.byte('l') )
  -- multiBuffer( 39, string.byte(' ') )
  -- multiBuffer( 40, string.byte('I') )
  -- multiBuffer( 41, string.byte('D') )
  -- multiBuffer( 42, 0xD0 + 4 )
  -- multiBuffer( 43, 0x12 )
  -- multiBuffer( 44, 0x34 )
  -- multiBuffer( 45, 0x56 )
  -- multiBuffer( 46, 0x78 )
  -- multiBuffer( 47, 0x00 )

  -- multiBuffer( 53, 0x90 + 9 )
  -- multiBuffer( 54, string.byte('R') )
  -- multiBuffer( 55, string.byte('e') )
  -- multiBuffer( 56, string.byte('s') )
  -- multiBuffer( 57, string.byte('e') )
  -- multiBuffer( 58, string.byte('t') )
  -- multiBuffer( 59, string.byte(' ') )
  -- multiBuffer( 60, string.byte('G') )
  -- multiBuffer( 61, string.byte('I') )
  -- multiBuffer( 62, string.byte('D') )
  -- multiBuffer( 63, 0x00 )
end

-- Main
local function Config_Run(event)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  elseif event == EVT_VIRTUAL_EXIT then
    Config_Release()
    return 2
  else
    Config_Draw_Menu()
    if ( event == EVT_VIRTUAL_PREV_PAGE or event == EVT_VIRTUAL_NEXT_PAGE ) and Edit < 1 then
      if event == EVT_VIRTUAL_PREV_PAGE then
        killEvents(event)
        if Page > 0 then
          --Page = Page - 1
          --Config_Page()
        end
      else
        --Page = Page + 1
        --Config_Page()
      end
    end
    if Focus > 0 then
      if Edit >= 0 then
        Config_Draw_Edit( event )
      elseif event == EVT_VIRTUAL_ENTER then
        Config_Draw_Edit( 0 )
      elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_NEXT then
        Config_Next_Prev( event )
      end
    end
    return 0
  end
end

return { init=Config_Init, run=Config_Run }
