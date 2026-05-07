# Biome + Ultracite Reference

## biome.jsonc

```jsonc
{
  "$schema": "./node_modules/@biomejs/biome/configuration_schema.json",
  "extends": ["ultracite/biome/core", "ultracite/biome/react"],
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true,
    "defaultBranch": "main"
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "assist": {
    "actions": {
      "source": {
        "organizeImports": "on"
      }
    }
  },
  "linter": {
    "rules": {
      "suspicious": {
        "noConsole": "error",
        "noReactForwardRef": "off"
      },
      "complexity": {
        "noExcessiveCognitiveComplexity": {
          "level": "error",
          "options": { "maxAllowedComplexity": 15 }
        }
      },
      "style": {
        "useFilenamingConvention": {
          "level": "error",
          "options": {
            "strictCase": true,
            "filenameCases": ["kebab-case"]
          }
        },
        "noRestrictedImports": {
          "level": "error",
          "options": {
            "paths": {
              "moment": "Use date-fns instead of moment.",
              "lodash": "Use native JS methods or specific lodash subpackages (e.g., lodash/get).",
              "classnames": "Use clsx or the cn utility instead.",
              "mobx": "Use zustand for state management instead of MobX.",
              "mobx-react": "Use zustand for state management instead of MobX.",
              "mobx-react-lite": "Use zustand for state management instead of MobX.",
              "yup": "Use zod for schema validation instead of yup.",
              "recoil": "Recoil is archived by Meta. Use zustand instead.",
              "react-scripts": "Create React App is deprecated. Use rsbuild or vite.",
              "react-beautiful-dnd": "Archived by Atlassian. Use @dnd-kit/core instead.",
              "framer-motion": "Renamed to 'motion'. Use the motion package instead.",
              "@redpanda-data/ui": "Legacy Chakra library. Use redpanda-ui registry components instead.",
              "lucide-react": "Use components/icons barrel for consistent icon usage."
            }
          }
        }
      },
      "correctness": {
        "noRestrictedElements": {
          "level": "error",
          "options": {
            "elements": {
              "button": "Use <Button> from @/components/ui/ instead.",
              "input": "Use <Input> from @/components/ui/ instead.",
              "select": "Use <Select> from @/components/ui/ instead.",
              "textarea": "Use <Textarea> from @/components/ui/ instead."
            }
          }
        }
      },
      "nursery": {
        "useExhaustiveSwitchCases": "error",
        "useConsistentTestIt": {
          "level": "error",
          "options": { "function": "test", "withinDescribe": "test" }
        },
        "noPlaywrightWaitForTimeout": "error"
      },
      "project": {
        "noDeprecatedImports": "error"
      }
    }
  },
  "overrides": [
    {
      "includes": ["**/*.test.*", "**/*.spec.*", "**/__tests__/**"],
      "linter": {
        "rules": {
          "suspicious": {
            "noExplicitAny": "error"
          }
        }
      }
    }
  ]
}
```

## biome-autofix.sh

Stop hook: auto-fix lint/format on changed JS/TS files.

> Script: [`scripts/biome-autofix.sh`](scripts/biome-autofix.sh)

## Ultracite Overrides Explained

Ultracite strict baseline. Overrides:

| Rule | Group | Ultracite default | Our override | Why |
|------|-------|-------------------|-------------|-----|
| `noConsole` | suspicious | off | error | Ban console.log prod |
| `noReactForwardRef` | suspicious | on | off | forwardRef still needed React 18 |
| `noExcessiveCognitiveComplexity` | complexity | 20 | 15 | Stricter complexity cap |
| `noExplicitAny` in tests | suspicious | off | error | No `any` even tests |
| `noDeprecatedImports` | project | off | error | Needs Biome Scanner |
| `useFilenamingConvention` | style | off | kebab-case strict | `my-component.tsx` not `MyComponent.tsx` |
| `noRestrictedImports` | style | empty | configured | Ban moment, lodash, classnames, mobx, yup, `@redpanda-data/ui`, lucide-react |
| `noRestrictedElements` | correctness | off | configured | Ban raw `<button>`, `<input>`, `<select>`, `<textarea>` |
| `useExhaustiveSwitchCases` | nursery | off | error | Type-safe switch/case |
| `useConsistentTestIt` | nursery | off | test only | `test()` over `it()` |
| `noPlaywrightWaitForTimeout` | nursery | off | error | Ban `page.waitForTimeout()` |
| `organizeImports` | assist | -- | on | Auto-sort imports |

`noClassComponent` removed Biome 2.x -- React Compiler skill enforce functional patterns.

## Import Deletion Loop Prevention

PostToolUse hook skip `noUnusedImports` (`--skip=lint/correctness/noUnusedImports`). Without: Claude add import -> Biome delete (unused, JSX not written yet) -> Claude re-add -> infinite loop. Stop hook catch when edit done.