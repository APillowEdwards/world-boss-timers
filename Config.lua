local _, WBT = ...;

local Config = {};
WBT.Config = Config;

local GUI = WBT.GUI;
local Util = WBT.Util;
local BossData = WBT.BossData;

Config.SOUND_CLASSIC = "classic";
Config.SOUND_FANCY = "fancy";

local SOUND_KEY_BATTLE_BEGINS = "battle-begins";

local CYCLIC_HELP_TEXT = "This mode will repeat the boss timers if you miss the kill. A timer in " ..
        Util.ColoredString(Util.COLOR_RED, "red text") ..
        " indicates cyclic mode. By clicking a boss's name in the timer window you can reset it permanently.";

----- Setters and Getters for options -----

local ConfigItem = {};

function ConfigItem.CreateDefaultGetter(var_name)
    local function getter()
        return WBT.db.global[var_name];
    end
    return getter;
end

function ConfigItem.CreateDefaultSetter(var_name)
    local function setter(state)
        WBT.db.global[var_name] = state;
        WBT.GUI:Rebuild();
    end
    return setter;
end

function ConfigItem:New(var_name, status_msg)
    local ci = {
        get = ConfigItem.CreateDefaultGetter(var_name);
        set = ConfigItem.CreateDefaultSetter(var_name);
        msg = status_msg,
    };

    setmetatable(ci, self);
    self.__index = self;

    return ci;
end

local ToggleItem = {};

function ToggleItem:New(var_name, status_msg)
    local ti = ConfigItem:New(var_name, status_msg);

    setmetatable(ti, self);
    self.__index = self;

    return ti;
end

function ToggleItem.GetColoredStatus(status_var)
    local color = Util.COLOR_RED;
    local status = "disabled";
    if status_var then
        color = Util.COLOR_GREEN;
        status = "enabled";
    end

    return color .. status .. Util.COLOR_DEFAULT;
end

function ToggleItem:PrintFormattedStatus(status_var)
    WBT:Print(self.msg .. " " .. self.GetColoredStatus(status_var) .. ".");
end

function ToggleItem:Toggle()
    local new_state = not self.get();
    self.set(new_state);
    self:PrintFormattedStatus(new_state);
end

local SelectItem = {};

-- This function creates tables needed for looking up values for the selection.
-- kv_table: is a table on the form: kv_table = { { k = "selection string to display", v = "<some value" }, ... }
-- The problem is that "select" stores the value of the "key" as a key for the value which should be shown from
-- field "values". So when I want to get the real value, I need a separate table that uses the same key (but with
-- a different value). I could just use the index for this, but that's hard to debug. So I'm creating two tables.
-- kk: key2key, which is used during look up for string to show in select box
-- kv: key2value, which contains the value which is actually used by the backend
function SelectItem:CreateTablesForSelectionLookup(kv_table)
    self.kk = {};
    self.kv = {};
    for i, e in ipairs(kv_table) do
        self.kk[e.k] = e.k;
        self.kv[e.k] = e.v;
    end
end

function SelectItem:OverrideGetter(default_key)
    local default_getter = self.get;
    self.get = function()
        local key = default_getter();
        if key == nil then
            return default_key;
        end
        return key;
    end
end

function SelectItem:New(var_name, status_msg, kv_table, default_key)
    local si = ConfigItem:New(var_name, status_msg);

    setmetatable(si, self);
    self.__index = self;

    si:CreateTablesForSelectionLookup(kv_table);
    si:OverrideGetter(default_key);

    return si;
end

function SelectItem:Key()
    return self:get();
end

function SelectItem:Value()
    return self.kv[self:Key()];
end

local RangeItem = {};

function RangeItem:OverrideGetter(default_val)
    local default_getter = self.get;
    self.get = function()
        local val = default_getter();
        if val == nil then
            return default_val;
        end
        return val;
    end
end

function RangeItem:New(var_name, status_msg, default_val)
    local si = ConfigItem:New(var_name, status_msg);

    setmetatable(si, self);
    self.__index = self;

    si:OverrideGetter(default_val);

    return si;
end

local spawn_alert_sound_kv_table = {
    { k = "DISABLED",                     v = nil                                                  },
    { k = "you-are-not-prepared",         v = "sound/creature/illidan/black_illidan_04.ogg"        },
    { k = "prepare-yourselves",           v = "sound/creature/EadricThePure/AC_Eadric_Aggro01.ogg" },
    { k = "alliance-bell",                v = "sound/doodad/belltollalliance.ogg"                  },
    { k = "alarm-clock",                  v = "sound/interface/alarmclockwarning2.ogg"             },
    { k = SOUND_KEY_BATTLE_BEGINS,        v = "sound/interface/ui_warfronts_battlebegin_horde.ogg" },
    { k = "pvp-warning",                  v = "sound/interface/pvpwarningalliancemono.ogg"         },
    { k = "drum-hit",                     v = "sound/doodad/fx_alarm_drum_hit_04.ogg"              },
};

