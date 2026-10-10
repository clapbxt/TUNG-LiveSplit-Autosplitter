# TUNG LiveSplit Autosplitter

Native ASL autosplitter for **TUNG**, normal **Any% Speedrun mode**, Steam build
**25782013**. Automatically starts, resets on a new attempt, and finishes on the
normal result screen. Game Time follows TUNG's clock and uses the game's captured
result text for the final hundredths.

The supplied layout shows all seven splits:

1. **Valves unlocked** — approaching the factory door enables the valve objective.
2. **Valve 1** — first distinct valve finishes turning.
3. **Valve 2**
4. **Valve 3**
5. **Valve 4** — valves may be collected in any order.
6. **Door** — the factory door opens.
7. **Finish** — normal ending.

There is no hedge split. This is a community script, not an official game tool.

## Download and setup

1. Install [LiveSplit for Windows](https://livesplit.org/downloads/). Testing used
   LiveSplit 1.8.37 with its Scriptable Auto Splitter component.
2. On this repository, choose **Code > Download ZIP**. Extract the entire ZIP
   into a permanent, writable folder.
3. Double-click **Launch-TUNG-LiveSplit.cmd** and select your **LiveSplit.exe**.
   The launcher connects the script, layout, and splits using your actual paths.
4. If LiveSplit was already open, right-click it and choose **Open Splits > From
   File**, selecting `TUNG-AnyPercent.lss`; then **Open Layout > From File**,
   selecting `TUNG.lsl` from the extracted folder.
5. In **Edit Layout**, open **Scriptable Auto Splitter** settings. Check **Start**,
   **Split**, and **Reset**. Keep **Synchronize Game Time with TUNG's speedrun
   timer** enabled. Do not add a second copy of the component.
6. The supplied Timer and split columns use **Game Time**. Select **Compare
   Against > Game Time** in the right-click menu for Game Time comparisons too.
7. Start TUNG. Enable **Speedrun** mode; disable **Tiny Tung** and **bhop** and do
   not use a checkpoint. Let LiveSplit see the main menu, then select **New Game**.
8. Play normally. A new attempt resets and starts the timer. Save your splits
   under your own filename to keep PBs when updating this download.

After moving the extracted folder, rerun the launcher to repair its paths.

### Manual setup without the launcher

Open the supplied splits and layout. In **Edit Layout > Scriptable Auto Splitter**,
browse to the extracted `TUNG.asl`. Check Start, Split, and Reset, and select Game
Time as described above. Save the layout. If using a custom layout, add **Control
> Scriptable Auto Splitter** once and select the script.

The optional command-line launcher accepts a LiveSplit directory:

```powershell
.\Launch-TUNG-LiveSplit.ps1 -LiveSplit 'C:\Tools\LiveSplit'
```

## Behavior and settings

- Keep the seven supplied rows in their supplied order. Alternatively, use
  exactly one **Finish** segment for finish-only timing. Other counts are rejected.
- Disabling **Start**, **Split**, or **Reset** disables the corresponding action.
  With Reset disabled, an existing attempt is preserved and is not rebound to the
  next in-game attempt. Split controls intermediates and the finish together.
- **Game Time** is the game's speedrun clock, including its own pause/loading
  behavior. This does not implement a separate load-removal policy. Real Time
  remains LiveSplit's wall clock.
- Menus and process loss hold the last Game Time. Returning to the menu does not
  reset; beginning the next fresh run does. Reopening the game is supported.
- Mid-run attachment does not start the timer. Return to the menu or restart.
- Each route stage splits once. If intermediate events are missing, completion
  still ends the run and skipped segment times stay blank.
- **Print state changes to LiveSplit's debug log** is available for troubleshooting.

## Compatibility and known limitations

Only the tested executable is accepted. A different SHA-256 disables timer actions:

```text
31AFB689D8730C5D52BFAF134D2D7E66B8E118C5473882A228FDA9C1A43AE258
```

Checkpoint loads, Tiny Tung, bhop, and other game builds are unsupported. A fresh
start missed by more than two seconds is deliberately rejected. Direct restarts
require new world and timer identities; if addresses are reused, return to the
menu before starting again. Intermediate times have polling precision; the final
Game Time uses the result screen's captured hundredths.

**Testing status:** 58 checks pass using the installed ASL compiler and LiveSplit
TimerModel. Start/reset/reconnect, four valves, and Door were exercised in the
visible application. The exact finish reader was tested against a live result
screen. The unlock flag was observed in live gameplay, but its newly added split
has not had a fresh live UI transition test. A complete fresh run with the final
seven-row version remains to be tested. See [TESTING.md](TESTING.md).

## Troubleshooting

- **Timer does not start:** check Speedrun mode, Start/Reset settings, script path,
  and supported game build. Begin a new run from the menu after LiveSplit loads.
- **Old six-row layout:** reopen both supplied files; the unlock row makes seven.
- **Times do not match:** verify Timer, split columns, and comparisons use Game
  Time. Final synchronization occurs at the normal result screen.
- **New game update:** do not guess replacement offsets. Report the Steam build
  and executable hash for investigation.

For a bug report, include your LiveSplit version, game build, mode, expected
behavior, actual behavior, and reproduction steps. Do not upload game executables
or memory dumps.

## Implementation

The script reads Unreal Engine 5.8 objects in `TUNG-Win64-Shipping.exe` at 60 Hz.
It resolves module-relative pointers and validates class identities. It discovers
the four valve actors and objective actor once per world and reads their cached
states. The item counter is deliberately not used because other maze objectives
reuse it. All game memory access is read-only.

The result widget's captured time string is checked against its captured float;
the live player clock continues increasing after completion and cannot be used
as the final timestamp. See the comments in [TUNG.asl](TUNG.asl) for the measured
offsets and consistency checks.

References: [TUNG on Steam](https://store.steampowered.com/app/4341400/TUNG/),
[official ASL documentation](https://github.com/LiveSplit/LiveSplit.AutoSplitters/blob/master/README.md),
[ASL dispatcher source](https://github.com/LiveSplit/LiveSplit.ScriptableAutoSplit/blob/master/src/LiveSplit.ScriptableAutoSplit/ASL/ASLScript.cs).
