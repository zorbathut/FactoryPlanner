-- Handles populating the preferences dialog
function open_preferences_dialog(flow_modal_dialog, args)
    flow_modal_dialog.parent.caption = {"label.preferences"}

    -- Label
    local label_preferences_info = flow_modal_dialog.add{type="label", name="label_preferences_info", 
      caption={"label.preferences_info"}}
    label_preferences_info.style.single_line = false
    label_preferences_info.style.bottom_padding = 6

    -- Machine preferences
    local label_machine_info = flow_modal_dialog.add{type="label", name="label_machines_info", 
      caption={"label.preferences_title_machines"}}
    label_machine_info.style.font = "fp-font-bold-15p"
    label_machine_info.tooltip = {"label.preferences_title_machines_tooltip"}
    local scroll_pane_all_machines = flow_modal_dialog.add{type="scroll-pane", name="scroll-pane_all_machines", 
      direction="vertical"}
    scroll_pane_all_machines.style.horizontally_stretchable = true
    scroll_pane_all_machines.style.maximal_height = 650
    local table_all_machines = scroll_pane_all_machines.add{type="table", name="table_all_machines", column_count=2}
    table_all_machines.style.bottom_padding = 6
    table_all_machines.style.left_padding = 6

    refresh_preferences_dialog(flow_modal_dialog.gui.player)
end

-- No additional action needs to be taken when the preferences dialog is closed
function close_preferences_dialog(flow_modal_dialog, action, data)
end

-- No conditions needed for the preferences dialog
function get_preferences_condition_instructions()
    return {data = {}, conditions = {}}
end


-- Creates the modal dialog to change your preferences
function refresh_preferences_dialog(player)
    -- Machine preferences
    local table_all_machines = player.gui.center["fp_frame_modal_dialog"]["flow_modal_dialog"]
      ["scroll-pane_all_machines"]["table_all_machines"]
    table_all_machines.clear()

    for category, data in pairs(global["all_machines"]) do
        if #data.order > 1 then
            table_all_machines.add{type="label", name="label_" .. category, caption="'" .. category .. "':    "}
            local table_machines = table_all_machines.add{type="table", name="table_machines:" .. category,
              column_count=#data.order+1}
            for _, machine_name in ipairs(data.order) do
                local button_machine = table_machines.add{type="sprite-button", name="fp_sprite-button_preferences_machine_"
                  .. category .. "_" .. machine_name, sprite="entity/" .. machine_name}
                local tooltip = data.machines[machine_name].localised_name
                if data.default_machine_name == machine_name then
                    button_machine.style = "fp_button_icon_medium_green"
                    tooltip = {"", tooltip, "\n", {"tooltip.selected"}}
                else 
                    button_machine.style = "fp_button_icon_medium_hidden"
                end
                button_machine.tooltip = tooltip
            end
        end
    end
end

-- Changes the preferred machine for the given category
function change_machine_preference(player, category, machine_name)
    global["all_machines"][category].default_machine_name = machine_name
    refresh_preferences_dialog(player)
end