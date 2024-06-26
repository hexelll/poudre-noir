local boxMaker = require "boxMaker"
boxedText = boxMaker.boxedText
drawBox = boxMaker.drawBox

local buttonAPI = {}

width,height = term.getSize()

function buttonAPI.mkbutton(button)
    local b = {
        isBoxed = button.isBoxed or false,
        x = button.x or 1,
        y = button.y or 1,
        text = button.text or 'button',
        fg = button.fg or colors.white,
        bg = button.bg or colors.gray,
        onDown = button.onDown or function()end,
        onUp = button.onUp or function()end,
        onDrag = button.onDrag or function()end,
        onRender = button.onRender or function()end,
        onTick = button.onTick or function()end,
        onScroll = button.onScroll or function()end
    }
    if button.active == nil then
        b.active = true
    else
        b.active = button.active
    end

    if not b.isBoxed then
        b.length = button.length or #b.text
        b.win = button.win or window.create(term.current(),1,1,width,height)
        b.height = button.height or 1
    else
        b.length = button.length or #b.text+2
        b.win = button.win or window.create(term.current(),1,1,width,height)
        b.height = button.height or 3
    end
    for k,v in pairs(buttonAPI) do
        b[k] = v
    end
    b.addTo = function(tab,i)
        i = i or 1
        table.insert(tab,i,b)
        return b
    end
    return b
end

function buttonAPI.draw(button)
    if button.isBoxed then
        boxedText(button.text,button.x,button.y,button.bg,button.fg,button.length,button.height,button.win)
    else
        button.win.setCursorPos(button.x,button.y)
        button.win.setBackgroundColor(button.bg)
        button.win.setTextColor(button.fg)
        button.win.write(button.text)
        for i=1,button.height-1 do
            button.win.setCursorPos(button.x,button.y+i)
            button.win.write(button.text)
        end
    end
    button.win.setBackgroundColor(colors.black)
    button.win.setTextColor(colors.white)
end

function buttonAPI.isIn(button,x,y)
    if button.isBoxed then
        return x >= button.x - 2 and
        x < button.x + button.length-2 and
        y >= button.y-1 and
        y < button.y+button.height-1
    else
        return x >= button.x and
        x < button.x + button.length and
        y >= button.y and
        y < button.y+button.height
    end
end

function buttonAPI.render(bundle,win)
    win.setVisible(false)
    win.clear()
    local new = {}
    for k,v in pairs(bundle) do
        new[#bundle-k+1] = v
    end
    for i,button in ipairs(new) do
        button.win = win
        button:onTick()
        if button.active then
            button:draw()
            button:onRender()
        end
    end
    win.setVisible(true)
end

function buttonAPI.handle(bundle,case,but,mx,my)
    if case == "down" then
        for i,button in ipairs(bundle) do
            button:onDown(but,mx,my)
            if button.active and button:isIn(mx,my) then
                break
            end
        end
    elseif case == "up" then
        for i,button in ipairs(bundle) do
            button:onUp(but,mx,my)
            if button:isIn(mx,my) then    
                break
            end
        end
    elseif case == "drag" then
        for i,button in ipairs(bundle) do
            button:onDrag(but,mx,my)
            if button:isIn(mx,my) then
                break
            end
        end
    elseif case == "scroll" then
        for i,button in ipairs(bundle) do
            button:onScroll(but,mx,my)
            if button:isIn(mx,my) then
                break
            end
        end
    end
end

return buttonAPI