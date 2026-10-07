# AmbuShop

Windower addon for automating bulk purchases from **Gorpa-Masorpa** in Mhaura.

Ambuscade only allows a maximum of **one stack (99 items) per individual purchase**. AmbuShop treats that as a hard limit and automatically splits larger quantities into separate, inventory-verified shop transactions.

## Safety model

Before sending a purchase, AmbuShop verifies:

- you are in Mhaura and within 6 yalms of Gorpa-Masorpa;
- live Hallmark and Gallantry balances;
- total currency cost for the requested purchase;
- required **main Inventory** slots, including room in existing partial stacks;
- every individual purchase is 99 items or fewer.

After every stack purchase, the addon waits until the expected item quantity is visible in main Inventory before opening Gorpa again. If a purchase is not confirmed, automation stops instead of continuing.

Manual Gorpa menu input while automation is active also cancels the run.

## Installation

Place the `AmbuShop` folder in your Windower addons directory:

```text
//lua l AmbuShop
```

Commands may use either `ambs` or `ambushop`.

## Alexandrite

For the current Alexandrite buyout:

- Hallmarks: **1,750 Alexandrite × 15 = 26,250 Hallmarks**
- Gallantry: **450 Alexandrite × 15 = 6,750 Gallantry**
- Total: **2,200 Alexandrite**
- Ambuscade transactions: **23** because each purchase is capped at 99

Stand near Gorpa-Masorpa and run:

```text
//ambs dryrun alex
```

This performs all point/space checks but buys nothing.

Then:

```text
//ambs alex
```

This purchases the full 1,750 Hallmark allotment followed by the 450 Gallantry allotment.

**Important:** `//ambs alex` assumes you have not already purchased part of this month's Alexandrite stock. If you already bought some, request the exact remaining quantity with the explicit commands below instead.

## Explicit purchases

```text
//ambs buy hallmarks alexandrite 1750
//ambs buy gallantry alexandrite 450

//ambs dryrun hallmarks alexandrite 1750
//ambs dryrun gallantry alexandrite 450
```

Hallmark consumables currently seeded in the catalog include Alexandrite, Dynamis currency, Heavy Metal, Riftdross/Riftcinder, Pluton, Beitetsu, Riftborn Boulder, High-Purity Bayld, Umbral Marrow, and Mulcibar's Scoria.

The Gallantry reward page can change after version updates, so only the verified Alexandrite entry is currently seeded there.

## Runtime commands

```text
//ambs status
//ambs stop
```

## Packet behavior

Gorpa-Masorpa uses Mhaura menu **386**.

Ambuscade purchase payloads encode the requested stack as:

```text
quantity * 256 + catalog_index
```

AmbuShop never sends a purchase quantity above 99.

Hallmark consumable purchases use option 6. Gallantry purchases use option 10.

## Notes

This addon performs automated NPC menu packet interaction. Use it only while standing at Gorpa-Masorpa and do not manually operate Gorpa's menu while a run is active.
