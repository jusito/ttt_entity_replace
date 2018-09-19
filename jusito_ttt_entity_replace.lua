
-- region DECLERATION
local DEBUG_MODE = false
local MOD_NAME = 'jusito_ttt_entity_replace'

-- path is relative to data dir
local FILE_CONFIG = MOD_NAME .. '/config.txt'
-- https://wiki.garrysmod.com/page/file/Read
local FILE_PATH = 'DATA'

-- hook configuration, the first calls if map is loaded, the second
local HOOK_REPLACE = 'OnEntityCreated'
local HOOK_REPLACE_ID = MOD_NAME .. '_entitycreation'
local HOOK_REPLACE_PREGAME = 'InitPostEntity'
local HOOK_REPLACE_PREGAME_ID = MOD_NAME .. '_pregame'
local HOOK_REPLACE_GAME = 'TTTPrepareRound'
local HOOK_REPLACE_GAME_ID = MOD_NAME .. '_game'

-- text searched in config file to identify parts / regions
local LINE_SOURCE = 'source'
local LINE_TARGET = 'target'
local LINE_END = 'end'

local config = {}

-- used for weapon info table
local KeyClassname = 'ClassName'
local KeyAmmoPrimary = 'AmmoNamePrimary'
local KeyAmmoSecondary = 'AmmoNameSecondary'
local KeyAmmoClass = 'AmmoClass'

-- used for spawn command
local weaponID = 0
local weaponInfos = {}

-- timed replacement
local timerActive = false
local timerTable = {}
-- end region DECLERATION










-- region UTIL
-- used as comparator for table.sort, needed KeyClassname key
local function compare(a,b)
  return a[KeyClassname] < b[KeyClassname]
end






