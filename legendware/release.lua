--local ffi = require("ffi")

--ffi.cdef[[
--    typedef void* LPUNKNOWN;
--    typedef void* LPBINDSTATUSCALLBACK;

--    void* __stdcall URLDownloadToFileA(
--        void* LPUNKNOWN, 
--        const char* LPCSTR, 
--        const char* LPCSTR2, 
--        int a, 
--        int LPBINDSTATUSCALLBACK
--    );

--    bool DeleteUrlCacheEntryA(
--        const char* lpszUrlName
--    );
--]]

--local urlmon = ffi.load 'UrlMon'
--local wininet = ffi.load 'WinInet'

--function download(from, to)
--    wininet.DeleteUrlCacheEntryA(from)
--    urlmon.URLDownloadToFileA(nil, from, to, 0,0)
--end

--
--
--

local appdataraw = os.getenv("appdata")
local appdata = string.gsub(appdataraw, "\\", "/")
local json = require("tyqwey-main/legendware/json")

--local url = "https://codeload.github.com/tolyareg/tyqwey/zip/refs/heads/main"
local directory = appdata.."/Legendware/Scripts/"
--local save_path = directory .. "tyqwey-main.zip"

local userdata
local grenade_locations
    
-- Теперь вы можете использовать модуль json для работы с данными
local file_name = io.open(directory .. "userdata.txt", "r")
if not file_name then
    file_name = io.open(directory .. "userdata.txt", "w")
    file_name:close()

    print("Файл userdata.txt создан")
    userdata = ""
else
    userdata = file_name:read("*a")
    file_name:close()
end

local console_weapon_id = {
    CFlashbang = "weapon_flashbang",
    CHEGrenade = "weapon_hegrenade",
    CSmokeGrenade = "weapon_smokegrenade",
    CMolotovGrenade = "weapon_molotov",
    CIncendiaryGrenade = 'weapon_molotov',
    CKnife = "weapon_knife"
}

--
--
--

local Settings, icon_images = {}, {}
local anim_contents = {}

local creating_new_table = false
local save_boolean, new_location

local NULL = 0
local VECTOR_NULL = vector.new(0, 0, 0)
local MAX_DIST_SELECT = 18*18

--
--
--

local user_locations = (userdata == "") and {} or json.decode(userdata)
local function loadJsonData(host, link)
    local success, response = pcall(http.get, host, link)
    if success then
        return response
    else
        return nil
    end
end

local json_data = loadJsonData("https://pastebin.com", "/raw/iBEcHWBS")

if json_data then
    -- Декодирование JSON
    local success, locations = pcall(json.decode, json_data)
    if success then
        locations = json.decode(json_data)
        grenade_locations = locations
    end
else
    print("Ошибка загрузки данных с сервера")
end

function is_grenade_being_thrown(weapon, cmd)
	local pin_pulled = weapon:get_prop_bool('CBaseCSGrenade', "m_bPinPulled")

	if pin_pulled ~= nil then
		if pin_pulled == false then
			local throw_time = weapon:get_prop_float('CBaseCSGrenade', "m_fThrowTime")

            if throw_time ~= nil and throw_time > globals.get_curtime() and throw_time ~= 0 then
                return true
            end
		end
	end
	return false
end

function get_weapon_name(player)
    local weapon_entity = entitylist.get_weapon_by_player(player)
    if weapon_entity ~= nil then
        return weapon_entity
    else
        return nil
    end
end

function table_clear(tbl)
	for key in pairs(tbl) do 
		tbl[key] = nil
	end
end

for weapon_name, file_title in pairs(console_weapon_id) do
    local data = file.read(appdata.."/Legendware/Scripts/tyqwey-main/legendware/" .. file_title .. ".png")
    icon_images[weapon_name] = render.create_image(data)
end

local data_settings = file.read(appdata.."/Legendware/Scripts/tyqwey-main/legendware/debug.png")
local debug_setting_icon = render.create_image(data_settings)

local data_warning = file.read(appdata.."/Legendware/Scripts/tyqwey-main/legendware/warning.png")
local debug_warning_icon = render.create_image(data_warning)

--
-- 
--

local function operate(a, b, operation)
    local result = {}
    if type(a) == "number" then
        if type(b) == "table" then
            for i = 1, 3 do
                result[i] = operation(a, b[i] or 0)
            end
        else
            error("Invalid type for b: " .. type(b))
        end
    elseif type(b) == "number" then
        if type(a) == "table" then
            for i = 1, 3 do
                result[i] = operation(a[i] or 0, b)
            end
        else
            error("Invalid type for a: " .. type(a))
        end
    else
        for i = 1, 3 do
            result[i] = operation(a[i] or 0, b[i] or 0)
        end
    end
    return vector.new(result[1], result[2], result[3])
end

function operateVector(a, b, operation)
    local result = vector.new(0, 0, 0)
    if type(a) == "userdata" then
        local ax, ay, az = a.x or 0, a.y or 0, a.z or 0
        if type(b) == "number" then
            result = vector.new(operation(ax, b), operation(ay, b), operation(az, b))
        elseif type(b) == "userdata" then
            local bx, by, bz = b.x or 0, b.y or 0, b.z or 0
            result = vector.new(operation(ax, bx), operation(ay, by), operation(az, bz))
        elseif type(b) == "table" then
            result = vector.new(operation(ax, b[1] or 0), operation(ay, b[2] or 0), operation(az, b[3] or 0))
        end
    elseif type(a) == "table" then
        if type(b) == "number" then
            result = vector.new(operation(a[1] or 0, b), operation(a[2] or 0, b), operation(a[3] or 0, b))
        elseif type(b) == "table" then
            result = vector.new(operation(a[1] or 0, b[1] or 0), operation(a[2] or 0, b[2] or 0), operation(a[3] or 0, b[3] or 0))
        elseif type(b) == "userdata" then
            local bx, by, bz = b.x or 0, b.y or 0, b.z or 0
            result = vector.new(operation(a[1] or 0, bx), operation(a[2] or 0, by), operation(a[3] or 0, bz))
        end
    elseif type(a) == "number" then
        if type(b) == "number" then
            result = operation(a, b)
        elseif type(b) == "userdata" then
            local bx, by, bz = b.x or 0, b.y or 0, b.z or 0
            result = vector.new(operation(a, bx), operation(a, by), operation(a, bz))
        elseif type(b) == "table" then
            result = vector.new(operation(a, b[1] or 0), operation(a, b[2] or 0), operation(a, b[3] or 0))
        end
    end
    return result
end

