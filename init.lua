--[[TestBars lua
    Example of vertical and horizontal status bars with ImAnim effects.
    Configuration options include colors, bar height, rounding, ticks, shimmer, glow, gradients, and borders.

    Includes Horizontal and Vertical Bars with shared options and some vertical-specific options (see StatusBar.Draw and StatusBar.DrawV functions).
]]

--[[attempt to replicate this from the demo cpp code with a resuable function and options:
// ============================================================
// USECASE 7: Progress Bar with Segments
// ============================================================
static void ShowUsecase_ProgressBar()
{
    ImGui::TextWrapped(
        "Animated progress bar with segmented fill and glow effects. "
        "Uses color interpolation in OKLAB for smooth gradients.");

    float dt = GetUsecaseDeltaTime();
    ImDrawList* dl = ImGui::GetWindowDrawList();

    static float target_progress = 0.65f;
    ImGui::SliderFloat("Progress", &target_progress, 0.0f, 1.0f);

    ImGuiID id = ImGui::GetID("progress_bar");

    // Animate progress value
    float progress = iam_tween_float(id, ImHashStr("value"), target_progress, 0.5f,
        iam_ease_preset(iam_ease_out_expo), iam_policy_crossfade, dt);

    ImVec2 bar_pos = ImGui::GetCursorScreenPos();
    ImVec2 bar_size(ImGui::GetContentRegionAvail().x - 20.0f, 24.0f);

    // Background
    dl->AddRectFilled(bar_pos, ImVec2(bar_pos.x + bar_size.x, bar_pos.y + bar_size.y),
        IM_COL32(30, 32, 40, 255), 6.0f);

    // Filled portion with gradient
    float filled_width = bar_size.x * progress;
    if (filled_width > 2.0f)
    {
        // Gradient from cyan to green based on progress
        ImVec4 start_col(0.2f, 0.6f, 0.9f, 1.0f);
        ImVec4 end_col(0.2f, 0.9f, 0.5f, 1.0f);
        ImVec4 fill_color = iam_get_blended_color(start_col, end_col, progress, iam_col_oklab);

        dl->AddRectFilled(bar_pos, ImVec2(bar_pos.x + filled_width, bar_pos.y + bar_size.y),
            ImGui::ColorConvertFloat4ToU32(fill_color), 6.0f, ImDrawFlags_RoundCornersLeft);

        // Glow effect at the edge
        float glow_x = bar_pos.x + filled_width - 4.0f;
        for (int i = 0; i < 4; i++)
        {
            float alpha = 0.3f * (1.0f - i * 0.25f);
            float offset = i * 4.0f;
            dl->AddRectFilled(
                ImVec2(glow_x - offset, bar_pos.y),
                ImVec2(glow_x + 4.0f, bar_pos.y + bar_size.y),
                IM_COL32(255, 255, 255, (int)(alpha * 255 * (1.0f - i * 0.2f))), 4.0f);
        }

        // Animated shimmer
        static float shimmer_time = 0.0f;
        shimmer_time += dt;
        float shimmer_pos = ImFmod(shimmer_time * 0.5f, 1.0f) * filled_width;
        float shimmer_width = 60.0f;

        if (shimmer_pos < filled_width)
        {
            float shimmer_alpha = 0.15f * ImSin(shimmer_pos / filled_width * 3.14159f);
            dl->AddRectFilledMultiColor(
                ImVec2(bar_pos.x + shimmer_pos, bar_pos.y),
                ImVec2(bar_pos.x + shimmer_pos + shimmer_width, bar_pos.y + bar_size.y),
                IM_COL32(255, 255, 255, 0),
                IM_COL32(255, 255, 255, (int)(shimmer_alpha * 255)),
                IM_COL32(255, 255, 255, (int)(shimmer_alpha * 255)),
                IM_COL32(255, 255, 255, 0));
        }
    }

    // Percentage text
    char percent_text[16];
    snprintf(percent_text, sizeof(percent_text), "%.0f%%", progress * 100.0f);
    ImVec2 text_size = ImGui::CalcTextSize(percent_text);
    ImVec2 text_pos(bar_pos.x + (bar_size.x - text_size.x) * 0.5f,
        bar_pos.y + (bar_size.y - text_size.y) * 0.5f);
    dl->AddText(text_pos, IM_COL32(255, 255, 255, 200), percent_text);

    ImGui::Dummy(ImVec2(bar_size.x, bar_size.y + 16.0f));
}]]

