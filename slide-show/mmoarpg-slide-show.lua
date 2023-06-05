-- Selects random recent art and credits it
-- Author: @SentientCrab
-- Version 0.1
-- Todo:
--  Regex for image data to credit pieces
--  Custom image credit output
--  Jank impossible to desync mode (regularlly save and load image settings to prevent desyncs)
-- HIGH PRI:
--  Rename shit so people don't laugh at my code
--  Copy bounds settings into slideshow aspect ratio to keep things centered (I think I did this?)

obs = obslua
text_label = ""
text_label_id = ""
image_source = ""
image_dir = ""
image_array = {}
is_running = false
is_streaming = false
is_recording = false
image_index = 0
image_array_size = 0
settings_num_of_bag = 200
settings_num_of_images = 20
auto_move = true
auto_start = true

allowed_extensions = {"bmp", "tga", "png", "jpeg", "jpg", "jxr", "gif", "webp"}

--on live
--  read transform dimensions, save size 
--  set slideshow size to same size
--  set transform size to same size
--  put all the pics in the slideshow
--  callback function checks to see if slideshow changed, then updates text

--default times
--slide_time: 8000ms
--transition_speed: 700ms


function get_source_scene_item(source_name) --obs is very cringe and needs the scene that an object is in, but won't give you the info you need. This may be very slow if you have a bunch of scenes
    local scene_names = obs.obs_frontend_get_scene_names()
    for i, name in ipairs(scene_names) do
        local scene_to_eval = obs.obs_get_scene_by_name(scene_names[i])
        local scene_item = obs.obs_scene_find_source(scene_to_eval, source_name)
        obs.obs_scene_release(scene_to_eval)
        if scene_item ~= nil then
            return scene_item
        end
    end
    return nil
end

function get_current_scene()--even more absurd you can't get the current scene without shenanigans
    local current_scene = obs.obs_frontend_get_current_scene()
    local to_return = obs.obs_get_scene_by_name(obs.obs_source_get_name(current_scene))
    obs.obs_source_release(current_scene)
    return to_return
end


function setup_scene(props, prop, script_settings)--used for spawning in the text and slideshow
    local current_scene = get_current_scene()
    local text_name = "art credits"
    local text_settings = obs.obs_data_create_from_json('{"font":{"face":"Arial","style":"Regular","size":100,"flags":0},"text":""}')
    local text_source = obs.obs_source_create("text_gdiplus", text_name, text_settings, nil)
    
    obs.obs_scene_add(current_scene, text_source)
    
    local text_sceneitem = obs.obs_scene_find_source(current_scene, obs.obs_source_get_name(text_source))
    local tmp_vec = obs.vec2()
    tmp_vec.x=1440--some hardcoded positions for new brb screen
    tmp_vec.y=227 --
    obs.obs_sceneitem_set_pos(text_sceneitem, tmp_vec)
    local tmp_vec2 = obs.vec2()
    tmp_vec2.x=1--so image isn't all stretched
    tmp_vec2.y=1--
    obs.obs_sceneitem_set_scale(text_sceneitem, tmp_vec2)
    
    obs.obs_sceneitem_set_alignment(text_sceneitem, 8)--magic number fucking bullshit because you can't actually bit or shit, it's just random enums
    obs.obs_sceneitem_set_bounds_type(text_sceneitem, 6)
    obs.obs_sceneitem_set_bounds_alignment(text_sceneitem, 8)--this is bottom center
    
    local tmp_vec3 = obs.vec2()
    tmp_vec3.x=963
    tmp_vec3.y=227
    obs.obs_sceneitem_set_bounds(text_sceneitem, tmp_vec3)
    
    obs.obs_source_update(text_source, text_settings)
	obs.obs_data_release(text_settings)
    obs.obs_source_release(text_source)
    
    
    
    local slide_name = "art slideshow"
    local slide_settings = obs.obs_data_create()--pretty sure pippa's previous settings were all default :pipSmug:    
    obs.obs_data_set_string(slide_settings, "use_custom_size", "963x853")
    local slide_source = obs.obs_source_create("slideshow", slide_name, slide_settings, nil)
    
    obs.obs_scene_add(current_scene, slide_source)
    
    local slide_sceneitem = obs.obs_scene_find_source(current_scene, obs.obs_source_get_name(slide_source))
    local tmp_vec4 = obs.vec2()
    tmp_vec4.x=1440
    tmp_vec4.y=227
    obs.obs_sceneitem_set_pos(slide_sceneitem, tmp_vec4)
    local tmp_vec5 = obs.vec2()
    
    obs.obs_sceneitem_set_alignment(slide_sceneitem, 4)--magic number fucking bullshit because you can't actually bit or shit, it's just random enums
    obs.obs_sceneitem_set_bounds_type(slide_sceneitem, 3)
    obs.obs_sceneitem_set_bounds_alignment(slide_sceneitem, 0)--this is bottom center
    
    local tmp_vec6 = obs.vec2()
    tmp_vec6.x=963
    tmp_vec6.y=853
    obs.obs_sceneitem_set_bounds(slide_sceneitem, tmp_vec6)
    
    obs.obs_source_update(slide_source, slide_settings)
	obs.obs_data_release(slide_settings)
    obs.obs_source_release(slide_source)
    
    obs.obs_scene_release(current_scene)
    
    local gallery_prop = obs.obs_properties_get(props, "source") --because OBS is very smart you have to re-run some parts to make these new items appear in the selector
    obs.obs_property_list_clear(gallery_prop)
    local text_prop = obs.obs_properties_get(props, "source2")
    obs.obs_property_list_clear(text_prop)
	
    local sources = obs.obs_enum_sources()
	-- As long as the sources are not empty, then
    if sources ~= nil then
        -- iterate over all the sources
        for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_id(source)
            if source_id == "slideshow" then--finding all slideshows
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(gallery_prop, name, name)
            end
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_gdiplus_v2" then--finding all text options
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(text_prop, name, name)
            end
        end
    end
    obs.source_list_release(sources)
    return true