Settings = {
    data_call = {},
    delay_call = function(time, fn)
        table.insert(Settings.data_call, {
            fn = fn,
            time = time,
            realtime = globals.get_realtime()
        })
    
        client.add_callback("on_paint", function()
            for i, data in ipairs(Settings.data_call) do
                if data.realtime + data.time < globals.get_realtime() then
                    data.fn()
                    data.realtime = globals.get_realtime()
                end
            end
        end)
    end,

    Initialize = {
        Font = {
            verdana_antialias = render.create_font(
                "Verdana",
                12,
                100,
                true
            ),
            verdana_debug = render.create_font(
                "tahoma",
                12,
                100
            ),
            DEBUG_font = render.create_font(
                "tahoma",
                13,
                1000,
                true
            ),
            icon = render.create_font(
                "undefeated",
                16,
                100,
                true
            )
        }
    },

    Math = {
        Angle = function(angle) -- angle to vector
            if not angle.x or not angle.y then
                return VECTOR_NULL
            end
    
            local pitch_rad = math.rad(angle.x)
            local yaw_rad = math.rad(angle.y)
    
            local x = angle.z * math.cos(pitch_rad) * math.cos(yaw_rad)
            local y = angle.z * math.cos(pitch_rad) * math.sin(yaw_rad)
            local z = -angle.z * math.sin(pitch_rad)
    
            return vector.new(x, y, z)
        end,
    
        World = function(view, pos) -- vector in world
            local angles = vector.new(
                view.x * 400 + pos.x,
                view.y * 400 + pos.y,
                view.z * 400 + pos.z + 80
            );
            return angles
        end,
    
        Sub = function(a, b)
            return operateVector(a, b, function(x, y) return x - y end)
        end,
        
        Add = function(a, b)
            return operateVector(a, b, function(x, y) return x + y end)
        end,
    
        Velocity = function(vec, yaw) -- vector is player velocity
            local x = vec.x * math.cos(yaw / 180 * math.pi) + vec.y * math.sin(yaw / 180 * math.pi)
            local y = vec.y * math.cos(yaw / 180 * math.pi) - vec.x * math.sin(yaw / 180 * math.pi)
            local z = vec.z
    
            return x, y, z
        end,
    
        ForwardVector = function(yaw)
            local radians = math.rad(yaw)
            
            local x = math.cos(radians)
            local y = math.sin(radians)
            
            return { x = x, y = y }
        end,
    
        PosClose = function(start, close, range)
            local distance_squared = (start[1] - close[1])^2 + (start[2] - close[2])^2 + (start[3] - close[3])^2
            return distance_squared <= range^2
        end,
    
        AngMove = function(angle)
            local angle_rad = math.rad(angle)
    
            local forward_move = math.cos(angle_rad) * 450.0
            local side_move = math.sin(angle_rad) * 450.0
    
            return forward_move, side_move
        end,
        
        NormalizeAngle = function(angle)
            angle = angle % 360
            
            if angle < 0 then
                angle = angle + 360
            end
            
            return angle
        end,
    
        Clamp = function(val, lower, upper)
            return math.max(lower, math.min(upper, val))
        end,

        Lerp = function(start, finish, t)
            return start + (finish - start) * math.sin(t * math.pi / 2)
        end,
    
        ColorLerp = function(color1, color2, t)
            local r = color1:r() + (color2:r() - color1:r()) * math.sin(t * math.pi / 2)
            local g = color1:g() + (color2:g() - color1:g()) * math.sin(t * math.pi / 2)
            local b = color1:b() + (color2:b() - color1:b()) * math.sin(t * math.pi / 2)
            local a = color1:a() + (color2:a() - color1:a()) * math.sin(t * math.pi / 2)
            
            return color.new(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
        end
    },
    Location = {
        ClosestTarget = function(current_pos, view, locations, grenade_name, epsilon)
            local closest_air = math.huge
            local closest_location
    
            for _, location in pairs(locations) do
                if location.position and location.viewangles and location.weapon == grenade_name then
                    local distance = vector.dist_to(
                        current_pos, 
                        vector.new(
                            location.position[1], 
                            location.position[2], 
                            location.position[3]
                        )
                    );
    
                    if distance <= epsilon then
                        local air_distance = vector.dist_to(
                            vector.new(
                                location.viewangles[1], 
                                location.viewangles[2], 
                                0
                            ), 
                            view
                        );
                        if air_distance < closest_air then
                            closest_air = air_distance
                            closest_location = location
                        end
                    end
                end
            end
    
            return closest_location, closest_air
        end,
        AngleToVec = function(pitch, yaw) 
            if pitch ~= nil then 
                local p = pitch * math.pi / 180
                local y = yaw * math.pi / 180
        
                local sin_p = math.sin(p)
                local cos_p = math.cos(p)
                local sin_y = math.sin(y)
                local cos_y = math.cos(y)
        
                return vector.new(cos_p * cos_y, cos_p * sin_y, -sin_p)
            end
            return VECTOR_NULL;
        end,
    }
}

--
--
--

local playback_begin, playback_weapon, playback_state, playback_progress
local playback_data = {}

local FL_ONGROUND = 1
local GRENADE_PLAYBACK_PREPARE = 1
local GRENADE_PLAYBACK_RUN = 2
local GRENADE_PLAYBACK_THROW = 3
local GRENADE_PLAYBACK_THROWN = 4
local GRENADE_PLAYBACK_FINISHED = 5


local menu_items = {
    space = menu.next_line(),

    -- hotkey
    key_bind = menu.add_key_bind("Helper"),
    create_loc = menu.add_check_box("create loc"),

    -- run elements
    duration = menu.add_slider_int("run duration", 0, 256),
    run_yaw = menu.add_slider_int("run yaw", -180, 180),
    recovery_yaw = menu.add_slider_int("recovery yaw", -180, 180),
    walk_bool = menu.add_check_box("walk (shift)"),
    extend_forward = menu.add_check_box("extend forward"),
    
    -- jump elements
    jump_bool = menu.add_check_box("jump bool"),
    duck_bool = menu.add_check_box("duck bool"),
    recovery_jump = menu.add_check_box("recovery jump"),
    throw_strenght = menu.add_combo_box("throw strength", {"Default", "Left/Right", "Right"}),
    delay = menu.add_slider_int("delay", 0, 45),

    debug_info = menu.add_check_box("debug info in create nade"),
    ready_loc = menu.add_check_box("Added location"),

    -- save
    smoothing = menu.get_int("misc.smoothing"),
    fast_stop = menu.get_bool("misc.fast_stop"),
    strafe = menu.get_int("misc.automatic_strafe"),

    fakelag = menu.get_bool("anti_aim.enable_fake_lag"),
    desync_type = menu.get_int("anti_aim.desync_type")
}

local function create_new_location()
    -- Инициализация переменных
    local local_player = entitylist.get_local_player()
    local eye_position = local_player:get_origin()
    local view_angles = engine.get_view_angles()
    local map_short = engine.get_level_name_short()

    local weapon = get_weapon_name(local_player):get_class_name()
    local console_weapon = console_weapon_id[weapon]

    if menu.get_bool("create loc") then
        -- обнуляем таблицу
        if not new_location then
            new_location = {}
        end

        if not creating_new_table then
            -- Создание новой локации и добавление ее в массив
            new_location.name = {"Unnamed", "User debug"}
            new_location.weapon = console_weapon
            new_location.grenade = {}
            new_location.duck = false
            new_location.position = {eye_position.x, eye_position.y, eye_position.z}
            new_location.viewangles = {view_angles.x, view_angles.y}

            local properties = new_location.grenade
            if properties == nil then
                new_location.grenade = {}
                properties = new_location.grenade
            end

            if menu.get_int("run yaw") ~= 0 then 
                properties.run_yaw = menu.get_int("run yaw") 
            end

            if menu.get_int("run duration") ~= 0 then 
                properties.run = menu.get_int("run duration") 
            end

            if menu.get_int("recovery yaw") ~= 0 and menu.get_int("run duration") ~= 0 then 
                properties.recovery_yaw = menu.get_int("recovery yaw") 
            end

            if menu.get_bool("recovery jump") then 
                properties.recovery_jump = true
            end

            if menu.get_bool("jump bool") then 
                properties.jump = true 
            end

            if menu.get_bool("extend forward") then 
                properties.extend_forward = true 
            end

            if menu.get_int("delay") ~= 0 then 
                properties.delay = menu.get_int("delay") 
            end

            if menu.get_bool("duck bool") then 
                new_location.duck = true 
            end

            if menu.get_bool("walk (shift)") then 
                properties.run_speed = true 
            end

            if menu.get_int("throw strength") == 0 then
                properties.strength = 1
            end

            if menu.get_int("throw strength") == 1 then
                properties.strength = 0.5
            end

            if menu.get_int("throw strength") == 2 then
                properties.strength = 0
            end

            -- кидаем созданную локацию уже к существующим
            if not grenade_locations[map_short] then
                grenade_locations[map_short] = {}
            end

            -- вот он этот процесс
            table.insert(grenade_locations[map_short], new_location)
            creating_new_table = true
        else
            -- Обновление значений в new_location, если они изменились в меню
            local properties = new_location.grenade

            local extend_forward = menu.get_bool("extend forward")
            local recovery_jump = menu.get_bool("recovery jump")
            local run_duration = menu.get_int("run duration")
            local recovery_yaw = menu.get_int("recovery yaw")
            local jump_boolean = menu.get_bool("jump bool")
            local duck_boolean = menu.get_bool("duck bool")
            local run_speed = menu.get_bool("walk (shift)")
            local strength = menu.get_int("throw strength")
            local run_yaw = menu.get_int("run yaw")
            local delay = menu.get_int("delay")

            if strength == 0 then
                properties.strength = nil
            end

            if strength == 1 then
                properties.strength = 0.5
            end

            if strength == 2 then
                properties.strength = 0
            end

            properties.delay = delay~=0 and delay or nil
            properties.run_yaw = run_yaw~=0 and run_yaw or nil
            properties.run = run_duration~=0 and run_duration or nil
            properties.run_speed = run_speed and run_speed or nil
            properties.jump = jump_boolean and jump_boolean or nil
            new_location.duck = duck_boolean and duck_boolean or nil
            properties.recovery_yaw = recovery_yaw~=0 and recovery_yaw or nil
            properties.recovery_jump = recovery_jump and recovery_jump or nil
            properties.extend_forward = extend_forward and extend_forward or nil 

            if run_duration == 0 then
                properties.recovery_yaw = nil
                properties.run_speed = nil
                properties.run_yaw = nil
            end

            if not jump_boolean then
                properties.delay = nil
            end
        end
    else
        creating_new_table = false
    end
end

function print_nade()
    local hotkey_add = menu.get_bool("Added location")
    local map_short = engine.get_level_name_short()

    if new_location == nil then
        return
    end

    if hotkey_add and save_boolean == nil then
        local location_to_print = {
            name = new_location.name,
            position = new_location.position,
            weapon = new_location.weapon,
            viewangles = new_location.viewangles,
            grenade = new_location.grenade,
            duck = new_location.duck
        }

        if not grenade_locations[map_short] then
            grenade_locations[map_short] = {}
        end

        add_location_and_save("userdata.txt", location_to_print)
        table.insert(grenade_locations[map_short], location_to_print)

        print("New location created and saved.")
        save_boolean = true
    elseif not hotkey_add then
        save_boolean = nil
    end
end

function pretty_json(json_string)
    local indent = "\t"
    local result = {} -- таблица для накопления результатов
    local in_string = false
    local current_indent = ""

    for i = 1, #json_string do
        local char = json_string:sub(i, i)

        if char == '"' then
            in_string = not in_string
            table.insert(result, '"')
        elseif not in_string then
            if char == "{" or char == "[" then
                table.insert(result, char)
                current_indent = current_indent .. indent
                table.insert(result, "\n" .. current_indent)
            elseif char == "}" or char == "]" then
                current_indent = current_indent:sub(1, #current_indent - #indent)
                table.insert(result, "\n" .. current_indent)
                table.insert(result, char)
            elseif char == "," then
                table.insert(result, char)
                table.insert(result, "\n" .. current_indent)
            else
                table.insert(result, char)
            end
        else
            table.insert(result, char)
        end
    end

    -- Используем table.concat для преобразования таблицы обратно в строку
    return table.concat(result)
end

function debug_render_info()
    local debug_info_boolean = menu.get_bool("debug info in create nade")
    local create_nade_boolean = menu.get_bool("create loc")
    local frame = globals.get_frametime()*8

    local screen_size = {
        x = engine.get_screen_width(),
        y = engine.get_screen_height()
    }

    local sx_center = screen_size.x/2.45
    local sy_center = screen_size.y/10.0

    local max_offset = 0

    anim_contents.container_alpha = anim_contents.container_alpha or 0.0
    anim_contents.container_alpha = Settings.Math.Lerp(
        anim_contents.container_alpha, 
        debug_info_boolean and 1 or 0, 
        frame
    );

    local DEFAULTS = {
        extend_forward = menu.get_bool("extend forward"),
        recovery_jump = menu.get_bool("recovery jump"),
        run_duration = menu.get_int("run duration"),
        recovery_yaw = menu.get_int("recovery yaw"),
        jump_boolean = menu.get_bool("jump bool"),
        duck_boolean = menu.get_bool("duck bool"),
        run_speed = menu.get_bool("walk (shift)"),
        strength = menu.get_int("throw strength"),
        run_yaw = menu.get_int("run yaw"),
        delay = menu.get_int("delay")
    };


    if anim_contents.container_alpha < 0.01 then
        if not debug_info_boolean then
            return
        end
    end

    local visibility_offset = not(
        DEFAULTS.extend_forward == false and DEFAULTS.recovery_jump == false 
        and DEFAULTS.run_duration == 0 and DEFAULTS.recovery_yaw == -180 
        and DEFAULTS.jump_boolean == false and DEFAULTS.duck_boolean == false
        and DEFAULTS.run_speed == false and DEFAULTS.strength == 0 
        and DEFAULTS.run_yaw == -180 and DEFAULTS.delay == 0
    );

    anim_contents.visibility_alpha = anim_contents.visibility_alpha or 0.0
    anim_contents.visibility_alpha = Settings.Math.Lerp(anim_contents.visibility_alpha, visibility_offset and 100 or 74, frame)

    if new_location then
        local icon_setting = debug_setting_icon
        local icon_warning = debug_warning_icon
        local DEFAULT_OPACITY = 220
        local interval = 20

        local color_t = {
            a = anim_contents.container_alpha,

            ui_table = {
                r = 176, 
                g = 36, 
                b = 55
            },

            ui_bases = {
                r = 210,
                g = 210,
                b = 210
            },

            ui_warns = {
                r = 246, 
                g = 216, 
                b = 5
            },

            ui_boxes = {
                r = 16,
                g = 16,
                b = 16
            },
        };

        local color_section = {
            table = color.new(
                color_t.ui_table.r,
                color_t.ui_table.g,
                color_t.ui_table.b,
                math.floor(color_t.a*DEFAULT_OPACITY)
            ),

            bases = color.new(
                color_t.ui_bases.r,
                color_t.ui_bases.g,
                color_t.ui_bases.b,
                math.floor(color_t.a*DEFAULT_OPACITY)
            ),

            warns = color.new(
                color_t.ui_warns.r,
                color_t.ui_warns.g,
                color_t.ui_warns.b,
                math.floor(color_t.a*DEFAULT_OPACITY)
            ),

            boxes = color.new(
                color_t.ui_boxes.r,
                color_t.ui_boxes.g,
                color_t.ui_boxes.b,
                math.floor(color_t.a*165*0.7)
            ),
        };

        local names = {
            edit = "Editing Location:",
            warn = "You have unsaved changes! Make sure to click Added.",
            DEBUG = {
                bracket1 = "[",
                bracket2 = "]",
                comma = ",",
                colon = ":"
            }
        };

        local debug_info = {
            {
                name = new_location.name, 
                text = string.format(
                    'name: ["%s", "%s"]', 
                    new_location.name[1], 
                    new_location.name[2]
                );
            },
            {
                name = new_location.weapon, 
                text = string.format(
                    'weapon: "%s"', 
                    new_location.weapon
                );
            },
            {
                name = new_location.position, 
                text = string.format(
                    "position: [%s, %s, %s]", 
                    new_location.position[1], 
                    new_location.position[2], 
                    new_location.position[3]
                );
            },
            {
                name = new_location.viewangles, 
                text = string.format(
                    "viewangles: [%s, %s]", 
                    new_location.viewangles[1], 
                    new_location.viewangles[2]
                );
            }
        };
        
        -- Добавляем информацию о гранатах
        for index, table_contains in pairs(new_location.grenade) do
            local property_exists = table_contains ~= nil
        
            if property_exists then
                table.insert(debug_info, { 
                    name = index, 
                    text = string.format(
                        "grenade.%s: %s", 
                        index, 
                        tostring(table_contains)
                    )
                });
                max_offset = max_offset + 12
            end
        end
        
        -- Добавляем информацию о duck
        if new_location.duck then
            table.insert(debug_info, { 
                name = "duck",
                text = string.format(
                    "duck: %s", 
                    tostring(new_location.duck)
                )
            });
            max_offset = max_offset + 12
        end

        local text_width = render.get_text_width(
            Settings.Initialize.Font.verdana_antialias, 
            string.format(
                "position: [%s, %s, %s],", 
                new_location.position[1], 
                new_location.position[2],
                new_location.position[3]
            )
        );

        -- Обновляем высоту прямоугольника
        local rect_width = text_width+10
        local rect_height = anim_contents.visibility_alpha+max_offset
        
        local sx_text = sx_center+interval
        local sy_text = sy_center+6

        if rect_width and rect_height then
            local color_section_boxes = color_section.boxes
            local color_section_bases = color_section.bases
            local text_edit = names.edit

            render.draw_rect_filled(
                sx_center, 
                sy_center, 
                rect_width, 
                rect_height, 
                color_section_boxes
            );

            --render.draw_rect(
            --    sx_center, 
            --    sy_center, 
            --    rect_width, 
            --    rect_height, 
            --    color_section_boxes
            --);

            render.draw_text(
                Settings.Initialize.Font.verdana_antialias, 
                sx_text, 
                sy_text, 
                color_section_bases, 
                text_edit
            );
        end

        -- шестеренка
        if icon_setting then
            local settings_x = sx_center+4
            local settings_y = sy_center+6

            local sx_settings = math.floor(settings_x)
            local sy_settings = math.floor(settings_y)
            local inter = 12

            if anim_contents.container_alpha > 0.4 then
                render.draw_image(
                    sx_settings, 
                    sy_settings, 
                    sx_settings+inter, 
                    sy_settings+inter, 
                    icon_setting
                );
            end
        end

        -- предупреждение что чувак не сохранил
        if visibility_offset then
            local warning_x = sx_center+interval
            local warning_y = sy_center+max_offset+(interval*4)

            if rect_height > 85 then
                local verdana_a = Settings.Initialize.Font.verdana_antialias
                local color_section_warns = color_section.warns
                local text_warning = names.warn

                render.draw_text(
                    verdana_a, 
                    warning_x, 
                    warning_y, 
                    color_section_warns, 
                    text_warning
                );

                if icon_warning then
                    local settings_x = sx_center+4
                    local settings_y = sy_center+max_offset+(interval*4)

                    local sx_settings = math.floor(settings_x)
                    local sy_settings = math.floor(settings_y)
                    local inter = 12

                    if anim_contents.container_alpha > 0.4 then
                        render.draw_image(
                            sx_settings, 
                            sy_settings, 
                            sx_settings+inter, 
                            sy_settings+inter, 
                            icon_warning
                        );
                    end
                end
            end
        end

        local text_x = sx_center+6
        local text_y = sy_center+interval
        local line_offset = 12

        for _, info in ipairs(debug_info) do
            local info_text = info.text
            local colon = names.DEBUG.colon
            local comma = names.DEBUG.comma
            local bracket1 = names.DEBUG.bracket1
            local bracket2 = names.DEBUG.bracket2

            local colon_index = string.find(info_text, colon)
            if colon_index then
                local first_part = string.sub(info_text, 1, colon_index)
                local second_part = string.sub(info_text, colon_index + 1)
            
                local verdana_a = Settings.Initialize.Font.verdana_antialias
                local color_bases = color_section.bases
                local color_table = color_section.table
            
                render.draw_text(verdana_a, text_x, text_y, color_bases, first_part)
            
                local text_width = render.get_text_width(verdana_a, first_part)
                local current_x = text_x + text_width
            
                for i = 1, #second_part do
                    local char = second_part:sub(i, i)
                    local char_color = color_bases
            
                    if char == bracket1 or char == bracket2 or char == comma then
                        char_color = color_table
                    end
            
                    render.draw_text(verdana_a, current_x, text_y, char_color, char)
                    current_x = current_x + render.get_text_width(verdana_a, char)
                end
            end
            
            text_y = text_y + line_offset
        end            
    end
end

local tickrates_mt = {
	__index = function(tbl, key)
		if tbl.tickrate ~= nil then
			return key / tbl.tickrate
		end
	end
}

AngleToRight = function(angle)
    local yaw = angle.y * (math.pi / 180)

    local x = -math.sin(yaw)
    local y = math.cos(yaw)

    return vector.new(x, y, 0)
end

AngleToForward = function(angle)
    local pitch = angle.x * (math.pi / 180)
    local yaw = angle.y * (math.pi / 180)

    local x = math.cos(pitch) * math.cos(yaw)
    local y = math.cos(pitch) * math.sin(yaw)

    return vector.new(x, y, 0)
end

local function cmd_remove_user_input(cmd)
    cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_forward))
    cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_back))
    cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_moveleft))
    cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_moveright))

	cmd.forwardmove = 0
	cmd.sidemove = 0

    cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_jump))
    cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_speed))
