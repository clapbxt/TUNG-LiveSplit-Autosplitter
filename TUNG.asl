// TUNG / Steam build 25782013 / UE 5.8
// Valves unlocked, four valves (any order), factory door, Finish.
// See README.md for installation and timing rules.
state("TUNG-Win64-Shipping") { }

startup
{
    refreshRate = 60;
    settings.Add("gameTime",    true,  "Synchronize Game Time with TUNG's speedrun timer");
    settings.Add("diagnostics", false, "Print state changes to LiveSplit's debug log");

    vars.model = new TimerModel { CurrentState = timer };
    vars.supported = false;
    vars.owned     = false;
    vars.hasGameTime  = false;
    vars.lastGameTime = 0.0;
    vars.previousStatus = "";
    vars.readSnapshot = null;

    vars.Clear = (Action)(() => {
        vars.menuSeen   = false;
        vars.active     = false;
        vars.owned      = false;
        vars.boundWorld = 0L;
        vars.boundClock = 0L;
        vars.startNow   = false;
        vars.finishNow  = false;
        vars.elapsed    = 0.0;
        vars.routeStage = 0;
        vars.status     = "Waiting for the main menu";
        vars.seenAttempt = false;
        vars.observedWorld = 0L;
        vars.observedClock = 0L;
    });
    vars.Clear();

    vars.Step = (Func<dynamic, object>)(s => {
        vars.startNow  = false;
        vars.finishNow = false;
        if (!s.valid) { vars.status = "Waiting for a coherent memory sample"; return null; }
        if (s.world == "L_Demo") {
            vars.menuSeen = true;
            vars.active   = false;
            vars.owned    = false;
            vars.status   = "Armed: choose New Game";
            return null;
        }
        if (s.world != "MAZE" || !s.allowed) {
            vars.menuSeen = false;
            vars.active   = false;
            vars.owned    = false;
            vars.seenAttempt = false;
            vars.status   = "Unsupported mode or checkpoint attempt";
            return null;
        }
        if (s.clock == 0L) { vars.status = "Waiting for the in-game timer"; return null; }
        // A fresh MAZE world and timer also identify the game's Restart action.
        // This transition was observed repeatedly in capture.jsonl without a menu.
        bool reloaded = vars.seenAttempt && s.worldId != vars.observedWorld
            && s.clock != vars.observedClock;
        vars.seenAttempt = true;
        vars.observedWorld = (long)s.worldId;
        vars.observedClock = (long)s.clock;
        if (vars.menuSeen || reloaded) {
            vars.menuSeen = false;
            vars.active   = false;
            vars.owned    = false;
            if (s.elapsed >= 0.0 && s.elapsed <= 2.0 && s.result == 0L) {
                vars.boundWorld    = (long)s.worldId;
                vars.boundClock    = (long)s.clock;
                vars.active        = true;
                vars.startNow      = true;
                vars.elapsed       = (double)s.elapsed;
                vars.routeStage    = 0;
                vars.status        = "New speedrun detected";
            } else vars.status = "Late attachment: return to the menu for a new run";
            return null;
        }
        if (!vars.active) return null;
        if (s.worldId != vars.boundWorld || s.clock != vars.boundClock || s.elapsed + 0.05 < vars.elapsed) {
            vars.active = false;
            vars.owned  = false;
            vars.status = "Attempt interrupted: return to the menu";
            return null;
        }
        vars.elapsed = (double)s.elapsed;
        if (vars.owned) vars.lastGameTime = (double)s.elapsed;
        var fields = (IDictionary<string, object>)s;
        if (fields.ContainsKey("routeStage"))
            vars.routeStage = Math.Max((int)vars.routeStage, (int)s.routeStage);

        if (s.result != 0L) {
            // Use the result widget's captured, displayed time, not the live clock.
            if (vars.owned) vars.lastGameTime = (double)s.finishTime;
            vars.finishNow = true;
            vars.active    = false;
            vars.status    = "Normal ending detected";
            return null;
        }

        vars.status = "Tracking";
        return null;
    });
}

