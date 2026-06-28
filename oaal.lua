--[[
    Дельта Чит: Режим полёта "Invincible" (Марк Грейсон)
    Версия: 1.0.0 | Цель: Android (GameGuardian API)
    Архитектура: Lua 5.3+ с gg API, сетевой синхронизацией и полным циклом управления
    Единый исполняемый блок — копировать и вставить целиком в GameGuardian
--]]

-- ====================== ОСНОВНОЙ МОДУЛЬ ======================
local DeltaFly = {
    Active = false, Phase = 0, LocalPlayer = nil, PlayerPed = nil,
    BaseHeight = 5.0, CurrentHeight = 0.0, TargetHeight = 5.0,
    FlySpeed = 15.0, DashMultiplier = 3.5, LerpFactor = 0.15, VerticalLerpFactor = 0.08,
    HoverStartTime = 0.0, HoverStartDuration = 0.8, HoverStartProgress = 0.0,
    Velocity = {x = 0.0, y = 0.0, z = 0.0},
    InputVector = {x = 0.0, y = 0.0, z = 0.0},
    BoneOffsets = {}, DefaultBonePositions = {},
    GuiElements = {}, GuiVisible = true,
    NetSyncEnabled = true, ForceModelUpdateTick = 0, ForceModelUpdateInterval = 2,
    MotionBlurActive = false, NoclipActive = false,
    FrameTimer = 0, LastFrameTime = 0.0, DeltaTime = 0.0,
    ProtectedMode = true, ErrorCount = 0, MaxErrors = 5
}

local function SafeCall(func, ...)
    if not DeltaFly.ProtectedMode then return func(...) end
    local s, r = pcall(func, ...)
    if not s then
        DeltaFly.ErrorCount = DeltaFly.ErrorCount + 1
        if DeltaFly.ErrorCount >= DeltaFly.MaxErrors then
            DeltaFly.Active = false; DeltaFly.Phase = 0
            DeltaFly:_cleanupEffects()
            gg.toast("Дельта Чит: Превышен лимит ошибок")
        end
        return nil
    end
    return r
end

local function GetCurrentTime() return os.clock() * 1000 end
local function Clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function Lerp(a, b, t) return a + (b - a) * Clamp(t, 0.0, 1.0) end
local function Vector3Lerp(v1, v2, t) return {x = Lerp(v1.x, v2.x, t), y = Lerp(v1.y, v2.y, t), z = Lerp(v1.z, v2.z, t)} end

function DeltaFly:Init()
    gg.toast("Дельта Чит v1.0: Инициализация")
    self.LocalPlayer = self:_findLocalPlayer()
    if not self.LocalPlayer then gg.alert("Ошибка: Локальный игрок не найден"); return false end
    self.PlayerPed = self:_getPlayerPed(self.LocalPlayer)
    if not self.PlayerPed then gg.alert("Ошибка: Ped не получен"); return false end
    self:_cacheDefaultBonePositions()
    self:_initGUI()
    self.Active = true
    self.LastFrameTime = GetCurrentTime()
    self.FrameTimer = 0
    gg.toast("Дельта Чит: Готов. [ВЗЛЕТ] для активации")
    return true
end

function DeltaFly:_findLocalPlayer()
    local results = gg.getResults(gg.getResultsCount())
    for _, v in ipairs(results) do
        if v.address and v.address > 0x10000000 then
            local playerPtr = gg.getValues({{address = v.address, flags = gg.TYPE_DWORD}})[1].value
            if playerPtr and playerPtr > 0x10000000 then
                local healthCheck = gg.getValues({{address = playerPtr + 0x280, flags = gg.TYPE_FLOAT}})[1].value
                if healthCheck and healthCheck > 0 and healthCheck <= 1000 then return playerPtr end
            end
        end
    end
    local sig = gg.searchNumber("100;0;0;0:9", gg.TYPE_FLOAT, false, gg.SIGN_EQUAL, 0, 0xFFFFFFFF)
    if sig and #sig > 0 then return sig[1].address - 0x100 end
    return nil