end

function updateRunningState(cmd, local_player, weapon)
    if location_playback == nil then
        menu.set_int("misc.smoothing", menu_items.smoothing)
        menu.set_int("misc.automatic_strafe", menu_items.strafe)
        menu.set_bool("anti_aim.enable_fake_lag", menu_items.fakelag)
        menu.set_int("anti_aim.desync_type", menu_items.desync_type)
        return
    end

    if location_playback.grenade == nil then
        console.execute("-attack")
        location_playback = nil
        playback_state = nil
        return
    end

    location_playback.grenade.run_yaw = location_playback.grenade.run_yaw or 0
    location_playback.grenade.run_speed = location_playback.grenade.run_speed or false
    location_playback.grenade.jump = location_playback.grenade.jump or false
    location_playback.grenade.run = location_playback.grenade.run or nil
    location_playback.grenade.delay = location_playback.grenade.delay or (location_playback.grenade.run == nil and 1 or 0)
    location_playback.grenade.strength = location_playback.grenade.strength or 1

    playback_data.tickrates = setmetatable({
        tickrate = location_playback.tickrate or 64,
        tickrate_set = location_playback.tickrate ~= nil
    }, tickrates_mt)

    cmd.viewangles.x = location_playback.viewangles[1]
    cmd.viewangles.y = location_playback.viewangles[2]
    
    local tickrate = 1/globals.get_intervalpertick()
    local tickrate_mp = playback_data.tickrates[tickrate]

    if playback_state == nil then
        playback_state = GRENADE_PLAYBACK_PREPARE
        table_clear(playback_data)
    end

    if weapon ~= playback_weapon and playback_state ~= GRENADE_PLAYBACK_FINISHED then
        location_playback = nil
        playback_progress = false
        return
    end

    if playback_state == GRENADE_PLAYBACK_PREPARE and weapon:get_prop_float('CBaseCSGrenade', "m_flThrowStrength") == location_playback.grenade.strength then
        playback_state = GRENADE_PLAYBACK_RUN
        playback_data.start_at = cmd.tickcount
    end

    if playback_state == GRENADE_PLAYBACK_PREPARE or playback_state == GRENADE_PLAYBACK_RUN or playback_state == GRENADE_PLAYBACK_THROWN then
        if location_playback.grenade.strength == 1 then
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_attack)
            cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_attack2))
        elseif location_playback.grenade.strength == 0.5 then
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_attack)
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_attack2)
        elseif location_playback.grenade.strength == 0 then
            cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_attack))
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_attack2)
        end
    end

    if playback_state == GRENADE_PLAYBACK_RUN or playback_state == GRENADE_PLAYBACK_THROW or playback_state == GRENADE_PLAYBACK_THROWN then
        menu.set_int("misc.automatic_strafe", 0)

        local step = cmd.tickcount-playback_data.start_at

        if location_playback.grenade.run ~= nil and location_playback.grenade.run*tickrate_mp > step then
        elseif playback_state == GRENADE_PLAYBACK_RUN then
            playback_state = GRENADE_PLAYBACK_THROW
        end

        if location_playback.grenade.run ~= nil then
            local forward_move, side_move = Settings.Math.AngMove(location_playback.grenade.run_yaw)
            cmd.forwardmove = forward_move
            cmd.sidemove = -side_move
        end

        if location_playback.grenade.run_speed then
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_speed)
        end

        if location_playback.duck then
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_duck)
        end
    end

    if playback_state == GRENADE_PLAYBACK_THROW then
        if location_playback.grenade.jump then
            cmd.buttons = bit.bor(cmd.buttons, buttons.in_jump)
        end

        playback_state = GRENADE_PLAYBACK_THROWN
        playback_data.throw_at = cmd.tickcount
    end  

    playback_progress = true

    if playback_state == GRENADE_PLAYBACK_THROWN then 
        if location_playback.grenade.extend_forward then
            local extend_duration = 0.01
    
            if not playback_data.extended_started then
                if cmd.tickcount - playback_data.throw_at > location_playback.grenade.delay+1 then
                    playback_data.extended_started = true
                    playback_data.extend_start_time = cmd.tickcount
                end
            end
    
            if playback_data.extended_started then
                local elapsed_time = cmd.tickcount - playback_data.extend_start_time
    
                -- Проверяем, прошло ли достаточное время для увеличения разброса
                if elapsed_time <= extend_duration then
                    -- Получаем направление движения игрока
                    local player_forward = AngleToForward(vector.new(0, cmd.viewangles.y, 0))
                    local player_side = AngleToRight(vector.new(0, cmd.viewangles.y, 0))
    
                    -- Рассчитываем вектор движения гранаты относительно направления движения игрока
                    local move_direction = vector.new(player_forward.x, player_forward.y, 0)
                    local smooth_factor = math.min(1, elapsed_time / extend_duration)
    
                    -- Рассчитываем новый вектор движения гранаты с учетом разброса
                    local forwardmove = move_direction.x * 450.0 * smooth_factor
                    local sidemove = move_direction.y * 450.0 * smooth_factor
    
                    menu.set_int("misc.automatic_strafe", 2)
                    menu.set_int("misc.smoothing", console.get_float("sv_airaccelerate") >= 102 and 0 or 50)
                    cmd.forwardmove = forwardmove
                    cmd.sidemove = sidemove
                else
                    -- Превышено время выполнения extend_forward, сбросить настройки
                    playback_data.extended_started = false
                    playback_data.extend_start_time = nil
                    menu.set_int("misc.automatic_strafe", 0)
                end
            end
        end
        
        if cmd.tickcount - playback_data.throw_at >= location_playback.grenade.delay then
            menu.set_bool("anti_aim.enable_fake_lag", false)
            menu.set_int("anti_aim.desync_type", 0)

            cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_attack))
            cmd.buttons = bit.band(cmd.buttons, bit.bnot(buttons.in_attack2))
        end
    end
    
    if playback_state == GRENADE_PLAYBACK_FINISHED then
        if location_playback.grenade.jump then
            local onground = bit.band(local_player:get_prop_int("CBasePlayer", "m_fFlags"), FL_ONGROUND) == FL_ONGROUND

            if onground then
                playback_state = nil
				location_playback = nil
                playback_progress = false

                menu.set_int("misc.smoothing", menu_items.smoothing)
                menu.set_int("misc.automatic_strafe", menu_items.strafe)
                menu.set_bool("anti_aim.enable_fake_lag", menu_items.fakelag)
                menu.set_int("anti_aim.desync_type", menu_items.desync_type)
            else

                -- recovery strafe after throw
                if cmd.buttons ~= buttons.in_forward and cmd.buttons ~= buttons.in_back and cmd.buttons ~= buttons.in_moveleft and cmd.buttons ~= buttons.in_moveright and cmd.buttons ~= buttons.in_jump then
                    cmd_remove_user_input(cmd)

                    local forward_move, side_move = Settings.Math.AngMove(location_playback.grenade.recovery_yaw or location_playback.grenade.run_yaw-180)

                    cmd.forwardmove = forward_move
                    cmd.sidemove = -side_move

                    if location_playback.grenade.recovery_jump then
                        cmd.buttons = bit.bor(cmd.buttons, location_playback.grenade.recovery_jump and buttons.in_jump or 0)
                    end
                end
            end
        elseif location_playback.grenade.recovery_yaw ~= nil then
            if cmd.buttons ~= buttons.in_forward and cmd.buttons ~= buttons.in_back and cmd.buttons ~= buttons.in_moveleft and cmd.buttons ~= buttons.in_moveright and cmd.buttons ~= buttons.in_jump then
                if playback_data.recovery_start_at == nil then
                    playback_data.recovery_start_at = cmd.command_number
                end

                local recovery_duration = math.min(32, location_playback.grenade.run or 16) + 13 + (location_playback.grenade.recovery_jump and 10 or 0)

                if playback_data.recovery_start_at + recovery_duration >= cmd.command_number then
                    local forward_move, side_move = Settings.Math.AngMove(location_playback.grenade.recovery_yaw)

                    --
                    cmd.forwardmove = forward_move
                    cmd.sidemove = -side_move

                    if location_playback.grenade.recovery_jump ~= nil then
                        cmd.buttons = bit.bor(cmd.buttons, location_playback.grenade.recovery_jump and buttons.in_jump or 0)
                    end
                end
            else
                location_playback = nil
                playback_progress = false
            end
        end
    end

    if playback_state == GRENADE_PLAYBACK_THROWN then
		-- true if this is the last tick of the throw, here we can start resetting stuff
		if is_grenade_being_thrown(weapon, cmd) then
			playback_data.thrown_at = cmd.command_number
        end

		if weapon:get_prop_float('CBaseCSGrenade', "m_fThrowTime") == 0 and playback_data.thrown_at ~= nil  then
			playback_state = GRENADE_PLAYBACK_FINISHED
            menu.set_int("misc.smoothing", console.get_float("sv_airaccelerate") >= 102 and 0 or 50)
            menu.set_int("misc.automatic_strafe", 2)

			-- timeout incase user starts noclipping after throwing or something
			local begin = playback_begin
			Settings.delay_call(0.6, function()
				if playback_state == GRENADE_PLAYBACK_FINISHED and playback_begin == begin then
                    menu.set_int("misc.smoothing", menu_items.smoothing)
                    menu.set_int("misc.automatic_strafe", menu_items.strafe)
                    menu.set_bool("anti_aim.enable_fake_lag", menu_items.fakelag)
                    menu.set_int("anti_aim.desync_type", menu_items.desync_type)

					location_playback = nil
                    playback_progress = false
				end
			end)
		end
	end

    --if location_playback == nil or playback_state == nil then
    --    menu.set_int("misc.smoothing", menu_items.smoothing)
    --    menu.set_int("misc.automatic_strafe", menu_items.strafe)
    --end