local mq = require('mq')
local ImGui = require('ImGui')

local StatusBar = require('progressBars')
local isRunning = false

local MyData = {}
local TargetData = {}
local expBarLength = 150
local maxWidth = 300
local maxHeight = 300
local revert = {}
local imagesPath
local overlayTexture_vert
local overlayTexture_hor
local tempBarTpye = "Health"

local _barOpts = {}
-- per-bar timing state
local timeLastRefresh = mq.gettime()
StatusBar._state = StatusBar._state or {}

local Colors = {
    HPMax = ImVec4(0.992, 0.138, 0.138, 1.000),
    HPMin = ImVec4(0.551, 0.207, 0.962, 1.000),
    ManaMax = ImVec4(0.124, 0.592, 0.920, 1.000),
    ManaMin = ImVec4(0.258, 0.069, 0.502, 1.000),
    EndurMin = ImVec4(0.063, 0.389, 0.117, 1.000),
    EndurMax = ImVec4(0.825, 0.727, 0.004, 1.000),
    XPMin = ImVec4(0.293, 0.416, 0.791, 1.000),
    XPMax = ImVec4(0.782, 0.905, 0.009, 1.000),
    borders = ImVec4(0.8, 0.8, 0.8, 1.0),
    --CON COLORS
    green = ImVec4(0.2, 0.8, 0.2, 1.0),
    red = ImVec4(0.8, 0.2, 0.2, 1.0),
    blue = ImVec4(0.2, 0.2, 0.8, 1.0),
    lightblue = ImVec4(0.2, 0.8, 0.8, 1.0),
    white = ImVec4(1.0, 1.0, 1.0, 1.0),
    grey = ImVec4(0.5, 0.5, 0.5, 1.0),
    yellow = ImVec4(0.8, 0.8, 0.2, 1.0),
}

local function getConColor(conColor)
    if not conColor then return Colors.grey end
    local key = conColor:gsub("%s+", ""):lower()
    local conCols = {
        green = ImVec4(0.2, 0.8, 0.2, 1.0),
        red = ImVec4(0.8, 0.2, 0.2, 1.0),
        blue = ImVec4(0.2, 0.2, 0.8, 1.0),
        lightblue = ImVec4(0.2, 0.8, 0.8, 1.0),
        white = ImVec4(1.0, 1.0, 1.0, 1.0),
        grey = ImVec4(0.5, 0.5, 0.5, 1.0),
        yellow = ImVec4(0.8, 0.8, 0.2, 1.0),
    }
    return conCols[key] or Colors.grey
end

local ProgressOptions = {
    height = 15.0,                     -- height of the bar, vertical bars set below 3 will default to using available vertical space
    width = 0,                         -- width of the bar, horizontal bars set below 3 will default to using available horizontal space
    padEnd = 10.0,                     -- spacing after the bar (below for vertical, right for horizontal)
    rounding = 4.0,                    -- corner rounding radius
    showText = true,                   -- show percentage text in the center of the bar
    textFmt = "%.1f%%",                -- how to format the string.
    showTicks = false,                 -- show tick marks on bar
    tickEvery = 0.2,                   -- interval between ticks as fraction (e.g. 0.1 for every 10%)
    tickAlpha = 50,                    -- alpha of tick marks (0-255)
    tickThickness = 1.0,               -- thickness of tick marks
    shimmer = false,                   -- animated shimmer effect on the fill; if true, will animate a highlight moving across the filled portion
    shimmerFollows = true,             -- shimmer follows progress direction (default true); if false, shimmer always moves left->right (or bottom->top for vertical)
    shimmerSpeed = 0.5,                -- cycles per second for shimmer animation
    shimmerWidth = 60.0,               -- width of the shimmer highlight in pixels
    shimmerDeadzone = 0.05,            -- minimum progress change to trigger shimmer direction change when shimmerFollows is true
    glow = true,                       -- glow effect at the leading edge of the fill bar

    tweenSeconds = 0.35,               -- duration of progress animation in seconds
    --gradient fill
    fillGradient = true,               -- blend from lowCol to highCol across the fill; if false, uses a single blended color for the entire fill
    fillGradientMode = "dynamic",      -- "static" or "dynamic" static will compress the blend on the visible bar fill, dynamic spreads this across the whole bar filled or not.
    fillGradientDir = "lr",            -- "lr" or "tb" gradient direction left to right or top to bottom.
    lowCol = Colors.HPMin,             -- color at 0% fill
    highCol = Colors.HPMax,            -- color at 100% fill
    -- Border
    border = false,                    -- draw borders
    borderThickness = 2.0,             -- thickness of border lines
    borderColor = Colors.borders,      -- color of borders (can be ImVec4 or U32)
    bgU32 = IM_COL32(30, 32, 40, 255), -- background color of the bar (as U32)
    --overlay an image
    overlayOn = false,                 -- draw an image overlay if enabled and overlay texture provided
    overlay = nil,                     -- texture using mq.CreateTexture
    overlayTint = IM_COL32(255, 255, 255, 255),
    overlayPadding = 0.0,              -- expand/shrink overlay rect
    overlayUv0 = ImVec2(0, 0),
    overlayUv1 = ImVec2(1, 1),
    overlayStatic = true, -- static overlays are drawn full-size over the bar; dynamic overlays are clipped to the filled portion
}