end

function DeltaFly:_getPlayerPed(pptr)
    if not pptr then return nil end
    local pedPtr = gg.getValues({{address = pptr + 0x1A8, flags = gg.TYPE_DWORD}})[1].value
    if pedPtr and pedPtr > 0x10000000 then
        local px = gg.getValues({{address = pedPtr + 0x30, flags = gg.TYPE_FLOAT}})[1].value
        if px and px > -100000 and px < 100000 then return pedPtr end
    end
    return nil
end

function DeltaFly:_cacheDefaultBonePositions()
    if not self.PlayerPed then return end
    local bids = {0x0E40, 0x0E4F, 0x0E50, 0x0E51, 0x0E4C, 0x0E4D, 0x0E4E, 0x0E57, 0x0E58, 0x0E54, 0x0E55}
    self.DefaultBonePositions = {}; self.BoneOffsets = {}
    for _, bid in ipairs(bids) do
        local bp = self:_getBoneWorldPosition(bid)
        if bp then self.DefaultBonePositions[bid] = bp; self.BoneOffsets[bid] = {x=0,y=0,z=0} end
    end
end

function DeltaFly:_getBoneWorldPosition(bid)
    if not self.PlayerPed then return nil end
    local skel = gg.getValues({{address = self.PlayerPed + 0x20, flags = gg.TYPE_DWORD}})[1].value
    if not skel then return nil end
    local bmat = gg.getValues({{address = skel + 0x50, flags = gg.TYPE_DWORD}})[1].value
    if not bmat then return nil end
    local boff = bmat + (bid * 0x40)
    local px = gg.getValues({{address = boff + 0x30, flags = gg.TYPE_FLOAT}})[1].value
    local py = gg.getValues({{address = boff + 0x34, flags = gg.TYPE_FLOAT}})[1].value
    local pz = gg.getValues({{address = boff + 0x38, flags = gg.TYPE_FLOAT}})[1].value
    if px and py and pz then return {x=px, y=py, z=pz} end
    return nil
end

function DeltaFly:_setBoneOffset(bid, ox, oy, oz)
    if not self.PlayerPed then return end
    local skel = gg.getValues({{address = self.PlayerPed + 0x20, flags = gg.TYPE_DWORD}})[1].value
    if not skel then return end
    local bmat = gg.getValues({{address = skel + 0x50, flags = gg.TYPE_DWORD}})[1].value
    if not bmat then return end
    local boff = bmat + (bid * 0x40)
    gg.setValues({
        {address = boff + 0x30, flags = gg.TYPE_FLOAT, value = ox},
        {address = boff + 0x34, flags = gg.TYPE_FLOAT, value = oy},
        {address = boff + 0x38, flags = gg.TYPE_FLOAT, value = oz}
    })
    if self.BoneOffsets[bid] then self.BoneOffsets[bid] = {x=ox, y=oy, z=oz} end
end

function DeltaFly:_activatePhase1()
    if self.Phase == 1 then return end
    self.Phase = 1; self.HoverStartTime = GetCurrentTime(); self.HoverStartProgress = 0.0
    self.TargetHeight = self.BaseHeight
    local cp = self:_getPlayerPosition()
    if cp then self.CurrentHeight = cp.y end
    gg.toast("Дельта Чит: Фаза 1 — Взлёт")
end

function DeltaFly:_processPhase1(dt)
    if self.Phase ~= 1 then return end
    local elapsed = (GetCurrentTime() - self.HoverStartTime) / 1000.0
    self.HoverStartProgress = Clamp(elapsed / self.HoverStartDuration, 0.0, 1.0)
    self:_animateHoverStart(self.HoverStartProgress)
    local ho = Lerp(0.0, 2.5, self.HoverStartProgress)
    local tgtY = self.TargetHeight + ho * (1.0 - self.HoverStartProgress)
    self:_setPlayerPosition(nil, tgtY, nil)
    if self.HoverStartProgress >= 1.0 then self:_processHovering(dt) end
