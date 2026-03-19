# FlagUtil

[![Documentation](https://img.shields.io/badge/docs-online-4ade80?style=flat-square)](https://GimmyFimmy.github.io/FlagUtil/docs)
[![Luau](https://img.shields.io/badge/language-Luau-60a5fa?style=flat-square)]()
[![Roblox](https://img.shields.io/badge/platform-Roblox-f87171?style=flat-square)]()

FlagUtil is a small, type-safe boolean state machine for Roblox. It wraps a single `true/false` value into a reactive object — you declare what should happen when the flag goes Up or Down, and FlagUtil takes care of the rest.

Instead of scattering `if isSprinting then` checks across your codebase, you bind behavior directly to state transitions. Loops start and stop automatically. Coroutines yield and resume cleanly. Every async operation returns a cancel function so you stay in control.

```
Up ──────────────────────────────► Down
     ExecuteUntil fires every frame
     WaitUntil resumes coroutines
     Changed notifies listeners
```

---

## Example

```lua
local FlagUtil = require(game.ReplicatedStorage:WaitForChild("FlagUtil"))
local UserInputService = game:GetService("UserInputService")

local sprinting = FlagUtil.new(FlagUtil.States.Down)

-- Drain stamina every frame while the player is sprinting
sprinting:ExecuteAfter(FlagUtil.States.Up, function(dt: number)
    stamina -= dt * 10
end)

-- Update the UI whenever the state changes
sprinting:Changed(function(state: boolean)
    sprintIcon.ImageTransparency = state and 0 or 0.5
end)

-- Toggle sprint on Shift
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift then
        sprinting:Up()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        sprinting:Down()
    end
end)

-- Clean up when the character is removed
player.CharacterRemoving:Connect(function()
    sprinting:Destroy()
end)
```

For the full API reference and more examples, see the **[documentation](https://your-username.github.io/your-repo-name/)**.

---

## Contributing

Contributions are welcome. If you find a bug, have a feature idea, or want to improve the docs, feel free to open an issue or a pull request.

A few things to keep in mind before submitting:

- **Keep it small.** FlagUtil is intentionally minimal. New methods should solve a clear problem that can't already be handled by composing existing ones.
- **Match the style.** Use the same assertion pattern (`assert(typeof(...) == "boolean", "[FlagUtil]: ...")`), keep types exported, and return a `CancelFn` from anything async.
- **Write a test.** If your change touches logic, add a corresponding case to the test script so it can be verified.
- **One thing per PR.** Focused pull requests are easier to review and faster to merge.

If you're unsure whether an idea fits, open an issue first and we can discuss it before you write any code.