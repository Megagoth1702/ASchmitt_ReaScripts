-- @version 1.0
-- @description Gradually Scale MIDI Note Lengths
-- @about
--   # Gradually Scale MIDI Note Lengths
--
--   This script allows you to scale MIDI note lengths gradually between a specified minimum and maximum length using correct PPQ calculations. It requires the SWS Extension.
-- @author Andrei Schmidt
-- @donation
--   Strike: https://strike.me/megagoth1702/
--   PayPal: https://www.paypal.com/paypalme/TheVayMusick
-- @screenshot
--   ![Screenshot](https://i.imgur.com/XLKt8B2.png)
-- @provides
--   [main] .

-- Gradually Scale MIDI Note Lengths Script with Correct PPQ Calculation

-- Step 0: Ensure the SWS Extension is available
if not reaper.APIExists("SNM_GetIntConfigVar") then
    reaper.ShowMessageBox("This script requires the SWS Extension.", "Error", 0)
    return
end

-- Begin undo block and prevent UI refresh for better performance
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Step 1: Get the MIDI editor and active take
local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)

if not take or not reaper.TakeIsMIDI(take) then
    reaper.ShowMessageBox("No active MIDI take found.", "Error", 0)
    -- End undo block and re-enable UI refresh before returning
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Gradually Scale MIDI Note Lengths", -1)
    return
end

-- Step 2: Ask user for min and max note lengths (musical values like 1/X)
local retval, input = reaper.GetUserInputs("Gradual Note Length", 2, "Min Length (1/X),Max Length (1/X)", "32,8")
if not retval then
    -- End undo block and re-enable UI refresh before returning
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Gradually Scale MIDI Note Lengths", -1)
    return
end

local min_denom, max_denom = input:match("(%d+),(%d+)")
min_denom, max_denom = tonumber(min_denom), tonumber(max_denom)

if not min_denom or not max_denom or min_denom == 0 or max_denom == 0 then
    reaper.ShowMessageBox("Invalid input. Enter valid note fractions.", "Error", 0)
    -- End undo block and re-enable UI refresh before returning
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Gradually Scale MIDI Note Lengths", -1)
    return
end

-- Step 3: Get the project's PPQ (ticks per quarter note)
local default_ppq = 960 -- Default PPQ if we can't get it from config
local ppq = reaper.SNM_GetIntConfigVar("miditicksperbeat", default_ppq)

-- Step 4: Convert musical note values to MIDI ticks
local min_len = ppq * (4 / min_denom)
local max_len = ppq * (4 / max_denom)

-- Step 5: Collect selected notes and store them in a table
local notes = {}
local _, note_count = reaper.MIDI_CountEvts(take)

for i = 0, note_count - 1 do
    local retval, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected then
        table.insert(notes, {index = i, startppq = startppq, endppq = endppq})
    end
end

-- Step 6: Check if at least two notes are selected
if #notes < 2 then
    reaper.ShowMessageBox("Select at least two notes.", "Error", 0)
    -- End undo block and re-enable UI refresh before returning
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Gradually Scale MIDI Note Lengths", -1)
    return
end

-- Step 7: Sort the notes by their start positions
table.sort(notes, function(a, b) return a.startppq < b.startppq end)

-- Step 8: Calculate the range of the selected notes
local first_note_start = notes[1].startppq
local last_note_start = notes[#notes].startppq
local relative_range = last_note_start - first_note_start

-- Handle case when all notes start at the same position
if relative_range == 0 then
    relative_range = 1 -- To prevent division by zero
end

-- Step 9: Adjust each note's length
for i, note in ipairs(notes) do
    -- Calculate the note's relative position within the selection
    local relative_position = (note.startppq - first_note_start) / relative_range

    -- Calculate new length
    local new_length = min_len + relative_position * (max_len - min_len)
    new_length = math.floor(new_length + 0.5) -- Round to nearest tick

    -- Adjust note endppq
    local new_endppq = note.startppq + new_length

    -- Set the new note length
    reaper.MIDI_SetNote(take, note.index, nil, nil, note.startppq, new_endppq, nil, nil, nil, true)
end

-- Step 10: Finalize changes and refresh UI
reaper.MIDI_Sort(take)
reaper.UpdateArrange()

-- End undo block and re-enable UI refresh
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Gradually Scale MIDI Note Lengths", -1)