end

function list_contains(tbl, val) --simple has check
    for i = #tbl, 1, -1 do
        if tbl[i] == val then return true end
    end
    return false
end

function shuffle(tbl) --shuffle to keep the images interesting
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

function get_artist_name(fullpath) --extracts artist name from ab's art archive naming convention
    --local real_filename = fullpath --for testing direct names
    local real_filename = string.sub(fullpath, string.find(fullpath, "/[^/]*$")+1, string.len(image_array[image_index]))
    real_filename = string.sub(real_filename, 0, string.find(real_filename, "%.[^%.]*$")-1)
    local first_space = string.find(real_filename, " ")
    local last_space = string.find(real_filename, " %d%d%d%d+[-]+%d+[-]+%d+") --matches at least YYYY-M-D with any extra number of dashes or digits in the date
    if last_space == nil then   --for files without dates like "sleepover.jpg"
        return "\""..real_filename.."\""
    end
    real_filename = string.sub(real_filename, 0,last_space-1) --remove date info
    if string.find(string.lower(real_filename), " comm") ~= nil then
        real_filename = string.sub(real_filename, 0,string.find(string.lower(real_filename), " comm")-1)
    end
    first_space = string.find(real_filename, " ")
    if first_space == nil then --substance20 2023-01-28.jpg
        return real_filename
    end
    if string.sub(real_filename,0,1) == "@" then
        return string.sub(real_filename,first_space+1, string.len(real_filename))
        --if first_space == last_space then --For filenames in the standard @ARTIST YYYY-MM-DD.ext
        --  return string.sub(real_filename,0, first_space-1)
        --end
    end
    return real_filename
end

