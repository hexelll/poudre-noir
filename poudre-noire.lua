local buttonAPI = require "buttonAPI"
local eventHandler = require "eventHandler"

term.setPaletteColour(colors.red,0xCF0000)
term.setPaletteColour(colors.orange,0xFD7D1F)
term.setPaletteColour(colors.cyan,0x00BCA4)

width,height = term.getSize()

my_win = window.create(term.current(),1,1,width,height)

bundle = {}

dir = "north"

function makeReader(args--[[bundle,parent,text,textbg,bg,lim,x,y]])
    bundle = args.bundle or {}
    text = args.text or ""
    textbg = args.textbg or colors.lightGray
    x = args.x or 1
    y = args.y or 1
    parent = args.parent or {}
    lim = args.lim
    
    local textB = buttonAPI.mkbutton(
        {
            active = false,
            x = x-#text,
            y = y,
            text = text,
            bg = textbg,
            onTick = function(self)
                if parent.clicked then
                    self.active = true
                else
                    self.active = false
                end
            end
        }
    ).addTo(bundle)
    local reader = buttonAPI.mkbutton(
        {
            active = false,
            x = x,
            y = y,
            text = " ",
            onTick = function(self)
                self.draw = function(button)
                    button.win.setCursorPos(button.x,button.y)
                    button.win.setBackgroundColor(button.bg)
                    button.win.setTextColor(button.fg)
                    button.win.write(button.text)
                    for i=1,button.height-1 do
                        button.win.setCursorPos(button.x,button.y+i)
                        button.win.write(button.text)
                    end
                    if button.clicked then
                        button.win.setCursorPos(button.x+button.cursor-1,button.y)
                        button.win.setBackgroundColor(button.fg)
                        button.win.setTextColor(button.bg)
                        button.win.write(string.sub(button.text,button.cursor,button.cursor))
                    end
                    button.win.setBackgroundColor(colors.black)
                    button.win.setTextColor(colors.white)
                end
                if string.sub(self.text,#self.text,#self.text) == "" then
                    self.text = self.text.." "
                end
                self.length = #self.text
                if parent.clicked then
                    self.active = true
                else
                    self.active = false
                end
            end,
            onDown = function(self,but,mx,my)
                if self:isIn(mx,my) then
                    self.bg = colors.orange
                    self.clicked = true
                    self.cursor = mx-self.x+1
                else
                    self.bg = colors.gray
                    self.clicked = false
                end
            end,
            onChar = function(self,char)
                if self.clicked then
                    if args.lim then
                        local done = false
                        for i,c in pairs(lim) do
                            if char == c then
                                done = true
                            end
                        end
                        if done then
                            self.text = string.sub(self.text,1,self.cursor-1)..char..string.sub(self.text,self.cursor,#self.text)
                            self.cursor = self.cursor + 1
                        end
                    else
                        self.text = string.sub(self.text,1,self.cursor-1)..char..string.sub(self.text,self.cursor,#self.text)
                        self.cursor = self.cursor + 1
                    end
                end
            end,
            onKey = function(self,key)
                if self.clicked then
                    if key == "backspace" and self.cursor > 1 then
                        self.text = string.sub(self.text,1,self.cursor-2)..string.sub(self.text,self.cursor,#self.text)
                        self.cursor = self.cursor-1
                    elseif key == "delete" and self.cursor < #self.text-1 then
                        self.text = string.sub(self.text,1,self.cursor)..string.sub(self.text,self.cursor+2,#self.text)
                    elseif key == "left" and self.cursor > 1 then
                        self.cursor = self.cursor - 1
                    elseif key == "right" and self.cursor < #self.text then
                        self.cursor = self.cursor + 1
                    end
                end
            end
        }
    ).addTo(bundle)
    return reader
end

function makeHeader(bundle,parent,text,textbg)
    return buttonAPI.mkbutton(
        {
            active = parent.active,
            text = text,
            x = parent.x-#text,
            y = parent.y,
            bg = textbg,
            onTick = function(self)
                self.active = parent.active
            end
        }
    ).addTo(bundle)
end

function worldToMap(dir,centerx,centery,refx,refy,x,y,zoom)
    mapx = x-refx
    mapy = y-refy
    if dir == "south" then
        mapx = -mapx
        mapy = -mapy
    elseif dir == "west" then
        mapx,mapy = -mapy,mapx
    elseif dir == "east" then
        mapy = -mapy
    end
    return {x = zoom*mapx*1/3+centerx,
            y = zoom*mapy*1/4+centery}
end

function mapToWorld(dir,centerx,centery,ref,refy,x,y,zoom)
    if dir == "south" then
        x = -x
        y = -y
    elseif dir == "west" then
        x,y = -y,x
    elseif dir == "east" then
        y = -y
    end
    return {
        x = 3*((x-centerx)/zoom)+refx,
        y = 4*((y-centery)/zoom)+refy
    }
end

function addMapPoint(text,data,bundle,parent,dir,centerx,centery,state,x,y)
    x = x or 0
    y = y or 0
    refx,refy,zoom = state.x,state.y,state.zoom
    local mapPoint = buttonAPI.mkbutton{
        x = 1,
        y = 1,
        text = text,
        data = data,
        active = false,
        selected = false,
        bg = colors.black,
        onDown = function(self,but,mx,my)
            if self.active and but == 1 and self:isIn(mx,my) and mapRenderer:isIn(mx,my) then
                if self.clicked then
                    self.selected = false
                    self.clicked = false
                    self.fg = colors.white
                else
                    self.selected = true
                    self.clicked = true
                    self.fg = colors.cyan
                end
            elseif self.active and mapRenderer:isIn(mx,my) then
                if not self.group then
                    self.selected = false
                    self.clicked = false
                    self.fg = colors.white
                end
            end
        end,
        onKey = function(self,key)
            if key == "leftShift" then
                self.group = true
            end
        end,
        onKeyUp = function(self,key)
            if key == "leftShift" then
                self.group = false
            end
        end,
        onTick = function(self)
            refx,refy,zoom = state.x,state.y,state.zoom
            self.pos = worldToMap(dir,centerx,centery,refx,refy,self.blockPos.x,self.blockPos.y,zoom)
            self.x = math.floor(self.pos.x)
            self.y = math.floor(self.pos.y)
            self.active = parent.clicked
            if not self.isIn({
                isBoxed = false,
                x = mapRenderer.x,
                y = mapRenderer.y,
                height = mapRenderer.height-2,
                length = mapRenderer.length-2,
                }
                ,self.x
                ,self.y) then
                self.active = false
            end
        end
    }.addTo(bundle)
    mapPoint.blockPos = {x=x,y=y}
    return mapPoint
end

bg = buttonAPI.mkbutton(
    {
        text = "",
        x = 3,
        y = 3,
        length = width-2,
        height = height-2,
        bg = colors.cyan,
        isBoxed = true,
        unclickable = true
    }
).addTo(bundle,#bundle+1)
config = buttonAPI.mkbutton(
    {
        text = "config ",
        y = bg.y,
        onDown = function(self,but,mx,my)
            if self:isIn(mx,my) and self.active then
                if not self.clicked then
                    self.bg = colors.lightGray
                    self.clicked = true
                    map.clicked = false
                    map.bg = colors.gray
                else
                    self.bg = colors.gray
                    self.clicked = false
                end
            end
        end,
    }
).addTo(bundle)
config.x = width - config.length
makeHeader(bundle,config,"o|",colors.orange)

map = buttonAPI.mkbutton(
    {
        text = "map ",
        y = bg.y+2,
        onDown = function(self,but,mx,my)
            if self:isIn(mx,my) then
                if not self.clicked then
                    self.bg = colors.lightGray
                    self.clicked = true
                    config.clicked = false
                    config.bg = colors.gray
                else
                    self.bg = colors.gray
                    self.clicked = false
                end
            end
        end,
    }
).addTo(bundle)
map.x = width - map.length
makeHeader(bundle,map,"o|",colors.orange)

local mapState = {
    x = 0,
    y = 0,
    zoom = 1,
}

mapRenderer = buttonAPI.mkbutton(
    {
        active = false,
        text = "",
        isBoxed = true,
        x = bg.x+1,
        y = bg.y+1,
        height = 13,
        length = 25,
        bg = colors.black,
        onTick = function(self)
            self.active = map.clicked
            if computer.pos then
                computer.blockPos.x = tonumber(readx.text) or 0
                computer.blockPos.y = tonumber(readz.text) or 0
            end
        end,
        onDown = function(self,but,mx,my)
            self.pre = {x = mx,y = my}
        end,
        onUp = function(self,but,mx,my)
            self.pre = {x = mx,y = my}
        end,
        onScroll = function(self,dir,mx,my)
            if self:isIn(mx,my) then
                if mapState.zoom - dir*0.25 > 0 then
                    mapState.zoom = mapState.zoom - dir*0.25
                end
            end
        end,
        onDrag = function(self,but,mx,my)
            if self:isIn(mx,my) then
                self.pre = self.pre or {
                    x = 0,
                    y = 0
                }
                mapState.x = mapState.x-(mx-self.pre.x)
                mapState.y = mapState.y-(my-self.pre.y)
                self.pre = {x = mx,y = my}
            end
        end
    }
).addTo(bundle)

function simpleMapAdd(text,data,dir,state,x,y)
    return addMapPoint(text,data,bundle,map,dir,(mapRenderer.x+mapRenderer.length)/2,(mapRenderer.y+mapRenderer.height)/2,state,x,y)
end

computer = simpleMapAdd("x",{},dir,mapState)

point = simpleMapAdd("o",{},dir,mapState,-14,-5)

cursor = buttonAPI.mkbutton{
    text = "+",
    active = false,
    bg = colors.black,
    onTick = function(self)
        self.active = map.clicked
    end
}.addTo(bundle)
cursor.x = math.floor((mapRenderer.x+mapRenderer.length)/2)+1
cursor.y = math.floor((mapRenderer.y+mapRenderer.height)/2)+1

indicator = buttonAPI.mkbutton(
    {
        active = false,
        text = "[zoom:"..tostring(mapState.zoom).." x:"..tostring(mapState.x+1).." z:"..tostring(mapState.y+1).."]",
        x = mapRenderer.x,
        y = mapRenderer.y,
        bg = colors.orange,
        onTick = function(self)
            self.active = map.clicked
            self.text = "[zoom:"..tostring(mapState.zoom).." x:"..tostring(mapState.x+1).." z:"..tostring(mapState.y+1).."]"
        end
    }
).addTo(bundle)

del = buttonAPI.mkbutton{
    x = mapRenderer.x,
    y = mapRenderer.y + mapRenderer.height-1,
    text = "|del|",
    bg = colors.gray,
    onTick = function(self)
        self.active = map.clicked
    end,
    onDown = function(self,but,mx,my)
        if self:isIn(mx,my) then
            self.bg = colors.lightGray
            self.clicked = true
            for i=1,#bundle do
                v = bundle[i] or {}
                if v.selected then
                    table.remove(bundle,i)
                    break
                end
            end
        end
    end,
    onUp = function(self,mx,my)
        if self.clicked then
            self.clicked = false
            self.bg = colors.gray
        end
    end
}.addTo(bundle)

readx = makeReader({
    bundle = bundle,
    parent = config,
    text = "x|",
    textbg = colors.orange,
    bg = colors.orange,
    lim = {'-','0','1','2','3','4','5','6','7','8','9'},
    x = bg.x+3,
    y = bg.y
})
ready = makeReader({
    bundle = bundle,
    parent = config,
    text = "y|",
    textbg = colors.orange,
    bg = colors.orange,
    lim = {'-','0','1','2','3','4','5','6','7','8','9'},
    x = bg.x+3,
    y = bg.y+2
})
readz = makeReader({
    bundle = bundle,
    parent = config,
    text = "z|",
    textbg = colors.orange,
    bg = colors.orange,
    lim = {'-','0','1','2','3','4','5','6','7','8','9'},
    x = bg.x+3,
    y = bg.y+4
})
infoRenderer = buttonAPI.mkbutton(
    {
        active = false,
        isBoxed = true,
        x = mapRenderer.x+mapRenderer.length,
        y = mapRenderer.y,
        text = "",
        length = 13,
        height = mapRenderer.height,
        bg = colors.gray,
        onTick = function(self)
            self.active = map.clicked
        end
    }
).addTo(bundle)
info = buttonAPI.mkbutton(
    {
        active = false,
        x = mapRenderer.x+mapRenderer.length-1,
        y = mapRenderer.y-1,
        bg = colors.orange,
        text = "|info|",
        onTick = function(self)
            self.active = map.clicked
        end
    }
).addTo(bundle)



eventHandler.eventLookUp = {
    {
        event = "mouse_click",
        react = function(eventData)
            local but,mx,my = eventData[2],eventData[3],eventData[4]
            buttonAPI.handle(bundle,"down",but,mx,my)
            if but == 2 and map.clicked then
                if mapRenderer:isIn(mx,my) then
                    pos = mapToWorld(dir,(mapRenderer.x+mapRenderer.length)/2,(mapRenderer.y+mapRenderer.height)/2,mapState.x,mapState.y,mx,my,mapState.zoom)
                    simpleMapAdd("T",{},dir,mapState,pos.x,pos.y)
                end
            end
        end,
    },
    {
        event = "mouse_up",
        react = function(eventData)
            local but,mx,my = eventData[2],eventData[3],eventData[4]
            buttonAPI.handle(bundle,"up",but,mx,my)
        end
    },
    {
        event = "mouse_drag",
        react = function(eventData)
            local but,mx,my = eventData[2],eventData[3],eventData[4]
            buttonAPI.handle(bundle,"drag",but,mx,my)
        end
    },
    {
        event = "mouse_scroll",
        react = function(eventData)
            local dir, x, y = eventData[2],eventData[3],eventData[4]
            buttonAPI.handle(bundle,"scroll",dir,x,y)
        end
    },
    {
        event = "key",
        react = function(eventData)
            local key = keys.getName(eventData[2])
            if key == "w" then
                mapState.y = mapState.y-1
            elseif key == "s" then
                mapState.y = mapState.y+1
            elseif key == "a" then
                mapState.x = mapState.x-1
            elseif key == "d" then
                mapState.x = mapState.x+1
            end
            buttonAPI.handle(bundle,"key",key)
        end
    },
    {
        event = "key_up",
        react = function(eventData)
            local key = keys.getName(eventData[2])
            buttonAPI.handle(bundle,"key_up",key)
        end
    },
    {
        event = "char",
        react = function(eventData)
            local char = eventData[2]
            buttonAPI.handle(bundle,"char",char)
        end
    }
}

parallel.waitForAny(
eventHandler.loop,
function()
    while true do
        buttonAPI.render(bundle,my_win)
        sleep()
    end
end
)