end

function DeltaFly:_animateHoverStart(prog)
    local rtb = self.DefaultBonePositions[0x0E57]; local ltb = self.DefaultBonePositions[0x0E54]
    if rtb and ltb then
        local mo = Lerp(0.0, 0.25, prog)
        self:_setBoneOffset(0x0E57, rtb.x - mo, rtb.y, rtb.z)
        self:_setBoneOffset(0x0E54, ltb.x + mo, ltb.y, ltb.z)
        local rcb = self.DefaultBonePositions[0x0E58]; local lcb = self.DefaultBonePositions[0x0E55]
        if rcb and lcb then
            self:_setBoneOffset(0x0E58, rcb.x - mo, rcb.y, rcb.z)
            self:_setBoneOffset(0x0E55, lcb.x + mo, lcb.y, lcb.z)
        end
    end
    local rab = self.DefaultBonePositions[0x0E4F]; local lab = self.DefaultBonePositions[0x0E4C]
    if rab and lab then
        local ado = Lerp(0.0, 0.35, prog); local aio = Lerp(0.0, 0.15, prog)
        self:_setBoneOffset(0x0E4F, rab.x + aio, rab.y - ado, rab.z)
        self:_setBoneOffset(0x0E50, self.DefaultBonePositions[0x0E50].x + aio, self.DefaultBonePositions[0x0E50].y - ado*1.2, self.DefaultBonePositions[0x0E50].z)
        local fc = Lerp(0.0, 0.05, prog)
        self:_setBoneOffset(0x0E51, self.DefaultBonePositions[0x0E51].x + aio + fc, self.DefaultBonePositions[0x0E51].y - ado*1.4, self.DefaultBonePositions[0x0E51].z)
        self:_setBoneOffset(0x0E4C, lab.x - aio, lab.y - ado, lab.z)
        self:_setBoneOffset(0x0E4D, self.DefaultBonePositions[0x0E4D].x - aio, self.DefaultBonePositions[0x0E4D].y - ado*1.2, self.DefaultBonePositions[0x0E4D].z)
        self:_setBoneOffset(0x0E4E, self.DefaultBonePositions[0x0E4E].x - aio - fc, self.DefaultBonePositions[0x0E4E].y - ado*1.4, self.DefaultBonePositions[0x0E4E].z)
    end
    local sb = self.DefaultBonePositions[0x0E40]
    if sb then
        local so = Lerp(0.0, 0.12, prog)
        self:_setBoneOffset(0x0E40, sb.x, sb.y + so, sb.z)
    end
end

function DeltaFly:_processHovering(dt)
    local ix = self.InputVector.x * self.FlySpeed * dt
    local iz = self.InputVector.z * self.FlySpeed * dt
    local cp = self:_getPlayerPosition()
    if cp then self:_setPlayerPosition(cp.x + ix, self.TargetHeight, cp.z + iz) end
end

function DeltaFly:_activatePhase2()
    if self.Phase ~= 1 then return end
    self.Phase = 2; self.MotionBlurActive = true
    self:_enableMotionBlur(true)
    gg.toast("Дельта Чит: Фаза 2 — Ускорение!")
end

function DeltaFly:_deactivatePhase2()
    if self.Phase ~= 2 then return end
    self.Phase = 1; self.MotionBlurActive = false
    self:_enableMotionBlur(false)
    gg.toast("Дельта Чит: Возврат в фазу 1")
end