function force_run()
    obs.timer_remove(text_update)
    local source = obs.obs_get_source_by_name(image_source)
    local text_source = obs.obs_get_source_by_name(text_label)
    local threw_error = false
    if source == nil then
        error("SLIDE SHOW ERROR: can't find slideshow. Either not selected or deleted.")
        if text_source ~= nill then
            local settings = obs.obs_source_get_settings(text_source)
            obs.obs_data_set_string(settings, "text", "")
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
        end
        threw_error=true
    end
    
    if text_source == nil then
        error("SLIDE SHOW ERROR: can't find credit text. Either not selected or deleted.")
        if source ~= nil then
            local files_data_array = obs.obs_data_get_array(temp_files, "files")
            for k in pairs (image_array) do
                image_array [k] = nil
            end
            local settings = obs.obs_source_get_settings(source)
        end
        threw_error=true
    end
    obs.obs_source_release(text_source)
    if threw_error then--get out if things are peachy
        obs.obs_source_release(source)
        return false
    end
    local p = io.popen('dir "'..image_dir..'" /o-d /B')  --Open directory look for files, save data in p. By giving '-type f' as parameter, it returns all files.
    local list_of_files = {}
    local current_index = 0
    for file in p:lines() do                         --Loop through all files
        for i = 1, #allowed_extensions, 1 do        --Make sure it's a valid extension
            if string.find(string.lower(file), "[.]"..allowed_extensions[i].."$") ~= nil then
                current_index = current_index + 1
                list_of_files[current_index] = file
                break
            end
        end
        if current_index == settings_num_of_bag+1 then break end
        --number and day checks
    end
    p:close()
    shuffle(list_of_files)
    local artist_table = {}
    local json_str = "{\"files\":["
    j = 1
    artist_list = {}
    for i = 1, #list_of_files, 1 do
        --if not list_contains(artist_list, list_of_files[i]) then                              --anon bypasses artist list because there's no way to tell if they're different people
        if list_of_files[i] ~= "anon" and not list_contains(artist_list, list_of_files[i]) then --this is exploitable so be good anons, otherwise comment this line and uncomment previous 
            
            json_str = json_str..[[{"hidden":false,"selected":false,"value":"]]..image_dir.."/"..list_of_files[i]..[["},]]
            artist_list[j] = list_of_files[i]
            j = j + 1
        end
        if j == settings_num_of_images+1 then break end
    end
    json_str = string.sub(json_str, 0, string.len(json_str)-1)
    json_str = json_str.."]}"
    local temp_files = obs.obs_data_create_from_json(json_str)
    local files_data_array = obs.obs_data_get_array(temp_files, "files")
    for k in pairs (image_array) do
        image_array [k] = nil
    end
    local settings = obs.obs_source_get_settings(source)
    --copy slide show's bounds into slide show aspect ratio
    local scene_item = get_source_scene_item(image_source)
    if scene_item == nil then
        error("SLIDE SHOW ERROR: can't find slideshow scene item")
    end
    local text_item = get_source_scene_item(text_label)
    if text_item == nil then
        error("SLIDE SHOW ERROR: can't find text scene item")
    end
    local bounds = obs.vec2()
    local bounds_t = obs.vec2()
    local transform_g = obs.vec2()
    obs.obs_sceneitem_get_bounds(scene_item, bounds)
    obs.obs_sceneitem_get_pos(scene_item, transform_g)
    if auto_move then
        obs.obs_sceneitem_get_bounds(text_item, bounds_t)
        bounds_t.x = bounds.x
        obs.obs_sceneitem_set_pos(text_item, transform_g)
        obs.obs_sceneitem_set_bounds(text_item, bounds_t)
    end
        
    obs.obs_data_set_array(settings, "files", files_data_array)
    obs.obs_data_set_string(settings, "use_custom_size", bounds.x.."x"..bounds.y)
    obs.obs_source_update(source, settings)
    obs.obs_data_array_release(files_data_array)
    obs.obs_data_release(temp_files)
    
    local slide_time = obs.obs_data_get_int(settings, "slide_time")
    local transition_speed = obs.obs_data_get_int(settings, "transition_speed")
    local files_aray = obs.obs_data_get_array(settings,"files")
    image_array_size = 0
    image_index = 0
    for i= 0, obs.obs_data_array_count(files_aray)-1, 1
    do
        local current_object = obs.obs_data_array_item(files_aray, i)
        image_array[i] = obs.obs_data_get_string(current_object, "value")
        image_array_size = image_array_size + 1
    end
    obs.obs_source_update(source, settings)
    obs.timer_add(text_update, transition_speed+slide_time)
    text_update()
    obs.obs_data_release(settings)
    obs.obs_source_release(source)
    is_running = true
    --image_array
end

function force_stop()
    obs.timer_remove(text_update)
    local text_source = obs.obs_get_source_by_name(text_label)
    if text_source ~= nil then
        local settings = obs.obs_source_get_settings(text_source)
        obs.obs_data_set_string(settings, "text", "")
        obs.obs_source_update(text_source, settings)
        obs.obs_data_release(settings)
    else
        print("nil text")
    end
    obs.obs_source_release(text_source)
    local gal_source = obs.obs_get_source_by_name(image_source)
    if gal_source ~= nil then
        local settings = obs.obs_source_get_settings(gal_source)
        obs.obs_data_set_array(settings, "files", obs.obs_data_get_default_array(settings, "files"))
        obs.obs_source_update(gal_source, settings)
        obs.obs_data_release(settings)
    else
        print("missing slideshow")
    end
    obs.obs_source_release(gal_source)
    
    is_running=false
