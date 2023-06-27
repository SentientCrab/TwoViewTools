-- Selects random recent art and credits it
-- Author: @SentientCrab
-- Version 0.3
-- Requires OBS 29.1.1+ (obs_get_source_by_uuid)
-- Todo:
--  Regex for image data to credit pieces
--  Custom image credit output
--  Jank impossible to desync mode (regularlly save and load image settings to prevent desyncs)
-- HIGH PRI:
--  Rename shit so people don't laugh at my code
 
obs = obslua
text_label = ""
--text_label_id = ""
slideshow_label = ""
image_dir = ""
image_array = {}
is_running = false
is_streaming = false
is_recording = false
image_index = 0
image_array_size = 0
settings_num_of_bag = 200
settings_num_of_images = 20
settings_max_of_artist = -1
auto_move = true
auto_start = true
slideshow_scene_item = nil

slide_text_UUID = ""
slide_show_UUID = ""
setup_pressed = false
is_slide_changing = false

set_callbacks = false

order_helper = 1


setting_ref = nil

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

function uuid_to_name(uuid)
    local temp = obs.obs_get_source_by_uuid(uuid)
    local name = obs.obs_source_get_name(temp)
    obs.obs_source_release(temp)
    return name
end

function get_source_scene_item(source_name) --obs is very cringe and needs the scene that an object is in, but won't give you the info you need. This may be very slow if you have a bunch of scenes
    local scene_names = obs.obs_frontend_get_scene_names()
    for i, name in ipairs(scene_names) do
		local scene_to_eval = obs.obs_get_scene_by_name(scene_names[i])
        local scene_item = obs.obs_scene_find_source_recursive(scene_to_eval, source_name)
		obs.obs_scene_release(scene_to_eval)
        if scene_item ~= nil then
		    return scene_item
        end
    end
	return nil
end

function get_source_scene(source_name) --obs is very cringe and needs the scene that an object is in, but won't give you the info you need. This may be very slow if you have a bunch of scenes
    local scene_names = obs.obs_frontend_get_scene_names()
    for i, name in ipairs(scene_names) do
		local scene_to_eval = obs.obs_get_scene_by_name(scene_names[i])
        local scene_item = obs.obs_scene_find_source_recursive(scene_to_eval, source_name)
        if scene_item ~= nil then
		    return scene_to_eval
        end
		obs.obs_scene_release(scene_to_eval)
    end
	return nil
end

function get_scene_item_by_id(source_id) --obs is very cringe and needs the scene that an object is in, but won't give you the info you need. This may be very slow if you have a bunch of scenes
    local scene_names = obs.obs_frontend_get_scene_names()
    for i, name in ipairs(scene_names) do
        local scene_to_eval = obs.obs_get_scene_by_name(scene_names[i])
        local scene_item = obs.obs_scene_find_sceneitem_by_id(scene_to_eval, source_id)
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


