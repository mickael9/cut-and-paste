This mod provides tools for cut and paste operation within Factorio.

Usage is similar to blueprints, except the tools are single-use (the blueprint
will be converted back to a tool upon placing or when putting it back in
inventory)

![Demo](https://mods-data.factorio.com/pub_data/media_files/3k2gtIPhUmPm.gif)

## Features

 - Quickly cut, copy and paste with single-use blueprints.
 - Keep circuit connections with entities outside the selection when doing cut & paste.
 - Move containers (chests, turrets, ...) along with their contents.
 - Pasting over existing entities deconstructs them if the blueprint is force-placed.
 - Compatible with instant blueprint mods like Creative Mode.

## Cut tool

The Cut tool allows you to select an area to be moved elsewhere.

Make a selection just like you would with a blueprint and then place the result
where you want. The selection will be ordered for deconstruction and the pasted
items will appear as ghost entities (just like blueprints).

By default, the Cut tool will try to maintain circuit connections with items
outside the selected area if the destination isn't too far from the source.
You can disable this in the mod setting (Esc, Options, Mods, Per player).

Items in containers (chests contents, turret ammo, etc.) will be moved to the
destination as well. This can be disabled in the mod settings.

Tiles (such as concrete) can be included by using the Alternative selection
mode (usually by holding Shift when selecting).

You can disable tile deconstruction in the settings. In that case, only
cut entities will be deconstructed while tiles will simply be copied.

Like normal blueprints, you can normally only paste the selection if there are
no conflicting entities at the destination. Shift-clicking overrides this
behavior but works differently than vanilla blueprints:

By default, conflicting entities at the destination of a different type will be
deconstructed before placing the new ones. This is different than vanilla
blueprint pasting where force placing will simply not build over conflicting
entities.

This behavior can be changed using the "Replace mode" setting:

 - *When different*: conflicting destination entities will be deconstructed if they have different type or if they can't be made to match the source (by pasting settings and rotating them)
 - *Always*: conflicting destination entities will always be deconstructed, even if they match exactly. Existing circuit connections will be kept if the destination is of the same type and position, otherwise they'll be destroyed.
 - *Never*: conflicting destination entities will not be replaced. This matches the game behavior when placing a blueprint.

## Copy tool

The Copy tool is similar to the Cut tool except it doesn't deconstruct the
source entities or reconnect circuit wires with items outside the selection
area. The selection remains in hand after being placed, allowing more copies to
be made.

By default, items in containers are not copied (except for modules). This can
be changed in the mod settings.

Conflicting entities are handled in the same way as the Cut tool and according
to the mod settings.

The selection is normally cleared as soon as it leaves the player's hand but
you can disable this behavior in the settings so that the copied selection can
be used like regular blueprints.

This is mainly useful if you want to duplicate something many times while also
replacing any conflicting entities at the destination (which isn't possible
with normal blueprints).

Note that once a copy blueprint leaves the hand, it won't be attached to the
source entities anymore and conflicting entities will always be deconstructed
(unless "Replace mode" was set to "Never").

## Hotkeys

 - "R": switch between the cut and copy tools (tool must be in hand with no current selection)
 - "CONTROL + R": clear the current selection

## Changelog

**0.1.5**

 - Fixed crash when pasting on tile ghosts (#9)
 - Fixed tile ghosts weren't deconstructed like normal tiles
 - Added support for moving item request slots
 - Added an hotkey to switch between cut and copy tools
 - Added an hotkey to clear the selection

**0.1.4**

 - Fixed crash when pasting rails (attempt to index local 'm' (a nil value)).
 - Fixed crash when non-blueprintable entities like the item request proxy are selected (table index is nil).
 - Fixed non-blueprintable terrain tiles being marked deconstruction when cutting them.
 - Fixed inexact/invalid source/destination position computation

**0.1.3**

 - When moving entities with inventories (chest, furnace, turret, etc.). their items are now moved as well except for output slots and logistics requester chests.
 - Conflicting entities at the destination will now copy settings and direction from the source if they match the source entity instead of being deconstructed.
 - Fixed mod not working in multiplayer for some players (#6)
 - Fixed "LuaEntity API call when LuaEntity was invalid" crash (#5)