end

function main(cmd, epsilon)
    local local_player = entitylist.get_local_player()

    if local_player:get_health() <= 0 then
        return
    end

    local current_pos = local_player:get_origin()
    local grenade_name = get_weapon_name(local_player):get_class_name()
    local map_name = engine.get_level_name_short()
    local data = grenade_locations[map_name]

    local velocity = local_player:get_velocity():length_2d()

    if not data then 
        return 
    end

    local weapon = get_weapon_name(local_player)
    local console_name = console_weapon_id[grenade_name]

    local view = engine.get_view_angles()

    local hotkey = menu.get_key_bind_state("Helper")
    if hotkey then
        if cmd.buttons == 1 then
            closest_location, closest_air = Settings.Location.ClosestTarget(current_pos, view, data, console_name, epsilon)
            --dista
        end
    end

    local correct_button = (cmd.buttons == buttons.in_attack or cmd.buttons == buttons.in_attack+buttons.in_duck)
    
    if location_playback ~= nil then
        local weapon = get_weapon_name(local_player)
        
        updateRunningState(cmd, local_player, weapon)
    elseif closest_location ~= nil and hotkey and correct_button and velocity < 5 and 
    vector.dist_to(current_pos, vector.new(
        closest_location.position[1],
        closest_location.position[2],
        closest_location.position[3]
    )) < 0.2 then
        --local pin_pulled = weapon:get_prop_bool('CBaseCSGrenade', "m_bPinPulled") == 1
        --local is_in_attack = cmd.buttons == buttons.in_attack or cmd.buttons == buttons.in_attack2

        location_playback = closest_location
        playback_state = nil
        playback_weapon = weapon
        playback_begin = cmd.command_number

        updateRunningState(cmd, local_player, weapon)
    end
