local _, ns = ...

local _fsn = 0
function fsn(s)
    _fsn = _fsn + 1
    return s or 'Artisan_' .. _fsn
end

function ns.easyFrame(frame, parent)
    frame = frame or CreateFrame("Frame", fsn(), parent)
    local ef = {
        frame = frame,
        children = {}
    }
    local tp = {
        Slider = "OptionsSliderTemplate",
        EditBox = "InputBoxTemplate",
        CheckButton = 'UICheckButtonTemplate',
        Button = 'UIPanelButtonTemplate'
    }
    local mt = {
        __index = function(self, key)
            local value = rawget(self, key)
            if value ~= nil then
                return value
            end
            local method = self.frame[key]
            if type(method) ~= 'function' then
                return method
            end
            return function(_, ...)
                return method(self.frame, ...)
            end
        end
    }

    setmetatable(ef, mt)

    local function child(t)
        local v = ns.easyFrame(t)
        ef.children[#ef.children + 1] = v
        return v
    end

    function ef.clear()
        for _, v in ipairs(ef.children) do
            v:Hide()
        end
        for i = #ef.children, 1, -1 do
            ef.children[i] = nil
        end
        return ef
    end

    function ef.len()
        return #ef.children
    end

    function ef.ef(_, ux)
        return ef:widget('Frame', ux)
    end

    function ef.text(_, s, ux)
        ux = ux or {}
        local t = frame:CreateFontString(nil, "OVERLAY", ux.font or 'GameFontNormal')
        local p = ux.point or 'TOPLEFT'
        t:SetPoint(p, frame, ux.rp or p, ux.x or 0, ux.y or 0)
        t:SetText(s or "")
        return ef, t
    end

    function ef.widget(_, type, ux)
        ux = ux or {}
        local t = CreateFrame(type, ux.name or fsn(), frame, ux.tp or tp[type])
        t:SetFrameLevel(frame:GetFrameLevel() + 1)
        local p = ux.point or 'TOPLEFT'
        t:SetPoint(p, frame, ux.rp or p, ux.x or 0, ux.y or 0)
        if ux.w and ux.h then
            t:SetSize(ux.w, ux.h)
        end
        if type == 'Slider' then
            t:SetMinMaxValues(ux.min or 1, ux.max or 300)
            t:SetValueStep(ux.step or 5)
        end
        if ux.numeric ~= nil then
            t:SetNumeric(ux.numeric)
        end
        if ux.autoFocus ~= nil then
            t:SetAutoFocus(ux.autoFocus)
        end
        if ux.text ~= nil then
            t:SetText(ux.text)
        end
        return child(t)
    end

    function ef.tile(_, res, ux)
        ux = ux or {}
        local t = frame:CreateTexture(nil, ux.layer or "ARTWORK")
        t:SetTexture("Interface\\" .. res)
        if not ux.w and not ux.h then
            t:SetAllPoints()
        else
            if ux.w then
                t:SetWidth(ux.w)
            end
            if ux.h then
                t:SetHeight(ux.h)
            end
            t:SetTexCoord(ux.l or 0, ux.r or 1, ux.t or 0, ux.b or 1)
            local p = ux.point or 'TOPLEFT'
            t:SetPoint(p, frame, ux.rp or p, ux.x or 0, ux.y or 0)
        end
        if ux.horiz then
            t:SetHorizTile(true)
        end
        if ux.vert then
            t:SetVertTile(true)
        end
        return ef, t
    end

    function ef.box(_, ux)
        local t = ef:widget("Frame", ux)
        t:tile("FrameGeneral\\UI-Background-Marble", {
            layer = "BACKGROUND",
            horiz = true,
            vert = true
        }):tile("FrameGeneral\\UI-Frame", {
            layer = "BORDER",
            w = 6,
            h = 6,
            l = 0.6328125,
            r = 0.6796875,
            t = 0.546875,
            b = 0.59375
        }):tile("FrameGeneral\\UI-Frame", {
            layer = "BORDER",
            w = 6,
            h = 6,
            l = 0.90625,
            r = 0.953125,
            t = 0.21875,
            b = 0.265625,
            point = "TOPRIGHT"
        }):tile("FrameGeneral\\UI-Frame", {
            layer = "BORDER",
            w = 6,
            h = 6,
            l = 0.6953125,
            r = 0.7421875,
            t = 0.546875,
            b = 0.59375,
            point = "BOTTOMLEFT",
            y = -1
        }):tile("FrameGeneral\\UI-Frame", {
            layer = "BORDER",
            w = 6,
            h = 6,
            l = 0.7578125,
            r = 0.8046875,
            t = 0.546875,
            b = 0.59375,
            point = "BOTTOMRIGHT",
            y = -1
        }):tile("FrameGeneral\\_UI-Frame", {
            layer = "BORDER",
            w = ux.w - 12,
            h = 3,
            t = 0.0859375,
            b = 0.109375,
            x = 6,
            horiz = true
        }):tile("FrameGeneral\\_UI-Frame", {
            layer = "BORDER",
            w = ux.w - 12,
            h = 3,
            t = 0.0078125,
            b = 0.03125,
            point = "BOTTOMLEFT",
            x = 6,
            y = -1,
            horiz = true
        }):tile("FrameGeneral\\!UI-Frame", {
            layer = "BORDER",
            w = 3,
            h = ux.h - 12,
            l = 0.09375,
            r = 0.140625,
            point = "TOPLEFT",
            y = -6,
            vert = true
        }):tile("FrameGeneral\\!UI-Frame", {
            layer = "BORDER",
            w = 3,
            h = ux.h - 12,
            l = 0.015625,
            r = 0.0625,
            point = "TOPRIGHT",
            y = -6,
            vert = true
        })
        return t
    end
    return ef
end
