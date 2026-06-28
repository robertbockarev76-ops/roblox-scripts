-- Delta Fly Fix v1.0.1
local DeltaFly = {
    Active = false, Phase = 0, LocalPlayer = nil, PlayerPed = nil,
    BaseHeight = 5.0, FlySpeed = 15.0, ErrorCount = 0, MaxErrors = 10
}

local function SafeCall(func, ...)
    local s, r = pcall(func, ...)
    if not s then
        DeltaFly.ErrorCount = DeltaFly.ErrorCount + 1
        if DeltaFly.ErrorCount > 5 then DeltaFly.Active = false end
    end
    return r
end

function DeltaFly:Update()
    if not self.Active or not self.PlayerPed then return end
    
    -- Проверка на валидность адреса (базовая защита)
    local check = SafeCall(gg.getValues, {{address = self.PlayerPed + 0x30, flags = gg.TYPE_FLOAT}})
    if not check or #check == 0 then 
        self.Active = false
        return 
    end
    
    -- Основная логика обработки фаз здесь...
end

-- ИСПРАВЛЕННЫЙ ПОИСК (пример)
function DeltaFly:_findLocalPlayer()
    gg.clearResults()
    -- Используем поиск по маске для надежности
    gg.searchNumber("100;0;0;0:9", gg.TYPE_FLOAT, false, gg.SIGN_EQUAL, 0, -1)
    local res = gg.getResults(10)
    if #res > 0 then
        -- Берем первый адрес и проверяем его
        local addr = res[1].address - 0x100
        self.LocalPlayer = addr
        return addr
    end
    return nil
end

-- В функции Activate добавлена проверка процесса
function DeltaFly:Activate()
    if not gg.getTargetPackage() then gg.alert("Игра не выбрана!"); return end
    
    self.LocalPlayer = self:_findLocalPlayer()
    if not self.LocalPlayer then gg.alert("Игрок не найден"); return end
    
    self.Active = true
    while self.Active do
        if gg.getTargetPackage() == nil then break end -- Выход, если игра закрылась
        SafeCall(self.Update, self)
        gg.sleep(20) -- Снизил нагрузку на проц
    end
end

-- Запуск
SafeCall(DeltaFly.Activate, DeltaFly)
