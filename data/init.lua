require("data.util")
require("data.classes.Factory")
require("data.classes.Subfactory")
require("data.classes.Ingredient")
require("data.classes.Product")
require("data.classes.Byproduct")
require("data.classes.Floor")
require("data.classes.Line")

-- Initiates all global variables
function data_init()
    global.factory = Factory.init()

    global["mods_changed"] = true  -- Prompts the recipe dialog to load the first time
    global["undesirable_recipes"] = generate_undesirable_recipes()
    global["all_recipes"] = generate_all_recipes()
    global["all_machines"] = {}
    data_util.update_all_machines()

    global["modal_dialog_type"] = nil
    global["current_activity"] = nil
    global["queued_hint_message"] = ""

    global["selected_subfactory_id"] = 0
    global["selected_product_id"] = 0
    global["selected_item_group_name"] = nil
    global["selected_line_id"] = 0
    
    global["devmode"] = true
end


-- Sets up environment for development purposes
function run_dev_config()
    Factory.add_subfactory(Subfactory.init("", {type="item", name="iron-plate"}))
    Factory.add_subfactory(Subfactory.init("Beta", nil))
    Factory.add_subfactory(Subfactory.init("Gamma", {type="item", name="copper-plate"}))
    global["selected_subfactory_id"] = 1

    local subfactory_id, id = global["selected_subfactory_id"], nil

    id = Subfactory.add(subfactory_id, Product.init({name="electronic-circuit", type="item"}, 400))
    Product.add_to_amount_produced(subfactory_id, id, 600)
    id = Subfactory.add(subfactory_id, Product.init({name="advanced-circuit", type="item"}, 200))
    Product.add_to_amount_produced(subfactory_id, id, 200)
    id = Subfactory.add(subfactory_id, Product.init({name="processing-unit", type="item"}, 100))
    Product.add_to_amount_produced(subfactory_id, id, 60)
    Subfactory.add(subfactory_id, Product.init({name="uranium-235", type="item"}, 40))

    Subfactory.add(subfactory_id, Ingredient.init({name="copper-plate", type="item"}, 800))
    Subfactory.add(subfactory_id, Ingredient.init({name="iron-plate", type="item"}, 400))

    id = Subfactory.add(subfactory_id, Byproduct.init({name="heavy-oil", type="fluid"}))
    Byproduct.add_to_amount_produced(subfactory_id, id, 600)
    id = Subfactory.add(subfactory_id, Byproduct.init({name="light-oil", type="fluid"}))
    Byproduct.add_to_amount_produced(subfactory_id, id, 750)

    Floor.add_line(subfactory_id, 1, Line.init(global["all_recipes"]["electronic-circuit"]))
    Floor.add_line(subfactory_id, 1, Line.init(global["all_recipes"]["advanced-circuit"]))
end