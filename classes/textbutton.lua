local tbug = LibStub:GetLibrary("merTorchbug")
local TextButton = tbug.classes.TextButton


function TextButton:__init__(parent, name)
    self.control = assert(parent:GetNamedChild(name))
    self.label = assert(self.control:GetLabelControl())
    self.onClicked = {}

    local function onClicked(control, mouseButton)
        local handler = self.onClicked[mouseButton]
        if handler then
            handler(self)
        end
    end

    self.control:SetHandler("OnClicked", onClicked)
end


function TextButton:enableMouseButton(mouseButton)
    self.control:EnableMouseButton(mouseButton, true)
end


function TextButton:fitText(text, padding)
    local width = self.label:GetStringWidth(text) + (padding or 0)
    self.control:SetText(text)
    self.control:SetWidth(width)
end


function TextButton:getText()
    return self.label:GetText()
end