end


function text_update()
    local source = obs.obs_get_source_by_name(text_label)
    local settings = obs.obs_source_get_settings(source)
    local name = get_artist_name(image_array[image_index])
    obs.obs_data_set_string(settings, "text", name)
    obs.obs_source_update(source, settings)
    image_index = 1 + image_index
    image_index = image_index % image_array_size
    obs.obs_data_release(settings)
    obs.obs_source_release(source)
end

function on_event(event) --for automatic start in the future
    if is_running then
        print("running")
    end
    if (event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED or event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED) and not is_streaming and not is_recording and not is_running then
        if auto_start then
            force_run()
        end
	end
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        is_recording=true
        print("is_recording true")
    end
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        is_recording=false
        print("is_recording false")
    end
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        is_streaming=true
        print("is_streaming true")
    end
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        is_streaming=false
        print("is_streaming false")
    end
	if (event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED or event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED) and not is_streaming and not is_recording then
		if auto_start then
            force_stop()
        end
	end
    if is_running then
        print("running 2")
    end
end


function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "bag_num", 200)
    obs.obs_data_set_default_int(settings, "num_of_images", 20)
    obs.obs_data_set_default_string(settings, "source", "Setup, then select 'art slideshow'")
    obs.obs_data_set_default_string(settings, "source2", "Setup, then select 'art credits'")
    obs.obs_data_set_default_bool(settings, "auto_move", true)
    obs.obs_data_set_default_bool(settings, "auto_start", true)
end


function script_properties()
	local props = obs.obs_properties_create()
    
    local setup_button = obs.obs_properties_add_button(props, "setup_button", "Setup", setup_scene)
	
        
	local gallery_prop = obs.obs_properties_add_list(props, "source", "Slideshow Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_clear(gallery_prop)
	local text_prop = obs.obs_properties_add_list(props, "source2", "Image Credits Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_clear(text_prop)
	
    local sources = obs.obs_enum_sources()
	-- As long as the sources are not empty, then
    if sources ~= nil then
        -- iterate over all the sources
        for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_id(source)
            if source_id == "slideshow" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(gallery_prop, name, name)
            end
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_gdiplus_v2" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(text_prop, name, name)
            end
        end
    end
    obs.source_list_release(sources)
    
    local image_dir_settomg = obs.obs_properties_add_path(props, "art_dir", "Art Directory", obs.OBS_PATH_DIRECTORY, "",NULL)
    local bag_num = obs.obs_properties_add_int(props, "bag_num", "# to select from", 1, 10000, 1)
    local num_of_recent_images = obs.obs_properties_add_int(props, "num_of_images", "# of images", 1, 10000, 1)
    local welcome_button = obs.obs_properties_add_button(props, "welcome_button", "Force run", force_run)
    local welcome2_button = obs.obs_properties_add_button(props, "welcome_button2", "Force stop", force_stop)
    local bool_button = obs.obs_properties_add_bool(props, "auto_move", "Auto move credit text")
    local bool_button = obs.obs_properties_add_bool(props, "auto_start", "Auto start/stop slideshow")

	return props
end


function script_update(settings)
    scene = obs.obs_data_get_string(settings, "scene")
    text_label = obs.obs_data_get_string(settings, "source2")
    image_source = obs.obs_data_get_string(settings, "source")
    image_dir = obs.obs_data_get_string(settings, "art_dir")
    settings_num_of_images = obs.obs_data_get_int(settings, "num_of_images")
    settings_num_of_bag = obs.obs_data_get_int(settings, "bag_num")
    auto_move = obs.obs_data_get_bool(settings, "auto_move")
    auto_start = obs.obs_data_get_bool(settings, "auto_start")
    local properties = obs.obs_source_properties(obs.obs_get_source_by_name(image_source))
    local windowProp = obs.obs_properties_get(properties, "slideshow")
    local propName = obs.obs_property_name(windowProp)
end

function script_description()
	return "Selects random recent art and credits it\nPippa love ^-^ 🔌🐰"
end

function script_load(settings)
	obs.obs_frontend_add_event_callback(on_event)
    math.randomseed(os.time())
end
