# ttt_entity_replace

This lua is for Gmod, TTT.

Its created to spawn your weapons of choice instead of default ones.
For example if you use the example config + all fas2 weapons, on every map every weapon is a fas2 weapon.

https://steamcommunity.com/sharedfiles/filedetails/?id=1517302772

## installation
The lua has to be in "server/garrysmod/lua/autorun/server/jusito_ttt_entity_replace.lua"
The config has to be "server/garrysmod/data/jusito_ttt_entity_replace/config.txt"

## config
The config file is a simple structured textfile.

```
#commentary
source
	classname of a weapon you don't like
target
	classname of a weapon you like
end
```

Multiple sources / targets are allowed.
Multiple blocks are allowed.
Check my example.
Classnames are easy found with command: jusito_weapons_list

## commands
jusito_list
Lists all functions usable with this mod.

jusito_spawn PlayerName ClassName
Gives the player the entity.

jusito_replace_entities
Replaces every entity on the map according to mapping rules in config.txt.

jusito_reload
Reloads config.txt.

jusito_weapons_list
Lists all registered weapon classes + ammo classes.

## how is this working?
https://wiki.garrysmod.com/page/GM/OnEntityCreated
The script processes every entity creation, btw if no mapping rule for a weapon is in the config.txt the weapon is untouched.

## does this work in gmod / ... which isn't ttt
The idea yes because I hook into gmod but its untested.