local DEFAULT_SPAWN_ALERT_OFFSET = 5;
Config.auto_announce = ToggleItem:New("auto_announce", "Automatic announcements are now");
Config.sound = ToggleItem:New("sound_enabled", "Sound is now");
Config.multi_realm = ToggleItem:New("multi_realm", "Multi-Realm/Warmode option is now");
Config.show_boss_zone_only = ToggleItem:New("show_boss_zone_only", "Only show GUI in boss zone mode is now");
Config.cyclic = ToggleItem:New("cyclic", "Cyclic mode is now");
Config.highlight = ToggleItem:New("highlight", "Highlighting of current zone is now");
Config.show_saved = ToggleItem:New("show_saved", "Showing if saved on boss (on timer) is now");
Config.spawn_alert_sound = SelectItem:New("spawn_alert_sound", "Spawn alert sound is now", spawn_alert_sound_kv_table, SOUND_KEY_BATTLE_BEGINS);
Config.spawn_alert_sec_before = RangeItem:New("spawn_alert_sec_before", "Spawn alert sound sec before is now", DEFAULT_SPAWN_ALERT_OFFSET);
 -- Wrapping in some help printing for cyclic mode.
local cyclic_set_temp = Config.cyclic.set;
Config.cyclic.set = function(state) cyclic_set_temp(state); WBT:Print(CYCLIC_HELP_TEXT); end
-- Wrapping in 'play sound file when selected'.
local spawn_alert_sound_set_temp = Config.spawn_alert_sound.set;
Config.spawn_alert_sound.set = function(state) spawn_alert_sound_set_temp(state); Util.PlaySoundAlert(Config.spawn_alert_sound:Value()); end

----- Slash commands -----

local function PrintHelp()
    WBT.AceConfigDialog:Open(WBT.addon_name);
    local indent = "   ";
    WBT:Print("WorldBossTimers slash commands:");
    WBT:Print("/wbt reset --> Reset all kill info.");
    WBT:Print("/wbt gui-reset --> Reset the position of the GUI.");
    WBT:Print("/wbt saved --> Print your saved bosses.");
    WBT:Print("/wbt say --> Announce timers for boss in zone.");
    WBT:Print("/wbt show --> Show the timers frame.");
    WBT:Print("/wbt hide --> Hide the timers frame.");
    WBT:Print("/wbt send --> Toggle send timer data in auto announce.");
    WBT:Print("/wbt sound --> Toggle sound alerts.");
    --WBT:Print("/wbt sound classic --> Sets sound to \'War Drums\'.");
    --WBT:Print("/wbt sound fancy --> Sets sound to \'fancy mode\'.");
    WBT:Print("/wbt ann --> Toggle automatic announcements.");
    WBT:Print("/wbt cyclic --> Toggle cyclic timers.");
    WBT:Print("/wbt multi --> Toggle multi-realm/warmode timers.");
    WBT:Print("/wbt zone --> Toggle show GUI in boss zones only.");
end

local function ShowGUI(show)
    local gui = GUI;
    if show then
        WBT.db.global.hide_gui = false;
        if gui:ShouldShow() then
            gui:Show();
        else
            WBT:Print("The GUI will show when next you enter a boss zone.");
        end
    else
        WBT.db.global.hide_gui = true;
        gui:Hide();
    end
    gui:Update();
end

function Config.SlashHandler(input)
    arg1, arg2 = strsplit(" ", input);

    if arg1 == "hide" then
        ShowGUI(false);
    elseif arg1 == "show" then
        ShowGUI(true);
    elseif arg1 == "say"
        or arg1 == "share"
        or arg1 == "a"
        or arg1 == "announce"
        or arg1 == "yell"
        or arg1 == "tell" then

        if not WBT.InBossZone() then
            WBT:Print("You can't announce outside of a boss zone.");
            return;
        end

        local ki = WBT.KillInfoInCurrentZoneAndShard();
        if not ki or not(ki:IsValid()) then
            local msg = "No spawn timer for ";
            for _, boss in pairs(WBT.BossesInCurrentZone()) do
                msg = msg .. WBT.GetColoredBossName(boss.name) .. ", "
            end
            msg = msg:sub(0, -3); -- Remove the trailing ', '.

            WBT:Print(msg);
            return;
        end

        local error_msgs = {};
        if ki:IsCompletelySafe(error_msgs) then
            WBT.AnnounceSpawnTime(ki);
        else
            WBT:Print(Util.ColoredString(Util.COLOR_RED, "WARNING") .. ": Timer might be incorrect. Not announcing.", "SAY", nil, nil);
            for i, v in ipairs(error_msgs) do
                WBT:Print(Util.ColoredString(Util.COLOR_RED, i) .. ": " .. v, "SAY", nil, nil);
            end
        end
    elseif arg1 == "ann" then
        Config.auto_announce:Toggle();
    elseif arg1 == "r"
        or arg1 == "reset"
        or arg1 == "restart" then
        WBT.ResetKillInfo();
    elseif arg1 == "s"
        or arg1 == "saved"
        or arg1 == "save" then
        WBT.PrintKilledBosses();
    elseif arg1 == "request" then
        WBT.RequestKillData();
    elseif arg1 == "sound" then
        sound_type_args = {Config.SOUND_CLASSIC, Config.SOUND_FANCY};
        if Util.SetContainsValue(sound_type_args, arg2) then
            WBT.db.global.sound_type = arg2;
            WBT:Print("SoundType: " .. arg2);
        else
            Config.sound:Toggle();
        end
    elseif arg1 == "cyclic" then
        Config.cyclic:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "multi" then
        Config.multi_realm:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "zone" then
        Config.show_boss_zone_only:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "gui-reset" then
        WBT.GUI:ResetPosition();
    else
        PrintHelp();
    end
