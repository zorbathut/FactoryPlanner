item_boxes = {}

--- ** LOCAL UTIL **
local function add_recipe(player, context, type, item_proto)
    if type == "byproduct" and context.subfactory.matrix_free_items == nil then
        title_bar.enqueue_message(player, {"fp.error_cant_add_byproduct_recipe"}, "error", 1, true)
        return
    end

    if context.floor.level > 1 then
        production_box.change_floor(player, "top")
        local message = {"fp.warning_recipe_wrong_floor", {"fp.pu_" .. type, 1}}
        -- This needs a lifetime of 2 to survive one additional refresh down the chain
        title_bar.enqueue_message(player, message, "warning", 2, false)
    end

    local production_type = (type == "byproduct") and "consume" or "produce"
    modal_dialog.enter(player, {type="recipe", modal_data={product_proto=item_proto, production_type=production_type}})
end

local function build_item_box(player, category, column_count)
    local item_boxes_elements = data_util.get("main_elements", player).item_boxes

    local window_frame = item_boxes_elements.horizontal_flow.add{type="frame", direction="vertical",
      style="inside_shallow_frame"}
    window_frame.style.top_padding = 6
    window_frame.style.bottom_padding = ITEM_BOX_PADDING

    local label = window_frame.add{type="label", caption={"fp.pu_" .. category, 2}, style="caption_label"}
    label.style.left_padding = ITEM_BOX_PADDING
    label.style.bottom_margin = 4

    local scroll_pane = window_frame.add{type="scroll-pane", style="fp_scroll-pane_slot_table"}
    scroll_pane.style.maximal_height = ITEM_BOX_MAX_ROWS * ITEM_BOX_BUTTON_SIZE
    scroll_pane.style.horizontally_stretchable = false
    scroll_pane.style.vertically_stretchable = false

    local item_frame = scroll_pane.add{type="frame", style="slot_button_deep_frame"}
    item_frame.style.width = column_count * ITEM_BOX_BUTTON_SIZE

    local table_items = item_frame.add{type="table", column_count=column_count, style="filter_slot_table"}
    item_boxes_elements[category .. "_item_table"] = table_items
end

local function refresh_item_box(player, category, subfactory, allow_addition)
    local ui_state = data_util.get("ui_state", player)
    local item_boxes_elements = ui_state.main_elements.item_boxes
    local class = (category:gsub("^%l", string.upper))

    local table_items = item_boxes_elements[category .. "_item_table"]
    table_items.clear()

    if not subfactory or not subfactory.valid then return 0 end

    local table_item_count = 0
    local metadata = view_state.generate_metadata(player, subfactory, 4, true)
    local default_style, tut_mode_tooltip, global_enable = "flib_slot_button_default", "", true

    if class == "Product" then
        default_style = "flib_slot_button_red"
        tut_mode_tooltip = ui_util.generate_tutorial_tooltip(player, "tl_product", true, true, true)
    elseif class == "Byproduct" then
        default_style = "flib_slot_button_red"
        if subfactory.matrix_free_items ~= nil then
            tut_mode_tooltip = ui_util.generate_tutorial_tooltip(player, "tl_byproduct", true, true, true)
        else
            global_enable = false
        end
    elseif class == "Ingredient" then
        tut_mode_tooltip = ui_util.generate_tutorial_tooltip(player, "tl_ingredient", true, true, true)
    end

    for _, item in ipairs(Subfactory.get_in_order(subfactory, class)) do
        local required_amount = (class == "Product") and Item.required_amount(item) or nil
        local amount, number_tooltip = view_state.process_item(metadata, item, required_amount, nil)
        if amount == -1 then goto skip_item end  -- an amount of -1 means it was below the margin of error

        local style, satisfaction_line = default_style, ""
        if class == "Product" and amount ~= nil and amount ~= "0" then
            local satisfied_percentage = (item.amount / required_amount) * 100
            local percentage_string = ui_util.format_number(satisfied_percentage, 3)
            satisfaction_line = {"fp.newline", {"fp.two_word_title", (percentage_string .. "%"), {"fp.satisfied"}}}

            if satisfied_percentage <= 0 then style = "flib_slot_button_red"
            elseif satisfied_percentage < 100 then style = "flib_slot_button_yellow"
            else style = "flib_slot_button_green" end
        end

        local indication, tut_tooltip, enabled = "", tut_mode_tooltip, global_enable
        if item.proto.type == "entity" then  -- only relevant to ingredients
            indication = {"fp.indication", {"fp.indication_raw_ore"}}
            tut_tooltip = ""
            enabled = false
        end

        local name_line = {"fp.two_word_title", item.proto.localised_name, indication}
        local number_line = (number_tooltip) and {"fp.newline", number_tooltip} or ""
        local tooltip = {"", name_line, number_line, satisfaction_line, tut_tooltip}

        table_items.add{type="sprite-button", tooltip=tooltip, number=amount, style=style, sprite=item.proto.sprite,
          tags={mod="fp", on_gui_click="act_on_top_level_item", category=category, item_id=item.id},
          enabled=enabled, mouse_button_filter={"left-and-right"}}
        table_item_count = table_item_count + 1

        ::skip_item::  -- goto for fun, wooohoo
    end

    if allow_addition then  -- meaning allow the user to add items of this type
        local button_add = table_items.add{type="sprite-button", enabled=(not ui_state.flags.archive_open),
          tags={mod="fp", on_gui_click="add_top_level_item", category=category}, sprite="utility/add",
          tooltip={"fp.two_word_title", {"fp.add"}, {"fp.pl_" .. category, 1}},
          style="fp_sprite-button_inset_tiny", mouse_button_filter={"left"}}
        button_add.style.padding = 3
        button_add.style.margin = 3
        table_item_count = table_item_count + 1
    end

    local table_rows_required = math.ceil(table_item_count / table_items.column_count)
    return table_rows_required