-- returns {{"ClassName", "AmmoNamePrimary", "AmmoNameSecondary", "AmmoClass"}, ...}
local function getWeaponInfos()

  local ret = {}
  local current = {}

  for k, v in pairs(weapons.GetList()) do
    current = {}
    current[KeyClassname] = v["ClassName"]

    if v.Primary ~= nil and v.Primary.Ammo ~= nil then
      current[KeyAmmoPrimary] = v.Primary.Ammo
    else
      current[KeyAmmoPrimary] = "-"
    end
    if v.Secondary ~= nil and v.Secondary.Ammo ~= nil then
      current[KeyAmmoSecondary] = v.Secondary.Ammo
    else
      current[KeyAmmoSecondary] = "-"
    end
    if v["AmmoEnt"] ~= nil then
      current[KeyAmmoClass] = v["AmmoEnt"]
    else
      current[KeyAmmoClass] = "-"
    end

    -- add only weapons which has a description EquipMenuData(only fas2), Slot(default weapons dont set this on server)
    if v["Kind"] ~= nil then
      ret[#ret + 1] = current
      -- todo check recursive if base = weapon_tttbase
    end
  end
  table.sort(ret, compare)
  return ret
end




local function givePlayerItem(playerName, itemClassName)
  for k, v in pairs(player.GetAll()) do
    if ((v:GetName()) == (playerName)) then
      v:Give(itemClassName)
    end
  end
end




-- trims whitespaces at the ends and convert to lower case
local function trim(s)
  if (s == nil) then
    return ""
  else
    return string.lower(s:match "^%s*(.-)%s*$")
  end
end




local function uprint( func, msg )
  print( "[" .. MOD_NAME .. "][" .. func .. "]" .. msg)
end
-- end region UTIL














-- region FILE
-- see if the file exists
local function fileExists(fileName, filePath)
  if DEBUG_MODE then uprint("fileExists", " => " .. filePath .. " -> " .. fileName) end

  --local f = io.open(file, "rb")
  local f = file.Open( fileName, "r", filePath )

  if f then
    f:Close()
  end

  if DEBUG_MODE then uprint("fileExists", " <= " .. tostring(f ~= nil)) end
  return f ~= nil
end

-- get all lines from a file, returns an empty
-- list/table if the file does not exist
local function fileReadLinesToArray(fileName, filePath)
  local ret = {}
  if DEBUG_MODE then uprint("fileReadLinesToArray", " => " .. filePath .. " -> " .. fileName) end

  if fileExists( fileName, filePath) then
    local f = file.Open( fileName, "r", filePath )

    if f then
      for _,line in pairs(string.Explode( "\n", f:Read( f:Size()))) do
        ret[#ret + 1] = line
      end
    end
  end

  if DEBUG_MODE then uprint("fileReadLinesToArray", " <= " .. tostring(#ret)) end
  return ret
end
-- end region FILE













-- region PRIMARY
-- processes the lines given as config
-- lines should be an table of strings
-- return is int->{lineSource->{int->class}, lineTarget->{int->class}}
-- return can be empty
local function configRead(lines)
  if DEBUG_MODE then uprint( "configRead", " => " .. tostring(#lines)) end

  local current = {}
  local line = ""
  local ret = {}
  local source = false
  local sourceTable = {}
  local target = false
  local targetTable = {}

  -- for every line
  for k,v in pairs(lines) do
    line = trim(v)

    -- if line is empty
    if string.len(line) == 0 then
      -- skip line
      if DEBUG_MODE then uprint("configRead", "line is empty [" .. line .. "]") end

      -- if in target part
    elseif target then
      -- found end?
      if ((line) == (LINE_END)) then
        source = false
        target = false

        current[LINE_TARGET] = targetTable
        ret[#ret + 1] = current

        fileLooksValid = true
        if DEBUG_MODE then uprint("configRead", "end found [" .. line .. "]") end

        -- if in target data
      else
        targetTable[#targetTable + 1] = line
        if DEBUG_MODE then uprint("configRead", "+target [" .. line .. "]") end
      end

      -- if in source part
    elseif source then
      -- if target path found
      if ((line) == (LINE_TARGET)) then
        source = false
        target = true
        targetTable = {}
        current[LINE_SOURCE] = sourceTable
        if DEBUG_MODE then uprint("configRead", "table section found [" .. line .. "]") end

        -- if in source data
      else
        sourceTable[#sourceTable + 1] = line
        if DEBUG_MODE then uprint("configRead", "+source [" .. line .. "]") end
      end

      -- if source begins
    elseif ((line) == (LINE_SOURCE)) then
      sourceTable = {}
      current = {}
      source = true
      target = false
      if DEBUG_MODE then uprint("configRead", "source found [" .. line .. "]") end
    end
  end

  if DEBUG_MODE then uprint("configRead", "configRead <= " .. tostring(#ret)) end
  return ret
end






-- replaces old ent with new ent
-- if second param is nil => ent is removed!
local function replaceEntity(oldEntity, newEntityClassName)
  if DEBUG_MODE then uprint("replaceEntity", tostring(oldEntity) .. "->" .. tostring(newEntityClassName)) end

  if oldEntity == nil then
    return
  end

  if newEntityClassName ~= nil then
    local current = {}
    
    current[1] = oldEntity
    current[2] = newEntityClassName
    timerTable[#timerTable + 1] = current
    
    if timerActive then
      if DEBUG_MODE then uprint("replaceEntity", "skipped timer") end
    elseif (SERVER) then
      if DEBUG_MODE then uprint("replaceEntity", "set timer") end
      timerActive = true
      timer.Simple( 0, function() jusitoReplaceEntityTimed() end )
    end
  end
end





function jusitoReplaceEntityTimed()
  local newEntity = nil
  local newEntityClassName = ""
  local oldEntity = nil
  
  if DEBUG_MODE then uprint( "replaceEntityTimed", "triggered" ) end
  
  for k, replace in pairs(timerTable) do
    oldEntity = replace[1]
    newEntityClassName = replace[2]
    
    if IsValid(oldEntity) then
      if DEBUG_MODE then uprint( "replaceEntityTimed", "created timed... " .. oldEntity:GetClass() .. "->" .. newEntityClassName) end
      
      oldEntity:SetSolid(SOLID_NONE)
      newEntity = ents.Create( newEntityClassName )
      
      -- maybe class name is spelled wrong or wrong registered, we don't know
      if newEntity ~= nil then
        -- in some maps position maybe not set?
        -- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/ent_replace.lua (ReplaceSingle 11-13)
        newEntity:SetPos(oldEntity:GetPos())
        newEntity:SetAngles(oldEntity:GetAngles())
      end
      SafeRemoveEntity(oldEntity)
      if newEntity ~= nil then
        newEntity:Spawn()
        newEntity:Activate()
        newEntity:PhysWake()
      end
    -- else => can be nil on map startup
    end
  end
  
  if DEBUG_MODE then uprint( "replaceEntityTimed", "done" ) end
  timerTable = {}
  timerActive = false
end
-- end region PRIMARY

















-- region HOOKS
concommand.Add( "jusito_list", function()
  uprint("jusito_list", "jusito_list: lists all functions usable with this mod")
  uprint("jusito_list", "jusito_spawn PlayerName ClassName: Gives the player the entity.")
  uprint("jusito_list", "jusito_replace_entities: Replaces every entity on the map according to mapping rules in config.txt")
  uprint("jusito_list", "jusito_reload: reloads config.txt")
  uprint("jusito_list", "jusito_weapons_list: lists all registered weapon classes + ammo classes")
end)






local function findReplacement( ent )
  if DEBUG_MODE then uprint( "findReplacement", "find replacement for " .. tostring(ent)) end
  
  local newEntityClassName = ""
  local sourceTable = {}
  local targetTable = {}
  
  if config == nil or #config == 0 then
    if DEBUG_MODE then uprint( "findReplacement", "loading config...") end
    config = configRead(fileReadLinesToArray(FILE_CONFIG, FILE_PATH))
  end
  
  if ent:IsValid() and config ~= nil then
    -- for every mapping
    for k, mapping in pairs(config) do
--      if DEBUG_MODE then uprint( "findReplacement", "processing mappin " .. tostring(k)) end
      sourceTable = mapping[LINE_SOURCE]
      targetTable = mapping[LINE_TARGET]

      -- check if one source is matching
      for km, class in pairs(sourceTable) do
        -- if so, replace
        if ((class) == (ent:GetClass())) then
          -- with one ent. of targetTable (nil = remove)
          newEntityClassName = targetTable[ math.random( #targetTable )]
          if DEBUG_MODE then uprint( "findReplacement", "match! Mapping to " .. newEntityClassName) end
          -- todo check if classname exists => if not retry
          replaceEntity(ent, newEntityClassName)
        end
      end
    end
  end
  
  if DEBUG_MODE then uprint( "findReplacement", "<= done") end
end
-- hook.Add( HOOK_REPLACE, HOOK_REPLACE_ID, findReplacement) => after map start!






concommand.Add( "jusito_spawn", function(ply, command, arg)
  -- if item is given
  if #arg > 1 then
    givePlayerItem(arg[1], arg[2])

    -- if item rotation
  elseif #arg == 1 then
    -- check lower bounds and set table
    if weaponID == 0 then
      weaponInfos = getWeaponInfos()
      weaponID = weaponID + 1
    end

    -- if table is accessible
    if #weaponInfos >= weaponID then
      uprint("jusito_spawn", " spawning [" .. weaponID .. "]" .. weaponInfos[weaponID][KeyClassname] .. " and ammo " .. weaponInfos[weaponID][KeyAmmoClass])
      givePlayerItem(arg[1], weaponInfos[weaponID][KeyClassname])
      givePlayerItem(arg[1], weaponInfos[weaponID][KeyAmmoClass])
      weaponID = weaponID + 1

      -- if table isnt accessible
    else
      weaponID = 0
    end
  end
end)




-- todo allow redrop + delete
-- todo allow sets of items
-- todo hook in item spawn for some maps https://wiki.garrysmod.com/page/GM/OnEntityCreated
function ProcessReplacing()
  uprint( "ProcessReplacing", "starting replacing..." )
  local foundEntities = {}
  local newEntityClassName = ""
  local sourceTable = {}
  local targetTable = {}

  -- todo only on map start!
  if config == nil or #config == 0 then
    if DEBUG_MODE then uprint( "ProcessReplacing", "config not set, try to load" ) end
    config = configRead(fileReadLinesToArray(FILE_CONFIG, FILE_PATH))
  end

  -- if config is set
  if config ~= nil then
    uprint( "ProcessReplacing", "Mappings: " .. tostring(#config) )

    -- for every mapping
    for k, mapping in pairs(config) do
      sourceTable = mapping[LINE_SOURCE]
      targetTable = mapping[LINE_TARGET]
      if DEBUG_MODE then uprint( "ProcessReplacing", " [" .. tostring(k) .. " " .. tostring(#sourceTable) .. " -> " .. tostring(#targetTable))  end

      -- check if any of source entities is found
      for km, class in pairs(sourceTable) do
        foundEntities = ents.FindByClass(class)

        -- if found, replace...
        if foundEntities ~= nil then
          -- ... every found entity ...
          for k, currentEntity in pairs(foundEntities) do
            -- with one ent. of targetTable (nil = remove)
            newEntityClassName = targetTable[ math.random( #targetTable )]
            -- todo check if classname exists => if not retry
            replaceEntity(currentEntity, newEntityClassName)
          end
        end
      end
    end
  else
    if DEBUG_MODE then uprint( "ProcessReplacing", "couldn't load config" ) end
  end
  
  hook.Add( HOOK_REPLACE, HOOK_REPLACE_ID, findReplacement)
  
  uprint( "ProcessReplacing", "replacing done" )
end
hook.Add( HOOK_REPLACE_PREGAME, HOOK_REPLACE_PREGAME_ID, ProcessReplacing)
-- hook.Add( HOOK_REPLACE_GAME, HOOK_REPLACE_GAME_ID, ProcessReplacing)
-- FCVAR_SERVER_CAN_EXECUTE (only in server console)
concommand.Add( "jusito_replace_entities", ProcessReplacing, nil, "Starts to replace every spawned entity according to rules set in " .. FILE_PATH .. " -> " .. FILE_CONFIG, 268435456)





concommand.Add( "jusito_reload", function()
  config = configRead(fileReadLinesToArray(FILE_CONFIG, FILE_PATH))
  weaponInfos = getWeaponInfos()
end)






concommand.Add( "jusito_weapons_list", function()
  PrintTable(getWeaponInfos())
end)
-- end region HOOKS
















-- region DEBUG
-- end region DEBUG