end

local function move_player_to_location(cmd, current_pos, closest_info)
    local MINIMUM_SPEED = 8
    local MAXIMUM_SPEED = 15

    local MINIMUM_DISTANCE = 5
    local MAXIMUM_DISTANCE = 30

    local local_player = entitylist.get_local_player()
    local duck_amount = closest_info.duck

    local min_speed = duck_amount and MINIMUM_SPEED*3 or MINIMUM_SPEED
    local max_speed = duck_amount and MAXIMUM_SPEED*2 or MAXIMUM_SPEED

    local distance = (Settings.Math.Sub(current_pos, closest_info.position)):length()
    local difference = (distance-MINIMUM_DISTANCE)/(MAXIMUM_DISTANCE-MINIMUM_DISTANCE)

    local time = Settings.Math.Clamp(difference, 0, 1)
    local multiplier = Settings.Math.Lerp(min_speed, max_speed, time)

    local yaw = closest_info.viewangles[2]
    local vec_forward = Settings.Math.Sub(current_pos, closest_info.position)
    local x_velocity, y_velocity = Settings.Math.Velocity(vec_forward, yaw)

    if closest_info.duck then
        cmd.buttons = distance <= 30 and bit.bor(cmd.buttons, buttons.in_duck) or 0
    end

    cmd.forwardmove = -x_velocity*multiplier
    cmd.sidemove = y_velocity*multiplier

    cmd.viewangles.x = closest_info.viewangles[1]
    cmd.viewangles.y = closest_info.viewangles[2]