function setup_scene(props, prop)--used for spawning in the text and slideshow
    if is_running then
        force_stop()
    end
    local current_scene = get_current_scene()
         
    local slide_name = "art slideshow"
    local slide_source = obs.obs_source_create("slideshow", slide_name, nil, nil)
    local slide_settings = obs.obs_source_get_settings(slide_source)
    
    obs.obs_scene_add(current_scene, slide_source)
    
	slide_show_UUID = obs.obs_source_get_uuid(slide_source)
    obs.obs_data_set_string(setting_ref, "slide_show_UUID", slide_show_UUID)
    obs.obs_data_set_string(setting_ref, "source", obs.obs_source_get_name(slide_source))
    
    local slide_sceneitem = obs.obs_scene_find_source_recursive(current_scene, obs.obs_source_get_name(slide_source))
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
    
    obs.obs_data_set_string(slide_settings, "use_custom_size", "963x853")
    obs.obs_source_update(slide_source, slide_settings)
	obs.obs_data_release(slide_settings)
    obs.obs_source_release(slide_source)
    
    local text_name = "art credits"
    local text_settings = obs.obs_data_create_from_json('{"font":{"face":"Arial","style":"Regular","size":100,"flags":0},"text":""}')
    local text_source = obs.obs_source_create("text_gdiplus", text_name, text_settings, nil)
    
    obs.obs_scene_add(current_scene, text_source)
	slide_text_UUID = obs.obs_source_get_uuid(text_source)
    obs.obs_data_set_string(setting_ref, "slide_text_UUID", slide_text_UUID)
    obs.obs_data_set_string(setting_ref, "source2", obs.obs_source_get_name(text_source))
    local text_sceneitem = obs.obs_scene_find_source_recursive(current_scene, obs.obs_source_get_name(text_source))
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
    --local testasdjaios = obs.obs_data_get_obj(props, "slide_show_UUID")
    
    obs.source_list_release(sources)    
    
    --local asdioas = obs.obs_data_get_string(script_settings, "slide_show_UUID")
    --print(asdioas)
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
    local real_filename = string.sub(fullpath, string.find(fullpath, "/[^/]*$")+1, string.len(fullpath))
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
    print("Running slideshow")
    clear_slideshow()
	
    local source = obs.obs_get_source_by_uuid(slide_show_UUID)
    local text_source = obs.obs_get_source_by_uuid(slide_text_UUID)
    local threw_error = false
    if source == nil then
        error("SLIDESHOW ERROR: can't find slideshow. Either not set or deleted.")
        if text_source ~= nill then
            local settings = obs.obs_source_get_settings(text_source)
            obs.obs_data_set_string(settings, "text", "")
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
        end
        threw_error=true
    end
    
    if text_source == nil then
        error("SLIDESHOW ERROR: can't find credit text. Either not set or deleted.")
        if source ~= nil then
            local files_data_array = obs.obs_data_get_array(temp_files, "files")
            for k in pairs (image_array) do
                image_array [k] = nil
            end
            local settings = obs.obs_source_get_settings(source)
        end
        threw_error=true
    end
    if image_dir == "" then
        error("SLIDESHOW ERROR: art dir hasn't been set")
        threw_error=true
    end
    obs.obs_source_release(text_source)
    if threw_error then--get out if things are peachy
        obs.obs_source_release(source)
        return false
    end
    local p = io.popen('dir "'..image_dir..'" /o-d /B')  --Open directory look for files, save data in p
    local list_of_files = {}                             --Shows path as "C:\WINDOWS\system32\cmd.exe" username isn
    local current_index = 0
    for file in p:lines() do                         --Loop through all files
        local lower_string = string.lower(file)
        for i = 1, #allowed_extensions, 1 do        --Make sure it's a valid extension
            if string.find(lower_string, "[.]"..allowed_extensions[i].."$") ~= nil then
                current_index = current_index + 1
                list_of_files[current_index] = file
                break
            end
        end
        if settings_num_of_bag > 0 and current_index == settings_num_of_bag then break end
    end
    p:close()
    if #list_of_files == 0 then
        error("SLIDESHOW ERROR: no images found in art dir")
        return false
    end
    shuffle(list_of_files)
    --local artist_table = {}
    local json_str = "{\"files\":["
    j = 0
    artist_list = {}
    for i = 1, #list_of_files, 1 do
        local skip = false
        --if not list_contains(artist_list, list_of_files[i]) then                              --anon bypasses artist list because there's no way to tell if they're different people
        if settings_max_of_artist > 0 then
            local artist_name = get_artist_name("/"..list_of_files[i])
            if artist_name ~= "anon" then --do artist checks
                local val = artist_list[artist_name]
                if val == nil or val < settings_max_of_artist then
                    if val == nil then val=0 end
                    artist_list[artist_name] = val + 1
                else
                    skip = true
                end
            end
        end
        if not skip then
            image_array[j] = image_dir.."/"..list_of_files[i]
            json_str = json_str..[[{"hidden":false,"selected":false,"value":"]]..image_array[j]..[["},]]
            --artist_list[j] = list_of_files[i]
            j = j + 1
        end
        if settings_num_of_images > 0 and j == settings_num_of_images then break end
    end
    json_str = string.sub(json_str, 0, string.len(json_str)-1)
    json_str = json_str.."]}"
    local temp_files = obs.obs_data_create_from_json(json_str)
    local files_data_array = obs.obs_data_get_array(temp_files, "files")
    --for k in pairs (image_array) do
    --    image_array [k] = nil
    --end
    
    
    local settings = obs.obs_source_get_settings(source)
    --copy slide show's bounds into slide show aspect ratio
    --local scene_item = get_source_scene_item(slideshow_label)
    local scene_item = get_source_scene_item(uuid_to_name(slide_show_UUID))
    obs.obs_sceneitem_addref(scene_item)
    slideshow_scene_item = scene_item
    if scene_item == nil then
        error("SLIDE SHOW ERROR: can't find slideshow scene item")
    end
	
	--local text_item = get_source_scene_item(text_label)
    local text_item = get_source_scene_item(uuid_to_name(slide_text_UUID))
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
    obs.obs_data_set_string(settings, "use_custom_size", math.floor(bounds.x).."x"..math.floor(bounds.y))
    obs.obs_source_update(source, settings)
    obs.obs_data_array_release(files_data_array)
    obs.obs_data_release(temp_files)
    --obs.obs_data_release(settings)
    --
    --settings = obs.obs_source_get_settings(source)
    --if obs.obs_data_save_json(settings, "H:\\Program Files (x86)\\obs-studio\\data\\obs-plugins\\frontend-tools\\scripts\\dump5.json") then
    --    print("true")
    --end
    --local slide_time = obs.obs_data_get_int(settings, "slide_time")
    --local transition_speed = obs.obs_data_get_int(settings, "transition_speed")
    --local files_aray = obs.obs_data_get_array(settings,"files")
    ----image_array_size = 0
    --image_index = 0
    --for i= 0, obs.obs_data_array_count(files_aray)-1, 1
    --do
    --    local current_object = obs.obs_data_array_item(files_aray, i)
    --    image_array[i] = obs.obs_data_get_string(current_object, "value")
    --    --image_array_size = image_array_size + 1
    --end
    --obs.obs_source_update(source, settings)
    --obs.timer_add(text_update, transition_speed+slide_time)
    text_update()
    obs.obs_data_release(settings)
    
    
    --print("dioasj"..obs.obs_source_get_name(source))
    is_slide_changing = false
    if set_callbacks == false then
        --print("setting callbacks")
        gsh = obs.obs_source_get_signal_handler(source)
        
        obs.signal_handler_connect(gsh, "update", source_update)
        obs.signal_handler_connect(gsh, "slide_changed", slide_changed)
        obs.signal_handler_connect(gsh, "media_next", media_next)
        obs.signal_handler_connect(gsh, "media_previous", media_prev)
        obs.signal_handler_connect(gsh, "media_restart", media_restart)
        obs.signal_handler_connect(gsh, "media_stopped", media_stopped)
        local scene = get_source_scene(uuid_to_name(slide_show_UUID))
        --if scene ~= nil then
        --    print("got scnee")
        --else
        --    print("no scene")
        --end
        sceneThing = obs.obs_source_get_signal_handler(obs.obs_scene_get_source(scene))
        
        --aksopd = obs.obs_source_get_signal_handler(get_source_scene_item("art slideshow"))
        obs.signal_handler_connect(sceneThing, "item_transform", item_transform)
        obs.obs_scene_release(scene)
        --local scene_item = get_source_scene_item(uuid_to_name(slide_show_UUID))
        --local adisjdis = obs.obs_get_signal_handler()
        --obs.signal_handler_connect_global(gsh, signals)
        --obs.signal_handler_connect_global(sceneThing, signals)
        --obs.signal_handler_connect_global(sceneThing, signals)
        set_callbacks = true
    end
    
    
    obs.obs_source_release(source)
    is_running = true
    --image_array
