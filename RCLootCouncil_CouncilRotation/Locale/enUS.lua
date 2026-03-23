local L = LibStub("AceLocale-3.0"):NewLocale("RCCouncilRotation", "enUS", true)
if not L then return end

-- General
L["Council Rotation"] = true
L["Enable"] = true
L["Rotating Seats"] = true
L["Eligible Guild Ranks"] = true
L["Auto-Rotate"] = true
L["Rotate Now"] = true

-- Permanent Council Ranks
L["Permanent Council Ranks"] = true
L["Enable Permanent Ranks"] = true
L["permanent_ranks_enable_desc"] = "When enabled, raid members with these ranks are automatically added to the council."
L["permanent_ranks_desc"] = "Select guild ranks that should always be on the council when in the raid."
L["permanent_ranks_synced"] = "Permanent council ranks synced: added %d member(s)."

-- Descriptions
L["addon_desc"] = "RCLootCouncil - Council Rotation |cFF87CEFAv%s|r\nRotate raid members into temporary council seats each raid night."
L["enable_desc"] = "Enable council rotation. When disabled, no automatic or manual rotations will occur."
L["seats_desc"] = "Number of raid members to rotate onto the council each session."
L["ranks_desc"] = "Select which guild ranks are eligible for the rotation pool."
L["auto_rotate_desc"] = "Automatically rotate council members when raid time starts (requires GitRaidTools)."
L["rotate_now_desc"] = "Immediately select new council members from eligible raiders. Requires Master Looter."
L["rotate_cmd_hint"] = "Or use:  |cFF87CEFA/rc rotate|r"
L["chat_cmd_desc"] = "Opens the Council Rotation options window"

-- Announcements
L["Announcements"] = true
L["Raid Announcement"] = true
L["Whisper Instructions"] = true
L["raid_announce_desc"] = "Announce selected council members to the raid."
L["whisper_desc"] = "Send instructions to newly selected council members via whisper."
L["Announcement Template"] = true
L["announce_template_desc"] = "Message sent to raid chat. Use {names} for the selected members."
L["Instruction Message"] = true
L["instruction_msg_desc"] = "Message whispered to each selected council member."
L["Mute Active"] = true
L["mute_active_desc"] = "GitRaidTools mute is active. No announcements will be sent."

-- History
L["History"] = true
L["Clear History"] = true
L["clear_history_desc"] = "Remove all rotation history entries."
L["Reset Cycle"] = true
L["reset_cycle_desc"] = "Reset the rotation cycle, allowing all eligible members to be selected again."
L["No history entries."] = true

-- Test mode
L["test_mode_on"] = "|cFFFFFF00[TEST MODE]|r Rotation will use online guild members, modify council, and print announcements locally."
L["unknown_arg"] = "Unknown argument: %s. Usage: /rc rotate [test]"

-- Status messages
L["rotation_success"] = "Council rotation complete: %s"
L["rotation_no_eligible"] = "No eligible raid members found for rotation."
L["rotation_not_enough"] = "Only %d eligible members found (requested %d). Selecting all available."
L["rotation_not_ml"] = "You must be the Master Looter to rotate council members."
L["rotation_not_in_raid"] = "You must be in a raid group to rotate council members."
L["rotation_disabled"] = "Council rotation is disabled."
L["rotation_cycle_reset"] = "Rotation cycle reset. All eligible members can be selected again."
L["rotation_auto_triggered"] = "Auto-rotation triggered at raid time."
L["grt_not_installed"] = "GitRaidTools is not installed. Auto-rotation is unavailable."

-- Defaults
L["default_announce"] = "Tonight's rotating council members: {names}"
L["default_instructions"] = "You've been picked for tonight's loot council — welcome! When loot drops, a voting frame will pop up. Review responses and vote on who should get each item. If you need to reopen it: /rc open. Ask in raid if anything's unclear!"
