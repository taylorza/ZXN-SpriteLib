# ZXN-SpriteLib [![ZXN-SpriteLib](https://github.com/taylorza/ZXN-SpriteLib/actions/workflows/build.yml/badge.svg)](https://github.com/taylorza/ZXN-SpriteLib/actions/workflows/build.yml)
Z80n Sprite library for the ZX Spectrum Next

The intent is to develop a library that makes it easier to develop games in assembly language for the ZX Spectrum Next.

## Assembling

To assemble the sample application use the following `sjasmplus` command line

```
sjasmplus src/main.asm --inc=inc --msg=war --fullpath
```

## Sprites
include <sprite.i.asm>

Sprites can be used completely independently of the rest of the objects. So at the lowest level this just simplifies the interface to the sprites. The in memory representation is an exact mapping of the hardware sprite attibutes, so the update will transfer the data verbatim to the hardware.
### Macros
The primary Sprite API is macro based. With a few exceptions, the macros typically set up a few registers based on the arguments provided and then call a function to do the actual work. The exceptions are either things that will change in the future or where calling to a function does not save much especially for one type calls to enable/disable the sprite system.

|Macro|Parameters|Description|
|-----|----------|-----------|
|sprite.StartDefinition||Starts the block where sprites are defined. The block must be terminated with sprite.EndDefinition|
|sprite.EndDefinition||Ends the sprite definition block. All sprites must be defined in the sprite definition block|
|sprite.Define|pattern|Defines a new sprite with the specified pattern. This must be with in a sprite start/end definition block|
|sprite.DefineUnified|pattern|Defines an anchor sprite for a compound unified sprite.|
|sprite.DefineRelative|pattern, xoffs, yoffs, isRelPattern|This must follow call to either sprite.DefineUnified, sprite.DefineUnifiedAuto. isRelPattern specified whether the pattern passed in is relative to the anchor pattern or an explicit pattern index|
|sprite.DefineUnifiedAuto|pattern, w, h, anchor|Auto creates a unified sprite, with the layout dictated by `w` and `h` which represent the width and height in sprite tiles. The patterns are assumed to be sequential from the initial `pattern` parameter. The `anchor` parameter controls which pattern in the matrix will be applied to the anchor, the layout will take this into account and offset the rest of the sprites around the anchor sprite. For example, in a 3x3 matrix, of the 9 sprites created, the 4th pattern can be applied to the anchor sprite, the engine will then assume the anchor sprite is in the middle and will therefore place the first non-anchor sprite at -16, -16, the second at 0, -16 and so on, making the anchor sprite take the center of the compound sprite.|
|sprite.UpdateAll||Updates all the sprites, synchronizing the in memory representation to the hardware|
|sprite.EnableSprites||Enable sprites, with higher sprite IDs on top|
|sprite.DisableSprites||Disable sprites|
|sprite.ClearSprites||Clears all the sprite data, resets the clipping window, loads the default palette into sprite palette 0 and 1 and sets the default transparency index to E3h (227)|
|sprite.ClipWindow|x, y, w, h|Sets the sprite clip window to the specified rectangle. Note the macro will automatically halve the values, so coordinates are specified using the full range|
|sprite.SetTransparency|index|Sets the transparency index used for the sprites|
|sprite.Upload|page|Uploads the data on the specified page into the FPGA pattern memory. Currently this loads the full 16k of page data|
|sprite.IncBin|page, file|Includes the specified file mapping it to the specified page. This page is passed to sprite.Upload to load the data into the FPGA|
|sprite.LoadPalette|paletteNo, paletteData, startIndex, count|Load color data into the specified sprite palette|
|sprite.LoadDefaultPalette|paletteNo|Loads the default color data into the specified sprite palette 0 or 1|
|sprite.SetActivePalette|paletteNo|Set the active pallete for the sprites|
|sprite.SetPaleteEntry|paletteNo,index,colorData|Set the color data for the specified palette and index|
|sprite.Show|sprite|Makes the specified sprite visible|
|sprite.Hide|sprite|Hides the specified sprite|
|sprite.SetPos|sprite, xpos, ypos|Sets the location of the specified sprite. `xpos` is a 9-bit value, `ypos` is a 8-bit value|
|sprite.SetPattern|sprite, pattern|Set the pattern used for the specified sprite|


