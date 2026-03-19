# FlagUtil

A lightweight, type-safe boolean state machine for Roblox. React to state changes, run frame-perfect loops, and coordinate async behavior — all without polling.

```lua
local isAlive = FlagUtil.new(FlagUtil.States.Up)

isAlive:OnEvent(humanoid.Died, FlagUtil.States.Down)

isAlive:ExecuteUntil(FlagUtil.States.Down, function(dt)
    -- runs every frame while alive
end)

isAlive:Changed(function(state)
    print("alive:", state)
end)
```

---

## Installation

Place `FlagUtil.lua` inside `ReplicatedStorage` (or any shared module folder), then require it:

```lua
local FlagUtil = require(game.ReplicatedStorage:WaitForChild("FlagUtil"))
```

No external dependencies. Only requires `RunService` from Roblox services.

---

## API Reference

### `flag.new(state: boolean) → Flag`

Creates a new Flag instance. Pass `FlagUtil.States.Up` (`true`) or `FlagUtil.States.Down` (`false`). Asserts if a non-boolean is passed.

```lua
local f = FlagUtil.new(FlagUtil.States.Up)
```

---

### `flag:Up() → ()`

Sets the flag to `Up` (`true`) and notifies all listeners. Warns if already Up.

---

### `flag:Down() → ()`

Sets the flag to `Down` (`false`) and notifies all listeners. Warns if already Down.

---

### `flag:Toggle() → ()`

Flips the current state. Calls `Down()` if currently Up, `Up()` if currently Down.

---

### `flag:Get() → boolean`

Returns the current state as a raw boolean.

```lua
if f:Get() == FlagUtil.States.Up then
    print("flag is Up")
end
```

---

### `flag:Changed(predicate: (boolean) → ()) → CancelFn`

Registers a callback that fires every time the state changes. Returns a `CancelFn` to unsubscribe.

```lua
local cancel = f:Changed(function(state)
    print("state changed to:", state)
end)

-- Later, unsubscribe
cancel()
```

---

### `flag:OnEvent(event: RBXScriptSignal, state: boolean) → ()`

Connects an `RBXScriptSignal` so that when it fires, the flag transitions to `state`. Uses `:Once()` internally — auto-disconnects after the first fire.

```lua
local isAlive = FlagUtil.new(FlagUtil.States.Up)
isAlive:OnEvent(humanoid.Died, FlagUtil.States.Down)
```

---

### `flag:WaitUntil(state: boolean) → ()` ⏸ yields

Yields the current coroutine until the flag reaches `state`. Returns immediately if already there. Must be called inside a coroutine or `task.spawn`.

```lua
task.spawn(function()
    f:WaitUntil(FlagUtil.States.Down)
    print("flag went Down")
end)
```

---

### `flag:ExecuteUntil(state: boolean, predicate: (dt: number, ...any) → (), ...any) → CancelFn?`

Binds `predicate` to `RenderStep` and calls it every frame until the flag reaches `state`. Returns a `CancelFn` to stop early, or `nil` if the flag is already at `state`.

| Parameter | Type | Description |
|---|---|---|
| `state` | `boolean` | Stop when the flag reaches this state |
| `predicate` | `(dt: number, ...any) → ()` | Called every frame with delta time and any extra args |
| `...` | `any` | Extra arguments forwarded to the predicate each frame |

```lua
local cancel = f:ExecuteUntil(FlagUtil.States.Down, function(dt)
    -- runs every frame until Down
end)

cancel() -- stop early if needed
```

---

### `flag:ExecuteAfter(state: boolean, predicate: (dt: number, ...any) → (), ...any) → CancelFn`

Waits until the flag reaches `state`, then runs `predicate` every frame until the flag flips back. Equivalent to `WaitUntil(state)` → `ExecuteUntil(not state, ...)`. Always returns a `CancelFn`.

> The cancel function works in both phases — before the state is reached it cancels the wait; after, it cancels the RenderStep.

```lua
local sprinting = FlagUtil.new(FlagUtil.States.Down)

local cancel = sprinting:ExecuteAfter(FlagUtil.States.Up, function(dt)
    stamina -= dt * 10
end)

sprinting:Up()   -- stamina drain begins
sprinting:Down() -- stamina drain stops
cancel()         -- or cancel at any point
```

---

### `flag:Destroy() → ()`

Cancels all pending threads, disconnects all connections, unbinds all RenderStep callbacks, and removes the metatable. The flag is unusable after this call.

> Always call `Destroy()` when the owning object is removed to prevent leaking RenderStep bindings and suspended coroutines.

```lua
player.CharacterRemoving:Connect(function()
    isAlive:Destroy()
end)
```

---

## Types

```lua
export type CancelFn = () -> ()

export type States = {
    Up: boolean,
    Down: boolean,
}

export type Flag = {
    Get:          (self: Flag) -> boolean,
    Up:           (self: Flag) -> (),
    Down:         (self: Flag) -> (),
    Toggle:       (self: Flag) -> (),

    Changed:      (self: Flag, predicate: (boolean) -> ()) -> CancelFn,
    OnEvent:      (self: Flag, event: RBXScriptSignal, state: boolean) -> (),

    WaitUntil:    (self: Flag, state: boolean) -> (),
    ExecuteUntil: (self: Flag, state: boolean, predicate: (dt: number, ...any) -> (), ...any) -> CancelFn?,
    ExecuteAfter: (self: Flag, state: boolean, predicate: (dt: number, ...any) -> (), ...any) -> CancelFn,

    Destroy:      (self: Flag) -> (),
}
```

---

## Examples

### Flashlight toggle

```lua
local flashlight = FlagUtil.new(FlagUtil.States.Down)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F then
        flashlight:Toggle()
    end
end)

flashlight:Changed(function(on)
    spotlight.Enabled = on
end)

flashlight:ExecuteAfter(FlagUtil.States.Up, function(dt)
    -- sway animation while flashlight is on
end)
```

### Combat lock

```lua
local attacking = FlagUtil.new(FlagUtil.States.Down)

local function attack()
    if attacking:Get() then return end
    attacking:Up()

    local track = animator:LoadAnimation(attackAnim)
    track:Play()
    track.Stopped:Wait()

    attacking:Down()
end

-- Wait for the attack to finish before doing something else
task.spawn(function()
    attacking:WaitUntil(FlagUtil.States.Down)
    print("can combo now")
end)
```

### Loading gate

```lua
local loaded = FlagUtil.new(FlagUtil.States.Down)

task.spawn(function()
    ContentProvider:PreloadAsync(assets)
    loaded:Up()
end)

-- Multiple systems wait independently
task.spawn(function()
    loaded:WaitUntil(FlagUtil.States.Up)
    initUI()
end)

task.spawn(function()
    loaded:WaitUntil(FlagUtil.States.Up)
    startGameLoop()
end)
```

---

## License

MIT