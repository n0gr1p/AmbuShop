# AmbuShop

Windower addon for automating bulk purchases from **Gorpa-Masorpa** in Mhaura.

Ambuscade only allows a maximum of **one stack (99 items) per individual purchase**. AmbuShop treats that as a hard limit and automatically splits larger quantities into separate, inventory-verified shop transactions.

## Safety model

Before sending a purchase, AmbuShop verifies:

- you are in Mhaura and within 6 yalms of Gorpa-Masorpa;
- live Hallmark and Gallantry balances;
- total currency cost for the complete plan;
- required **main Inventory** slots across every item in the plan, including room in existing partial stacks;
- every individual transaction is 99 items or fewer;
- requested quantities do not exceed the published monthly cap for each catalog entry;
- purchases already confirmed by AmbuShop during the current addon session are deducted from those caps.

After every stack purchase, the addon waits until the **specific expected item** is visible in main Inventory at the expected quantity before continuing. If Gorpa rejects a transaction, an index changes, a monthly cap was already consumed manually, or inventory does not update, automation stops instead of continuing.

Manual Gorpa menu input while automation is active also cancels the run.

> Monthly-cap history made outside AmbuShop is not exposed by the normal currency packet. AmbuShop therefore enforces the published cap plus purchases it has confirmed during the current addon load. The game server remains authoritative for purchases made manually or before an addon reload; a rejected transaction stops the plan immediately.

## Installation

Place the `AmbuShop` folder in your Windower addons directory:

```text
//lua l AmbuShop
```

Commands may use either `ambs` or `ambushop`.

## Gallantry profile

Gallantry reward ordering changes by Ambuscade reward rotation, so AmbuShop does **not** guess packet indices.

The active profile is:

```text
alexandrite-rotation
verified: 2026-10-07
```

The current verified Gallantry packet catalog is:

| Index | Item | Cost | Monthly cap |
|---:|---|---:|---:|
| 0 | Tukuku Whiteshell | 20 | 90 |
| 1 | Ordelle Bronzepiece | 20 | 90 |
| 2 | One Byne Bill | 20 | 90 |
| 3 | Pluton | 50 | 125 |
| 4 | Umbral Marrow | 30,000 | 1 |
| 5 | Alexandrite | 15 | 450 |

Alexandrite index 5 was proven by the live AmbuShop purchase on this rotation. The remaining prefix matches the retail Ambuloot Alexandrite-rotation map.

**Beitetsu, Riftborn Boulder, Heavy Metal, Riftdross and Riftcinder are intentionally not assigned speculative Gallantry indices in this profile.** They remain available through the stable Hallmark catalog.

Inspect the active catalog in game with:

```text
//ambs catalog gallantry
//ambs catalog hallmarks
```

After an Ambuscade version update changes the Gallantry rotation, update/verify the profile before using Gallantry automation again.

## Alexandrite

For the full Alexandrite buyout:

- Hallmarks: **1,750 Alexandrite × 15 = 26,250 Hallmarks**
- Gallantry: **450 Alexandrite × 15 = 6,750 Gallantry**
- Total: **2,200 Alexandrite**
- Transactions: **23** because every purchase is capped at 99

Preview:

```text
//ambs dryrun alex
```

Execute:

```text
//ambs alex
```

The full command assumes the monthly Alexandrite allotment has not already been consumed.

## Stockup plan

The built-in stockup plan is currently **Yagrush-focused** and adapts to the character's live point balances.

Preview it first:

```text
//ambs plan stockup
```

or:

```text
//ambs dryrun stockup
```

Execute:

```text
//ambs stockup
```

Current priority:

1. Spend Hallmarks on **Beitetsu**, up to the 500/month Hallmark cap.
2. Spend Gallantry on **Pluton**, up to the 125/month Gallantry cap.
3. If at least 30,000 Gallantry remains, buy the verified **Umbral Marrow**.
4. Spend remaining usable Gallantry on the verified single Dynamis currencies:
   - Tukuku Whiteshell
   - Ordelle Bronzepiece
   - One Byne Bill

The plan only uses entries whose packet indices are verified in the active Gallantry rotation. It will not silently substitute an unverified Beitetsu/Boulder/HMP/Dross/Cinder Gallantry index.

For the current post-Alex balances, this means the four characters with 18,800 Hallmarks buy 376 Beitetsu each, while Nyoourke and Terrasjr with 800 Hallmarks buy 16 each. Gallantry is then spent on verified current-rotation entries.

## Explicit purchases

Examples:

```text
//ambs buy hallmarks beitetsu 376
//ambs buy hallmarks pluton 125
//ambs buy gallantry pluton 125
//ambs buy gallantry tukuku whiteshell 90
```

Dry-run any explicit purchase:

```text
//ambs dryrun hallmarks beitetsu 376
//ambs dryrun gallantry pluton 125
```

## Commands

```text
//ambs alex
//ambs stockup
//ambs plan stockup
//ambs dryrun stockup
//ambs buy <hallmarks|gallantry> <item> <quantity>
//ambs dryrun <hallmarks|gallantry> <item> <quantity>
//ambs catalog <hallmarks|gallantry>
//ambs status
//ambs stop
```

## Packet behavior

Gorpa-Masorpa uses Mhaura menu **386**.

Purchase payloads encode one stack/chunk as:

```text
quantity * 256 + catalog_index
```

AmbuShop never sends a purchase quantity above 99.

Hallmark consumable purchases use option 6. Gallantry purchases use option 10.

## Notes

This addon performs automated NPC menu packet interaction. Use it only while standing at Gorpa-Masorpa and do not manually operate Gorpa's menu while a run is active.