## Animations
include <animation.i.asm>

Animations allow the user to define some basic animations that the system will manage automatically. Animations need to be paired with `Game Objects` to be useful.

### Macros
The animation API is only has a single macro that is used to define the animation.

|Macro|Parameters|Description|
|-----|----------|-----------|
|animation.Define|firstPattern, frameCount, frameDelay, mode, stopAfter|Defines an animation. The animation will run from the firstPattern to firstPatter+frameCount, with an update occuring every frameDelay. If the updates (see Game Objects), are synchronized with the frame rate then the number specified will effectively be the number of screen frames before moving to the next animation frame. The `mode` parameter controls what happens when you reach the end of the animation sequence ie. the last frame.|

Animation modes

|Mode|Description|
|----|----------|
|animation.modeStop|Stop the animation when the last frame is reached|
|animation.modeRestart|Restart at the first frame for the next update after reaching the last frame|
|animation.modeReverse|Reverse the animation and step backward through the frames. When the first frame is reached, the animation will again reverse and run forward again|
|animation.modeRotateRight|Restarts the animation and automatically applies Mirroring and Rotation to the sprite for the next cycle through the animation. Using this with only two frames, one pointing up and the other pointing to the right at 45 degrees will allow a full rotation of the animated sprite through 8 positions.|
|animation.modeRotateLeft|Similar to `animation.modeRotateRight` except that it runs through the mirroring and rotation in reverse allowing for anti-clockwise rotation. Currently this does require a frame sequence that is pre-flipped, but this functionality will be enhanced. `stopAfter` will stop the animation after the specified number of frames have been completed. As an example you could the rotation animation, run through `n` steps of the animation before it stops as part of a dying sequence for a game character.|

## Game Objects
include <gameobj.i.asm>

Game objects tie the sprites and the animation system together. By creating a game object with a specified sprite and optional animation the animation engine will use the specified animation to control the sprite pattern to create the desired visual effect.

### Macros
As with sprites, the API for the game objects is exposed through a set of macros.

|Macro|Parameters|Description|
|-----|----------|-----------|
|gameobj.StartDefinition||Starts the block where game objects are defined. The block must be terminated with gameobj.EndDefinition|
|gameobj.EndDefinition||Ends the game object definition block. All game objects must be defined in the game object definition block|
|gameobj.Define|sprite, animation|Defines a game object with the specified sprite that will be used to render the object and the animation used to control the visuals of the game object. If no animation is required you can pass `gameobj.noAnimation` as an argument.|
|gameobj.UpdateAll||Updates all the game objects. This runs the animation engine for each object updating the in memory sprite data, once all that is done the sprite data is sync'd to the hardware|
|gameobj.Show|obj|Makes the specified game object visible|
|gameobj.Hide|obj|Hides the specified game object|
|gameobj.SetPos|obj, xpos, ypos|Set the screen position of the specified game object.`xpos` is a 9-bit value, `ypos` is a 8-bit value|
|gameobj.SetAnimation|obj, animation, flags|Changes the animation associated with the game object. In addition flags can be passed to apply any mirroring or rotation. Note when using an animation with `animation.modeRotate` the animation rotation will override this. The possible flags currently include the following that can be combined with an `or` operator.|

Flags for the `gameobj.SetAnimation` macro
|Flag|Description|
|----|-----------|
|gameobj.flagRotateSet|Sets the rotate flag|
|gameobj.flagMirrorYSet|Sets the Mirror-Y flag|
|gameobj.flagMirrorXSet|Sets the Mirror-X flag|