end

function attractToLocation(cmd, epsilon)
    local local_player = entitylist.get_local_player()
    if not local_player then return end

    local current_pos = local_player:get_origin()
    if not current_pos then return end

    local map_name = engine.get_level_name_short()

    if grenade_locations == nil then
        grenade_locations = {}
    end

    local data = grenade_locations[map_name]
    if not data then return end

    local weapon = get_weapon_name(local_player):get_class_name()
    local console_weapon = console_weapon_id[weapon]

    if local_player and local_player:get_health() > 0 then
        local view = engine.get_view_angles()

        if menu.get_key_bind_state("Helper") then
            menu.set_bool("misc.fast_stop", false)

            -- Найти ближайшую локацию, если игрок не выполняет бросок гранаты

            local closest_location, closest_air = Settings.Location.ClosestTarget(current_pos, view, data, console_weapon, epsilon)

            if closest_location and not playback_progress then
                move_player_to_location(cmd, current_pos, closest_location)
            end
        else
            menu.set_int("misc.automatic_strafe", menu_items.strafe)

            if not playback_progress then
                menu.set_bool("misc.fast_stop", menu_items.fast_stop)
            end
        end
    end
end


local function get_location_id(location)
    local x, y, z = table.unpack(location.position)
    return math.floor(x * 1000) + math.floor(y * 100) + math.floor(z)
end