local targetOpts = {}
local verticalOpts = {}

local function loadOverlay(file)
    local path = imagesPath .. file
    local tex = mq.CreateTexture(path)
    if not tex then
        print("Failed to load overlay texture: " .. path)
        return nil
    end
    return tex
end


local function shallowCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

local function GetMyData()
    return {
        PctExp = mq.TLO.Me.PctExp(),
        HpMax = mq.TLO.Me.MaxHPs(),
        HpCur = mq.TLO.Me.CurrentHPs(),
        ManaMax = mq.TLO.Me.MaxMana(),
        ManaCur = mq.TLO.Me.CurrentMana(),
        EnduranceMax = mq.TLO.Me.MaxEndurance(),
        EnduranceCur = mq.TLO.Me.CurrentEndurance(),
        PctEnd = mq.TLO.Me.PctEndurance(),
        PctHps = mq.TLO.Me.PctHPs(),
        PctMana = mq.TLO.Me.PctMana(),
    }
end

local function GetTargetData()
    if not mq.TLO.Target() then
        targetOpts.textFmt = string.format("%s: ", TargetData and TargetData.Name or "Target") .. "%.1f%%"
        return {
            Name = "No Target",
            HpPct = 0,
            ConColor = getConColor('GREY'),
        }
    end
    local Name = mq.TLO.Target and mq.TLO.Target.CleanName() or "unknown"
    local HpPct = mq.TLO.Target and mq.TLO.Target.PctHPs() or 0
    local conColor = mq.TLO.Target and mq.TLO.Target.ConColor() or 'GREY'

    return {
        Name = Name,
        HpPct = HpPct,
        ConColor = getConColor(conColor),
    }
end