end

function signals(a)
    print(a)
end

function clear_slideshow()
    local text_source = obs.obs_get_source_by_uuid(slide_text_UUID)
    if text_source ~= nil then
        local settings = obs.obs_source_get_settings(text_source)
        obs.obs_data_set_string(settings, "text", "")
        obs.obs_source_update(text_source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(text_source)
    else
        error("nil text")
    end
    local gal_source = obs.obs_get_source_by_uuid(slide_show_UUID)
    if gal_source ~= nil then
        local settings = obs.obs_source_get_settings(gal_source)
        obs.obs_data_set_array(settings, "files", obs.obs_data_get_default_array(settings, "files"))
        obs.obs_source_update(gal_source, settings)
        obs.obs_data_release(settings)
        --obs.obs_source_media_stop(gal_source)
        obs.obs_source_release(gal_source)
    else
        error("missing slideshow")
    end
end

function fix_stupid_changing()
    if is_slide_changing == false then
        obs.remove_current_callback()
        force_stop()
    end
end

function force_stop()
    --print("set_callbacks "..set_callbacks)
    --if is_slide_changing==true then
    --    print("slide is changing")
    --    obs.timer_add(fix_stupid_changing, 200)
    --    return false
    --end
    print("Stopping slideshow")
    local gal_source = obs.obs_get_source_by_uuid(slide_show_UUID)
    if set_callbacks == true and gal_source ~= nil then
        gsh = obs.obs_source_get_signal_handler(gal_source)
        obs.signal_handler_disconnect(gsh, "update", source_update)
        obs.signal_handler_disconnect(gsh, "slide_changed", slide_changed)
        obs.signal_handler_disconnect(gsh, "media_next", media_next)
        obs.signal_handler_disconnect(gsh, "media_previous", media_prev)
        obs.signal_handler_disconnect(gsh, "media_restart", media_restart)
        obs.signal_handler_disconnect(gsh, "media_stopped", media_stopped)
        --obs.signal_handler_disconnect_global(gsh, signals)
        
        local scene = get_source_scene(uuid_to_name(slide_show_UUID))
        sceneThing = obs.obs_source_get_signal_handler(obs.obs_scene_get_source(scene))
        obs.signal_handler_disconnect(sceneThing, "item_transform", item_transform)
        obs.obs_source_release(gal_source)
        obs.obs_scene_release(scene)
        obs.obs_sceneitem_release(slideshow_scene_item)
        set_callbacks = false
    end
    clear_slideshow()

    is_running=false
end


function text_update()
    local source = obs.obs_get_source_by_uuid(slide_text_UUID)
    local settings = obs.obs_source_get_settings(source)
    local name = get_artist_name(image_array[image_index])
    obs.obs_data_set_string(settings, "text", name)
    obs.obs_source_update(source, settings)
    obs.obs_data_release(settings)
    obs.obs_source_release(source)
end

function item_transform(calldata)
    local gal_source = obs.obs_get_source_by_uuid(slide_show_UUID)
    local settings = obs.obs_source_get_settings(gal_source)
    if slideshow_scene_item == nil then
        error("SLIDE SHOW ERROR: can't find slideshow scene item")
    end
    local bounds = obs.vec2()
    obs.obs_sceneitem_get_bounds(slideshow_scene_item, bounds)
    bounds.x = math.floor(bounds.x)--if the slideshow is in a group the bounds get floating points which cause issues for this setup
    bounds.y = math.floor(bounds.y)--I hate obs
    if obs.obs_data_get_string(settings, "use_custom_size") ~= bounds.x.."x"..bounds.y then
        obs.obs_data_set_string(settings, "use_custom_size", bounds.x.."x"..bounds.y)
        obs.obs_source_update(gal_source, settings)
        obs.obs_sceneitem_set_bounds(slideshow_scene_item, bounds)
    end
    obs.obs_data_release(settings)
    obs.obs_source_release(gal_source)
end

function slide_changed()
    is_slide_changing = true --sometimes media_next gets called when the slide doesn't actually change, need this to keep things sane
end

function media_next()
    if is_slide_changing == true then
        image_index = 1 + image_index
        image_index = image_index % image_array_size
        text_update()
        is_slide_changing=false
    end
    local gal_source = obs.obs_get_source_by_uuid(slide_show_UUID)
    obs.obs_source_release(gal_source)
end

function media_prev()
    if is_slide_changing == true then
        image_index = image_index - 1 
        image_index = image_index % image_array_size
        text_update()
        is_slide_changing=false
    end
end

function media_restart()
    is_running = true
    image_index = 0
    text_update()
end

function media_stopped()
    local source = obs.obs_get_source_by_uuid(slide_text_UUID)
    local settings = obs.obs_source_get_settings(source)
    obs.obs_data_set_string(settings, "text", "")
    obs.obs_source_update(source, settings)
    obs.obs_data_release(settings)
    
    obs.obs_source_media_stop(source)
    obs.obs_source_release(source)
    is_running = false
end

function source_update() --update
    is_slide_changing=false
    while #image_array ~= 0 do rawset(image_array, #image_array, nil) end
    local gal_source = obs.obs_get_source_by_uuid(slide_show_UUID)
    local settings = obs.obs_source_get_settings(gal_source)
    local file_list = obs.obs_data_get_array(settings, "files")
    for i = 1, obs.obs_data_array_count(file_list), 1 do
        local item = obs.obs_data_array_item(file_list, i)
        local s = obs.obs_data_get_string(item, "value")
        if s ~= "" then
            image_array[i]=obs.obs_data_get_string(item, "value")
        end
        --print(obs.obs_data_get_string(item, "value"))
        obs.obs_data_release(item)
    end
    
    ph = obs.obs_source_get_proc_handler(gal_source)
    cd = obs.calldata()
    obs.proc_handler_call(ph, "total_files", cd)    
    image_array_size = obs.calldata_int(cd, "total_files")
    obs.calldata_free(cd)
    obs.obs_source_release(gal_source)
    --print(artist_list)
    obs.obs_data_array_release(file_list)
    obs.obs_data_release(settings)
    image_index = 0
    text_update()
end

function on_event(event) --for automatic start in the future
    if (event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED or event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED) and not is_streaming and not is_recording and not is_running then
        if auto_start then
            force_run()
        end
	end
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
        is_recording=true
        --print("is_recording true")
    end
    if event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
        is_recording=false
        --print("is_recording false")
    end
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
        is_streaming=true
        --print("is_streaming true")
    end
    if event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
        is_streaming=false
        --print("is_streaming false")
    end
	if (event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED or event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED) and not is_streaming and not is_recording then
		if auto_start then
            force_stop()
        end
	end
    if event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
        if slide_text_UUID ~= nil then
            force_stop()
        end
    end
    
    --if event == obs.OBS_FRONTEND_EVENT_SCRIPTING_SHUTDOWN then
    --    clear_slideshow()
    --    force_stop()
    --    if setting_ref ~= nil then
    --        obs.obs_data_release(setting_ref)
    --    end
    --end
    --if event == obs.OBS_FRONTEND_EVENT_EXIT then
    --    force_stop()
    --end
end


function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "slide_text_UUID", "")
    obs.obs_data_set_default_string(settings, "slide_show_UUID", "")
    obs.obs_data_set_default_int(settings, "bag_num", -1)
    obs.obs_data_set_default_int(settings, "num_of_images", -1)
    obs.obs_data_set_default_int(settings, "restrict_artists", -1)
    obs.obs_data_set_default_string(settings, "source", "Click Setup")
    obs.obs_data_set_default_string(settings, "source2", "Click Setup")
    obs.obs_data_set_default_bool(settings, "auto_move", true)
    obs.obs_data_set_default_bool(settings, "auto_start", true)
    --if setting_ref ~= nil then
    --    --local gay = settings --needs a copy of settings to make sure it isn't released on next line, for some reason
    --    obs.obs_data_release(setting_ref)
    --    --setting_ref = settings
    --    --obs.obs_data_release(gay)
    --end
    if setting_ref == nil then
        obs.obs_data_addref(settings)
        setting_ref = settings
    end
