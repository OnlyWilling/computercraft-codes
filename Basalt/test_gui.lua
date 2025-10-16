local basalt = require("basalt")

-- Create the main frame (automatically becomes active)
local main = basalt.createFrame()

-- Add elements to the frame
local button = main:addButton()
    :setText("Click Me")
    :setPosition(2, 2)
    :setSize(10, 3)
    :onClick(function(self)
        main:addLabel()
            :setText("Button clicked!")
            :setPosition(2, 6)
    end)

-- Start the event loop
basalt.run()