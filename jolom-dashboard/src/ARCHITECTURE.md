# Source layout

```
src/
  app/                  # Next.js routes (thin)
    (auth)/             # login / public auth screens
    (dashboard)/        # authenticated shell
  components/
    ui/                 # design-system primitives
    layout/             # sidebar, header, page shell
    shared/             # cross-feature composites
  features/             # one folder per admin domain
  lib/                  # api, auth, utils
  hooks/                # global hooks only
  types/                # shared contracts
  config/               # navigation, flags
```

See `.cursor/rules/architecture.mdc` and skills under `.cursor/skills/`.
