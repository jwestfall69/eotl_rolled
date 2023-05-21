# eotl_rolled

This is a TF2 sourcemod plugin I wrote for the [EOTL](https://www.endofthelinegaming.com/) community.

This plugin is targeted at playload maps.  If blue team wins the playload map fast enough (rolled) or red team blocks blue on one of the early cap points (stuffed) it will cause a sound to be played.

By default sounds from this plugin are enabled for players.


### Config File (addons/sourcemod/configs/eotl_rolled.cfg)
<hr>

This config file defines the rolled and stuffed sounds that can be played.  Multiple of each type can be defined, for which one will be picked at random.  Refer to the config file for more details.

### Say Commands
<hr>

**!rolled**
This command will enable rolled sounds for the user

**!rolled disabled**
This command will disable rolled sounds for the user


### ConVars
<hr>

The below convars likely will need to be setup on a per level basis as different payload maps have a different number of cap points and how fast you think blue needs to win to consider its a roll.

**eotl_rolled_time_rolled [minutes]**

If blue won and round lasted less then [minutes] minutes, then a random rolled sound will play from the config.  A value of -1 will disable this setting.

Default: 8

**eotl_rolled_time_stuffed [minutes]**

If red won and round lasted less then [minutes] minutes, then a random stuffed sound will play from the config.  A value of -1 will disable this setting.

Default: -1

**eotl_rolled_cap_stuffed [num]**

If red won and blue capped <= [num] cap points, then a random stuffed sound will play from the config.  A value of -1 will disable this setting.

Default: 1

**eotl_rolled_delay [seconds]**

Wait [seconds] seconds after the end of round before playing the rolled/stuffed sound.  This is to avoid playing at the same time as the tf2 built in you win/lose sound.

Default: 5