function on_paint()
    -- player settings
    local local_player = entitylist.get_local_player()
    if not local_player then return end

    -- get coors player and map
    local player_position = local_player:get_origin()
    local map_name = engine.get_level_name_short()

    -- check this map
    local data = grenade_locations[map_name]
    if not data then return end

    -- massive of spot's
    local selected_spots = {}
    local sorted_grenade = {}
    local comb_spots_ids = {}

    local smooth = {}
    local goto_alpha

    -- relevant variables
    local weapon = get_weapon_name(local_player)
    if weapon == nil then
        return
    end

    local weapon_id = weapon:get_class_name()
    local console_weapon = console_weapon_id[weapon_id]

    -- settings renderer
    local frame = globals.get_frametime() * 8
    local font = Settings.Initialize.Font.verdana_antialias
    local font_b = Settings.Initialize.Font.DEBUG_font
    local font_icon = Settings.Initialize.Font.icon

    -- closest location
    local closest_distance = math.huge
    local closest_group_key = nil

    -- closest air cross and loc
    local closest_air = math.huge
    local closest_location = nil

    -- Create distance
    local MAXIMUM_DISTANCE = 850
    local MINIMUM_DISTANCE = 650

    -- Spoof locs
    for i, location_spot in ipairs(data) do
        comb_spots_ids[get_location_id(location_spot)] = i
    end

    local location_last_weapon = console_weapon ~= nil and console_weapon or nil

    if location_last_weapon == nil then
        table_clear(selected_spots)
        table_clear(sorted_grenade)
        table_clear(comb_spots_ids)
        return
    end
    
    -- Find a center
    for _, location_spot in ipairs(data) do
        -- Create loc ids
        local location_id = get_location_id(location_spot)

        -- Cond of weapon
        if location_spot.weapon == location_last_weapon and not sorted_grenade[location_id] then
            -- заносим крч лок спот в таблицу )
            local target_location = {location_spot}
            sorted_grenade[location_id] = true

            -- уникальный ключ
            local group_key = console_weapon .. "_" .. location_id
            
            -- присваиваем началаьное значение к чему будет присваивать
            local sum_x, sum_y, sum_z = location_spot.position[1], location_spot.position[2], location_spot.position[3]
            local count = 1
            
            for id, index in pairs(comb_spots_ids) do
                -- айди другой локации
                local other_spot = data[index]

                -- считаем центр
                if other_spot and other_spot.weapon == location_last_weapon and not sorted_grenade[id] and Settings.Math.PosClose(location_spot.position, other_spot.position, 30) then
                    table.insert(target_location, other_spot)
                    sorted_grenade[id] = true
                    sum_x = sum_x + other_spot.position[1]
                    sum_y = sum_y + other_spot.position[2]
                    sum_z = sum_z + other_spot.position[3]

                    -- считаем скок локаций
                    count = count + 1
                end
            end
            
            -- ебашим крч центер )))
            local center = vector.new(sum_x / count, sum_y / count, sum_z / count)

            -- присваиваем таблицам новое значение
            selected_spots[group_key] = target_location
            
            -- ну и для дальнейших операций ближайшую локу находим
            local distance = vector.dist_to(player_position, center)
            if distance < closest_distance then
                closest_distance = distance
                closest_group_key = group_key
            end
        end
    end

    -- pair target loc
    for group_key, target_location in pairs(selected_spots) do
        -- size text var's
        local total_height, max_width = 0, 0
        local sum_x, sum_y, sum_z = 0, 0, 0
        local center, loc_dist = 0, 0
    
        for _, location in ipairs(target_location) do
            -- cond in table
            local dataname = type(location.name) == "table" and location.name[2] or location.name

            -- max len text
            local width_text = render.get_text_width(font, dataname)

            -- len calculation
            max_width = math.max(max_width, width_text)
            total_height = total_height + 12
    
            -- find center pos
            sum_x = sum_x + location.position[1]
            sum_y = sum_y + location.position[2]
            sum_z = sum_z + location.position[3]

            --if location.weapon == console_weapon then

                location.hide_a = location.hide_a or 0.0
                location.width = location.width or 0.0
                location.height = location.height or 0.0

                center = vector.new(
                    sum_x / #target_location, 
                    sum_y / #target_location, 
                    sum_z / #target_location + 6
                );
        
                -- dist to group loc's
                loc_dist = vector.dist_to(player_position, center);
                
                local c_dist = loc_dist >= MINIMUM_DISTANCE
                local hotkey = menu.get_key_bind_state("Helper")
                local aa = location.t_alpha and location.t_alpha < 0.1 or false

                if closest_distance <= 15 then
                    local closest_boolean = group_key == closest_group_key
                
                    -- Установка прозрачности в зависимости от того, активен ли hotkey и является ли локация ближайшей
                    location.hide_a = Settings.Math.Lerp(location.hide_a, closest_boolean and 1 or 0.35, frame)
                    --local aa = location.t_alpha and location.t_alpha < 0.5 or false
                
                    if hotkey and not closest_boolean then
                        -- Если hotkey активен, и это не ближайшая локация, уменьшаем ширину и высоту
                        goto_alpha = true
                        location.width = Settings.Math.Lerp(location.width, aa and -6 or max_width, frame)
                        location.height = Settings.Math.Lerp(location.height, aa and 12 or total_height, frame)
                    elseif not c_dist then
                        -- Если локация ближе 650 юнитов и не удовлетворяет условиям hotkey, устанавливаем max_width и total_height
                        goto_alpha = false
                        location.width = Settings.Math.Lerp(location.width, max_width, frame)
                        location.height = Settings.Math.Lerp(location.height, total_height, frame)
                    else
                        -- Если локация дальше 650 юнитов, устанавливаем минимальные размеры
                        goto_alpha = true
                        location.width = Settings.Math.Lerp(location.width, aa and -6 or max_width, frame)
                        location.height = Settings.Math.Lerp(location.height, aa and 12 or total_height, frame)
                    end
                else
                    --goto_alpha = false
                    location.hide_a = Settings.Math.Lerp(location.hide_a, 1, frame)
                    -- Условия для локаций, находящихся на расстоянии более 15 юнитов от игрока
                    if c_dist then
                        -- Если расстояние больше 650 юнитов, устанавливаем минимальные размеры
                        goto_alpha = true
                        location.width = Settings.Math.Lerp(location.width, aa and -6 or max_width, frame)
                        location.height = Settings.Math.Lerp(location.height, aa and 12 or total_height, frame)
                    else
                        -- В противном случае, если hotkey не активен, применяем максимальные размеры
                        goto_alpha = false
                        location.width = Settings.Math.Lerp(location.width, max_width, frame)
                        location.height = Settings.Math.Lerp(location.height, total_height, frame)
                    end
                end
            --end
        end

        -- dist to group loc's
        local center_pos = center
        local distance_to_loc = loc_dist
        local hotkey = menu.get_key_bind_state("Helper")

        -- pair closest loc's
        for _, location_replace in ipairs(target_location) do
            -- cond with dist
            if distance_to_loc <= 30 then -- Проверяем, что локация в пределах допустимого расстояния
                -- dist cross and circle
                local air_distance = vector.dist_to(vector.new(location_replace.viewangles[1], location_replace.viewangles[2], 0), engine.get_view_angles())

                -- cond with calculate distance
                if air_distance < closest_air then
                    closest_air = air_distance
                    closest_location = location_replace
                end
            end
        end

        -- cond with dist
        if distance_to_loc <= MAXIMUM_DISTANCE+50 then
            -- if text in group > 1
            local is_group_large = #target_location > 1 or distance_to_loc < 450

            -- pair loc's
            for _, render_info in ipairs(target_location) do
                -- wh
                render_info.width = render_info.width or 0.0
                render_info.height = render_info.height or 0.0

                -- xy (rect)
                render_info.wx_rect = render_info.wx_rect or 0.0
                render_info.wy_rect = render_info.wy_rect or 0.0

                -- xy (icon)
                render_info.wx_icon = render_info.wx_icon or 0.0
                render_info.wy_icon = render_info.wy_icon or 0.0

                -- text, rect
                render_info.t_alpha = render_info.t_alpha or 0.0
                render_info.w_alpha = render_info.w_alpha or 0.0

                -- xy air
                render_info.wx_a = render_info.wx_a or 0.0
                render_info.wy_a = render_info.wy_a or 0.0

                -- rect, text alpha air
                render_info.rect_a = render_info.rect_a or 0.0
                render_info.text_a = render_info.text_a or 0.0

                -- rand int
                render_info.numbers = render_info.numbers or 0.0
                render_info.a_alpha = render_info.a_alpha or 0.0

                render_info.box_hide = render_info.box_hide or 0.0

                -- spots dist
                local location_dist_eye = distance_to_loc >= 30
                local location_dist_number = distance_to_loc >= 650
                local location_global_dist = distance_to_loc >= 800

                -- correct table name
                local grenade = render_info.name
                local dataname = type(grenade) == "table" and grenade[2] or grenade

                -- text size
                local width_text_air = render.get_text_width(font_b, "»" .. dataname)

                -- start with 0.01 alpha
                local cond_text_alpha = render_info.text_a < 0.01
                local cond_text_world = location_global_dist and render_info.t_alpha < 0.01

                local alpha_set_world_text = math.min(render_info.t_alpha)
                local width_calcutation = (location_dist_number or goto_alpha) or render_info.width < max_width-3

                -- animation -> rect icon
                render_info.wx_rect = Settings.Math.Lerp(render_info.wx_rect, is_group_large and 22 or 18, frame)
                render_info.wy_rect = Settings.Math.Lerp(render_info.wy_rect, is_group_large and 7 or 6, frame)
                render_info.wx_icon = Settings.Math.Lerp(render_info.wx_icon, is_group_large and 6 or 7, frame / 2)
                render_info.wy_icon = Settings.Math.Lerp(render_info.wy_icon, is_group_large and 9 or 8, frame / 2)
                render_info.numbers = Settings.Math.Lerp(render_info.numbers, is_group_large and 3.5 or 0, frame/1.25)

                -- alpha channel 
                render_info.t_alpha = Settings.Math.Lerp(render_info.t_alpha, width_calcutation and 0 or 1, frame)
                render_info.w_alpha = Settings.Math.Lerp(render_info.w_alpha, cond_text_world and 0 or 1, frame/2)

                -- w alpha text and rect 
                render_info.text_a = Settings.Math.Lerp(render_info.text_a, location_dist_eye and 0 or 1, frame*2)
                render_info.wx_a = Settings.Math.Lerp(render_info.wx_a, cond_text_alpha and -6 or width_text_air, frame)
                render_info.rect_a = Settings.Math.Lerp(render_info.rect_a, cond_text_alpha and 0 or 1, frame*1.25)
            
                --global_alpha = render_info.global_alpha

                -- new era variable's
                w = render_info.width
                h = render_info.height

                -- icon size
                wx_rect = render_info.wx_rect
                wy_rect = render_info.wy_rect
                wx_icon = render_info.wx_icon
                wy_icon = render_info.wy_icon

                -- text group alpha's
                t_alpha = render_info.t_alpha
                w_alpha = render_info.w_alpha

                -- air method's
                wx_rect_air = render_info.wx_a
                text_air = render_info.text_a
                rect_air = render_info.rect_a

                -- rand names of var's
                numbers = render_info.numbers
                hide_a = render_info.hide_a

                box_hide = render_info.box_hide
            

                -- localize new group alpha's
                local w_group_rect = math.min(w_alpha, hide_a)
                local a_group_rect = math.min(rect_air, hide_a)
                local group_text = math.min(t_alpha, hide_a)

                -- color calculation
                color_t = {
                    -- world rect
                    w_body = {
                        r = 22,
                        g = 22,
                        b = 22,
                        a = math.floor(w_group_rect*150)
                    },

                    -- air rect
                    a_body = {
                        r = 25,
                        g = 25,
                        b = 25,
                        --a = 185
                        a = a_group_rect
                    },

                    -- world text
                    w_text = {
                        r = 230,
                        g = 230,
                        b = 230,
                        a = math.floor(group_text*150)
                    },

                    -- air  text
                    a_basic = {
                        r = 230,
                        g = 230,
                        b = 230,
                        a = text_air
                    },

                    -- air select loc
                    a_select = {
                        r = 245,
                        g = 216,
                        b = 5,
                        a = math.floor(text_air*180)
                    },

                    -- color with start move player
                    a_start = {
                        r = 20,
                        g = 236,
                        b = 0,
                        a = math.floor(text_air*180)
                    },
                }
            
                -- render air text
                if rect_air >= 0.1 then
                    -- calculate closest_pos
                    local closest_pos_with_hotkey = closest_location == render_info and hotkey
                    local closest_pos = closest_location == render_info
                
                    render_info.chunk_render = render_info.chunk_render or MAX_DIST_SELECT
                    render_info.chunk_render = Settings.Math.Lerp(render_info.chunk_render, closest_pos and MAX_DIST_SELECT or MAX_DIST_SELECT*1.25, frame)
                
                    -- remove table
                    local chunk_renderer = render_info.chunk_render
                
                    -- get player's angel
                    local vector_ang = Settings.Location.AngleToVec(
                        render_info.viewangles[1],
                        render_info.viewangles[2],
                        render_info or NULL
                    );

                    -- changing angle's to vec in world
                    local player_angle = vector.new(
                        vector_ang.x*chunk_renderer+render_info.position[1], 
                        vector_ang.y*chunk_renderer+render_info.position[2], 
                        vector_ang.z*chunk_renderer+render_info.position[3]+64
                    );
                
                    -- viewangle's to world
                    local a_pos = render.world_to_screen(player_angle);
                
                    -- fix trouble with fps
                    if a_pos.x ~= 0 and a_pos.y ~= 0 then
                        -- Air *x* coords
                        local ax_rect = a_pos.x
                        local ax_text = a_pos.x
                
                        -- Main *y* coords
                        local ay_render = a_pos.y

                        local body_air = closest_pos and color_t.a_body.a
                        local text_air = closest_pos and color_t.a_basic.a
                
                        render_info.box_hide = Settings.Math.Lerp(
                            render_info.box_hide, 
                            hotkey and (body_air or 0.35) or (body_air or 0.65), 
                            frame
                        );
                
                        render_info.alpha_set = render_info.alpha_set or 0.0
                        render_info.alpha_set = Settings.Math.Lerp(
                            render_info.alpha_set, 
                            hotkey and (text_air or 0.25) or (text_air or 0.55), 
                            frame
                        );
                
                        local alpha_set = math.min(color_t.a_basic.a, render_info.alpha_set)
                
                        local size_circle = 5
                        local radius_circle = 60

                        -- Настройка цвета прямоугольника в зависимости от значения box_hide
                        local box_color = color.new(
                            color_t.a_body.r,
                            color_t.a_body.g, 
                            color_t.a_body.b, 
                            math.ceil(render_info.box_hide*180)  -- Это значение масштабируется до 0 или 185
                        );
                
                        -- Установка базового цвета текста
                        local color_basic = {
                            r = color_t.a_basic.r,
                            g = color_t.a_basic.g, 
                            b = color_t.a_basic.b, 
                            a = math.floor(alpha_set*185)
                        }
                
                        -- Начальный и конечный цвета для анимации
                        local start_color = color.new(color_t.a_basic.r, color_t.a_basic.g, color_t.a_basic.b, math.floor(alpha_set*185))  -- Красный
                        local end_color = color.new(color_t.a_select.r, color_t.a_select.g, color_t.a_select.b, math.floor(alpha_set*185))    -- Зелёный
                
                        if render_info.current_color == nil then 
                            render_info.current_color = start_color 
                        end
                
                        -- Интерполируем текущий цвет между начальным и конечным
                        render_info.current_color = Settings.Math.ColorLerp(render_info.current_color, closest_pos and end_color or start_color, frame/2)
                
                        -- Определяем размеры прямоугольника
                        local w_size_rect = math.ceil(wx_rect_air)

                        -- После этого, мы можем использовать adjusted_text_width для коррекции прямоугольника и текста:
                        render.draw_rect_filled(ax_text - 10, ay_render - 12, w_size_rect + 24, 24, box_color)
                        render.draw_circle_filled(ax_text, ay_render, radius_circle, size_circle, render_info.current_color)
                        render.draw_text(font_b, ax_text + 8, ay_render - 6, color.new(color_basic.r, color_basic.g, color_basic.b, color_basic.a), "»" .. dataname)
                    end                    
                end
            end
            
            -- world screen
            local wscreen = render.world_to_screen(center_pos)

            -- mathematic ceil )
            local wx_count = math.ceil(w)
            local wy_count = math.ceil(h)

            -- world cords
            local wx_screen = wscreen.x
            local wy_screen = wscreen.y-wy_count

            -- skip conditional
            if total_height == 0 then
                goto continue_target_location
            end

            -- fps boost and design trouble fix
            if wscreen.x == 0 or wscreen.y == 0 then
                goto continue_target_location
            end

            -- cond alpha status
            if w_alpha >= 0.3 then
                -- get hand weapon icon

                local icon = icon_images[weapon_id]
                --local icon_text = Settings.init.all_icon[weapon]

                -- offsets
                local offset_x = math.ceil(wx_screen)+10
                local offset_y = math.ceil(wy_screen)+3

                -- if weapon smoke
                local weapon_select = weapon == "CSmokeGrenade" and 2 or 0

                if icon then
                    -- icon offsets
                    local icon_x = offset_x
                    local icon_y = offset_y

                    -- end pos icon
                    local icon_end_x = math.floor(icon_x+numbers+8-weapon_select)
                    local icon_end_y = math.floor(icon_y+numbers+16)

                    --render.draw_text(
                    --    font_icon, 
                    --    icon_x-math.floor(wx_icon),
                    --    wx_screen,
                    --    wy_screen,
                    --    icon_y-math.floor(wy_icon-h/2)-8, 
                    --    icon_end_x-math.floor(wx_icon), 
                    --    icon_end_y-math.floor(wy_icon-h/2)-8, icon_text
                    --    color.new(
                    --        color_t.w_text.r, 
                    --        color_t.w_text.g, 
                    --        color_t.w_text.b, 
                    --        color_t.w_body.a
                    --    ),
                    --    icon_text
                    --);

                    render.draw_image(
                        icon_x-math.floor(wx_icon), 
                        icon_y-math.floor(wy_icon-h/2), 
                        icon_end_x-math.floor(wx_icon), 
                        icon_end_y-math.floor(wy_icon-h/2), icon
                    );
                end
            end

            -- rect renderer
            render.draw_rect_filled(
                wx_screen, 
                wy_screen,
                wx_count+math.ceil(wx_rect+4), 
                wy_count+math.ceil(wy_rect*2), 
                color.new(
                    color_t.w_body.r, 
                    color_t.w_body.g, 
                    color_t.w_body.b, 
                    color_t.w_body.a
                )
            )

            -- cond with alpha status
            if t_alpha >= 0.1 then
                -- localize height
                local current_y = 0

                -- cords calculate
                local wx_text = wscreen.x
                local wy_text = wy_screen

                -- pair loc's
                for _, location in ipairs(target_location) do
                    -- fix trouble with table
                    local set_name = location.name
                    local dataname = type(set_name) == "table" and set_name[2] or set_name

                    -- default text renderer
                    render.draw_text(
                        font, 
                        wx_text+wx_rect, 
                        wy_text+current_y+6, 
                        color.new(
                            color_t.w_text.r, 
                            color_t.w_text.g, 
                            color_t.w_text.b, 
                            color_t.w_text.a
                        ),  dataname
                    ); 

                    -- height if text in table > 1
                    current_y = current_y + 12
                end
            end
            ::continue_target_location::
        end
    end