local function DrawContextMenu(settings, barLabel)
    if revert[barLabel] == nil then
        revert[barLabel] = {
            defaults = shallowCopy(_barOpts[barLabel] or ProgressOptions),
            colorMin = (barLabel:find("Health") and Colors.HPMin) or (barLabel:find("Mana") and Colors.ManaMin) or (barLabel:find("Endurance") and Colors.EndurMin) or Colors.XPMin,
            colorMax = (barLabel:find("Health") and Colors.HPMax) or (barLabel:find("Mana") and Colors.ManaMax) or (barLabel:find("Endurance") and Colors.EndurMax) or Colors.XPMax,
        }
    end

    settings.lowCol = ImGui.ColorEdit4("Min Color", settings.lowCol)
    settings.highCol = ImGui.ColorEdit4("Max Color", settings.highCol)

    local changed = false
    if settings.height ~= nil then
        settings.height, changed = ImGui.SliderInt("Bar Height", settings.height, 0, maxHeight)
        if changed and settings.height <= 1 then
            settings.height = maxHeight - settings.padEnd
        end
    end
    if settings.width ~= nil then
        settings.width, changed = ImGui.SliderInt("Bar Width", settings.width, 0, maxWidth)
        if changed and settings.width <= 1 then
            settings.width = maxWidth - settings.padEnd
        end
    end
    if settings.padEnd ~= nil then
        settings.padEnd = ImGui.SliderInt("Bar Pad End", settings.padEnd or 0, 0, 50)
    end

    settings.rounding = ImGui.SliderInt("Bar Rounding", settings.rounding or 0, 0, 20)
    settings.border = ImGui.Checkbox("Border", settings.border)
    if settings.border then
        if barLabel:find("Target") then
            settings.borderConColor = ImGui.Checkbox("Border Color Follows Con Color", (settings.borderConColor == true) or false)
        end
        settings.borderThickness = ImGui.SliderInt("Border Thickness", settings.borderThickness, 0, 5)
        if not settings.borderConColor then
            settings.borderColor = ImGui.ColorEdit4("Border Color", settings.borderColor or Colors.borders)
        end
    end
    settings.showText = ImGui.Checkbox("Show Text", settings.showText)
    settings.shimmer = ImGui.Checkbox("Shimmer", settings.shimmer)
    if settings.shimmer then
        settings.shimmerFollows = ImGui.Checkbox("Shimmer Follows", settings.shimmerFollows)
        settings.shimmerSpeed = ImGui.SliderFloat("Shimmer Speed", settings.shimmerSpeed or 0.5, 0.0, 5.0)
        settings.shimmerWidth = ImGui.SliderInt("Shimmer Width", settings.shimmerWidth or 50, 5, 200)
        settings.shimmerDeadzone = ImGui.SliderFloat("Shimmer Deadzone", settings.shimmerDeadzone or 0.01, 0.0, 0.05)
    end
    settings.glow = ImGui.Checkbox("Glow", settings.glow)
    settings.showTicks = ImGui.Checkbox("Show Ticks", settings.showTicks)
    if settings.showTicks then
        settings.tickEvery = ImGui.SliderFloat("Tick Every", settings.tickEvery, 0.0, 1.0)
        settings.tickAlpha = ImGui.SliderFloat("Tick Alpha", settings.tickAlpha, 0.0, 255.0)
        settings.tickThickness = ImGui.SliderFloat("Tick Thickness", settings.tickThickness, 1.0, 5.0)
    end
    settings.fillGradient = ImGui.Checkbox("Gradient Fill", settings.fillGradient)
    if settings.fillGradient then
        if ImGui.BeginCombo("Gradient Mode", settings.fillGradientMode) then
            local comboOptions = { "static", "dynamic", }
            for i, option in ipairs(comboOptions) do
                local isSelected = (settings.fillGradientMode == option)
                if ImGui.Selectable(option, isSelected) then
                    settings.fillGradientMode = option
                end
            end
            ImGui.EndCombo()
        end
        if ImGui.BeginCombo("Gradient Direction", settings.fillGradientDir) then
            local comboOptions = { "lr", "tb", }
            for i, option in ipairs(comboOptions) do
                local isSelected = (settings.fillGradientDir == option)
                if ImGui.Selectable(option, isSelected) then
                    settings.fillGradientDir = option
                end
            end
            ImGui.EndCombo()
        end
    end
    settings.tweenSeconds = ImGui.SliderFloat("Tween Seconds", settings.tweenSeconds, 0.0, 5.0)

    settings.overlayOn = ImGui.Checkbox("Overlay Image", settings.overlayOn)
    settings.overlayStatic = ImGui.Checkbox("Overlay Static", settings.overlayStatic)

    if ImGui.Button("Revert") then
        for k, v in pairs(revert[barLabel].defaults) do
            settings[k] = v
        end
        if barLabel:find("Health") then
            Colors.HPMin = revert[barLabel].colorMin
            Colors.HPMax = revert[barLabel].colorMax
        elseif barLabel:find("Mana") then
            Colors.ManaMin = revert[barLabel].colorMin
            Colors.ManaMax = revert[barLabel].colorMax
        elseif barLabel:find("Endurance") then
            Colors.EndurMin = revert[barLabel].colorMin
            Colors.EndurMax = revert[barLabel].colorMax
        else
            barLabel:find("Exp")
            Colors.XPMin = revert[barLabel].colorMin
            Colors.XPMax = revert[barLabel].colorMax
        end

        ImGui.CloseCurrentPopup()
    end

    ImGui.SameLine()
    if ImGui.Button("Close") then
        ImGui.CloseCurrentPopup()
    end
    ImGui.EndPopup()
