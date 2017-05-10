This mod provides tools for cut and paste operation within Factorio.

Usage is similar to blueprints, except the tools are single-use (the blueprint
will be converted back to a tool upon placing or when putting it back in
inventory)

## Cut tool

The Cut tool allows you to select an area to be moved elsewhere.

Make a selection just like you would with a blueprint and then place the result
where you want. The selection will be ordered for deconstruction and the pasted
items will appear as ghost entities (just like blueprints).

By default, the Cut tool will try to maintain circuit connections with items
outside the selected area if the destination isn't too far from the source.
You can disable this in the mod setting (Esc, Options, Mods, Per player).

Tiles (such as concrete) can be included by using the Alternative selection
mode (usually by holding Shift when selecting).

You can disable tile deconstruction in the settings. In that case, only
cut entities will be deconstructed while tiles will simply be copied.

Like normal blueprints, you can normally only paste the selection if there are
no conflicting entities at the destination. Shift-clicking overrides this
behavior but works differently than vanilla blueprints:

By default, conflicting entities at the destination will be deconstructed
before placing the new ones. This is different than vanilla blueprint pasting
where force placing will simply not build conflicting entities.

This behavior can be changed using the "Replace mode" setting:

 - *When different*: conflicting destination entities will be replaced if they
   have different type, position or direction (the default).

 - *Always*: conflicting destination entities will always be replaced, even if
   they match exactly. Existing circuit connections will be kept if the
   destination is of the same type, position and direction, otherwise they'll
   be destroyed.

 - *Never*: conflicting destination entities will not be replaced. This
   matches the game behavior when placing a blueprint.

## Copy tool

The copy tool is similar to the Cut tool except it doesn't deconstruct the
source entities or reconnect circuit wires.

It exhibits the same replacing behavior as the Cut tool.

Another minor difference is that the selection remains in hand after being
placed, allowing more copies to be made. The selection is cleared as soon as it
leaves the player's hand (you can disable this behavior in the settings so
that the copied selection can be used like regular blueprints).
