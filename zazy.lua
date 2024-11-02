local PlaceID = getgenv().placeId
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game.Players
local jsonFileName = "NotSameServers.json"

-- Load existing IDs or create a new file
local function loadIDs()
    print("Loading IDs from file...")
    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(jsonFileName))
    end)
    if success and type(result) == "table" then
        AllIDs = result
        print("Loaded IDs successfully:", AllIDs)
    else
        AllIDs = {actualHour}
        print("No existing ID file found or failed to load, creating new file with current hour:", actualHour)
        writefile(jsonFileName, HttpService:JSONEncode(AllIDs))
    end
end

-- Save IDs to file
local function saveIDs()
    print("Saving IDs to file...")
    writefile(jsonFileName, HttpService:JSONEncode(AllIDs))
    print("IDs saved successfully.")
end

-- Clear the file if the hour has changed
local function clearFileIfHourChanged()
    print("Checking if the hour has changed...")
    if tonumber(actualHour) ~= tonumber(AllIDs[1]) then
        print("Hour changed, clearing ID file...")
        pcall(function()
            delfile(jsonFileName)
        end)
        AllIDs = {actualHour}
        saveIDs()
        print("ID file cleared and reset with current hour:", actualHour)
    else
        print("Hour has not changed, no need to clear the file.")
    end
end

-- Fetch the server data from the Roblox API
local function fetchServers(cursor)
    print("Fetching servers with cursor:", cursor or "None")
    
    local url = 'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100'
    
    if cursor then
        url = url .. '&cursor=' .. cursor
    end
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if not success then
        warn("Failed to fetch servers: " .. tostring(result))
        return nil
    end
    
    print("Fetched servers successfully. Number of servers retrieved:", #result.data)
    return result
end

-- Attempt to teleport to a new server
local function tryTeleport(ID)
    print("Attempting to teleport to server ID:", ID)
    table.insert(AllIDs, ID)
    saveIDs()
    TeleportService:TeleportCancel()
    TeleportService:TeleportToPlaceInstance(PlaceID, ID, Players.LocalPlayer)
end

-- Main function to find and teleport to a suitable server
local function TPReturner()
    print("Running TPReturner function...")
    local Site = fetchServers(foundAnything)
    
    if not Site then
        return
    end
    
    if Site.nextPageCursor then
        foundAnything = Site.nextPageCursor
        print("Next page cursor set to:", foundAnything)
    end

    clearFileIfHourChanged()

    local serverFound = false
    for _, server in ipairs(Site.data) do
        local ID = tostring(server.id)
        print("Checking server ID:", ID, "Players:", server.playing, "/", server.maxPlayers)
        
        if tonumber(server.maxPlayers) > tonumber(server.playing) and not table.find(AllIDs, ID) then
            print("Suitable server found:", ID)
            tryTeleport(ID)
            serverFound = true
            break
        end
    end

    if not serverFound then
        print("No suitable servers found on this page.")
    end
end

-- Main teleport loop
local function Teleport()
    while true do
        local success, errorMessage = pcall(TPReturner)
        if not success then
            warn("Error occurred during TPReturner: " .. tostring(errorMessage))
        end
        wait(2) -- Fixed wait time before the next fetch
    end
end

-- Load IDs and start the teleport process
loadIDs()
Teleport()