end

function RenderUI()
    ImGui.SetNextWindowSize(ImVec2(300, 120), ImGuiCond.FirstUseEver)
    local open, show = ImGui.Begin("Status Bars", true, ImGuiWindowFlags.NoCollapse)
    if not open then
        isRunning = false
    end

    if show then
        ImGui.Spacing()
        ImGui.TextWrapped("This is a demo of custom status bars using ImGui drawing and ImAnim tweens.")
        if ImGui.CollapsingHeader("Information") then
            ImGui.TextWrapped("You can customize each bar's appearance and behavior.")
            ImGui.Spacing()
            ImGui.TextWrapped(
                "The bar in this Demo will send all options to the draw function and expose them all in the config window. The exception to this is the No Optons bars at the bottom.")
            ImGui.TextWrapped("Some features include: gradient fills, animated shimmer highlights, glow effects, tick marks, transparent overlay support, and more.")
            ImGui.Spacing()
            ImGui.TextWrapped("Hover over a bar to see its current value.")
            ImGui.TextWrapped("Right Click a Bar to change That Bars Options")
            ImGui.Spacing()
            ImGui.TextWrapped("You can include the progressBars.lua file in your own projects to use the StatusBar.Draw and StatusBar.DrawV functions with these options.")
        end

        if ImGui.CollapsingHeader("Horizontal Bars") then
            maxWidth = math.floor(ImGui.GetContentRegionAvail())
            if _barOpts["Health"] == nil then
                _barOpts["Health"] = shallowCopy(ProgressOptions)
                _barOpts["Health"].overlay = overlayTexture_hor
                _barOpts["Health"].lowCol = Colors.HPMin
                _barOpts["Health"].highCol = Colors.HPMax
                _barOpts["Health"].fillGradient = false
                _barOpts["Health"].height = 20
            end
            StatusBar.DrawProgress("Health", MyData.PctHps, _barOpts["Health"].lowCol, _barOpts["Health"].highCol, _barOpts["Health"])

            if ImGui.BeginPopupContextItem("Health") then
                DrawContextMenu(_barOpts["Health"], "Health")
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("HP: %s / %s", MyData.HpCur, MyData.HpMax)
            end

            if _barOpts["Mana"] == nil then
                _barOpts["Mana"] = shallowCopy(ProgressOptions)
                _barOpts["Mana"].overlay = overlayTexture_hor
                _barOpts["Mana"].lowCol = Colors.ManaMin
                _barOpts["Mana"].highCol = Colors.ManaMax
                _barOpts["Mana"].fillGradient = true
                _barOpts["Mana"].fillGradientMode = "static"
                _barOpts["Mana"].height = 20
            end
            StatusBar.DrawProgress("Mana", MyData.PctMana, _barOpts["Mana"].lowCol, _barOpts["Mana"].highCol, _barOpts["Mana"])

            if ImGui.BeginPopupContextItem("Mana") then
                DrawContextMenu(_barOpts["Mana"], "Mana")
            end

            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Mana: %s / %s", MyData.ManaCur, MyData.ManaMax)
            end

            if _barOpts["Endurance"] == nil then
                _barOpts["Endurance"] = shallowCopy(ProgressOptions)
                _barOpts["Endurance"].overlay = overlayTexture_hor
                _barOpts["Endurance"].lowCol = Colors.EndurMin
                _barOpts["Endurance"].highCol = Colors.EndurMax
                _barOpts["Endurance"].fillGradient = true
                _barOpts["Endurance"].fillGradientMode = "dynamic"
                _barOpts["Endurance"].height = 20
            end
            StatusBar.DrawProgress("Endurance", MyData.PctEnd, _barOpts["Endurance"].lowCol, _barOpts["Endurance"].highCol, _barOpts["Endurance"])
            if ImGui.BeginPopupContextItem("Endurance") then
                DrawContextMenu(_barOpts["Endurance"], "Endurance")
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Endurance: %s / %s", MyData.EnduranceCur, MyData.EnduranceMax)
            end

            ImGui.Separator()

            if _barOpts["Experience"] == nil then
                _barOpts["Experience"] = shallowCopy(ProgressOptions)
                _barOpts["Experience"].length = expBarLength
                _barOpts["Experience"].border = true
                _barOpts["Experience"].borderThickness = 1
                _barOpts["Experience"].borderColor = Colors.borders
                _barOpts["Experience"].borderConColor = false
                _barOpts["Experience"].showText = true
                _barOpts["Experience"].textFmt = "EXP: %.1f%%"
                _barOpts["Experience"].tickEvery = 0.10
                _barOpts["Experience"].fillGradient = true
                _barOpts["Experience"].fillGradientMode = "static"
                _barOpts["Experience"].fillGradientDir = "lr"
                _barOpts["Experience"].showTicks = true
                _barOpts["Experience"].tickThickness = 1.0
                _barOpts["Experience"].overlay = overlayTexture_hor
                _barOpts["Experience"].lowCol = Colors.XPMin
                _barOpts["Experience"].highCol = Colors.XPMax
            end
            StatusBar.DrawProgress(
                "Experience",
                MyData.PctExp,
                _barOpts["Experience"].lowCol,
                _barOpts["Experience"].highCol,
                _barOpts["Experience"]
            )
            if ImGui.BeginPopupContextItem("Experience") then
                DrawContextMenu(_barOpts["Experience"], "Experience")
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("EXP: %.1f%%", MyData.PctExp or 0)
            end

            ImGui.Separator()
            -- if mq.TLO.Target() then
            if targetOpts.borderConColor then
                targetOpts.borderColor = TargetData.ConColor
            end
            targetOpts.textFmt = string.format("%s: ", TargetData.Name) .. "%.1f%%"
            ImGui.Text(TargetData.Name)
            if targetOpts.overlay == nil then
                targetOpts.overlay = overlayTexture_hor
            end
            if _barOpts["TargetHealth"] == nil then
                _barOpts["TargetHealth"] = targetOpts
                _barOpts["TargetHealth"].lowCol = Colors.HPMin
                _barOpts["TargetHealth"].highCol = Colors.HPMax
                _barOpts["TargetHealth"].borderConColor = true
                _barOpts["TargetHealth"].height = 30
                _barOpts["TargetHealth"].showText = true
                _barOpts["TargetHealth"].fillGradient = true
                _barOpts["TargetHealth"].fillGradientMode = "dynamic"
                _barOpts["TargetHealth"].shimmer = true
                _barOpts["TargetHealth"].shimmerFollows = true
            end
            _barOpts["TargetHealth"].borderColor = _barOpts["TargetHealth"].borderConColor and TargetData.ConColor or _barOpts["TargetHealth"].borderColor
            StatusBar.DrawProgress(
                "TargetHealth",
                mq.TLO.Target.PctHPs() or 0,
                _barOpts["TargetHealth"].lowCol,
                _barOpts["TargetHealth"].highCol,
                _barOpts["TargetHealth"]
            )
            if ImGui.BeginPopupContextItem("TargetHealth") then
                DrawContextMenu(_barOpts["TargetHealth"], "TargetHealth")
            end
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("HP: %.1f%%", mq.TLO.Target.PctHPs() or 0)
            end
            -- end
        end

        if ImGui.CollapsingHeader("Vertical Bars") then
            _, maxHeight = ImGui.GetContentRegionAvail()
            maxHeight = math.floor(maxHeight)
            if ImGui.BeginTable("VerticalStatus", 5, bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.SizingFixedFit)) then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()

                ImGui.Text("HP")
                if _barOpts["HealthV"] == nil then
                    _barOpts["HealthV"] = shallowCopy(verticalOpts)
                    _barOpts["HealthV"].lowCol = Colors.HPMin
                    _barOpts["HealthV"].highCol = Colors.HPMax
                end
                StatusBar.DrawProgressVert("HealthV", MyData.PctHps, _barOpts["HealthV"].lowCol, _barOpts["HealthV"].highCol,
                    _barOpts["HealthV"])

                if ImGui.BeginPopupContextItem("HealthV") then
                    DrawContextMenu(_barOpts["HealthV"], "HealthV")
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%s / %s", MyData.HpCur, MyData.HpMax)
                end

                ImGui.TableNextColumn()

                ImGui.Text("MP")
                if _barOpts["ManaV"] == nil then
                    _barOpts["ManaV"] = shallowCopy(verticalOpts)
                    _barOpts["ManaV"].lowCol = Colors.ManaMin
                    _barOpts["ManaV"].highCol = Colors.ManaMax
                end
                StatusBar.DrawProgressVert("ManaV", MyData.PctMana, _barOpts["ManaV"].lowCol, _barOpts["ManaV"].highCol,
                    _barOpts["ManaV"])
                if ImGui.BeginPopupContextItem("ManaV") then
                    DrawContextMenu(_barOpts["ManaV"], "ManaV")
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%s / %s", MyData.ManaCur, MyData.ManaMax)
                end

                ImGui.TableNextColumn()

                ImGui.Text("End")
                if _barOpts["EnduranceV"] == nil then
                    _barOpts["EnduranceV"] = shallowCopy(verticalOpts)
                    _barOpts["EnduranceV"].lowCol = Colors.EndurMin
                    _barOpts["EnduranceV"].highCol = Colors.EndurMax
                end
                StatusBar.DrawProgressVert("EnduranceV", MyData.PctEnd, _barOpts["EnduranceV"].lowCol, _barOpts["EnduranceV"].highCol,
                    _barOpts["EnduranceV"])
                if ImGui.BeginPopupContextItem("EnduranceV") then
                    DrawContextMenu(_barOpts["EnduranceV"], "EnduranceV")
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%s / %s", MyData.EnduranceCur, MyData.EnduranceMax)
                end

                ImGui.TableNextColumn()

                ImGui.Indent(5)
                ImGui.Text("EXP")
                ImGui.Unindent(5)
                if _barOpts["ExperienceV"] == nil then
                    _barOpts["ExperienceV"] = shallowCopy(verticalOpts)
                    _barOpts["ExperienceV"].width = 50
                    _barOpts["ExperienceV"].height = 120
                    _barOpts["ExperienceV"].rounding = 6
                    _barOpts["ExperienceV"].showText = false
                    _barOpts["ExperienceV"].fillGradient = true
                    _barOpts["ExperienceV"].fillGradientDir = "tb"
                    _barOpts["ExperienceV"].fillGradientMode = "dynamic"
                    _barOpts["ExperienceV"].shimmer = true
                    _barOpts["ExperienceV"].shimmerSpeed = 0.5
                    _barOpts["ExperienceV"].shimmerWidth = 50
                    _barOpts["ExperienceV"].shimmerDeadzone = 0.01
                    _barOpts["ExperienceV"].shimmerFollows = true
                    _barOpts["ExperienceV"].showTicks = false
                    _barOpts["ExperienceV"].tickThickness = 1.0
                    _barOpts["ExperienceV"].tickHeight = 1.0
                    _barOpts["ExperienceV"].tickEvery = 0.20
                    _barOpts["ExperienceV"].tickAlpha = 100
                    _barOpts["ExperienceV"].tweenSeconds = 0.35
                    _barOpts["ExperienceV"].border = true
                    _barOpts["ExperienceV"].borderThickness = 1
                    _barOpts["ExperienceV"].borderColor = Colors.borders
                    _barOpts["ExperienceV"].lowCol = Colors.XPMin
                    _barOpts["ExperienceV"].highCol = Colors.XPMax
                end

                StatusBar.DrawProgressVert(
                    "ExperienceV",
                    MyData.PctExp, _barOpts["ExperienceV"].lowCol,
                    _barOpts["ExperienceV"].highCol,
                    _barOpts["ExperienceV"]
                )

                if ImGui.BeginPopupContextItem("ExperienceV") then
                    DrawContextMenu(_barOpts["ExperienceV"], "ExperienceV")
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%.1f%%", MyData.PctExp or 0)
                end

                ImGui.TableNextColumn()

                ImGui.Text("%s", TargetData.Name)

                if _barOpts["TargetHealthV"] == nil then
                    _barOpts["TargetHealthV"] = shallowCopy(verticalOpts)
                    _barOpts["TargetHealthV"].height = 120
                    _barOpts["TargetHealthV"].width = 45
                    _barOpts["TargetHealthV"].borderConColor = true
                    _barOpts["TargetHealthV"].lowCol = Colors.HPMin
                    _barOpts["TargetHealthV"].highCol = Colors.HPMax
                end
                _barOpts["TargetHealthV"].border = true
                _barOpts["TargetHealthV"].borderColor = _barOpts["TargetHealthV"].borderConColor and TargetData.ConColor or _barOpts["TargetHealthV"].borderColor
                _barOpts["TargetHealthV"].lowCol = _barOpts["TargetHealthV"].lowCol or Colors.HPMin
                _barOpts["TargetHealthV"].highCol = _barOpts["TargetHealthV"].highCol or Colors.HPMax

                StatusBar.DrawProgressVert(
                    "TargetHealthV",
                    mq.TLO.Target.PctHPs() or 0,
                    _barOpts["TargetHealthV"].lowCol,
                    _barOpts["TargetHealthV"].highCol,
                    _barOpts["TargetHealthV"]
                )

                if ImGui.BeginPopupContextItem("TargetHealthV") then
                    DrawContextMenu(_barOpts["TargetHealthV"], "TargetHealthV")
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%.1f%%", mq.TLO.Target.PctHPs() or 0)
                end

                ImGui.EndTable()
            end
        end

        if ImGui.CollapsingHeader("Generic No Options") then
            ImGui.TextWrapped("This uses all the default options. It will use the ImGuiStyle Color for PlotHistogram (progress bars) when no color is supplied..")
            ImGui.Spacing()
            local barValue = { Health = MyData.PctHps, Mana = MyData.PctMana, Endurance = MyData.PctEnd, Experience = MyData.PctExp, TargetHealth = mq.TLO.Target.PctHPs() or 0, }

            if ImGui.BeginCombo("Select Bar Type", tempBarTpye) then
                local comboOptions = { "Health", "Mana", "Endurance", "Experience", "TargetHealth", }
                for i, option in ipairs(comboOptions) do
                    local isSelected = (tempBarTpye == option)
                    if ImGui.Selectable(option, isSelected) then
                        tempBarTpye = option
                    end
                end
                ImGui.EndCombo()
            end
            StatusBar.DrawProgress("NoOptions", barValue[tempBarTpye])
        end
    end
    ImGui.End()
