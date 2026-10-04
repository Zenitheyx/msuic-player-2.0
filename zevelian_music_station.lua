--[[
ZEVELIAN MUSIC STATION
Dedicated CC:Tweaked music machine.

Designed for a dedicated Advanced Computer + large monitor + Speaker.

FEATURES
- Full-screen monitor dashboard
- Music library
- Search/filter library
- Play / pause / stop / previous / next
- Queue
- Shuffle
- Repeat OFF / ALL / ONE
- Volume control
- Download direct .dfpwm audio files
- Track metadata stored locally
- Persistent settings
- Animated visualizer
- Hardware status page
- Touch controls
- Keyboard controls
- Safe shutdown
- No OS files are modified

AUDIO FORMAT
CC:Tweaked's native DFPWM format is used for playback.
The download function accepts DIRECT .dfpwm URLs only.
It does not bypass or extract protected streaming services.

FILES
/music/                  audio library
/zevelian_music_station.db   settings/library state
]]

local MUSIC_DIR = "/music"
local DB_FILE = "/zevelian_music_station.db"
local VERSION = "3.0"

fs.makeDir(MUSIC_DIR)

local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not monitor then
    error("ZEVELIAN MUSIC STATION: No monitor detected.")
end

if not speaker then
    error("ZEVELIAN MUSIC STATION: No Speaker detected.")
end

local decoderOK, dfpwm = pcall(require, "cc.audio.dfpwm")
if not decoderOK then
    error("ZEVELIAN MUSIC STATION: cc.audio.dfpwm is unavailable.")
end

monitor.setTextScale(0.5)

local W, H = monitor.getSize()

local state = {
    volume = 1,
    shuffle = false,
    repeatMode = "all",
    page = "home",
    current = 1,
    selected = 1,
    libraryOffset = 0,
    search = "",
    queue = {},
    queuePos = 1
}

local tracks = {}
local playing = false
local paused = false
local stopping = false
local playbackToken = 0
local currentPath = nil
local currentTitle = "NOTHING PLAYING"
local status = "READY"
local elapsed = 0
local duration = 0
local visualTick = 0
local message = ""

math.randomseed(os.epoch("utc"))

local function clamp(n, a, b)
    return math.max(a, math.min(b, n))
end

local function saveState()
    local h = fs.open(DB_FILE, "w")
    if h then
        h.write(textutils.serialise(state))
        h.close()
    end
end

local function loadState()
    if not fs.exists(DB_FILE) then return end

    local h = fs.open(DB_FILE, "r")
    if not h then return end

    local raw = h.readAll()
    h.close()

    local ok, data = pcall(textutils.unserialise, raw)

    if ok and type(data) == "table" then
        if type(data.volume) == "number" then
            state.volume = clamp(data.volume, 0, 3)
        end

        state.shuffle = data.shuffle == true

        if data.repeatMode == "off" or data.repeatMode == "one" or data.repeatMode == "all" then
            state.repeatMode = data.repeatMode
        end
    end
end

