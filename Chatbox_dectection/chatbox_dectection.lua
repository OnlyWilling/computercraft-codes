-- Chatbox Detection Example

local chatbox = peripheral.find("chatBox")

while true do
    local event, username, message, uuid, isHidden, messageUtf8 = os.pullEvent("chat")
    if event == "chat" then
        print("The 'chat' event was fired with the username: " .. username .. " and the message: " .. message)
        chatbox.sendMessage(message, username.." said")
        os.sleep(1)
    end
end