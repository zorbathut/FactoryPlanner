require("ui.elements.title_bar")
require("ui.elements.subfactory_list")
require("ui.elements.subfactory_info")
require("ui.elements.view_state")
require("ui.elements.item_boxes")
require("ui.elements.production_box")
require("ui.elements.production_table")
require("ui.elements.production_handler")

main_dialog = {}

-- ** LOCAL UTIL **
-- Makes sure that another GUI can open properly while a modal dialog is open.
-- The FP interface can have at most 3 layers of GUI: main interface, modal dialog, selection mode.
-- We need to make sure opening the technology screen (for example) from any of those layers behaves properly.
-- We need to consider that if the technology screen is opened (which is the reason we get this event),
-- the game automtically closes the currently open GUI before calling this one. This means the top layer
-- that's open at that stage is closed already when we get here. So we're at most at the modal dialog
-- layer at this point and need to close the things below, if there are any.
local function handle_other_gui_opening(player)
    local ui_state = data_util.get("ui_state", player)

    -- With that in mind, if there's a modal dialog open, we were in selection mode, and need to close the dialog
    if ui_state.modal_dialog_type ~= nil then modal_dialog.exit(player, "cancel", true) end

    -- Then, at this point we're at most at the stage where the main dialog is open, so close it
    if main_dialog.is_in_focus(player) then main_dialog.toggle(player, true) end
end

local function handle_background_dimmer_click(player, _, _)
    local ui_state = data_util.get("ui_state", player)
    ui_state.main_elements.main_frame.bring_to_front()

    if ui_state.modal_dialog_type ~= nil then
        local modal_elements = ui_state.modal_data.modal_elements
        modal_elements.interface_dimmer.bring_to_front()
        modal_elements.modal_frame.bring_to_front()
    end
end


-- ** TOP LEVEL **
function main_dialog.rebuild(player, default_visibility)
    local ui_state = data_util.get("ui_state", player)
    local main_elements = ui_state.main_elements

    local interface_visible = default_visibility
    -- Delete the existing interface if there is one
    if main_elements.main_frame ~= nil then
        if main_elements.main_frame.valid then
            interface_visible = main_elements.main_frame.visible
            main_elements.main_frame.destroy()
        end
        main_elements.background_dimmer.destroy()

        -- Reset all main element references
        ui_state.main_elements = {}
        main_elements = ui_state.main_elements
    end


    -- Background dimmer (created first so the layering is correct, style set afterwards)
    local background_dimmer = player.gui.screen.add{type="frame",
      tags={mod="fp", on_gui_click="re-layer_background_dimmer"}}
    main_elements["background_dimmer"] = background_dimmer


    -- Create and configure the top-level frame
    local frame_main_dialog = player.gui.screen.add{type="frame", direction="vertical",
      visible=interface_visible, tags={mod="fp", on_gui_closed="close_main_dialog"},
      name="fp_frame_main_dialog"}
    main_elements["main_frame"] = frame_main_dialog

    local dimensions = main_dialog.determine_main_dialog_dimensions(player)
    ui_state.main_dialog_dimensions = dimensions
    frame_main_dialog.style.size = dimensions
    ui_util.properly_center_frame(player, frame_main_dialog, dimensions)


    -- Create the actual dialog structure
    main_elements.flows = {}

    view_state.rebuild_state(player)  -- initializes the view_state
    title_bar.build(player)

    local main_horizontal = frame_main_dialog.add{type="flow", direction="horizontal"}
    main_horizontal.style.horizontal_spacing = FRAME_SPACING
    main_elements.flows["main_horizontal"] = main_horizontal

    local left_vertical = main_horizontal.add{type="flow", direction="vertical"}
    left_vertical.style.vertical_spacing = FRAME_SPACING
    main_elements.flows["left_vertical"] = left_vertical
    subfactory_list.build(player)
    subfactory_info.build(player)

    local right_vertical = main_horizontal.add{type="flow", direction="vertical"}
    right_vertical.style.vertical_spacing = FRAME_SPACING
    main_elements.flows["right_vertical"] = right_vertical
    item_boxes.build(player)
    production_box.build(player)
    production_table.build(player)

    title_bar.refresh_message(player)

    if interface_visible then player.opened = frame_main_dialog end
    main_dialog.set_pause_state(player, frame_main_dialog)
end


local refreshable_elements = {subfactory_list=true, subfactory_info=true,
  item_boxes=true, production_box=true, production_table=true}

function main_dialog.refresh(player, context_to_refresh)
    if context_to_refresh == nil then return end

    local main_frame = data_util.get("main_elements", player).main_frame
    if main_frame == nil then return end

    if refreshable_elements[context_to_refresh] ~= nil then
        -- If the given argument points to a specific element, only refresh that one
        _G[context_to_refresh].refresh(player)
    else
        -- If not, it designates a category of elements that need to be refreshed
        -- The code to refresh is independent for each element so call order doesn't matter

        production_table.refresh(player)
        -- If you only want the production table, refresh it using "production_table"
        production_box.refresh(player)
        if context_to_refresh == "production_detail" then goto end_refresh end
        item_boxes.refresh(player)
        if context_to_refresh == "production" then goto end_refresh end
        subfactory_info.refresh(player)
        if context_to_refresh == "subfactory" then goto end_refresh end
        subfactory_list.refresh(player)
        -- Refreshing everything doesn't need a name, but should be called "all" for clarity
    end

    ::end_refresh::
    title_bar.refresh_message(player)