end

function Init()
    isRunning = true
    MyData = GetMyData()
    TargetData = GetTargetData()
    mq.delay(10)
    if imagesPath == nil then
        -- get last PID
        local lastPID = mq.TLO.Lua.PIDs():match("(%d+)$")
        local scriptFolder = mq.TLO.Lua.Script(lastPID).Name()
        imagesPath = string.format("%s/%s/images/", mq.luaDir, scriptFolder)
    end
    overlayTexture_hor = loadOverlay("hp_hor.png")
    overlayTexture_vert = loadOverlay("hp_vert.png")
    ProgressOptions.overlay = overlayTexture_hor

    targetOpts = shallowCopy(ProgressOptions)
    targetOpts.textFmt = string.format("%s: ", TargetData and TargetData.Name or "Target") .. "%.1f%%"
    targetOpts.borderColor = TargetData.ConColor ~= nil and TargetData.ConColor or Colors.borders
    targetOpts.borderConColor = true

    verticalOpts = shallowCopy(ProgressOptions)
    verticalOpts.width = 25
    verticalOpts.height = 120
    verticalOpts.fillGradientDir = "tb"
    verticalOpts.overlay = overlayTexture_vert

    mq.imgui.init("test##bars", RenderUI)
end

function Main()
    while isRunning do
        mq.delay(10)
        if (mq.gettime() - timeLastRefresh) > 100 then
            MyData = GetMyData()
            timeLastRefresh = mq.gettime()
        end
        TargetData = (mq.TLO.Target() ~= nil) and GetTargetData() or {
            Name = "No Target",
            HpPct = 0,
            ConColor = getConColor('GREY'),
        }
    end
end

Init()
Main()

return StatusBar
