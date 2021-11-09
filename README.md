Pile of Shaders <!-- omit in toc -->
======

Exactly what it says on the tin. Just a collections of hopefully at least somewhat interesting shaders I've written/will write in various different projects. They're not production ready at all and usually also pretty inefficient.

These will (probably) all come from Unity projects across various versions I'm not even keeping track of. Things may work, or may not work in your version. I'm also going for "works on my machine"-approach, not using the proper tools like [`UNITY_REVERSED_Z` and friends](https://docs.unity3d.com/Manual/SL-PlatformDifferences.html). These shaders are very much not production ready.

Also, they're in just one giant unorganised pile. Mainly because some things will probably be dependencies of multiple other things, without me knowing about it just yet.

Note that almost everything here is [unlicense](./UNLICENSE)-licensed. Go ham. Except if that ham lives in the realm of production ready software, as I might not have mentioned yet they are not of that quality. The files not unlicensed have their source mentioned at the top of their files, and are also listed here for convenience:

* [`Distributions.cginc`](./Distributions.cginc) has been modified from <https://www.chilliant.com/rgb2hsv.html>
* [`xoshiroplus.cginc`](./xoshiroplus.cginc) has been modified from <https://vigna.di.unimi.it/xorshift/> via [CC0](http://creativecommons.org/publicdomain/zero/1.0/).


Table of Contents <!-- omit in toc -->
======
- [Palette Generator](#palette-generator)
- [Sketch Outline](#sketch-outline)

Palette Generator
======
![](thumbnails/palette-generator.png)

Main shader files: [`Palette.shader`](./Palette.shader) + [`PaletteContent.cginc`](./PaletteContent.cginc), [`PaletteGenerator.cginc`](./PaletteGenerator.cginc)  
Dependencies: [`ColorSpaces.cginc`](./ColorSpaces.cginc), [`Distributions.cginc`](./Distributions.cginc), [`xoshiroplus.cginc`](./xoshiroplus.cginc)  
Preview: [Youtube](https://youtu.be/3f-_7IJsX74) (No audio)

A shader that can generate monochromatic, complementary, analogous, etc. palettes. Also has the option to get discrete brighter/darker shades (which have a bit of hue-shifting to make it look nicer). They are displayed in a simple grid, but the `palette` struct defined in `PaletteGenerator.cginc` contains everything needed to do more than just displaying a simple grid.

Sketch Outline
======
![](thumbnails/sketch-outline.png)

Main shader files: [`SketchOutline.shader`](./SketchOutline.shader) + [`SketchOutlineContent.cginc`](./SketchOutlineContent.cginc) (Pass 1) + [`SketchOutlineContent2.cginc`](./SketchOutlineContent2.cginc) (Pass 2)  
Dependencies: [`xoshiroplus.cginc`](./xoshiroplus.cginc), `UnityCG.cginc`  
Preview: All red/black portions (usually in just the peripherals) in [this video](https://youtu.be/8FtlRY6haUI) (Audio warning!)

A shader that renders geometry by wireframes that look messily sketched out. (Compare this to most wireframe shaders that just draw straight thin lines.) This shader is *very* expensive, drawing up to seven triangles per triangle. Six of those are generated in a geometry shader, and geometry shaders aren't known for their speed. This shader is a fun one for working nontrivially with all coordinate spaces you can encounter while writing shaders.

One of the things the shader needs to have passed is the textures of the sketched out lines. The texture I used can be found at [SketchOutlineLines.png](./SketchOutlineLines.png). Import that without discarding any transparent pixel's information because all four channels are equally important.
