matrix_dialog = {}

-- ** LOCAL UTIL **
local function show_linearly_dependent_recipes(modal_data, recipe_protos)
    local flow_recipes = modal_data.modal_elements.content_frame.add{type="flow", direction="vertical"}
    local label_title = flow_recipes.add{type="label", caption={"fp.matrix_linearly_dependent_recipes"}}
    label_title.style.font = "heading-2"

    local frame_recipes = flow_recipes.add{type="frame", direction="horizontal", style="slot_button_deep_frame"}
    local table_recipes = frame_recipes.add{type="table", column_count=8, style="filter_slot_table"}
    for _, recipe_proto in ipairs(recipe_protos) do
        table_recipes.add{type="sprite", sprite=recipe_proto.sprite, tooltip=recipe_proto.localised_name}
    end
end

local function update_dialog_submit_button(modal_data, matrix_metadata)
    local num_needed_free_items = matrix_metadata.num_rows - matrix_metadata.num_cols + #matrix_metadata.free_items
    local curr_free_items = #modal_data["free_items"]

    local message = nil
    if num_needed_free_items > curr_free_items then
        message = {"fp.matrix_constrained_items", num_needed_free_items, {"fp.pl_item", num_needed_free_items}}
    end
    modal_dialog.set_submit_button_state(modal_data.modal_elements, (message == nil), message)
end

local function refresh_item_category(modal_data, type)
    local table_items = modal_data.modal_elements[type .. "_table"]
    table_items.clear()

    for index, proto in ipairs(modal_data[type .. "_items"]) do
        local button = table_items.add{type="sprite-button", sprite=proto.sprite, tooltip=proto.localised_name,
          tags={mod="fp", on_gui_click="swap_item_category", type=type, index=index}, style="flib_slot_button_default",
          mouse_button_filter={"left"}}
        button.style.size = 48
    end
end

local function create_item_category(modal_data, type, label_arg)
    local flow_category = modal_data.modal_elements.content_frame.add{type="flow", direction="vertical"}

    local title_string = (type == "free") and {"fp.matrix_free_items"} or
      {"fp.matrix_constrained_items", label_arg, {"fp.pl_item", label_arg}}
    local label_title = flow_category.add{type="label", caption=title_string}
    label_title.style.font = "heading-2"

    local frame_items = flow_category.add{type="frame", direction="horizontal", style="slot_button_deep_frame"}
    local table_items = frame_items.add{type="table", column_count=8, style="filter_slot_table"}
    modal_data.modal_elements[type .. "_table"] = table_items

    refresh_item_category(modal_data, type)
end

local function swap_item_category(player, tags, _)
    local ui_state = data_util.get("ui_state", player)
    local subfactory = ui_state.context.subfactory
    local modal_data = ui_state.modal_data

    -- update the free items here, set the constrained items based on linear dependence data
    if tags.type == "free" then
        -- note this assumes the gui's list has the same order as the subfactory
        table.remove(subfactory.matrix_free_items, tags.index)
    else -- "constrained"
        local item_proto = modal_data["constrained_items"][tags.index]
        table.insert(subfactory.matrix_free_items, item_proto)
    end

    local matrix_metadata = matrix_solver.get_matrix_solver_metadata(modal_data.subfactory_data)
    local linear_dependence_data = matrix_solver.get_linear_dependence_data(modal_data.subfactory_data, matrix_metadata)
    modal_data.constrained_items = linear_dependence_data.allowed_free_items
    modal_data.free_items = matrix_metadata.free_items

    refresh_item_category(modal_data, "constrained")
    refresh_item_category(modal_data, "free")
    update_dialog_submit_button(modal_data, matrix_metadata)
end


-- ** TOP LEVEL **
matrix_dialog.dialog_settings = (function(_) return {
    caption = {"fp.matrix_solver"},
    create_content_frame = true,
    show_submit_button = true
} end)

function matrix_dialog.early_abort_check(player, modal_data)
    local ui_state = data_util.get("ui_state", player)
    local subfactory = ui_state.context.subfactory

    if subfactory.selected_floor.Line.count == 0 then return true end

    local subfactory_data = calculation.interface.generate_subfactory_data(player, subfactory)
    local matrix_metadata = matrix_solver.get_matrix_solver_metadata(subfactory_data)

    modal_data.subfactory_data = subfactory_data

    local linear_dependence_data = matrix_solver.get_linear_dependence_data(subfactory_data, matrix_metadata)

    if #linear_dependence_data.linearly_dependent_recipes > 0 then  -- too many ways to create the products
        modal_data.linearly_dependent_recipes = linear_dependence_data.linearly_dependent_recipes
        subfactory.linearly_dependant = true
        return false
    end
    subfactory.linearly_dependant = false  -- TODO not the proper way to signal this, but it works

    modal_data.constrained_items = linear_dependence_data.allowed_free_items
    modal_data.free_items = matrix_metadata.free_items

    local num_needed_free_items = matrix_metadata.num_rows - matrix_metadata.num_cols + #matrix_metadata.free_items
    if num_needed_free_items == 0 then  -- User doesn't need to select any free items, just run the matrix solver
        if modal_data.configuration then
            title_bar.enqueue_message(player, {"fp.warning_no_matrix_configuration_needed"}, "warning", 1, false)
        end
        return true
    end

    -- If it gets to here, the dialog should open normally
    modal_data.num_needed_free_items = num_needed_free_items
    modal_data.matrix_metadata = matrix_metadata
    return false
end

function matrix_dialog.open(player, modal_data)
    if data_util.get("context", player).subfactory.linearly_dependant then
        show_linearly_dependent_recipes(modal_data, modal_data.linearly_dependent_recipes)
        modal_dialog.set_submit_button_state(modal_data.modal_elements, false, {"fp.matrix_linearly_dependent_recipes"})

        -- Dispose of the temporary GUI-opening variables
        modal_data.linearly_dependent_recipes = nil
    else
        create_item_category(modal_data, "constrained", modal_data.num_needed_free_items)
        create_item_category(modal_data, "free")
        update_dialog_submit_button(modal_data, modal_data.matrix_metadata)

        -- Dispose of the temporary GUI-opening variables
        modal_data.num_needed_free_items = nil
        modal_data.matrix_metadata = nil
    end
end

function matrix_dialog.close(player, action)
    if action == "submit" then
        local ui_state = data_util.get("ui_state", player)
        local subfactory = ui_state.context.subfactory
        subfactory.matrix_free_items = ui_state.modal_data.free_items

        calculation.update(player, subfactory)
        main_dialog.refresh(player, "subfactory")

    elseif action == "cancel" then
        main_dialog.refresh(player, "production_detail")
    end
end


-- ** EVENTS **
matrix_dialog.gui_events = {
    on_gui_click = {
        {
            name = "swap_item_category",
            handler = swap_item_category
        }
    }
}