function DeltaFly:_processPhase2(dt)
    if self.Phase ~= 2 then return end
    self:_animateDynamicDash()
    local cf = self:_getCameraForward()
    if cf then
        local ds = self.FlySpeed * self.DashMultiplier
        self.Velocity.x = cf.x * ds; self.Velocity.y = 0.0; self.Velocity.z = cf.z * ds
        local cp = self:_getPlayerPosition()
        if cp then
            local nx = cp.x + self.Velocity.x * dt
            local ny = Lerp(cp.y, self.TargetHeight, self.VerticalLerpFactor * 2.0)
            local nz = cp.z + self.Velocity.z * dt
            self:_setPlayerPosition(nx, ny, nz)
        end
    end
end

function DeltaFly:_animateDynamicDash()
    local rab = self.DefaultBonePositions[0x0E4F]
    if rab then
        self:_setBoneOffset(0x0E4F, rab.x + 0.45, rab.y + 0.60, rab.z + 0.15)
        local fob = self.DefaultBonePositions[0x0E50]
        if fob then self:_setBoneOffset(0x0E50, fob.x + 0.55, fob.y + 0.80, fob.z + 0.25) end
        local hab = self.DefaultBonePositions[0x0E51]
        if hab then self:_setBoneOffset(0x0E51, hab.x + 0.65, hab.y + 0.95, hab.z + 0.35) end
    end
    local lab = self.DefaultBonePositions[0x0E4C]
    if lab then
        self:_setBoneOffset(0x0E4C, lab.x - 0.10, lab.y + 0.15, lab.z + 0.20)
        local lfb = self.DefaultBonePositions[0x0E4D]
        if lfb then self:_setBoneOffset(0x0E4D, lfb.x - 0.05, lfb.y + 0.30, lfb.z + 0.35) end
        local lhb = self.DefaultBonePositions[0x0E4E]
        if lhb then self:_setBoneOffset(0x0E4E, lhb.x - 0.08, lhb.y + 0.35, lhb.z + 0.40) end
    end
    local rtb = self.DefaultBonePositions[0x0E57]
    if rtb then
        self:_setBoneOffset(0x0E57, rtb.x, rtb.y - 0.15, rtb.z - 0.50)
        local rcb = self.DefaultBonePositions[0x0E58]
        if rcb then self:_setBoneOffset(0x0E58, rcb.x, rcb.y - 0.25, rcb.z - 0.70) end
    end
    local ltb = self.DefaultBonePositions[0x0E54]
    if ltb then
        self:_setBoneOffset(0x0E54, ltb.x, ltb.y - 0.15, ltb.z - 0.50)
        local lcb = self.DefaultBonePositions[0x0E55]
        if lcb then self:_setBoneOffset(0x0E55, lcb.x, lcb.y - 0.25, lcb.z - 0.70) end
    end
    local sb = self.DefaultBonePositions[0x0E40]
    if sb then self:_setBoneOffset(0x0E40, sb.x + 0.25, sb.y + 0.10, sb.z + 0.30) end
end

function DeltaFly:_getPlayerPosition()
    if not self.PlayerPed then return nil end
    local px = gg.getValues({{address = self.PlayerPed + 0x30, flags = gg.TYPE_FLOAT}})[1].value
    local py = gg.getValues({{address = self.PlayerPed + 0x34, flags = gg.TYPE_FLOAT}})[1].value
    local pz = gg.getValues({{address = self.PlayerPed + 0x38, flags = gg.TYPE_FLOAT}})[1].value
    if px and py and pz then return {x = px, y = py, z = pz} end
    return nil
end

function DeltaFly:_setPlayerPosition(x, y, z)
    if not self.PlayerPed then return end
    local cp = self:_getPlayerPosition()
    if not cp then return end
    local nx = x or cp.x; local ny = y or cp.y; local nz = z or cp.z
    gg.setValues({
        {address = self.PlayerPed + 0x30, flags = gg.TYPE_FLOAT, value = nx},
        {address = self.PlayerPed + 0x34, flags = gg.TYPE_FLOAT, value = ny},
        {address = self.PlayerPed + 0x38, flags = gg.TYPE_FLOAT, value = nz}
    })
    if self.NetSyncEnabled then self:_syncVelocity() end
