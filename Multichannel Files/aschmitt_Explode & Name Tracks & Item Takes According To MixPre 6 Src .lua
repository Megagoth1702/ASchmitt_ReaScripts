-- @description Explode MulChan & Name Tracks & Item Takes According To MixPre 6 Source
-- @version 1.0.1
-- @author Andrej Schmitt
-- @about Script made specifically to work with MixPre 6 Source Files.
--	Per MixPre polywav-channel will create according single-channel item, route appropriate source
--	file channel to it & name the item & track by using Metadata from the Original Wav File.
-- @changelog	# added some ReaScript Packaging Info
--	#tried to fix PackInfo
--	#fiiiixxxiiiittt


-- Check if REAPER is available
if not reaper then
  error("This script requires REAPER to run.")
end

-- Function to retrieve track metadata
local function getTrackMetadata()
    local selectedItem = reaper.GetSelectedMediaItem(0, 0)
    if not selectedItem then return nil end

    local take = reaper.GetActiveTake(selectedItem)
    if not take then return nil end

    local source = reaper.GetMediaItemTake_Source(take)
    local retval, description = reaper.CF_GetMediaSourceMetadata(source, "DESC", "")
    if not retval or description == "" then return nil end

    local trackInfo = {}
    for trackNum, trackName in string.gmatch(description, "sTRK(%d+)=(%S+)") do
        trackInfo[tonumber(trackNum)] = trackName
    end
    return trackInfo
end

-- Function to explode multichannel item into mono items
local function explodeMultichannelToMono()
    local selectedItem = reaper.GetSelectedMediaItem(0, 0)
    
    if not selectedItem then
        reaper.ShowMessageBox("No item selected", "Error", 0)
        return
    end

    local activeTake = reaper.GetActiveTake(selectedItem)
    if not activeTake then
        reaper.ShowMessageBox("Selected item has no active take", "Error", 0)
        return
    end

    local source = reaper.GetMediaItemTake_Source(activeTake)
    local numChannels = reaper.GetMediaSourceNumChannels(source)
    local trackMetadata = getTrackMetadata()

    -- Store original track and position
    local originalTrack = reaper.GetMediaItem_Track(selectedItem)
    local originalTrackName = ({reaper.GetSetMediaTrackInfo_String(originalTrack, "P_NAME", "", false)})[2]
    local itemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
    
    -- Begin undo block
    reaper.Undo_BeginBlock()

    for channel = 1, numChannels do
        -- Insert new track below original track
        local newTrackIndex = reaper.GetMediaTrackInfo_Value(originalTrack, "IP_TRACKNUMBER") + channel - 1
        reaper.InsertTrackAtIndex(newTrackIndex, true)
        local newTrack = reaper.GetTrack(0, newTrackIndex)

        -- Set track name using metadata if available, otherwise use channel number
        local trackName = trackMetadata and trackMetadata[channel + 2] or ("Ch " .. channel)
        local fullTrackName = originalTrackName .. " - " .. trackName
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", fullTrackName, true)

        -- Duplicate item to new track
        local newItem = reaper.AddMediaItemToTrack(newTrack)
        reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", itemPosition)
        reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemLength)
        local newTake = reaper.AddTakeToMediaItem(newItem)

        -- Set new item as mono, using the respective channel
        reaper.SetMediaItemTakeInfo_Value(newTake, "I_CHANMODE", 2 + channel)
        reaper.SetMediaItemTake_Source(newTake, source)

        -- Set take name
        reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", fullTrackName, true)
    end

    -- Mute the original item
    reaper.SetMediaItemInfo_Value(selectedItem, "B_MUTE", 1)

    -- End undo block
    reaper.Undo_EndBlock("Explode Multichannel to Mono Items", -1)

    -- Update the arrangement view
    reaper.UpdateArrange()
end

-- Execute the function
explodeMultichannelToMono()

