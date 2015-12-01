local tbug = SYSTEMS:GetSystem("merTorchbug")
local TextButton = tbug.classes.TextButton


function TextButton:__init__(parent, name)
    self.control = assert(parent:GetNamedChild(name))
    self.label = assert(self.control:GetLabelControl())
    self.padding = 0
    self.onClicked = {}

    local function onClicked(control, mouseButton)
        local handler = self.onClicked[mouseButton]
        if handler then
            handler(self)
        end
    end

    local function onScreenResized()
        local text = self.label:GetText()
        local width = self.label:GetStringWidth(text) / GetUIGlobalScale()
        self.control:SetWidth(width + self.padding)
    end

    self.control:SetHandler("OnClicked", onClicked)
    self.control:RegisterForEvent(EVENT_SCREEN_RESIZED, onScreenResized)
end


function TextButton:enableMouseButton(mouseButton)
    self.control:EnableMouseButton(mouseButton, true)
end


function TextButton:fitText(text, padding)
    local padding = padding or 0
    local width = self.label:GetStringWidth(text) / GetUIGlobalScale()
    self.control:SetText(text)
    self.control:SetWidth(width + padding)
    self.padding = padding
end


function TextButton:getText()
    return self.label:GetText()
end


function TextButton:setMouseOverBackgroundColor(r, g, b, a)
    local mouseOverBg = self.control:GetNamedChild("MouseOverBg")
    if not mouseOverBg then
        mouseOverBg = self.control:CreateControl("$(parent)MouseOverBg", CT_TEXTURE)
        mouseOverBg:SetAnchorFill()
        mouseOverBg:SetHidden(true)
    end
    mouseOverBg:SetColor(r, g, b, a)
end