end

function DeltaFly:_syncVelocity()
    if not self.PlayerPed then return end
    gg.setValues({
        {address = self.PlayerPed + 0x320, flags = gg.TYPE_FLOAT, value = self.Velocity.x},
        {address = self.PlayerPed + 0x324, flags = gg.TYPE_FLOAT, value = self.Velocity.y},
        {address = self.PlayerPed + 0x328, flags = gg.TYPE_FLOAT, value = self.Velocity.z}
    })
end

function DeltaFly:_getCameraForward()
    local cptr = gg.getValues({{address = 0x1EB4A20, flags = gg.TYPE_DWORD}})[1].value
    if not cptr then return nil end
    local fx = -gg.getValues({{address = cptr + 0x20, flags = gg.TYPE_FLOAT}})[1].value
    local fy = -gg.getValues({{address = cptr + 0x24, flags = gg.TYPE_FLOAT}})[1].value
    local fz = -gg.getValues({{address = cptr + 0x28, flags = gg.TYPE_FLOAT}})[1].value
    local len = math.sqrt(fx*fx + fy*fy + fz*fz)
    if len > 0 then return {x = fx/len, y = fy/len, z = fz/len} end
    return nil
end

function DeltaFly:_enableMotionBlur(enable)
    local gptr = gg.getValues({{address = 0x1EB4B50, flags = gg.TYPE_DWORD}})[1].value
    if gptr then gg.setValues({{address = gptr + 0x1A4, flags = gg.TYPE_DWORD, value = enable and 1 or 0}}) end
    if enable then self:_setParticleState(2.0) else self:_setParticleState(1.0) end
end

function DeltaFly:_setParticleState(sm)
    local pptr = gg.getValues({{address = 0x1EB4C00, flags = gg.TYPE_DWORD}})[1].value
    if pptr then gg.setValues({{address = pptr + 0xF0, flags = gg.TYPE_FLOAT, value = sm}}) end
end

function DeltaFly:_enableNoclip(enable)
    if not self.PlayerPed then return end
    local nf = enable and 0x2000 or 0x0
    local cf = gg.getValues({{address = self.PlayerPed + 0x1E0, flags = gg.TYPE_DWORD}})[1].value
    if cf then
        local nv = enable and (cf | nf) or (cf & ~nf)
        gg.setValues({{address = self.PlayerPed + 0x1E0, flags = gg.TYPE_DWORD, value = nv}})
        self.NoclipActive = enable
    end
end

function DeltaFly:_cleanupEffects()
    if self.MotionBlurActive then self:_enableMotionBlur(false); self.MotionBlurActive = false end
    if self.NoclipActive then self:_enableNoclip(false); self.NoclipActive = false end
end

function DeltaFly:_forceModelUpdate()
    if not self.PlayerPed then return end
    self.ForceModelUpdateTick = self.ForceModelUpdateTick + 1
    if self.ForceModelUpdateTick >= self.ForceModelUpdateInterval then
        self.ForceModelUpdateTick = 0
        local nsptr = gg.getValues({{address = self.PlayerPed + 0x3B0, flags = gg.TYPE_DWORD}})[1].value
        if nsptr then
            local pos = self:_getPlayerPosition()
            if pos then
                gg.setValues({
                    {address = nsptr + 0x40, flags = gg.TYPE_DWORD, value = 1},
                    {address = nsptr + 0x44, flags = gg.TYPE_FLOAT, value = pos.x},
                    {address = nsptr + 0x48, flags = gg.TYPE_FLOAT, value = pos.y},
                    {address = nsptr + 0x4C, flags = gg.TYPE_FLOAT, value = pos.z}
                })
            end
        end
        gg.setValues({{address = 0x5A3B20, flags = gg.TYPE_DWORD, value = 1}})
    end
end

