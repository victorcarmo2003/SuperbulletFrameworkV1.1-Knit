# superbullet-knit

Fork of [Sleitnick/Knit](https://github.com/Sleitnick/Knit) (MIT, archived
2024-07-31) used by [SuperbulletFrameworkV1-Knit](https://github.com/H4K0R/SuperbulletKnitV1.1).
Adds:

- `SuperbulletInit`/`SuperbulletStart` lifecycle methods, with automatic
  fallback to `KnitInit`/`KnitStart` if not present — vanilla Knit services
  and controllers keep working unmodified.
- Automatic component loading: when a Service/Controller is created with
  `Instance = script`, a `Components` folder inside that instance is scanned
  for `Accessor.lua`/`Mutator.lua`/`Others/*.lua` and required automatically.
  See `ComponentInitializer.lua`.
- `ClientExtension` — dynamic `RegisterClientSignal`/`RegisterClientMethod`/
  `RegisterClientProperty` API, locked once `SuperbulletStart` begins.

## Install

```toml
[dependencies]
Superbullet = "hakor/superbullet-knit@0.1.0"
```

```lua
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)

local MyService = Superbullet.CreateService({
	Name = "MyService",
	Instance = script, -- enables automatic Components/ loading
})

function MyService:SuperbulletInit() end
function MyService:SuperbulletStart() end
```

`require(Packages.Knit)` also works, for drop-in compatibility with code
written against vanilla Knit.

## License

MIT — see [LICENSE](LICENSE). Retains the original Knit copyright notice as
required by its license, plus a separate notice for the modifications.