local function refreshLibrary()
    tracks = {}

    for _, name in ipairs(fs.list(MUSIC_DIR)) do
        local path = fs.combine(MUSIC_DIR, name)

        if not fs.isDir(path) and name:lower():match("%.dfpwm$") then
            tracks[#tracks + 1] = path
        end
    end

    table.sort(tracks, function(a, b)
        return a:lower() < b:lower()
    end)

    if #tracks == 0 then
        state.current = 1
        state.selected = 1
    else
        state.current = clamp(state.current, 1, #tracks)
        state.selected = clamp(state.selected, 1, #tracks)
    end
end

local function trackName(path)
    local n = fs.getName(path)
    n = n:gsub("%.dfpwm$", "")
    n = n:gsub("_", " ")
    return n
end

local function truncate(s, width)
    s = tostring(s or "")

    if #s <= width then
        return s
    end

    if width <= 3 then
        return s:sub(1, width)
    end

    return s:sub(1, width - 3) .. "..."
end

local function timeString(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function clear()
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function put(x, y, value)
    monitor.setCursorPos(x, y)
    monitor.write(tostring(value))
end

local function center(y, value)
    value = tostring(value)
    local x = math.max(1, math.floor((W - #value) / 2) + 1)
    put(x, y, value)
end

local function rule(y)
    put(1, y, string.rep("-", W))
end

local function button(y, label)
    center(y, "[ " .. label .. " ]")
end

local function header(title)
    clear()
    center(1, "ZEVELIAN MUSIC STATION")
    center(2, "DEDICATED AUDIO SYSTEM  //  v" .. VERSION)
    rule(3)
    center(4, title)
    rule(5)
end

local function progressBar(y)
    local barWidth = math.max(16, W - 20)
    local ratio = duration > 0 and clamp(elapsed / duration, 0, 1) or 0
    local filled = math.floor(barWidth * ratio)

    local bar =
        string.rep("=", filled) ..
        string.rep("-", barWidth - filled)

    put(
        1,
        y,
        string.format(
            "%5s [%s] %5s",
            timeString(elapsed),
            bar,
            timeString(duration)
        )
    )
end

local function visualizer(y)
    local width = math.max(20, W - 4)
    local chars = {}

    for i = 1, width do
        local wave =
            math.sin((i * 0.45) + visualTick * 0.4) +
            math.sin((i * 0.19) - visualTick * 0.25)

        local height = math.floor((wave + 2) / 4 * 3)

        if not playing or paused then
            height = math.floor((math.sin(i * 0.4) + 1) / 2)
        end

        chars[#chars + 1] =
            height >= 2 and "#" or
            height == 1 and "+" or
            "."
    end

    put(2, y, table.concat(chars))
end

local function nowPlayingPanel()
    center(7, truncate(currentTitle, W))
    center(8, status)

    progressBar(10)
    visualizer(12)

    center(14, "[<<]   [ PLAY / PAUSE ]   [>>]")
    center(16, "[ STOP ]     [ VOL- ]   " ..
        math.floor(state.volume * 100) ..
        "%   [ VOL+ ]")

    center(18, "[ LIBRARY ]     [ QUEUE ]")
    center(20, "[ SHUFFLE ]     [ REPEAT: " ..
        state.repeatMode:upper() .. " ]")

    if message ~= "" then
        center(22, truncate(message, W))
    end
end

local function drawHome()
    header("NOW PLAYING")
    nowPlayingPanel()
end

local function filteredLibrary()
    if state.search == "" then
        return tracks
    end

    local result = {}
    local needle = state.search:lower()

    for _, path in ipairs(tracks) do
        if trackName(path):lower():find(needle, 1, true) then
            result[#result + 1] = path
        end
    end

    return result
end

local function drawLibrary()
    header("LIBRARY")

    put(1, 7, "SEARCH: " .. truncate(state.search, W - 9))
    rule(8)

    local list = filteredLibrary()
    local visible = math.max(1, H - 12)

    state.libraryOffset =
        clamp(
            state.libraryOffset,
            0,
            math.max(0, #list - visible)
        )

    if #list == 0 then
        center(11, "NO MUSIC FOUND")
        center(13, "Put .dfpwm files into /music")
    else
        for row = 1, visible do
            local index = row + state.libraryOffset
            local path = list[index]

            if path then
                local marker = index == state.current and ">" or " "
                local selected = index == state.selected and "*" or " "

                put(
                    1,
                    8 + row,
                    truncate(
                        string.format(
                            "%s%s %02d  %s",
                            selected,
                            marker,
                            index,
                            trackName(path)
                        ),
                        W
                    )
                )
            end
        end
    end

    center(H - 2, "[ BACK ]  [ UP ]  [ DOWN ]  [ PLAY ]")
    center(H, "Touch a track to play it")
end

local function drawQueue()
    header("PLAY QUEUE")

    if #state.queue == 0 then
        center(10, "QUEUE IS EMPTY")
        center(12, "Add tracks from the Library")
    else
        for i, index in ipairs(state.queue) do
            if i <= H - 9 and tracks[index] then
                local marker = i == state.queuePos and ">" or " "
                put(
                    2,
                    7 + i,
                    truncate(
                        marker .. " " .. i .. ". " .. trackName(tracks[index]),
                        W - 2
                    )
                )
            end
        end
    end

    center(H - 1, "[ BACK ]")
end

local function drawDownload()
    header("MUSIC DOWNLOAD")

    center(7, "DIRECT .DFPWM AUDIO")
    center(9, "Press START and enter a direct URL")
    center(11, "Downloaded tracks are stored in /music")
    center(13, "No protected-service extraction")
    center(16, "[ START DOWNLOAD ]")
    center(19, "[ BACK ]")
end

local function drawSystem()
    header("SYSTEM")

    center(7, "ZEVELIAN MUSIC STATION")
    center(9, "Monitor: ONLINE")
    center(10, "Speaker: ONLINE")
    center(11, "DFPWM: ONLINE")
    center(12, "Tracks: " .. #tracks)
    center(13, "Volume: " .. math.floor(state.volume * 100) .. "%")
    center(14, "Shuffle: " .. (state.shuffle and "ON" or "OFF"))
    center(15, "Repeat: " .. state.repeatMode:upper())
    center(18, "[ BACK ]")
end

local function draw()
    W, H = monitor.getSize()

    if state.page == "home" then
        drawHome()
    elseif state.page == "library" then
        drawLibrary()
    elseif state.page == "queue" then
        drawQueue()
    elseif state.page == "download" then
        drawDownload()
    elseif state.page == "system" then
        drawSystem()
    end
end

local function stopPlayback()
    stopping = true
    playbackToken = playbackToken + 1

    pcall(function()
        speaker.stop()
    end)

    playing = false
    paused = false
    elapsed = 0
    duration = 0
    status = "STOPPED"
end

local function estimateDuration(path)
    local size = fs.getSize(path) or 0
    return size / 48000
end

local function nextIndex()
    if #tracks == 0 then
        return nil
    end

    if state.shuffle and #tracks > 1 then
        local next = state.current

        while next == state.current do
            next = math.random(1, #tracks)
        end

        return next
    end

    if state.current < #tracks then
        return state.current + 1
    end

    if state.repeatMode == "all" then
        return 1
    end

    return nil
end

local function previousIndex()
    if #tracks == 0 then
        return nil
    end

    if state.current > 1 then
        return state.current - 1
    end

    return #tracks
end

local function playTrack(index)
    refreshLibrary()

    if #tracks == 0 then
        status = "NO MUSIC"
        draw()
        return
    end

    index = clamp(index, 1, #tracks)

    state.current = index
    state.selected = index

    currentPath = tracks[index]
    currentTitle = trackName(currentPath)

    elapsed = 0
    duration = estimateDuration(currentPath)

    playing = true
    paused = false
    stopping = false

    playbackToken = playbackToken + 1
    local myToken = playbackToken

    status = "PLAYING"
    message = ""

    draw()

    local h = fs.open(currentPath, "rb")

    if not h then
        playing = false
        status = "FILE ERROR"
        message = "Could not open " .. currentTitle
        draw()
        return
    end

    local decoder = dfpwm.make_decoder()
    local started = os.clock()

    while not stopping and myToken == playbackToken do
        while paused and not stopping and myToken == playbackToken do
            sleep(0.05)
        end

        local chunk = h.read(16 * 1024)

        if not chunk then
            break
        end

        local pcm = decoder(chunk)

        local sent = false

        while not sent and not stopping and myToken == playbackToken do
            local okPlay, result =
                pcall(
                    speaker.playAudio,
                    pcm,
                    state.volume
                )

            if okPlay and result then
                sent = true
            else
                sleep(0.02)
            end
        end

        elapsed = os.clock() - started
    end

    h.close()

    if myToken ~= playbackToken or stopping then
        return
    end

    playing = false
    elapsed = duration

    if state.repeatMode == "one" then
        playTrack(state.current)
        return
    end

    local next = nextIndex()

    if next then
        playTrack(next)
    else
        status = "FINISHED"
        draw()
    end
end

local function togglePlay()
    if playing then
        paused = not paused
        status = paused and "PAUSED" or "PLAYING"
        draw()
        return
    end

    playTrack(state.current)
end

local function previous()
    local n = previousIndex()

    if n then
        stopPlayback()
        playTrack(n)
    end
end

local function next()
    local n = nextIndex()

    if n then
        stopPlayback()
        playTrack(n)
    end
end

local function changeVolume(amount)
    state.volume = clamp(state.volume + amount, 0, 3)
    saveState()

    status = "VOLUME " .. math.floor(state.volume * 100) .. "%"
    draw()
end

local function cycleRepeat()
    if state.repeatMode == "off" then
        state.repeatMode = "all"
    elseif state.repeatMode == "all" then
        state.repeatMode = "one"
    else
        state.repeatMode = "off"
    end

    saveState()
    draw()
end

local function toggleShuffle()
    state.shuffle = not state.shuffle
    saveState()
    draw()
end

local function addCurrentToQueue()
    if #tracks == 0 then return end

    state.queue[#state.queue + 1] = state.current
    message = "ADDED TO QUEUE"
    draw()
end

local function downloadTrack()
    term.clear()
    term.setCursorPos(1, 1)
    term.setCursorBlink(true)

    print("ZEVELIAN MUSIC STATION")
    print("DIRECT DFPWM DOWNLOAD")
    print("----------------------")
    print("Enter a direct .dfpwm URL.")
    print("")

    write("URL: ")
    local url = read()

    term.setCursorBlink(false)

    if not url or url == "" then
        return
    end

    if not url:lower():match("%.dfpwm([%?#].*)?$") then
        print("")
        print("ERROR: URL is not a direct .dfpwm file.")
        sleep(2)
        return
    end

    print("")
    print("Connecting...")

    local ok, response, err =
        pcall(
            http.get,
            url,
            {
                ["User-Agent"] = "ZEVELIAN-MUSIC-STATION/3.0"
            }
        )

    if not ok or not response then
        print("Download failed: " .. tostring(err or response))
        sleep(2)
        return
    end

    local code = response.getResponseCode()

    if code ~= 200 then
        response.close()
        print("Server returned HTTP " .. tostring(code))
        sleep(2)
        return
    end

    local data = response.readAll()
    response.close()

    local filename =
        url:match("/([^/?#]+)") or "download.dfpwm"

    filename = filename:gsub("[^%w%._%- ]", "_")

    if not filename:lower():match("%.dfpwm$") then
        filename = filename .. ".dfpwm"
    end

    local path = fs.combine(MUSIC_DIR, filename)
    local h = fs.open(path, "wb")

    if not h then
        print("Could not create file.")
        sleep(2)
        return
    end

    h.write(data)
    h.close()

    refreshLibrary()

    print("")
    print("DOWNLOAD COMPLETE")
    print(filename)
    sleep(1.5)
end

local function handleTouch(x, y)
    if state.page == "home" then
        if y == 14 then
            if x < W / 3 then
                previous()
            elseif x < W * 2 / 3 then
                togglePlay()
            else
                next()
            end

        elseif y == 16 then
            if x < W / 4 then
                stopPlayback()
                draw()
            elseif x < W / 2 then
                changeVolume(-0.1)
            elseif x < W * 3 / 4 then
                changeVolume(0.1)
            end

        elseif y == 18 then
            if x < W / 2 then
                state.page = "library"
            else
                state.page = "queue"
            end
            draw()

        elseif y == 20 then
            if x < W / 2 then
                toggleShuffle()
            else
                cycleRepeat()
            end
        end

    elseif state.page == "library" then
        if y >= 9 and y <= H - 3 then
            local row = y - 8 + state.libraryOffset
            local list = filteredLibrary()

            if list[row] then
                for i, path in ipairs(tracks) do
                    if path == list[row] then
                        state.current = i
                        state.selected = i
                        break
                    end
                end

                playTrack(state.current)
            end

        elseif y == H - 2 then
            if x < W / 4 then
                state.page = "home"
                draw()
            elseif x < W / 2 then
                state.libraryOffset = math.max(0, state.libraryOffset - 1)
                draw()
            elseif x < W * 3 / 4 then
                local maxOffset =
                    math.max(
                        0,
                        #filteredLibrary() - math.max(1, H - 12)
                    )

                state.libraryOffset =
                    math.min(maxOffset, state.libraryOffset + 1)

                draw()
            else
                playTrack(state.selected)
            end
        end

    elseif state.page == "queue" then
        if y == H - 1 then
            state.page = "home"
            draw()
        end

    elseif state.page == "download" then
        if y == 16 then
            downloadTrack()
            state.page = "home"
            draw()
        elseif y == 19 then
            state.page = "home"
            draw()
        end

    elseif state.page == "system" then
        if y == 18 then
            state.page = "home"
            draw()
        end
    end
end

local function touchLoop()
    while true do
        local _, side, x, y = os.pullEvent("monitor_touch")

        if side == peripheral.getName(monitor) or side == "monitor" then
            handleTouch(x, y)
        end
    end
end

local function keyboardLoop()
    while true do
        local _, key = os.pullEvent("key")

        if key == keys.space then
            togglePlay()

        elseif key == keys.left then
            previous()

        elseif key == keys.right then
            next()

        elseif key == keys.up then
            changeVolume(0.1)

        elseif key == keys.down then
            changeVolume(-0.1)

        elseif key == keys.s then
            toggleShuffle()

        elseif key == keys.r then
            cycleRepeat()

        elseif key == keys.l then
            state.page = "library"
            draw()

        elseif key == keys.q then
            stopPlayback()
            saveState()
            clear()
            center(3, "ZEVELIAN MUSIC STATION")
            center(5, "SYSTEM OFFLINE")
            return
        end
    end
end

local function animationLoop()
    while true do
        sleep(0.25)

        if state.page == "home" and playing then
            visualTick = visualTick + 1
            draw()
        end
    end
end

loadState()
refreshLibrary()
draw()

parallel.waitForAny(
    touchLoop,
    keyboardLoop,
    animationLoop
)

stopPlayback()
saveState()