end

local function merge_locations(existing_locations, new_locations)
    -- одинаковую структуру и ключи
    for map, map_locations in pairs(new_locations) do
        if not existing_locations[map] then
            existing_locations[map] = {}
        end
        for _, location in ipairs(map_locations) do
            table.insert(existing_locations[map], location)
        end
    end
end

local function load_locations_from_file(filename)
    local file_path = appdata.."/Legendware/Scripts/"..filename
    local file, err = io.open(file_path, "r")
    if not file then
        print("Файл не найден, будет создан новый файл: " .. err)
        return {}
    end

    local content = file:read("*a")
    file:close()

    -- Проверка, что файл не пустой
    if content == "" then
        return {}
    end

    -- Удаление лишних символов, если они есть
    content = content:gsub("^%s*(.-)%s*$", "%1")

    local data, pos, err = json.decode(content)
    if err then
        print("Ошибка при чтении JSON из файла: " .. err)
        return {}
    end

    return data
end

local function save_locations_to_file(base_filename, location_data)
    local full_path = appdata.."/Legendware/Scripts/"..base_filename
    local file, err = io.open(full_path, "w")
    if not file then
        print("Ошибка при открытии файла для записи: " .. err)
        return false
    end

    -- кажись тут нету этава indent)
    local json_string = json.encode(location_data, { indent = true })

    if json_string then
        local pretty_json_string = pretty_json(json_string)
        file:write(pretty_json_string)
    else
        print("Ошибка при сериализации данных локации в JSON.")
    end

    file:close()
end

function add_location_and_save(filename, location_to_print)
    local locations = load_locations_from_file(filename)
    local map_short = engine.get_level_name_short()

    if not locations[map_short] then
        locations[map_short] = {}
    end

    table.insert(locations[map_short], location_to_print)
    save_locations_to_file(filename, locations)
end

merge_locations(grenade_locations, user_locations)


-- @region: callbacks
client.add_callback("on_paint", function()
    debug_render_info();
    on_paint();
    print_nade();
end);

client.add_callback("create_move", function(cmd)
    attractToLocation(cmd, 30)
    main(cmd, 30)
    create_new_location()
end);