end


local function handle_item_button_click(player, tags, metadata)
    local context = data_util.get("context", player)
    local subfactory = context.subfactory

    local class = (tags.category:gsub("^%l", string.upper))
    local item = Subfactory.get(subfactory, class, tags.item_id)

    if metadata.alt then
        data_util.execute_alt_action(player, "show_item", {item=item.proto, click=metadata.click})

    elseif not ui_util.check_archive_status(player) then
        return

    else  -- individual handlers
        if class == "Product" then
            if metadata.direction ~= nil then  -- Shift product in the given direction
                if Subfactory.shift(subfactory, item, metadata.direction) then
                    -- Row count doesn't change, so we can refresh directly
                    refresh_item_box(player, "product", subfactory, true)
                else
                    local direction_string = (metadata.direction == "negative") and {"fp.left"} or {"fp.right"}
                    local message = {"fp.error_list_item_cant_be_shifted", {"fp.pl_product", 1}, direction_string}
                    title_bar.enqueue_message(player, message, "error", 1, true)
                end

            elseif metadata.click == "left" then
                add_recipe(player, context, "product", item.proto)

            elseif metadata.click == "right" then
                if metadata.action == "edit" then
                    modal_dialog.enter(player, {type="picker", modal_data={object=item, item_category="product"}})

                elseif metadata.action == "delete" then
                    Subfactory.remove(subfactory, item)

                    calculation.update(player, subfactory)
                    main_dialog.refresh(player, "subfactory")
                end
            end

        elseif class == "Byproduct" then
            add_recipe(player, context, "byproduct", item.proto)

        elseif class == "Ingredient" then
            if metadata.click == "left" then
                add_recipe(player, context, "ingredient", item.proto)
            elseif metadata.click == "right" then
                -- Set the view state so that the amount shown in the dialog makes sense
                view_state.select(player, "items_per_timescale", "subfactory")  -- refreshes "subfactory" if necessary

                local modal_data = {
                    title = {"fp.options_item_title", {"fp.pl_ingredient", 1}},
                    text = {"fp.options_item_text", item.proto.localised_name},
                    submission_handler_name = "scale_subfactory_by_ingredient_amount",
                    object = item,
                    fields = {
                        {
                            type = "numeric_textfield",
                            name = "item_amount",
                            caption = {"fp.options_item_amount"},
                            tooltip = {"fp.options_subfactory_ingredient_amount_tt"},
                            text = item.amount,
                            width = 140,
                            focus = true
                        }
                    }
                }
                modal_dialog.enter(player, {type="options", modal_data=modal_data})
            end
        end
    end
end

function GENERIC_HANDLERS.scale_subfactory_by_ingredient_amount(player, options, action)
    if action == "submit" then
        local ui_state = data_util.get("ui_state", player)
        local item = ui_state.modal_data.object
        local subfactory = item.parent

        if options.item_amount then
            -- The division is not pre-calculated to avoid precision errors in some cases
            local current_amount, target_amount = item.amount, options.item_amount
            for _, product in pairs(Subfactory.get_all(subfactory, "Product")) do
                local requirement = product.required_amount
                requirement.amount = requirement.amount * target_amount / current_amount
            end
        end

        calculation.update(player, ui_state.context.subfactory)
        main_dialog.refresh(player, "subfactory")
    end
end


-- ** TOP LEVEL **
function item_boxes.build(player)
    local main_elements = data_util.get("main_elements", player)
    main_elements.item_boxes = {}

    local parent_flow = main_elements.flows.right_vertical
    local flow_horizontal = parent_flow.add{type="flow", direction="horizontal"}
    flow_horizontal.style.horizontal_spacing = FRAME_SPACING
    main_elements.item_boxes["horizontal_flow"] = flow_horizontal

    local products_per_row = data_util.get("settings", player).products_per_row
    build_item_box(player, "product", products_per_row)
    build_item_box(player, "byproduct", products_per_row)
    build_item_box(player, "ingredient", products_per_row*2)

    item_boxes.refresh(player)
end

function item_boxes.refresh(player)
    local ui_state = data_util.get("ui_state", player)
    local subfactory = ui_state.context.subfactory

    local prow_count = refresh_item_box(player, "product", subfactory, true)
    local brow_count = refresh_item_box(player, "byproduct", subfactory, false)
    local irow_count = refresh_item_box(player, "ingredient", subfactory, false)

    local maxrow_count = math.max(prow_count, math.max(brow_count, irow_count))
    local item_table_height = math.min(math.max(maxrow_count, 1), ITEM_BOX_MAX_ROWS) * ITEM_BOX_BUTTON_SIZE

    -- set the heights for both the visible frame and the scroll pane containing it
    local item_boxes_elements = ui_state.main_elements.item_boxes
    item_boxes_elements.product_item_table.parent.style.minimal_height = item_table_height
    item_boxes_elements.product_item_table.parent.parent.style.minimal_height = item_table_height
    item_boxes_elements.byproduct_item_table.parent.style.minimal_height = item_table_height
    item_boxes_elements.byproduct_item_table.parent.parent.style.minimal_height = item_table_height
    item_boxes_elements.ingredient_item_table.parent.style.minimal_height = item_table_height
    item_boxes_elements.ingredient_item_table.parent.parent.style.minimal_height = item_table_height
end


-- ** EVENTS **
item_boxes.gui_events = {
    on_gui_click = {
        {
            name = "add_top_level_item",
            handler = (function(player, tags, _)
                modal_dialog.enter(player, {type="picker", modal_data={object=nil, item_category=tags.category}})
            end)
        },
        {
            name = "act_on_top_level_item",
            handler = handle_item_button_click
        }
    }
}