init
{
    vars.Clear();
    vars.supported    = false;
    vars.readSnapshot = null;
    version = "Unsupported build (no timer actions)";

    string hash;
    using (var sha = System.Security.Cryptography.SHA256.Create())
    using (var file = System.IO.File.OpenRead(modules.First().FileName))
        hash = BitConverter.ToString(sha.ComputeHash(file)).Replace("-", "");
    if (hash != "31AFB689D8730C5D52BFAF134D2D7E66B8E118C5473882A228FDA9C1A43AE258") {
        print("TUNG: unrecognized executable SHA-256 " + hash + ". Autosplitting disabled.");
        return;
    }

    long moduleBase = modules.First().BaseAddress.ToInt64();
    Func<long, int, byte[]> read = (address, count) => {
        if (address < 0x10000L || address >= 0x800000000000L || count < 1 || count > 4096)
            throw new Exception("Invalid read range");
        byte[] bytes = memory.ReadBytes(new IntPtr(address), count);
        if (bytes == null || bytes.Length != count) throw new Exception("Incomplete memory read");
        return bytes;
    };
    Func<long, long>   ptr = address => BitConverter.ToInt64(read(address, 8), 0);
    Func<long, uint>   u32 = address => BitConverter.ToUInt32(read(address, 4), 0);
    Func<long, double> dbl = address => BitConverter.ToDouble(read(address, 8), 0);

    var names = new Dictionary<uint, string>();
    Func<uint, string> name = index => {
        string value;
        if (names.TryGetValue(index, out value)) return value;
        if (index > 0x02000000) throw new Exception("Invalid FName index");
        long block = ptr(moduleBase + 0x8F8D090 + 8L * (index >> 16));
        long entry = block + 2L * (index & 65535);
        ushort header = BitConverter.ToUInt16(read(entry, 2), 0);
        int length = header >> 6;
        if (length < 1 || length > 512) throw new Exception("Invalid FName length");
        bool wide = (header & 1) != 0;
        value = (wide ? System.Text.Encoding.Unicode : System.Text.Encoding.ASCII)
            .GetString(read(entry + 2, length * (wide ? 2 : 1)));
        names[index] = value;
        return value;
    };
    Func<long, string> className = obj => obj == 0 ? "" : name(u32(ptr(obj + 0x10) + 0x18));

    long worldAddress = moduleBase + 0x90DDAB0;
    long actorWorld = 0;
    var routeActors = new Dictionary<string, long>();
    string[] valveClasses = { "BP_BlueValve_C", "BP_GreenValve_C", "BP_YellowValve_C", "BP_RedValve_C" };

    vars.readSnapshot = (Func<dynamic>)(() => {
        dynamic s = new System.Dynamic.ExpandoObject();
        s.valid        = false;
        s.world        = "";
        s.worldId      = 0L;
        s.clock        = 0L;
        s.result       = 0L;
        s.elapsed      = 0.0;
        s.allowed      = false;
        s.finishTime   = -1.0;
        try {
            long world = ptr(worldAddress);
            if (className(world) != "World") return s;
            s.worldId = world;
            s.world   = name(u32(world + 0x18));
            if (s.world == "L_Demo") { s.valid = ptr(worldAddress) == world; return s; }
            if (s.world != "MAZE")   { s.valid = true; return s; }

            long gi = ptr(world + 0x228);
            if (className(gi) != "GI_C") return s;
            byte checkpoint = read(gi + 0x1D8, 1)[0];
            byte speedrun   = read(gi + 0x1F8, 1)[0];
            byte tiny       = read(gi + 0x1FA, 1)[0];
            byte bhop       = read(gi + 0x208, 1)[0];
            if (checkpoint > 1 || speedrun > 1 || tiny > 1 || bhop > 1) return s;
            s.allowed = checkpoint == 0 && speedrun == 1 && tiny == 0 && bhop == 0;
            if (!s.allowed) { s.valid = ptr(worldAddress) == world; return s; }

            long level  = ptr(world + 0x30);
            long script = ptr(level + 0xF8);
            if (className(script) != "MAZE_C") return s;

            // Resolve actor identities once per UWorld, never per-frame absolute addresses.
            // Route failures do not disable the independently verified finish reader.
            try {
                if (actorWorld != world) {
                    routeActors.Clear();
                    long actors = ptr(level + 0xA0);
                    int count = (int)u32(level + 0xA8);
                    if (count < 1 || count > 10000) throw new Exception("Invalid actor array");
                    for (int i = 0; i < count; i++) {
                        long actor = ptr(actors + i * 8L);
                        if (actor == 0) continue;
                        string cls = className(actor);
                        if (valveClasses.Contains(cls) || cls == "BP_TurnValves_C") routeActors[cls] = actor;
                    }
                    if (routeActors.Count != 5) throw new Exception("Valve actors unavailable");
                    actorWorld = world;
                }
                int completed = 0;
                foreach (string cls in valveClasses) {
                    long actor = routeActors[cls];
                    if (className(actor) != cls) throw new Exception("Actor changed");
                    float angle = BitConverter.ToSingle(read(actor + (cls == "BP_GreenValve_C" ? 0x2D0 : 0x2C8), 4), 0);
                    if (Single.IsNaN(angle) || angle < 0 || angle > 360.1) throw new Exception("Invalid valve track");
                    if (angle >= 359.99) completed++;
                }
                long door = ptr(script + 0x3F8);
                if (className(door) != "BP_ValveDoor_C") throw new Exception("Invalid door");
                byte opened = read(door + 0x2E0, 1)[0];
                if (opened > 1) throw new Exception("Invalid door state");
                long objective = routeActors["BP_TurnValves_C"];
                if (className(objective) != "BP_TurnValves_C") throw new Exception("Invalid objective");
                // canStartObjective? changes 1 -> 0 when the door approach enables
                // the Turn Valves objective (observed live, before any valve turns).
                byte canStart = read(objective + 0x2E1, 1)[0];
                if (canStart > 1) throw new Exception("Invalid objective state");
                s.routeStage = canStart == 1 ? 0 : (completed == 4 && opened == 1 ? 6 : completed + 1);
            } catch { }

            long frame = ptr(script + 0x2B0);
            if (frame == 0) return s;
            long clock  = ptr(frame + 0x68);
            long result = ptr(frame + 0x60);
            if (clock == 0) { s.valid = ptr(worldAddress) == world; return s; }
            if (className(clock)  != "WB_SpeedrunTimer_C")     return s;
            if (result != 0 && className(result) != "WB_EndSpeedrunningTime_C") return s;

            long player = ptr(clock + 0x348);
            if (className(player) != "BP_Player_C") return s;

            double elapsed = dbl(player + 0x850);
            if (Double.IsNaN(elapsed) || Double.IsInfinity(elapsed) || elapsed < 0 || elapsed > 86400) return s;

            if (result != 0) {
                // Verified from ExecuteUbergraph_WB_EndSpeedrunningTime reflection:
                // 0x460 is the FString returned by TimeSecondsToString; 0x64C is
                // its captured float input. The live player timer keeps increasing.
                long endFrame = ptr(result + 0x328);
                long textData = ptr(endFrame + 0x460);
                int length = BitConverter.ToInt32(read(endFrame + 0x468, 4), 0);
                if (length < 9 || length > 32) return s; // construction not finished
                string text = System.Text.Encoding.Unicode.GetString(read(textData, length * 2)).TrimEnd('\0');
                var match = System.Text.RegularExpressions.Regex.Match(text, @"^(\d{2,}):([0-5]\d)\.([0-9]{2})$");
                if (!match.Success) return s;
                double finish = Int32.Parse(match.Groups[1].Value) * 60.0
                    + Int32.Parse(match.Groups[2].Value) + Int32.Parse(match.Groups[3].Value) / 100.0;
                double captured = (double)BitConverter.ToSingle(read(endFrame + 0x64C, 4), 0);
                if (Double.IsNaN(captured) || Double.IsInfinity(captured) || finish < 0
                    || finish > 86400 || captured < finish - 0.001 || captured - finish > 0.011
                    || captured > elapsed + 0.1) return s;
                if (ptr(result + 0x328) != endFrame || ptr(endFrame + 0x460) != textData) return s;
                s.finishTime = finish;
            }

            // Consistency check before committing.
            if (ptr(worldAddress) != world || ptr(frame + 0x68) != clock || ptr(frame + 0x60) != result) return s;

            s.clock   = clock;
            s.result  = result;
            s.elapsed = elapsed;

            s.valid = true;
        } catch { }
        return s;
    });

    vars.supported = true;
    version = "Steam 25782013 / Any%";
}

