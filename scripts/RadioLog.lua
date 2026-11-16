--
-- RadioLog 1.4
--
-- Shows the current radio station and song on the HUD and logs every change to a dated file:
--   Documents/My Games/FarmingSimulator2025/modSettings/RadioLog/YYYY-MM-DD.txt  (for you to read)
--   Documents/My Games/FarmingSimulator2025/modSettings/RadioLog/YYYY-MM-DD.xml  (same data, used to keep the day's file across sessions)
--
-- Every song line says how it started (you switched station / next song on the same station),
-- how long you listened and how it ended (played to the end / you switched away / radio off).
-- When you leave a station a line with the total time on that station is added.
--
-- Source of the data (found with version 0.1):
--   MessageType.RADIO_CHANNEL_CHANGE(stationName, songName, isOnlineStream)
--   is published by the game on every station change and every new song, built-in stations and online streams alike.
--   The game does not expose song lengths, so "listened" is the time you actually heard the song.
--

RadioLog = {}
RadioLog.MOD_NAME = g_currentModName

-- HUD display (screen coordinates 0..1, bottom left is 0,0)
RadioLog.SHOW_HUD = true
RadioLog.HUD_ALIGN = "center"         -- "center": HUD_POS_X is the middle of the box, "right": HUD_POS_X is its right edge
RadioLog.HUD_POS_X = 0.5
RadioLog.HUD_POS_Y = 0.045            -- bottom edge of the box
RadioLog.HUD_TEXT_SIZE = 0.019
RadioLog.HUD_LINE_SPACING = 0.024
RadioLog.HUD_SHOW_BOX = true          -- dark transparent box behind the text
RadioLog.HUD_BOX_COLOR = {0, 0, 0, 0.75}
RadioLog.HUD_BOX_PADDING_X = 0.010    -- space left and right of the text inside the box
RadioLog.HUD_BOX_PADDING_Y = 0.009    -- space above and below the text inside the box
RadioLog.HUD_MAX_CHARS = 70           -- longer station/song names are shortened with "..."

-- Logging
RadioLog.LOG_RADIO_OFF = true          -- write a "RADIO OFF" line when the radio stops
RadioLog.POLL_INTERVAL = 1000          -- ms between radio on/off checks
RadioLog.MIN_LISTEN_SECONDS = 5        -- songs heard for less than this are left out of the log (flicking through stations)

-- placeholders sent while an online stream connects
RadioLog.IGNORED_SONGS = {["Connecting..."] = true, [""] = true}

RadioLog.END_REASON_TEXTS = {
    next = "played to the end",
    switched = "you switched away",
    off = "radio turned off",
    closed = "game closed"
}


local function debugLog(fmt, ...)
    print("[RadioLog] " .. string.format(fmt, ...))
end


---Real time in seconds, independent of the game speed
local function now()
    if getTimeSec ~= nil then
        return getTimeSec()
    end
    return (g_time or 0) / 1000
end


local function formatDuration(seconds)
    if seconds == nil then
        return "?"
    end
    seconds = math.max(0, math.floor(seconds + 0.5))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end


-------------------------------------------------------------------------------
-- Dated log
--
-- entry = {time, kind, station, song, listened, ended}
--   kind: "switch" (song heard after switching station), "song" (next song on the same station),
--         "total" (time spent on a station), "off" (radio turned off)
-------------------------------------------------------------------------------

---Switches to today's files, loading earlier entries of the day from the XML file
function RadioLog:openDay()
    local day = getDate("%Y-%m-%d")
    if self.day == day then
        return
    end

    self.day = day
    self.entries = {}

    local directory = getUserProfileAppPath() .. "modSettings/RadioLog/"
    createFolder(getUserProfileAppPath() .. "modSettings/")
    createFolder(directory)

    self.xmlPath = directory .. day .. ".xml"
    self.txtPath = directory .. day .. ".txt"

    local xmlFile = XMLFile.loadIfExists("RadioLogDay", self.xmlPath)
    if xmlFile ~= nil then
        local i = 0
        while true do
            local key = string.format("radioLog.entry(%d)", i)
            if not xmlFile:hasProperty(key) then
                break
            end
            local listened = xmlFile:getInt(key .. "#listened", -1)
            table.insert(self.entries, {
                time = xmlFile:getString(key .. "#time", ""),
                kind = xmlFile:getString(key .. "#kind", "song"),
                station = xmlFile:getString(key .. "#station", ""),
                song = xmlFile:getString(key .. "#song", ""),
                listened = listened >= 0 and listened or nil,
                ended = xmlFile:getString(key .. "#ended")
            })
            i = i + 1
        end
        xmlFile:delete()
    end

    debugLog("Logging to %s (%d earlier entries today)", self.txtPath, #self.entries)
end


function RadioLog:formatEntry(entry)
    if entry.kind == "total" then
        return string.format("          -- %s on %s", formatDuration(entry.listened), entry.station)
    elseif entry.kind == "off" then
        return string.format("%s  RADIO OFF", entry.time)
    end

    local label = entry.kind == "switch" and "SWITCHED TO" or "next song  "
    local line = string.format("%s  %s  %s", entry.time, label, entry.station)
    if entry.song ~= "" then
        line = line .. "  |  " .. entry.song
    end

    if entry.ended ~= nil then
        line = string.format("%s   [listened %s, %s]", line, formatDuration(entry.listened),
            RadioLog.END_REASON_TEXTS[entry.ended] or entry.ended)
    else
        line = line .. "   [playing]"
    end

    return line
end


---Writes the whole day to the XML and TXT files
function RadioLog:saveDay()
    local ok, err = pcall(function()
        self:openDay()

        local xmlFile = XMLFile.create("RadioLogDay", self.xmlPath, "radioLog")
        if xmlFile ~= nil then
            for i, e in ipairs(self.entries) do
                local key = string.format("radioLog.entry(%d)", i - 1)
                xmlFile:setString(key .. "#time", e.time)
                xmlFile:setString(key .. "#kind", e.kind)
                xmlFile:setString(key .. "#station", e.station)
                xmlFile:setString(key .. "#song", e.song)
                if e.listened ~= nil then
                    xmlFile:setInt(key .. "#listened", math.floor(e.listened + 0.5))
                end
                if e.ended ~= nil then
                    xmlFile:setString(key .. "#ended", e.ended)
                end
            end
            xmlFile:save()
            xmlFile:delete()
        end

        local file = createFile(self.txtPath, FileAccess.WRITE)
        if file ~= 0 then
            local lines = {}
            for i, e in ipairs(self.entries) do
                lines[i] = self:formatEntry(e)
            end
            fileWrite(file, table.concat(lines, "\n") .. "\n")
            delete(file)
        end
    end)

    if not ok then
        debugLog("Writing log failed: %s", tostring(err))
    end
end


function RadioLog:addEntry(entry)
    local ok, err = pcall(self.openDay, self)
    if not ok then
        debugLog("Opening log failed: %s", tostring(err))
    end

    entry.time = entry.time or getDate("%H:%M:%S")
    entry.station = entry.station or ""
    entry.song = entry.song or ""
    table.insert(self.entries, entry)

    return entry
end


---Ends the song that is currently playing (if any) with the given reason.
-- Songs heard for less than MIN_LISTEN_SECONDS are removed from the log again.
function RadioLog:closeSong(reason, time)
    local entry = self.openSong
    if entry == nil then
        return
    end
    self.openSong = nil

    entry.listened = time - entry.startSec
    entry.ended = reason
    entry.startSec = nil

    if entry.listened < RadioLog.MIN_LISTEN_SECONDS then
        for i = #self.entries, 1, -1 do
            if self.entries[i] == entry then
                table.remove(self.entries, i)
                break
            end
        end
        self.stationSongCount = math.max((self.stationSongCount or 1) - 1, 0)

        -- the station switch is still worth showing: mark the next song on this station instead
        if entry.kind == "switch" and reason == "next" then
            self.pendingSwitch = true
        end
    end
end


---Adds the "time on station" line for the station that is currently playing (if any).
-- Skipped when only one song was heard, its line already shows the same time.
function RadioLog:closeStation(time)
    if self.currentStation ~= nil and self.stationStartSec ~= nil and (self.stationSongCount or 0) > 1 then
        self:addEntry({kind = "total", station = self.currentStation, listened = time - self.stationStartSec})
    end
    self.currentStation = nil
    self.currentSong = nil
    self.stationStartSec = nil
end


-------------------------------------------------------------------------------
-- Radio events
-------------------------------------------------------------------------------

function RadioLog:onRadioChannelChange(station, song, isStream)
    station = station or ""
    song = song or ""
    local time = now()

    -- leaving the current station: stop the clock right away, even if the new
    -- stream still needs a few seconds to connect
    if self.currentStation ~= nil and station ~= self.currentStation then
        self:closeSong("switched", time)
        self:closeStation(time)
        self:saveDay()
    end

    -- streams report "" / "Connecting..." until the stream is up
    if station == "" or RadioLog.IGNORED_SONGS[song] then
        return
    end

    -- the game sends every change twice
    if station == self.currentStation and song == self.currentSong then
        return
    end

    local kind = "song"
    if station ~= self.currentStation then
        kind = "switch"
        self.currentStation = station
        self.stationStartSec = time
        self.stationSongCount = 1
        self.pendingSwitch = false
    else
        self:closeSong("next", time)
        self.stationSongCount = (self.stationSongCount or 0) + 1
        if self.pendingSwitch then
            kind = "switch"
            self.pendingSwitch = false
        end
    end

    self.currentSong = song
    self.wasPlaying = true
    self.openSong = self:addEntry({kind = kind, station = station, song = song, startSec = time})

    self:saveDay()
end


function RadioLog:getIsRadioPlaying()
    return g_soundPlayer ~= nil and g_soundPlayer.getIsPlaying ~= nil and g_soundPlayer:getIsPlaying()
end


-------------------------------------------------------------------------------
-- Mod event listener
-------------------------------------------------------------------------------

function RadioLog:loadMap(filename)
    self.day = nil
    self.entries = {}
    self.currentStation = nil
    self.currentSong = nil
    self.stationStartSec = nil
    self.openSong = nil
    self.wasPlaying = false
    self.pollTimer = 0


    if MessageType.RADIO_CHANNEL_CHANGE ~= nil then
        g_messageCenter:subscribe(MessageType.RADIO_CHANNEL_CHANGE, self.onRadioChannelChange, self)
        debugLog("RadioLog 1.4 loaded")
    else
        debugLog("MessageType.RADIO_CHANNEL_CHANGE not found, RadioLog is inactive")
    end
end


function RadioLog:update(dt)
    self.pollTimer = self.pollTimer + dt
    if self.pollTimer < RadioLog.POLL_INTERVAL then
        return
    end
    self.pollTimer = 0

    local isPlaying = self:getIsRadioPlaying()
    if self.wasPlaying and not isPlaying and self.currentStation ~= nil then
        local time = now()
        self:closeSong("off", time)
        self:closeStation(time)
        if RadioLog.LOG_RADIO_OFF then
            self:addEntry({kind = "off"})
        end
        self:saveDay()
    end
    self.wasPlaying = isPlaying
end


function RadioLog:draw()
    if not RadioLog.SHOW_HUD or self.currentStation == nil or not self:getIsRadioPlaying() then
        return
    end
    if g_gui ~= nil and g_gui:getIsGuiVisible() then
        return
    end
    local hud = g_currentMission ~= nil and g_currentMission.hud or nil
    if hud ~= nil and hud.getIsVisible ~= nil and not hud:getIsVisible() then
        return
    end

    local size = RadioLog.HUD_TEXT_SIZE
    local station = RadioLog.shortenText(self.currentStation)
    local song = RadioLog.shortenText(self.currentSong or "")
    local hasSong = song ~= ""

    -- measure both lines (bold changes the width, so measure each with its own style)
    setTextBold(true)
    local textWidth = getTextWidth(size, station)
    setTextBold(false)
    if hasSong then
        textWidth = math.max(textWidth, getTextWidth(size, song))
    end

    -- box: bottom edge at HUD_POS_Y, text lines stacked inside
    local padX, padY = RadioLog.HUD_BOX_PADDING_X, RadioLog.HUD_BOX_PADDING_Y
    local boxWidth = textWidth + 2 * padX
    local boxHeight = size + 2 * padY + (hasSong and RadioLog.HUD_LINE_SPACING or 0)
    local boxX = RadioLog.HUD_POS_X - boxWidth
    if RadioLog.HUD_ALIGN == "center" then
        boxX = RadioLog.HUD_POS_X - boxWidth * 0.5
    end
    local boxY = RadioLog.HUD_POS_Y

    if RadioLog.HUD_SHOW_BOX then
        local c = RadioLog.HUD_BOX_COLOR
        drawFilledRect(boxX, boxY, boxWidth, boxHeight, c[1], c[2], c[3], c[4])
    end

    local textX = boxX + boxWidth * 0.5
    local songY = boxY + padY
    local stationY = songY + (hasSong and RadioLog.HUD_LINE_SPACING or 0)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(textX, stationY, size, station)
    setTextBold(false)
    if hasSong then
        setTextColor(0.9, 0.9, 0.9, 1)
        renderText(textX, songY, size, song)
    end

    -- leave the text state as we found it for everything drawn after us
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end


---Shortens long names so the box doesn't run across the screen (UTF-8 safe)
function RadioLog.shortenText(text)
    if utf8Strlen(text) > RadioLog.HUD_MAX_CHARS then
        return utf8Substr(text, 0, RadioLog.HUD_MAX_CHARS - 3) .. "..."
    end
    return text
end


function RadioLog:deleteMap()
    -- finish the song and station that were playing, so their times are saved
    if self.currentStation ~= nil then
        local time = now()
        self:closeSong("closed", time)
        self:closeStation(time)
        self:saveDay()
    end

    if g_messageCenter ~= nil then
        g_messageCenter:unsubscribeAll(self)
    end
end


addModEventListener(RadioLog)
