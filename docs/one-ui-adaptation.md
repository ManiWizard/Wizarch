# One UI adaptation for Wizarch Shell

Wizarch is a desktop Quickshell interface. This adaptation applies the archived Samsung One UI guidance where it fits a desktop panel and keeps Wizarch's existing theme. The Samsung source text is bundled in `/home/Mw/.codex/skills/one-ui/`; the listed paths point to that corpus.

| Area | One UI guidance | Wizarch decision |
| --- | --- | --- |
| Quick settings | `structure/basic-structure.md` (Quick panel), `layout/basic-layout.md` (Interaction area) | Group frequent controls in subdued focus blocks, show action labels and states, and keep volume and brightness together. |
| Navigation | `components/app-bar.md` (App bar), `accessibility/interaction-and-control.md` | Give secondary panels a title and an explicit Back action. The collapsed pill has named keyboard actions for apps, calendar, and quick settings. |
| Lists and settings | `components/lists.md` (Main text), `accessibility/focus-order.md` | Put the notification sound switch on the right of its row; use short labels, readable values, and visible focus marks. |
| Search and shortcuts | `components/search.md` (Search), `writing/focused-and-purposeful.md` | Use a prominent editable launcher search field, show pinned apps before typing, and give app context menus explicit launch, pin, and group actions. Emoji search accepts names. |
| Launcher groups | `components/lists.md` (Main text; Subheader), `components/buttons.md` (Buttons), `accessibility/focus-order.md` | Place group names below their previews. Compact groups preview four icons and open a full group view. Large groups use normal app icon size in eight slots and reserve the ninth tile for opening the full view. The preview dimensions and 10 px spacing are Wizarch desktop choices, not Samsung phone specifications. |
| Clipboard deletion | `writing/simple-and-human.md` (Only interrupt for important things), `components/dialog.md` | Ask for confirmation before clearing all clipboard history. Keep the choice visible until the user answers or dismisses it. |
| Motion | `motion/motion-basics-and-usage.md` (Transitions; Duration) | Animate the pill's width and height together; opening and closing motions each finish within 500 ms. Resize directly when content changes inside an open panel. |
| Accessibility | `accessibility/screen-reader.md`, `focus-order.md`, `color-and-contrast.md`, `interaction-and-control.md`, `layout-and-typography.md` | Give interactive icons names, keyboard activation, and focus marks; show toggle states as text; keep panels open until dismissed. Both shipped themes exceed 4.5:1 for primary and secondary text on the main panel surfaces. |

The archived guidance describes Samsung phone interfaces. Wizarch keeps its desktop pill, keyboard workflows, and violet palette. Its fixed-size QML layouts do not yet support the archive's 200% text scaling guidance; this document does not claim full One UI accessibility compliance.