end

function gallery_callback(props, prop, settings)
	--print("text callback")
    local new_thing = obs.obs_get_source_by_name(obs.obs_data_get_string(settings, "source"))
    if new_thing ~= nil and obs.obs_data_get_string(settings, "slide_show_UUID") ~= obs.obs_source_get_uuid(new_thing) then
		slide_show_UUID = obs.obs_source_get_uuid(new_thing)
        obs.obs_data_set_string(settings, "slide_show_UUID", slide_show_UUID)
    end
    obs.obs_source_release(new_thing)
    return true
end

function text_callback(props, prop, settings)
	--print("text callback")
    local new_thing = obs.obs_get_source_by_name(obs.obs_data_get_string(settings, "source2"))
    if new_thing ~= nil and obs.obs_data_get_string(settings, "slide_text_UUID") ~= obs.obs_source_get_uuid(new_thing) then
        slide_text_UUID = obs.obs_source_get_uuid(new_thing)
        obs.obs_data_set_string(settings, "slide_text_UUID", slide_text_UUID)
    end
    obs.obs_source_release(new_thing)
    return true
end

function script_properties()
    slide_text_UUID = obs.obs_data_get_string(setting_ref, "slide_text_UUID")
	if slide_text_UUID ~= "" then
		local text_source = obs.obs_get_source_by_uuid(slide_text_UUID)
		if text_source ~= nil and obs.obs_source_get_name(text_source) ~= obs.obs_data_get_string(setting_ref, "source2") then
			obs.obs_data_set_string(setting_ref, "source2", obs.obs_source_get_name(text_source))
		end
		obs.obs_source_release(text_source)
    end
	slide_show_UUID = obs.obs_data_get_string(setting_ref, "slide_show_UUID")
	if slide_show_UUID ~= "" then
		local slide_source = obs.obs_get_source_by_uuid(slide_show_UUID)
		if slide_source ~= nil and obs.obs_source_get_name(slide_source) ~= obs.obs_data_get_string(setting_ref, "source") then
			obs.obs_data_set_string(setting_ref, "source", obs.obs_source_get_name(slide_source))
		end
		obs.obs_source_release(slide_source)
    end
	local props = obs.obs_properties_create()
    
    local slide_show_UUID_prop = obs.obs_properties_add_text(props, "slide_show_UUID", "private slideshow UUID", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_visible(slide_show_UUID_prop, false)
    local slide_text_UUID_prop = obs.obs_properties_add_text(props, "slide_text_UUID", "private slideshow text UUID", obs.OBS_TEXT_DEFAULT)
    obs.obs_property_set_visible(slide_text_UUID_prop, false)
    if setup_pressed then
        setup_pressed = false
    end
    
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
                --print(obs.obs_source_get_uuid(source))
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(gallery_prop, name, name)
            end
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_gdiplus_v2" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(text_prop, name, name)
            end
        end
    end
    
    obs.obs_property_set_modified_callback(gallery_prop, gallery_callback)
    obs.obs_property_set_modified_callback(text_prop, text_callback)
    obs.source_list_release(sources)
    
    local image_dir_settomg = obs.obs_properties_add_path(props, "art_dir", "Art Directory", obs.OBS_PATH_DIRECTORY, "",NULL)
    local welcome_button = obs.obs_properties_add_button(props, "welcome_button", "Force run", force_run)
    local welcome2_button = obs.obs_properties_add_button(props, "welcome_button2", "Force stop", force_stop)
    local bool_button = obs.obs_properties_add_bool(props, "auto_move", "Auto move credit text")
    local bool_button_auto = obs.obs_properties_add_bool(props, "auto_start", "Auto start/stop slideshow")
    local bag_num = obs.obs_properties_add_int(props, "bag_num", "# of most recent pics \n(-1 for whole folder)", -1, 10000, 1)
    local num_of_recent_images = obs.obs_properties_add_int(props, "num_of_images", "Slideshow length\n(-1 for max size)", -1, 10000, 1)
    local artist_num = obs.obs_properties_add_int(props, "restrict_artists", "Max # allowed\nfrom same artist\n(-1 for disabled)", -1, 30, 1)
    obs.obs_property_set_long_description(artist_num, "uhsuids")

	return props
end

function script_update(settings)
    order_helper = order_helper * 3
	--print("update called")
    --local text_source = obs.obs_get_source_by_uuid(slide_text_UUID)
    --print(obs.obs_source_get_name(text_source))
    --print(obs.obs_data_get_string(settings, "source2"))
    --if obs.obs_source_get_name(text_source) ~= obs.obs_data_get_string(settings, "source2") then
    --    if obs.obs_source_get_uuid(settings, "source2") ~= nil then
    --        obs.obs_data_set_string(settings, "slide_text_UUID", obs.obs_source_get_uuid(settings, "source2"))
    --    end
    --end
    --print(obs.obs_data_get_string(settings, "source2"))
    --obs.obs_source_release(text_source)
    --
    --
    --local slide_source = obs.obs_get_source_by_uuid(slide_show_UUID)
    --if obs.obs_source_get_name(slide_source) ~= obs.obs_data_get_string(settings, "source") then
    --    obs.obs_data_set_string(settings, "slide_show_UUID", obs.obs_source_get_uuid(slide_source))
    --end
    --obs.obs_source_release(slide_source)
    
    slide_text_UUID = obs.obs_data_get_string(settings, "slide_text_UUID")
    slide_show_UUID = obs.obs_data_get_string(settings, "slide_show_UUID")
    
	scene = obs.obs_data_get_string(settings, "scene")
    text_label = obs.obs_data_get_string(settings, "source2")
    slideshow_label = obs.obs_data_get_string(settings, "source")
    image_dir = obs.obs_data_get_string(settings, "art_dir")
    settings_num_of_images = obs.obs_data_get_int(settings, "num_of_images")
    settings_max_of_artist = obs.obs_data_get_int(settings, "restrict_artists")
    settings_num_of_bag = obs.obs_data_get_int(settings, "bag_num")
    auto_move = obs.obs_data_get_bool(settings, "auto_move")
    auto_start = obs.obs_data_get_bool(settings, "auto_start")

    
    ----local properties = obs.obs_source_properties(obs.obs_get_source_by_name(slideshow_label))
    ----local windowProp = obs.obs_properties_get(properties, "slideshow")
    ----local propName = obs.obs_property_name(windowProp)
    --if setting_ref ~= nil then
    --    --local gay = settings --needs a copy of settings to make sure it isn't released on next line, for some reason
    --    obs.obs_data_release(setting_ref)
    --    --setting_ref = settings
    --    --obs.obs_data_release(gay)
    --end
    if setting_ref == nil then
        obs.obs_data_addref(settings)
        setting_ref = settings
    end
end

--function script_save()--apparently this is only called when obs is shutting down, could cause random stops otherwise
--    print("saving")
--    force_stop()
--end

function script_description()
	return "Selects random recent art and credits it\nPippa love ^-^ 🔌🐰"
end

function script_load(settings)
    
    slide_text_UUID = obs.obs_data_get_string(settings, "slide_text_UUID")
    slide_show_UUID = obs.obs_data_get_string(settings, "slide_show_UUID")
    
    --if slide_text_UUID ~= nil then
    --    force_stop()
    --end
    
    order_helper = order_helper + 2
	obs.obs_frontend_add_event_callback(on_event)
    math.randomseed(os.time())
end

function script_unload()
    if setting_ref ~= nil then
        obs.obs_data_release(setting_ref)
    end
end