function DeltaFly:_initGUI()
    self.GuiElements = {}
    table.insert(self.GuiElements, {
        type = "menu", name = "Delta Fly Menu",
        items = {
            {type = "toggle", name = "[ВЗЛЕТ]", callback = function(v)
                if v then SafeCall(DeltaFly._activatePhase1, DeltaFly)
                else DeltaFly.Phase = 0; DeltaFly:_cleanupEffects(); DeltaFly:_resetBonePositions(); SafeCall(DeltaFly._enableNoclip, DeltaFly, false); gg.toast("Полёт отключен") end
            end},
            {type = "button", name = "[УСКОРЕНИЕ] (Hold)", callback = function() SafeCall(DeltaFly._activatePhase2, DeltaFly) end, releaseCallback = function() SafeCall(DeltaFly._deactivatePhase2, DeltaFly) end},
            {type = "slider", name = "[ВЫСОТА]", min = 1, max = 50, current = self.BaseHeight, callback = function(v) DeltaFly.BaseHeight = v; if DeltaFly.Phase >= 1 then DeltaFly.TargetHeight = v end end}
        }
    })
    self.GuiVisible = true; self:_drawGUI()
end

function DeltaFly:_drawGUI()
    if not self.GuiVisible then return end
    local mi = "══════ Дельта Чит v1.0 ══════\nРежим: " .. (self.Phase==0 and "ВЫКЛ" or self.Phase==1 and "ПАРЕНИЕ" or "УСКОРЕНИЕ") .. "\nВысота: " .. string.format("%.1f", self.TargetHeight) .. "м\nСкорость: " .. string.format("%.0f", self.Phase==2 and self.FlySpeed*self.DashMultiplier or self.FlySpeed) .. "\n════════════════════════════"
    gg.alert(mi)
end

function DeltaFly:_resetBonePositions()
    for bid, dp in pairs(self.DefaultBonePositions) do self:_setBoneOffset(bid, dp.x, dp.y, dp.z) end
    self.BoneOffsets = {}
end

function DeltaFly:Update()
    if not self.Active then return end
    if not self.LocalPlayer then self:_cleanupEffects(); self.Active = false; return end
    self.PlayerPed = self:_getPlayerPed(self.LocalPlayer)
    if not self.PlayerPed then self:_cleanupEffects(); return end
    local ct = GetCurrentTime()
    self.DeltaTime = (ct - self.LastFrameTime) / 1000.0
    self.LastFrameTime = ct
    self.DeltaTime = Clamp(self.DeltaTime, 0.0, 0.1)
    if self.Phase >= 1 and not self.NoclipActive then SafeCall(self._enableNoclip, self, true) end
    if self.Phase == 1 then SafeCall(self._processPhase1, self, self.DeltaTime)
    elseif self.Phase == 2 then SafeCall(self._processPhase2, self, self.DeltaTime) end
    SafeCall(self._forceModelUpdate, self)
    self.FrameTimer = self.FrameTimer + 1
    if self.FrameTimer % 60 == 0 then SafeCall(self._drawGUI, self) end
end

function DeltaFly:Activate()
    if self:Init() then
        gg.setRanges(gg.REGION_ANONYMOUS); gg.clearResults()
        while self.Active do
            self:Update()
            if gg.isVisible(true) then gg.sleep(16) else break end
        end
        self:Deactivate()
    end
end

function DeltaFly:Deactivate()
    self.Active = false; self.Phase = 0
    self:_cleanupEffects(); self:_enableNoclip(false); self:_resetBonePositions()
    self.GuiVisible = false; self.GuiElements = {}
    gg.toast("Дельта Чит: Система полёта деактивирована")
end

local function onGameExit() DeltaFly:Deactivate() end
if gg.processKill then gg.processKill(onGameExit) end

-- ====================== ЗАПУСК ======================
local flyInstance = DeltaFly
SafeCall(flyInstance.Activate, flyInstance)
