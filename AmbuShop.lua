_addon.name = 'AmbuShop'
_addon.author = 'n0gr1p + OpenAI'
_addon.version = '0.2.0'
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

-- Packet payload: _unknown1 = quantity * 256 + catalog index.
--
-- Hallmark consumable indices are stable.
-- Gallantry changes by reward rotation.  The active profile below is the
-- Alexandrite rotation verified on retail on 2026-10-07:
--   * Alexandrite index 5 was proven by a live AmbuShop purchase.
--   * indices 0-5 match the retail Ambuloot Alexandrite-rotation map.
-- Never add speculative Gallantry indices to a stockup plan.
local GALLANTRY_PROFILE = {
    name = 'retail-2026-09-10',
    verified = '2026-10-07',
    source = 'current retail event 386 DAT + live Alexandrite purchase',
}

local CATALOG = {
    hallmarks = {
        ['tukuku whiteshell'] = {name='Tukuku Whiteshell', cost=20, index=0, limit=150},
        ['lungo-nango jadeshell'] = {name='Lungo-Nango Jadeshell', cost=2000, index=1, limit=2},
        ['ordelle bronzepiece'] = {name='Ordelle Bronzepiece', cost=20, index=2, limit=150},
        ['montiont silverpiece'] = {name='Montiont Silverpiece', cost=2000, index=3, limit=2},
        ['one byne bill'] = {name='One Byne Bill', cost=20, index=4, limit=150},
        ['one hundred byne bill'] = {name='One Hundred Byne Bill', cost=2000, index=5, limit=2},
        ['alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=6, limit=1750},
        ['piece of alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=6, limit=1750},
        ['heavy metal'] = {name='Heavy Metal Plate', resource_name='Plate of Heavy Metal', cost=200, index=7, limit=100},
        ['heavy metal plate'] = {name='Heavy Metal Plate', resource_name='Plate of Heavy Metal', cost=200, index=7, limit=100},
        ['plate of heavy metal'] = {name='Heavy Metal Plate', resource_name='Plate of Heavy Metal', cost=200, index=7, limit=100},
        ['riftdross'] = {name='Riftdross', resource_name='Clump of Riftdross', cost=1500, index=8, limit=3},
        ['riftcinder'] = {name='Riftcinder', resource_name='Pinch of Riftcinder', cost=1500, index=9, limit=3},
        ['pluton'] = {name='Pluton', cost=50, index=10, limit=500},
        ['beitetsu'] = {name='Beitetsu', cost=50, index=11, limit=500},
        ['riftborn boulder'] = {name='Riftborn Boulder', cost=50, index=12, limit=500},
        ['h-p bayld'] = {name='High-Purity Bayld', resource_name='Pinch of High-Purity Bayld', cost=35, index=13, limit=750},
        ['high-purity bayld'] = {name='High-Purity Bayld', resource_name='Pinch of High-Purity Bayld', cost=35, index=13, limit=750},
        ['umbral marrow'] = {name='Umbral Marrow', resource_name='Vial of Umbral Marrow', cost=30000, index=14, limit=2},
        ['mulcibar scoria'] = {name="Mulcibar's Scoria", resource_name="Chunk of Mulcibar's Scoria", cost=50000, index=15, limit=1},
        ["mulcibar's scoria"] = {name="Mulcibar's Scoria", resource_name="Chunk of Mulcibar's Scoria", cost=50000, index=15, limit=1},
    },
    gallantry = {
        -- Current verified Alexandrite rotation.
        ['tukuku whiteshell'] = {name='Tukuku Whiteshell', cost=20, index=0, limit=90},
        ['ordelle bronzepiece'] = {name='Ordelle Bronzepiece', cost=20, index=1, limit=90},
        ['one byne bill'] = {name='One Byne Bill', cost=20, index=2, limit=90},
        ['pluton'] = {name='Pluton', cost=50, index=3, limit=125},
        ['umbral marrow'] = {name='Umbral Marrow', resource_name='Vial of Umbral Marrow', cost=30000, index=4, limit=1},
        ['alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=5, limit=450},
        ['piece of alexandrite'] = {name='Alexandrite', resource_name='Piece of Alexandrite', cost=15, index=5, limit=450},
        ['beitetsu'] = {name='Beitetsu', cost=50, index=6, limit=125},
        ['h-p bayld'] = {name='High-Purity Bayld', resource_name='Pinch of High-Purity Bayld', cost=35, index=7, limit=190},
        ['high-purity bayld'] = {name='High-Purity Bayld', resource_name='Pinch of High-Purity Bayld', cost=35, index=7, limit=190},
        ['mulcibar scoria'] = {name="Mulcibar's Scoria", resource_name="Chunk of Mulcibar's Scoria", cost=50000, index=8, limit=1},
        ["mulcibar's scoria"] = {name="Mulcibar's Scoria", resource_name="Chunk of Mulcibar's Scoria", cost=50000, index=8, limit=1},
        ['heavy metal'] = {name='Heavy Metal Plate', resource_name='Plate of Heavy Metal', cost=200, index=9, limit=25},
        ['heavy metal plate'] = {name='Heavy Metal Plate', resource_name='Plate of Heavy Metal', cost=200, index=9, limit=25},
        ['plate of heavy metal'] = {name='Heavy Metal Plate', resource_name='Plate of Heavy Metal', cost=200, index=9, limit=25},
        ['riftdross'] = {name='Riftdross', resource_name='Clump of Riftdross', cost=1500, index=10, limit=1},
        ['riftcinder'] = {name='Riftcinder', resource_name='Pinch of Riftcinder', cost=1500, index=11, limit=1},
        ['riftborn boulder'] = {name='Riftborn Boulder', cost=50, index=12, limit=125},
    },
}

local PAGE = {
    hallmarks = {purchase_option=6, submenu_option=1},
    gallantry = {purchase_option=10, submenu_option=8},
}

local FULL_ALEX = {
    {page='hallmarks', item='alexandrite', quantity=1750},
    {page='gallantry', item='alexandrite', quantity=450},
}

-- Tracks only purchases confirmed during the current addon load.  This lets
-- repeated plan/stockup commands respect the monthly cap within the session.
-- Purchases made manually or before an addon reload remain server-authoritative;
-- if one of those consumed a cap, inventory verification stops on the first
-- rejected transaction rather than continuing blindly.
local purchased_this_session = {}

local s = {
    mode='idle',
    plan={},
    plan_index=0,
    txn=nil,
    request_plan=nil,
    pending_requests=nil,
    npc_id=nil,
    npc_index=nil,
    menu=nil,
    deadline=nil,
    next_at=nil,
    hallmarks=nil,
    gallantry=nil,
    start_counts={},
    expected_counts={},
    item_names={},
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
        mode='idle', plan={}, plan_index=0, txn=nil, request_plan=nil,
        pending_requests=nil, npc_id=nil, npc_index=nil, menu=nil,
        deadline=nil, next_at=nil, hallmarks=nil, gallantry=nil,
        start_counts={}, expected_counts={}, item_names={},
        last_raw={}, dry_run=false,
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

local function item_count(item_id)
    if not item_id then return 0 end
    local total = inventory_stats(item_id)
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

local function cap_key(page, index)
    return tostring(page)..':'..tostring(index)
end

local function session_bought(page, index)
    return purchased_this_session[cap_key(page, index)] or 0
end

local function add_session_bought(page, index, quantity)
    local key = cap_key(page, index)
    purchased_this_session[key] = (purchased_this_session[key] or 0) + quantity
end

local function canonical_catalog_entries(page)
    local unique = {}
    local result = {}
    for _, item in pairs(CATALOG[page] or {}) do
        if not unique[item.index] then
            unique[item.index] = true
            result[#result+1] = item
        end
    end
    table.sort(result, function(a,b) return a.index < b.index end)
    return result
end

local function build_plan(requests)
    local plan = {}

    for _, req in ipairs(requests or {}) do
        local page = tostring(req.page):lower()
        local page_catalog = CATALOG[page]
        if not page_catalog then return nil, 'page must be hallmarks or gallantry' end

        local key = tostring(req.item):lower()
        local item = page_catalog[key]
        if not item then
            return nil, string.format(
                'unsupported %s item "%s" for active catalog/profile',
                page, key)
        end

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

        plan[#plan+1] = {
            page=page,
            name=item.name,
            item_id=item_id,
            cost=item.cost,
            index=item.index,
            limit=item.limit,
            quantity=qty,
        }
    end

    if #plan == 0 then return nil, 'plan has no purchasable entries' end
    return plan
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
                limit=entry.limit,
                quantity=qty,
            }
            remain = remain - qty
        end
    end
    return txns
end

local function summarize_plan(plan)
    local totals = {hallmarks=0, gallantry=0, quantity=0, transactions=0}
    local by_cap = {}
    local by_item = {}

    for _, entry in ipairs(plan) do
        totals[entry.page] = totals[entry.page] + entry.cost * entry.quantity
        totals.quantity = totals.quantity + entry.quantity
        totals.transactions = totals.transactions + math.ceil(entry.quantity / STACK_CAP)

        local ck = cap_key(entry.page, entry.index)
        by_cap[ck] = by_cap[ck] or {
            page=entry.page, index=entry.index, name=entry.name,
            limit=entry.limit, quantity=0,
        }
        by_cap[ck].quantity = by_cap[ck].quantity + entry.quantity

        by_item[entry.item_id] = by_item[entry.item_id] or {
            name=entry.name, quantity=0,
        }
        by_item[entry.item_id].quantity = by_item[entry.item_id].quantity + entry.quantity
    end

    return totals, by_cap, by_item
end

local function validate_plan(plan)
    local totals, by_cap, by_item = summarize_plan(plan)

    if s.hallmarks == nil or s.gallantry == nil then
        return false, 'Ambuscade currency values are not available yet'
    end

    if totals.hallmarks > s.hallmarks then
        return false, string.format('need %d Hallmarks but only have %d', totals.hallmarks, s.hallmarks)
    end
    if totals.gallantry > s.gallantry then
        return false, string.format('need %d Gallantry but only have %d', totals.gallantry, s.gallantry)
    end

    for _, cap in pairs(by_cap) do
        local already = session_bought(cap.page, cap.index)
        if cap.quantity + already > cap.limit then
            return false, string.format(
                '%s %s request %d + session-confirmed %d exceeds monthly limit %d',
                cap.page, cap.name, cap.quantity, already, cap.limit)
        end
    end

    local free_slots
    local needed_slots = 0
    for item_id, item in pairs(by_item) do
        local slots, free = required_slots(item_id, item.quantity)
        needed_slots = needed_slots + slots
        free_slots = free_slots or free
    end
    free_slots = free_slots or 0

    if needed_slots > free_slots then
        return false, string.format(
            'plan needs %d new Inventory slots but only %d are free',
            needed_slots, free_slots)
    end

    return true, totals, needed_slots, free_slots
end

local function init_inventory_tracking(plan)
    s.start_counts = {}
    s.expected_counts = {}
    s.item_names = {}

    for _, entry in ipairs(plan) do
        if s.start_counts[entry.item_id] == nil then
            local n = item_count(entry.item_id)
            s.start_counts[entry.item_id] = n
            s.expected_counts[entry.item_id] = n
            s.item_names[entry.item_id] = entry.name
        end
    end
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

    send_cancel()

    s.expected_counts[txn.item_id] = (s.expected_counts[txn.item_id] or item_count(txn.item_id)) + txn.quantity
    s.mode = 'await_result'
    s.menu = nil
    s.deadline = now() + RESULT_TIMEOUT

    chat(string.format(
        '%s: requested %d %s (transaction %d/%d).',
        txn.page, txn.quantity, txn.name, s.plan_index, #s.plan))
end

local function finish_run()
    chat('Complete. Inventory-confirmed gains:', 158)
    for item_id, start_count in pairs(s.start_counts) do
        local final_count = item_count(item_id)
        local gained = math.max(0, final_count - start_count)
        chat(string.format('  +%d %s (%d -> %d)',
            gained, s.item_names[item_id] or tostring(item_id), start_count, final_count), 158)
    end
    reset()
end

local function advance()
    if s.plan_index >= #s.plan then
        finish_run()
        return
    end

    s.plan_index = s.plan_index + 1
    s.txn = s.plan[s.plan_index]
    poke()
end

local function add_affordable_request(requests, page, key, balance)
    local item = CATALOG[page] and CATALOG[page][key]
    if not item then return balance, 0 end

    local remaining_cap = math.max(0, item.limit - session_bought(page, item.index))
    if remaining_cap == 0 or balance < item.cost then return balance, 0 end

    local qty = math.min(remaining_cap, math.floor(balance / item.cost))
    if qty <= 0 then return balance, 0 end

    requests[#requests+1] = {page=page, item=key, quantity=qty}
    return balance - qty * item.cost, qty
end

local function add_exact_request(requests, page, key, quantity, balance)
    local item = CATALOG[page] and CATALOG[page][key]
    if not item or quantity <= 0 then return balance, 0 end

    local remaining_cap = math.max(0, item.limit - session_bought(page, item.index))
    local qty = math.min(quantity, remaining_cap, math.floor(balance / item.cost))
    if qty <= 0 then return balance, 0 end

    requests[#requests+1] = {page=page, item=key, quantity=qty}
    return balance - qty * item.cost, qty
end

local function stockup_requests(hallmarks, gallantry)
    local requests = {}
    local hm = tonumber(hallmarks) or 0
    local gall = tonumber(gallantry) or 0

    -- Yagrush priority: use every available Hallmark on Beitetsu, up to the
    -- 500/month Hallmark cap.
    hm = add_affordable_request(requests, 'hallmarks', 'beitetsu', hm)

    -- Current retail Gallantry material page is decoded from event 386.
    -- First lock in the highest-value limited materials we want every month.
    gall = add_exact_request(requests, 'gallantry', 'beitetsu', 125, gall)
    gall = add_exact_request(requests, 'gallantry', 'riftdross', 1, gall)
    gall = add_exact_request(requests, 'gallantry', 'riftcinder', 1, gall)

    -- With >=12,500 remaining, take full Pluton + Boulder caps first; this
    -- matches the balanced REMA stockpile plan.  With less than that (TJ's
    -- current case), prioritize HMP so the remaining points can be consumed
    -- cleanly rather than creating tiny partial Pluton/Boulder allocations.
    if gall >= 12500 then
        gall = add_exact_request(requests, 'gallantry', 'pluton', 125, gall)
        gall = add_exact_request(requests, 'gallantry', 'riftborn boulder', 125, gall)
        gall = add_affordable_request(requests, 'gallantry', 'heavy metal plate', gall)
    else
        gall = add_affordable_request(requests, 'gallantry', 'heavy metal plate', gall)
        gall = add_affordable_request(requests, 'gallantry', 'pluton', gall)
        gall = add_affordable_request(requests, 'gallantry', 'riftborn boulder', gall)
    end

    -- Generic cleanup for odd point balances after the priority package.
    gall = add_affordable_request(requests, 'gallantry', 'h-p bayld', gall)
    gall = add_affordable_request(requests, 'gallantry', 'tukuku whiteshell', gall)
    gall = add_affordable_request(requests, 'gallantry', 'ordelle bronzepiece', gall)
    gall = add_affordable_request(requests, 'gallantry', 'one byne bill', gall)

    return requests
end

local function begin(requests_or_builder, dry_run)
    if s.mode ~= 'idle' then
        chat('Already busy. Use //ambs stop.', 167)
        return
    end

    local npc, err = get_gorpa()
    if not npc then chat(err, 167) return end

    s.mode = 'await_currency'
    s.npc_id = npc.id
    s.npc_index = npc.index
    s.pending_requests = requests_or_builder
    s.dry_run = dry_run and true or false
    s.deadline = now() + OPEN_TIMEOUT

    request_currency()
    chat('Refreshing Ambuscade currencies before purchase preflight.')
end

local function start_after_currency()
    local requests = s.pending_requests
    if type(requests) == 'function' then
        requests = requests(s.hallmarks, s.gallantry)
    end

    local plan, plan_err = build_plan(requests)
    if not plan then
        chat(plan_err, 167)
        reset()
        return
    end

    local ok, result, slots, free = validate_plan(plan)
    if not ok then
        chat(result, 167)
        reset()
        return
    end

    local totals = result
    s.request_plan = plan
    s.plan = expand_transactions(plan)
    init_inventory_tracking(plan)

    chat(string.format(
        'Preflight: %d items in %d transaction(s), cost %d Hallmarks + %d Gallantry, Inventory slots %d/%d.',
        totals.quantity, totals.transactions, totals.hallmarks, totals.gallantry, slots, free))

    for _, entry in ipairs(plan) do
        chat(string.format(
            '  %s: %d x %s = %d points (monthly cap %d).',
            entry.page, entry.quantity, entry.name, entry.quantity * entry.cost, entry.limit))
    end

    if s.dry_run then
        chat('Plan complete; no purchases sent.', 158)
        reset()
        return
    end

    s.plan_index = 0
    s.deadline = nil
    advance()
end

local function full_alex_requests()
    local result = {}
    for _, entry in ipairs(FULL_ALEX) do
        result[#result+1] = {
            page=entry.page, item=entry.item, quantity=entry.quantity,
        }
    end
    return result
end

local function show_catalog(page)
    page = page and tostring(page):lower() or 'gallantry'
    if not CATALOG[page] then
        chat('Catalog page must be hallmarks or gallantry.', 167)
        return
    end

    if page == 'gallantry' then
        chat(string.format(
            'Gallantry profile: %s (verified %s).',
            GALLANTRY_PROFILE.name, GALLANTRY_PROFILE.verified), 158)
    end

    for _, item in ipairs(canonical_catalog_entries(page)) do
        chat(string.format(
            '  index=%d cost=%d cap=%d  %s',
            item.index, item.cost, item.limit, item.name))
    end
end

local function usage()
    chat('//ambs alex                         - full monthly Alexandrite buyout')
    chat('//ambs stockup                      - execute Yagrush-focused stockup plan')
    chat('//ambs plan stockup                 - preview stockup without buying')
    chat('//ambs dryrun stockup               - same as plan stockup')
    chat('//ambs buy <hallmarks|gallantry> <item> <quantity>')
    chat('//ambs dryrun <hallmarks|gallantry> <item> <quantity>')
    chat('//ambs catalog <hallmarks|gallantry>')
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

    if cmd == 'stockup' then
        begin(stockup_requests, false)
        return
    end

    if (cmd == 'plan' or cmd == 'dryrun') and a[2] and tostring(a[2]):lower() == 'stockup' then
        begin(stockup_requests, true)
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

    if cmd == 'catalog' then
        show_catalog(a[2])
        return
    end

    if cmd == 'status' then
        local txn = s.txn
        chat(string.format(
            'mode=%s transaction=%d/%d current=%s HM=%s Gallantry=%s profile=%s',
            s.mode, s.plan_index, #s.plan,
            txn and (txn.page..':'..txn.name..' x'..txn.quantity) or '-',
            tostring(s.hallmarks), tostring(s.gallantry), GALLANTRY_PROFILE.name))
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

    if s.mode == 'await_result' and s.txn then
        local expected = s.expected_counts[s.txn.item_id] or 0
        local current = item_count(s.txn.item_id)

        if current >= expected then
            add_session_bought(s.txn.page, s.txn.index, s.txn.quantity)
            chat(string.format(
                'Inventory confirmed %s: %d total (expected %d).',
                s.txn.name, current, expected))
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
        elseif s.mode == 'await_result' and s.txn then
            local expected = s.expected_counts[s.txn.item_id] or 0
            local current = item_count(s.txn.item_id)
            stop(string.format(
                '%s purchase was not inventory-confirmed (expected %d total, saw %d); monthly limit, points, or catalog index may have changed',
                s.txn.name, expected, current))
        end
    end
end)

windower.register_event('zone change', function()
    if s.mode ~= 'idle' then reset() end
end)

windower.register_event('unload', function()
    if s.mode ~= 'idle' and s.menu then send_cancel() end
end)
