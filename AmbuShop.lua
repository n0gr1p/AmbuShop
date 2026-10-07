_addon.name = 'AmbuShop'
_addon.author = 'n0gr1p + OpenAI'
_addon.version = '0.1.0'
_addon.commands = {'ambs','ambushop'}

local packets = require('packets')
local res = require('resources')
local socket_ok, socket = pcall(require, 'socket')

local ZONE = 249
local NPC_NAME = 'Gorpa-Masorpa'
local MENU = 386
local MAX_DISTANCE = 6
local STACK_CAP = 99
local OPEN_TIMEOUT = 4.0
local RESULT_TIMEOUT = 5.0
local NEXT_DELAY = 0.35

-- Gorpa's Hallmark consumables are stable. Gallantry reward ordering can change
-- after monthly updates, so only entries we have explicitly verified are seeded.
-- Packet payload: _unknown1 = quantity * 256 + catalog index.
local CATALOG = {
    hallmarks = {
        ['tukuku whiteshell'] = {name='Tukuku Whiteshell', cost=20, index=0},
        ['lungo-nango jadeshell'] = {name='Lungo-Nango Jadeshell', cost=2000, index=1},
        ['ordelle bronzepiece'] = {name='Ordelle Bronzepiece', cost=20, index=2},
        ['montiont silverpiece'] = {name='Montiont Silverpiece', cost=2000, index=3},
        ['one byne bill'] = {name='One Byne Bill', cost=20, index=4},
        ['one hundred byne bill'] = {name='One Hundred Byne Bill', cost=2000, index=5},
        ['alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=6},
        ['piece of alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=6},
        ['heavy metal'] = {name='Heavy Metal', resource_name='Plate of Heavy Metal', cost=200, index=7},
        ['plate of heavy metal'] = {name='Heavy Metal', resource_name='Plate of Heavy Metal', cost=200, index=7},
        ['riftdross'] = {name='Riftdross', resource_name='Clump of Riftdross', cost=1500, index=8},
        ['riftcinder'] = {name='Riftcinder', resource_name='Pinch of Riftcinder', cost=1500, index=9},
        ['pluton'] = {name='Pluton', cost=50, index=10},
        ['beitetsu'] = {name='Beitetsu', cost=50, index=11},
        ['riftborn boulder'] = {name='Riftborn Boulder', cost=50, index=12},
        ['h-p bayld'] = {name='High-Purity Bayld', resource_name='Pinch of High-Purity Bayld', cost=35, index=13},
        ['high-purity bayld'] = {name='High-Purity Bayld', resource_name='Pinch of High-Purity Bayld', cost=35, index=13},
        ['umbral marrow'] = {name='Umbral Marrow', resource_name='Vial of Umbral Marrow', cost=30000, index=14},
        ['mulcibar scoria'] = {name="Mulcibar's Scoria", resource_name="Chunk of Mulcibar's Scoria", cost=30000, index=15},
    },
    gallantry = {
        -- Verified Alexandrite entry. Other Gallantry entries are intentionally
        -- omitted because that page is version-update dependent.
        ['alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=5},
        ['piece of alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=5},
    },
}

local PAGE = {
    hallmarks = {purchase_option=6, submenu_option=1, currency='hallmarks'},
    gallantry = {purchase_option=10, submenu_option=8, currency='gallantry'},
}

local FULL_ALEX = {
    {page='hallmarks', quantity=1750},
    {page='gallantry', quantity=450},
}

local s = {
    mode='idle',
    plan={},
    plan_index=0,
    txn=nil,
    npc_id=nil,
    npc_index=nil,
    menu=nil,
    deadline=nil,
    next_at=nil,
    start_count=0,
    expected_count=0,
    item_id=nil,
    item_name=nil,
    hallmarks=nil,
    gallantry=nil,
    last_raw={},
    dry_run=false,
}

local function now()
    if socket_ok and socket and socket.gettime then return socket.gettime() end
    return os.clock()
end

local function chat(msg, color)
    windower.add_to_chat(color or 207, '[AmbuShop] '..tostring(msg))
end

local function reset()
    s = {
        mode='idle', plan={}, plan_index=0, txn=nil,
        npc_id=nil, npc_index=nil, menu=nil, deadline=nil, next_at=nil,
        start_count=0, expected_count=0, item_id=nil, item_name=nil,
        hallmarks=nil, gallantry=nil, last_raw={}, dry_run=false,
    }
end

local function same_packet(id, data)
    if s.last_raw[id] == data then return true end
    s.last_raw[id] = data
    return false
end

local function distance(mob)
    local me = windower.ffxi.get_mob_by_target('me')
    if me and mob and me.x and me.y and mob.x and mob.y then
        local dx, dy = mob.x-me.x, mob.y-me.y
        return math.sqrt(dx*dx + dy*dy)
    end
    if mob and mob.distance and mob.distance >= 0 then
        return math.sqrt(mob.distance)
    end
end

local function get_gorpa()
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return nil, 'not logged in' end
    if tonumber(info.zone) ~= ZONE then return nil, 'not in Mhaura' end
    local npc = windower.ffxi.get_mob_by_name(NPC_NAME)
    if not npc then return nil, NPC_NAME..' not found' end
    local d = distance(npc)
    if not d or d >= MAX_DISTANCE then return nil, 'move within 6 yalms of '..NPC_NAME end
    return npc
end

local function resolve_item_id(name)
    local needle = tostring(name):lower()
    for id, item in pairs(res.items) do
        if item and item.en and tostring(item.en):lower() == needle then
            return tonumber(id)
        end
    end
end

local function inventory_stats(item_id)
    local all = windower.ffxi.get_items()
    local inv = all and all.inventory
    if not inv then return 0, 0, 0 end

    local total = 0
    local partial_room = 0
    for _, slot in pairs(inv) do
        if type(slot) == 'table' and tonumber(slot.id) == tonumber(item_id) then
            local count = tonumber(slot.count) or 0
            total = total + count
            if count > 0 and count < STACK_CAP then
                partial_room = partial_room + (STACK_CAP - count)
            end
        end
    end

    local max = tonumber(inv.max) or 0
    local used = tonumber(inv.count) or 0
    return total, math.max(0, max-used), partial_room
end

local function item_count()
    if not s.item_id then return 0 end
    local total = inventory_stats(s.item_id)
    return total
end

local function required_slots(item_id, quantity)
    local _, free, partial_room = inventory_stats(item_id)
    local remainder = math.max(0, quantity - partial_room)
    return math.ceil(remainder / STACK_CAP), free
end

local function request_currency()
    packets.inject(packets.new('outgoing', 0x115, {['_unknown2']=0}))
end

local function send_cancel()
    if not s.npc_id or not s.npc_index then return end
    packets.inject(packets.new('outgoing', 0x05B, {
        ['Target']=s.npc_id,
        ['Option Index']=0,
        ['_unknown1']=16384,
        ['Target Index']=s.npc_index,
        ['Automated Message']=false,
        ['_unknown2']=0,
        ['Zone']=ZONE,
        ['Menu ID']=MENU,
    }))
end

local function stop(reason)
    if s.mode == 'idle' then return end
    chat('Stopped: '..tostring(reason), 167)
    if s.menu then send_cancel() end
    reset()
end

local function page_currency(page)
    if page == 'hallmarks' then return s.hallmarks end
    if page == 'gallantry' then return s.gallantry end
end

local function summarize_plan(plan)
    local totals = {hallmarks=0, gallantry=0, quantity=0, transactions=0}
    for _, entry in ipairs(plan) do
        totals[entry.page] = totals[entry.page] + entry.cost * entry.quantity
        totals.quantity = totals.quantity + entry.quantity
        totals.transactions = totals.transactions + math.ceil(entry.quantity / STACK_CAP)
    end
    return totals
end

local function build_plan(requests)
    local plan = {}
    local common_item_id, common_name

    for _, req in ipairs(requests) do
        local page = tostring(req.page):lower()
        local page_catalog = CATALOG[page]
        if not page_catalog then return nil, 'page must be hallmarks or gallantry' end

        local key = tostring(req.item or 'alexandrite'):lower()
        local item = page_catalog[key]
        if not item then return nil, 'unsupported '..page..' item: '..key end

        local qty = tonumber(req.quantity)
        if not qty or qty < 1 or qty ~= math.floor(qty) then
            return nil, 'quantity must be a positive integer'
        end

        local resource_name = item.resource_name or item.name
        local item_id = resolve_item_id(resource_name)
        if not item_id and item.name == 'Alexandrite' then
            item_id = resolve_item_id('Alexandrite')
        end
        if not item_id then return nil, 'could not resolve item ID for '..resource_name end

        if common_item_id and item_id ~= common_item_id then
            return nil, 'one automation run may only purchase one item type'
        end
        common_item_id = item_id
        common_name = item.name

        plan[#plan+1] = {
            page=page,
            name=item.name,
            item_id=item_id,
            cost=item.cost,
            index=item.index,
            quantity=qty,
        }
    end

    return plan, nil, common_item_id, common_name
end

local function expand_transactions(plan)
    local txns = {}
    for _, entry in ipairs(plan) do
        local remain = entry.quantity
        while remain > 0 do
            local qty = math.min(STACK_CAP, remain)
            txns[#txns+1] = {
                page=entry.page,
                name=entry.name,
                item_id=entry.item_id,
                cost=entry.cost,
                index=entry.index,
                quantity=qty,
            }
            remain = remain - qty
        end
    end
    return txns
end

local function validate_plan(plan, item_id)
    local totals = summarize_plan(plan)

    if s.hallmarks == nil or s.gallantry == nil then
        return false, 'Ambuscade currency values are not available yet'
    end

    if totals.hallmarks > s.hallmarks then
        return false, string.format('need %d Hallmarks but only have %d', totals.hallmarks, s.hallmarks)
    end
    if totals.gallantry > s.gallantry then
        return false, string.format('need %d Gallantry but only have %d', totals.gallantry, s.gallantry)
    end

    local slots, free = required_slots(item_id, totals.quantity)
    if slots > free then
        return false, string.format('need %d new Inventory slots but only %d are free', slots, free)
    end

    return true, totals, slots, free
end

local function poke()
    local npc, err = get_gorpa()
    if not npc then stop(err) return end
    if npc.id ~= s.npc_id or npc.index ~= s.npc_index then
        stop('Gorpa identity changed')
        return
    end

    packets.inject(packets.new('outgoing', 0x01A, {
        ['Target']=s.npc_id,
        ['Target Index']=s.npc_index,
        ['Category']=0,
        ['Param']=0,
        ['_unknown1']=0,
    }))

    s.mode = 'opening'
    s.menu = nil
    s.deadline = now() + OPEN_TIMEOUT
end

local function send_purchase(txn)
    local p = PAGE[txn.page]
    local encoded = txn.quantity * 256 + txn.index

    -- Enter the relevant reward submenu.
    packets.inject(packets.new('outgoing', 0x05B, {
        ['Target']=s.npc_id,
        ['Option Index']=p.submenu_option,
        ['_unknown1']=0,
        ['Target Index']=s.npc_index,
        ['Automated Message']=true,
        ['_unknown2']=0,
        ['Zone']=ZONE,
        ['Menu ID']=MENU,
    }))

    -- Buy exactly one stack/chunk. Ambuscade caps a single purchase at 99.
    packets.inject(packets.new('outgoing', 0x05B, {
        ['Target']=s.npc_id,
        ['Option Index']=p.purchase_option,
        ['_unknown1']=encoded,
        ['Target Index']=s.npc_index,
        ['Automated Message']=true,
        ['_unknown2']=0,
        ['Zone']=ZONE,
        ['Menu ID']=MENU,
    }))

    -- Return from the purchase page using the same encoded selection.
    packets.inject(packets.new('outgoing', 0x05B, {
        ['Target']=s.npc_id,
        ['Option Index']=p.submenu_option,
        ['_unknown1']=encoded,
        ['Target Index']=s.npc_index,
        ['Automated Message']=true,
        ['_unknown2']=0,
        ['Zone']=ZONE,
        ['Menu ID']=MENU,
    }))

    -- Close Gorpa's menu so each stack is an independent verified transaction.
    send_cancel()

    s.expected_count = s.expected_count + txn.quantity
    s.mode = 'await_result'
    s.menu = nil
    s.deadline = now() + RESULT_TIMEOUT

    chat(string.format(
        '%s: requested %d %s (%s transaction %d/%d).',
        txn.page, txn.quantity, txn.name, txn.page, s.plan_index, #s.plan))
end

local function advance()
    if s.plan_index >= #s.plan then
        local final_count = item_count()
        local gained = math.max(0, final_count - s.start_count)
        chat(string.format('Complete: inventory confirmed +%d %s (%d -> %d).',
            gained, s.item_name, s.start_count, final_count), 158)
        reset()
        return
    end

    s.plan_index = s.plan_index + 1
    s.txn = s.plan[s.plan_index]
    poke()
end

local function begin(requests, dry_run)
    if s.mode ~= 'idle' then
        chat('Already busy. Use //ambs stop.', 167)
        return
    end

    local npc, err = get_gorpa()
    if not npc then chat(err, 167) return end

    local plan, plan_err, item_id, item_name = build_plan(requests)
    if not plan then chat(plan_err, 167) return end

    s.mode = 'await_currency'
    s.npc_id = npc.id
    s.npc_index = npc.index
    s.item_id = item_id
    s.item_name = item_name
    s.start_count = item_count()
    s.expected_count = s.start_count
    s.dry_run = dry_run and true or false
    s.plan = expand_transactions(plan)
    s.request_plan = plan
    s.deadline = now() + OPEN_TIMEOUT

    request_currency()
    chat('Refreshing Ambuscade currencies before purchase preflight.')
end

local function start_after_currency()
    local ok, result, slots, free = validate_plan(s.request_plan, s.item_id)
    if not ok then
        chat(result, 167)
        reset()
        return
    end

    local totals = result
    chat(string.format(
        'Preflight: %d %s in %d transaction(s), cost %d Hallmarks + %d Gallantry, Inventory slots %d/%d.',
        totals.quantity, s.item_name, totals.transactions,
        totals.hallmarks, totals.gallantry, slots, free))

    if s.dry_run then
        chat('Dry run complete; no purchases sent.', 158)
        reset()
        return
    end

    s.plan_index = 0
    s.deadline = nil
    advance()
end

local function full_alex_requests()
    return {
        {page='hallmarks', item='alexandrite', quantity=FULL_ALEX[1].quantity},
        {page='gallantry', item='alexandrite', quantity=FULL_ALEX[2].quantity},
    }
end

local function usage()
    chat('//ambs alex              - full monthly Alexandrite: 1750 HM + 450 Gallantry')
    chat('//ambs dryrun alex       - validate points/space and show transaction count')
    chat('//ambs buy <hallmarks|gallantry> <item> <quantity>')
    chat('//ambs dryrun <hallmarks|gallantry> <item> <quantity>')
    chat('//ambs status')
    chat('//ambs stop')
end

windower.register_event('addon command', function(...)
    local a = {...}
    local cmd = a[1] and tostring(a[1]):lower() or 'help'

    if cmd == 'alex' then
        begin(full_alex_requests(), false)
        return
    end

    if cmd == 'dryrun' and a[2] and tostring(a[2]):lower() == 'alex' then
        begin(full_alex_requests(), true)
        return
    end

    if cmd == 'buy' or cmd == 'dryrun' then
        local page = a[2] and tostring(a[2]):lower()
        local qty = tonumber(a[#a])
        if not page or not qty or #a < 4 then usage() return end
        local parts = {}
        for i=3,#a-1 do parts[#parts+1] = tostring(a[i]) end
        begin({{page=page, item=table.concat(parts,' '), quantity=qty}}, cmd == 'dryrun')
        return
    end

    if cmd == 'status' then
        chat(string.format(
            'mode=%s transaction=%d/%d inventory=%d expected=%d HM=%s Gallantry=%s',
            s.mode, s.plan_index, #s.plan, item_count(), s.expected_count,
            tostring(s.hallmarks), tostring(s.gallantry)))
        return
    end

    if cmd == 'stop' or cmd == 'cancel' then
        stop('cancelled by user')
        return
    end

    usage()
end)

windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
    if s.mode == 'idle' or id ~= 0x05B or injected or blocked then return end
    local ok, p = pcall(packets.parse, 'outgoing', original)
    if not ok or not p then return end
    if tonumber(p['Target']) == tonumber(s.npc_id) and tonumber(p['Target Index']) == tonumber(s.npc_index) then
        stop('manual Gorpa menu input during automation')
        return true
    end
end)

windower.register_event('incoming chunk', function(id, data)
    if id == 0x118 then
        local ok, p = pcall(packets.parse, 'incoming', data)
        if ok and p then
            if p['Hallmarks'] ~= nil then s.hallmarks = tonumber(p['Hallmarks']) end
            if p['Badges of Gallantry'] ~= nil then s.gallantry = tonumber(p['Badges of Gallantry']) end
        end

        if s.mode == 'await_currency' and s.hallmarks ~= nil and s.gallantry ~= nil then
            start_after_currency()
        end
        return
    end

    if s.mode == 'idle' then return end

    if (id == 0x032 or id == 0x033 or id == 0x034) and s.mode == 'opening' then
        if same_packet(id, data) then return true end
        local ok, p = pcall(packets.parse, 'incoming', data)
        if not ok or not p then return end
        if tonumber(p['NPC']) ~= tonumber(s.npc_id) or tonumber(p['NPC Index']) ~= tonumber(s.npc_index) then return end

        local menu = tonumber(p['Menu ID'])
        if menu ~= MENU then
            stop('unexpected Gorpa menu '..tostring(menu))
            return true
        end

        s.menu = menu
        send_purchase(s.txn)
        return true
    end
end)

windower.register_event('prerender', function()
    if s.mode == 'idle' then return end
    local t = now()

    if s.mode == 'await_result' then
        local current = item_count()
        if current >= s.expected_count then
            chat(string.format('Inventory confirmed %d/%d total gained.',
                current - s.start_count, s.expected_count - s.start_count))
            s.mode = 'between'
            s.next_at = t + NEXT_DELAY
            s.deadline = nil
            request_currency()
            return
        end
    elseif s.mode == 'between' and s.next_at and t >= s.next_at then
        advance()
        return
    end

    if s.deadline and t >= s.deadline then
        if s.mode == 'await_currency' then
            stop('currency refresh timed out')
        elseif s.mode == 'opening' then
            stop('Gorpa menu did not open')
        elseif s.mode == 'await_result' then
            local current = item_count()
            stop(string.format(
                'purchase was not inventory-confirmed (expected %d total, saw %d); monthly limit, points, or menu index may have changed',
                s.expected_count, current))
        end
    end
end)

windower.register_event('zone change', function()
    if s.mode ~= 'idle' then reset() end
end)

windower.register_event('unload', function()
    if s.mode ~= 'idle' and s.menu then send_cancel() end
end)