update
{
    if (!vars.supported) return false;
    vars.Step(vars.readSnapshot());

    // A final split stops LiveSplit only when it is the last segment.
    if (timer.Run.Count != 1 && timer.Run.Count != 7) {
        vars.Clear();
        vars.status = "Use the supplied seven-segment splits or one Finish segment";
        return false;
    }

    if (settings["diagnostics"] && vars.status != vars.previousStatus) {
        print("TUNG: " + vars.status);
        vars.previousStatus = vars.status;
    }
    if (vars.startNow && timer.CurrentPhase == TimerPhase.Ended && settings.ResetEnabled)
        vars.model.Reset();
    return true;
}

start  { return vars.startNow; }
reset  { return vars.startNow && settings.ResetEnabled; }

split {
    if (!vars.owned) return false;
    if (vars.finishNow) {
        // Missing/manual-skipped route events must never prevent the final stop.
        while (timer.CurrentSplitIndex < timer.Run.Count - 1) vars.model.SkipSplit();
        return true;
    }
    return vars.active && timer.Run.Count == 7 && timer.CurrentSplitIndex < (int)vars.routeStage;
}

onStart
{
    vars.owned = vars.active;
    if (vars.owned && settings["gameTime"]) {
        vars.hasGameTime  = true;
        vars.lastGameTime = (double)vars.elapsed;
        vars.model.InitializeGameTime();
        timer.IsGameTimePaused = true;
        timer.SetGameTime(TimeSpan.FromSeconds((double)vars.elapsed));
    }
}

onReset
{
    vars.owned       = false;
    vars.hasGameTime = false;
}

isLoading { return settings["gameTime"] && vars.hasGameTime; }

gameTime
{
    if (settings["gameTime"] && vars.hasGameTime)
        return TimeSpan.FromSeconds((double)vars.lastGameTime);
}

exit
{
    vars.Clear();
    vars.supported    = false;
    vars.readSnapshot = null;
}

shutdown { timer.IsGameTimePaused = false; }
