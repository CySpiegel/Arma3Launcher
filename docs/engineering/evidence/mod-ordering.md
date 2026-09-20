# Mod ordering findings — 2026-09-19

The user asked whether selected mods are automatically ordered and how the
Windows launcher behaves. Current behavior was checked in LaunchPlanner and the
selection model: IDs retain selection/preset order, duplicates are removed without
sorting, and the paths are passed in that order. There is no dependency graph or
automatic enable/download/reorder feature in this checkpoint.

Bohemia documents that its official launcher handles declared Workshop
dependencies, including dependencies of dependencies, and offers missing mods
for download. See [Launcher mod handling](https://community.bistudio.com/wiki/Arma_3%3A_Launcher_-_Mod_Handling).

Separately, Arma's addon initialization uses `CfgPatches.requiredAddons` inside
addon configs. Mod-folder ordering alone cannot establish compatible addon
initialization or resolve missing dependencies. See
[Mod folders](https://community.bistudio.com/wiki/Arma%3A_Mod_Folders) and
[CfgPatches](https://community.bistudio.com/wiki/CfgPatches).

The scoped local installation investigation found no Workshop dependency edges
in Steam's ACF/mod.cpp/meta.cpp metadata. A future dependency feature needs an
explicit reliable source and rules for missing/disabled dependencies, cycles,
offline or stale data and user selections. It must not guess relationships from
mod names or claim a universal conflict solver. No such design has been adopted,
and this note authorizes no network service or dependency auto-installation.