end

-- Counter so I don't have to increment order all the time.
-- Option items are ordered as they are inserted.
local t_cnt = { 0 };
function t_cnt:plusplus()
    self[1] = self[1] + 1;
    return self[1];
end

----- Options table -----
local desc_toggle = "Enable/Disable";
Config.optionsTable = {
  type = "group",
  childGroups = "select",
  args = {
    show = {
        name = "Show GUI",
        order = t_cnt:plusplus(),
        desc = desc_toggle,
        type = "toggle",
        width = "full",
        set = function(info, val) ShowGUI(val) end,
        get = function(info) return not WBT.db.global.hide_gui; end
    },
    show_boss_zone_only = {
        name = "Only show GUI in boss zones",
        order = t_cnt:plusplus(),
        desc = desc_toggle,
        type = "toggle",
        width = "full",
        set = function(info, val) Config.show_boss_zone_only:Toggle(); end,
        get = function(info) return Config.show_boss_zone_only.get() end,
    },
    sound = {
        name = "Sound",
        order = t_cnt:plusplus(),
        desc = desc_toggle,
        type = "toggle",
        width = "full",
        set = function(info, val) Config.sound:Toggle(); end,
        get = function(info) return Config.sound.get() end,
    },
    cyclic = {
        name = "Cyclic (show expired)",
        order = t_cnt:plusplus(),
        desc = "If you missed a kill, the timer will wrap around and will now have a red color",
        type = "toggle",
        width = "full",
        set = function(info, val) Config.cyclic:Toggle(); end,
        get = function(info) return Config.cyclic.get(); end,
    },
    auto_announce = {
        name = "Announce",
        order = t_cnt:plusplus(),
        desc = "Automatically announce spawn timers on certain time intervals",
        type = "toggle",
        width = "full",
        set = function(info, val) Config.auto_announce:Toggle(); end,
        get = function(info) return Config.auto_announce.get() end,
    },
    multi_realm = {
        name = "Multi-realm + Warmode",
        order = t_cnt:plusplus(),
        desc = "Show timers that are not for your current Realm or Warmode",
        type = "toggle",
        width = "full",
        set = function(info, val) Config.multi_realm:Toggle(); end,
        get = function(info) return Config.multi_realm.get() end,
    },
    highlight = {
        name = "Highlight boss in current zone",
        order = t_cnt:plusplus(),
        desc = "The boss in your current zone will have a different color if your Realm + Warmode matches the timer:\n" ..
                Util.ColoredString(Util.COLOR_LIGHTGREEN, "Green") .. " if timer not expired\n" ..
                Util.ColoredString(Util.COLOR_YELLOW, "Yellow") .." if timer expired (with Cyclic mode)",
        type = "toggle",
        width = "full",
        set = function(info, val) Config.highlight:Toggle(); end,
        get = function(info) return Config.highlight.get() end,
    },
    show_saved = {
        name = "Show if saved",
        order = t_cnt:plusplus(),
        desc = "Appends a colored 'X' (" .. Util.ColoredString(Util.COLOR_RED, "X") .. "/" .. Util.ColoredString(Util.COLOR_GREEN, "X") .. ")" ..
                " after the timer if you are saved for the boss.\n" ..
                "NOTE: The color of the 'X' has no special meaning, it's just for improved visibility.",
        type = "toggle",
        width = "full",
        set = function(info, val) Config.show_saved:Toggle(); end,
        get = function(info) return Config.show_saved.get() end,
    },
    spawn_alert_sound = {
        name = "Spawn alert sound",
        order = t_cnt:plusplus(),
        desc = "Sound alert that plays when boss spawns",
        type = "select",
        style = "dropdown",
        width = "normal",
        values = Config.spawn_alert_sound.kk,
        set = function(info, val) Config.spawn_alert_sound.set(val); end,
        get = function(info) return Config.spawn_alert_sound.get(); end,
    },
    spawn_alert_sec_before = {
        name = "Alert sec before spawn",
        order = t_cnt:plusplus(),
        desc = "How many seconds before boss spawns that alerts should happen",
        type = "range",
        min = 0,
        max = 60*5,
        softMin = 0,
        softMax = 30,
        bigStep = 1,
        isPercent = false,
        width = "normal",
        set = function(info, val) Config.spawn_alert_sec_before.set(val); end,
        get = function(info) return Config.spawn_alert_sec_before.get(); end,
    },
  }
}