end

function main_dialog.toggle(player, skip_player_opened)
    local ui_state = data_util.get("ui_state", player)
    local frame_main_dialog = ui_state.main_elements.main_frame

    if frame_main_dialog == nil or not frame_main_dialog.valid then
        main_dialog.rebuild(player, true)  -- sets opened and paused-state itself

    elseif ui_state.modal_dialog_type == nil then  -- don't toggle if modal dialog is open
        local new_dialog_visible = not frame_main_dialog.visible
        frame_main_dialog.visible = new_dialog_visible
        if not skip_player_opened then  -- flag used only for hacky internal reasons
            player.opened = (new_dialog_visible) and frame_main_dialog or nil
        end

        main_dialog.set_pause_state(player, frame_main_dialog)
        title_bar.refresh_message(player)

        -- Make sure FP is not behind some vanilla interfaces
        if new_dialog_visible then
            ui_state.main_elements.background_dimmer.bring_to_front()
            frame_main_dialog.bring_to_front()
        end
    end
end


-- Returns true when the main dialog is open while no modal dialogs are
function main_dialog.is_in_focus(player)
    local frame_main_dialog = data_util.get("main_elements", player).main_frame
    return (frame_main_dialog ~= nil and frame_main_dialog.valid and frame_main_dialog.visible
      and data_util.get("ui_state", player).modal_dialog_type == nil)
end

-- Sets the game.paused-state as is appropriate
function main_dialog.set_pause_state(player, frame_main_dialog, force_false)
    local background_dimmer = data_util.get("main_elements", player).background_dimmer
    background_dimmer.visible = false

    -- Don't touch paused-state if this is a multiplayer session or the editor is active
    if game.is_multiplayer() or player.controller_type == defines.controllers.editor then return end

    local paused = false
    if not data_util.get("preferences", player).pause_on_interface or force_false then
        paused = false
    else
        paused = frame_main_dialog.visible
    end
    game.tick_paused = paused

    -- Hide the dimmer completely when the main interface is not shown
    background_dimmer.visible = frame_main_dialog.visible
    -- Use the dimmer as click protection on vanilla GUIs even if it doesn't actually dim anything
    background_dimmer.style = (paused) and "fp_frame_semitransparent" or "fp_frame_transparent"
    -- Re-set the size because assigning a new style resets it (*grumble*)
    local resolution, scale = player.display_resolution, player.display_scale
    background_dimmer.style.size = {math.ceil(resolution.width / scale), math.ceil(resolution.height / scale)}
end

-- Accepts custom width and height parameters so dimensions can be tried out without needing to change actual settings
function main_dialog.determine_main_dialog_dimensions(player, products_per_row, subfactory_list_rows)
    local settings = data_util.get("settings", player)
    products_per_row = products_per_row or settings.products_per_row
    subfactory_list_rows = subfactory_list_rows or settings.subfactory_list_rows

    -- Width of the larger ingredients-box, which has twice the buttons per row
    local boxes_width_1 = (products_per_row * 2 * ITEM_BOX_BUTTON_SIZE) + (2 * ITEM_BOX_PADDING)
    -- Width of the two smaller product+byproduct-boxes
    local boxes_width_2 = 2 * ((products_per_row * ITEM_BOX_BUTTON_SIZE) + (2 * ITEM_BOX_PADDING))
    local width = SUBFACTORY_LIST_WIDTH + boxes_width_1 + boxes_width_2 + ((2+3) * FRAME_SPACING)

    local subfactory_list_height = SUBFACTORY_SUBHEADER_HEIGHT + (subfactory_list_rows * SUBFACTORY_LIST_ELEMENT_HEIGHT)
    local height = TITLE_BAR_HEIGHT + subfactory_list_height + SUBFACTORY_INFO_HEIGHT + ((2+1) * FRAME_SPACING)

    return {width=width, height=height}
end


function NTH_TICK_HANDLERS.delayed_interface_toggle(metadata)
    game.print("Mods reloaded")
    main_dialog.toggle(game.get_player(metadata.player_index))
end


-- ** EVENTS **
main_dialog.gui_events = {
    on_gui_closed = {
        {
            name = "close_main_dialog",
            handler = (function(player, _)
                main_dialog.toggle(player)
            end)
        }
    },
    on_gui_click = {
        {
            name = "mod_gui_toggle_interface",
            handler = (function(player, _, _)
                if DEVMODE then  -- implicit mod reload for easier development
                    game.reload_mods()   -- needs to be delayed by a tick since the reload is not instant
                    data_util.nth_tick.add((game.tick + 1), "delayed_interface_toggle", {player_index=player.index})
                else
                    main_dialog.toggle(player)
                end
            end)
        },
        {
            name = "re-layer_background_dimmer",
            handler = handle_background_dimmer_click
        }
    }
}

main_dialog.misc_events = {
    on_gui_opened = handle_other_gui_opening,

    on_player_display_resolution_changed = (function(player, _)
        main_dialog.rebuild(player, false)
    end),

    on_player_display_scale_changed = (function(player, _)
        main_dialog.rebuild(player, false)
    end),

    on_lua_shortcut = (function(player, event)
        if event.prototype_name == "fp_open_interface" then
            main_dialog.toggle(player)
        end
    end),

    fp_toggle_main_dialog = (function(player, _)
        main_dialog.toggle(player)
    end)
}
