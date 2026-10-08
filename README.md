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
retail-2026-09-10
verified against current retail client data: 2026-10-07
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
| 6 | Beitetsu | 50 | 125 |
| 7 | High-Purity Bayld | 35 | 190 |
| 8 | Mulcibar's Scoria | 50,000 | 1 |
| 9 | Heavy Metal Plate | 200 | 25 |
| 10 | Riftdross | 1,500 | 1 |
| 11 | Riftcinder | 1,500 | 1 |
| 12 | Riftborn Boulder | 50 | 125 |

The mapping was decoded directly from the current retail **Mhaura event 386** data from the September 10, 2026 client update. The table contains the item IDs, monthly caps, and point costs in matching index order. Alexandrite index 5 was also independently proven by the live AmbuShop purchase on October 7. The next announced version update is mid-October, so this is the current retail menu layout until that update changes it.

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
2. From Gallantry, buy the full **125 Beitetsu** cap.
3. Buy **1 Riftdross + 1 Riftcinder**.
4. If at least 12,500 Gallantry remains, buy the full **125 Pluton + 125 Riftborn Boulder** caps, then Heavy Metal Plates with the remainder.
5. If less than 12,500 remains, use Heavy Metal Plates first so small balances are consumed efficiently, then Pluton/Boulders.
6. For unusual leftover balances, clean up with H-P Bayld and then single Dynamis currencies.

For the current post-Alex balances this produces the intended exact allocation:

| Character group | Hallmark Beitetsu | Gallantry Beitetsu | Pluton | Boulder | Dross | Cinder | HMP |
|---|---:|---:|---:|---:|---:|---:|---:|
| Etamame / Niightsiide / Ponpon / Redrogue | 376 each | 125 | 125 | 125 | 1 | 1 | 25 |
| Nyoourke | 16 | 125 | 125 | 125 | 1 | 1 | 0 |
| Terrasjr | 16 | 125 | 0 | 0 | 1 | 1 | 5 |

Across all six characters that is **2,286 Beitetsu, 625 Plutons, 625 Riftborn Boulders, 6 Riftdross, 6 Riftcinder, and 105 Heavy Metal Plates**, consuming the current **76,800 Hallmarks + 139,000 Gallantry exactly**.

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
