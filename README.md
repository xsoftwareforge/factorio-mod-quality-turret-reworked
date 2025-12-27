# Quality Turrets Reworked

**Turn your defense into a legendary fortress!**

Quality Turrets Reworked allows your turrets to level up and gain **Quality** tiers simply by doing what they do best: eradicating enemies. As your turrets rack up kills, they will automatically upgrade to the next Quality tier, becoming more effective and durable.

## Features

*   **Dynamic Leveling**: Turrets upgrade quality tiers automatically upon reaching a configurable kill count.
*   **Smart Upgrades**:
    *   **Keeps Ammo**: Your turret won't lose its precious magazine when upgrading.
    *   **stat Preservation**: Excess kills carry over to the next level so no kill is wasted.
    *   **Fluid Preservation**: Flamethrower turrets keep their fuel during the upgrade.
    *   **Circuit Safe**: Uses `fast-replace` logic to attempt to preserve circuit network connections.
*   **Visual & Audio Feedback**: Satisfaction guaranteed with a "Quality Up!" flying text and sound effect on every upgrade.
*   **Progress GUI**: detailed progress bar appears when you open a turret, showing exactly how many kills are needed for the next tier.
*   **Broad Support**: Works with:
    *   Ammo Turrets (Gun Turrets)
    *   Electric Turrets (Laser Turrets)
    *   Fluid Turrets (Flamethrowers)
    *   Artillery Turrets
*   **Preserve Kill Counter**: (Optional, v0.8.0+) Turrets can keep their kill count when mined and placed again.
*   **Configurable**: You decide how many kills are required for an upgrade via Mod Settings.
*   **Ghost Restoration**: (v0.10.0+) Smart handling of destroyed turrets (Downgrade/Fixed quality).
*   **Localized**: Available in 10 languages!


## Usage

Simply place your turrets and let them defend your base. When a turret achieves the required number of kills (Default: **1**), it will instantly transform into the next quality tier of the same turret type.

You can adjust the "Kills to next quality" setting in the **Startup Mod Settings**.

### XP Scaling System (v0.7.0)

You can now configure how the required kills scale as the turret gains quality.
**Settings**:
*   **XP Start Value**: Kills required for the first upgrade (Normal -> Uncommon).
*   **XP Scaling Algorithm**:
    *   `Constant`: Required kills remain the same for every level.
    *   `Linear`: Required kills increase by `Factor` each level. `Start + (Level * Factor)`
    *   **Exponential**: Required kills multiply by `Factor` each level. `Start * (Factor ^ Level)`
*   **XP Scaling Factor**: The number used by the algorithm.

**Examples (Start Value = 10)**

| Mode | Factor | Normal -> Uncommon (L0) | Uncommon -> Rare (L1) | Rare -> Epic (L2) | Epic -> Legendary (L3) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Constant** | - | 10 | 10 | 10 | 10 |
| **Linear** | 5 | 10 | 15 | 20 | 25 |
| **Exponential** | 2.0 | 10 | 20 | 40 | 80 |
| **Exponential** | 2.0 | 10 | 20 | 40 | 80 |

### Ghost Restoration (v0.10.0)

When a turret is destroyed, the mod can now intelligently handle the ghost creation based on what you have available in your logistic network.
**Settings (Global)**:
*   **Ghost Replacement Strategy**:
    *   `Same Quality` (Default): The ghost retains the quality of the destroyed turret.
    *   `Downgrade if missing`: If the exact quality is not available in the logistic network, it will try to find the next lowest available quality (e.g., Legendary -> Epic -> Rare...).
    *   `Always replace`: Forces the ghost to be a specific quality defined by "Fixed Ghost Quality".
*   **Fixed Ghost Quality**: Select the target quality for the "Always replace" strategy.
*   **Fallback to Normal Quality**: (For "Downgrade" strategy) If enabled, and no suitable lower quality is found, the ghost will be set to Normal quality.

### New Settings (v0.6.0)

*   **Limit quality to unlocked** (Startup): If enabled, turrets will not upgrade past the highest quality level currently unlocked by your force.
*   **Show level up text** (Map): Toggle the "Quality Up!" flying text.
*   **Play level up sound** (Map): Toggle the level-up sound effect.
*   **Preserve kill counter** (Global): If enabled, turrets will save their kill count when mined. When you build a turret using that item, the kills are restored.

## Supported Languages

*   English (en)
*   German (de)
*   Spanish (es-ES)
*   French (fr)
*   Italian (it)
*   Japanese (ja)
*   Korean (ko)
*   Portuguese (Brazil) (pt-BR)
*   Russian (ru)
*   Chinese (Simplified) (zh-CN)


## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Credits

*   **Original Author**: Naarkerotics
*   **Reworked & Maintained by**: Xearox (since v0.5.0)
