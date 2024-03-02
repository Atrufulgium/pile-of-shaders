using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// <para>
/// Represents a 2D square texture defined by smooth gradients between
/// specified colours at specified positions.
/// </para>
/// <para>
/// Having multiple entries at the same position gives undefined results.
/// </para>
/// </summary>
// This could be a more performant structure if we want a lot of entries.
// Doubt that though.
[Serializable]
public class ColorMap : IList<ColorMapEntry> {

    [SerializeField]
    private List<ColorMapEntry> list = new();
    /// <summary>
    /// Controls the speed of fall-off of colours. An exponent of <c>1</c>
    /// diffuses very quickly, while an exponent of for instance <c>32</c>
    /// makes it nearly look like a voronoi diagram.
    /// </summary>
    [SerializeField]
    [Range(0,32)]
    public float idwExponent = 2f;

    public int Count => list.Count;

    public ColorMapEntry this[int index] { get => list[index]; set => list[index] = value; }

    /// <summary>
    /// The color of the ColorMap when there are no entries.
    /// </summary>
    static readonly float4 emptyColor = new(1, 0, 1, 1);

    /// <summary>
    /// <para>
    /// Returns the index of the nearest ColorMapEntry to a given point.
    /// If there are multiple such points, the result is arbitrary.
    /// </para>
    /// <para>
    /// If the list is empty it will throw.
    /// </para>
    /// </summary>
    public int GetIndexOfNearest(float2 pos) {
        if (list.Count == 0)
            throw new InvalidOperationException("Empty ColorMap has no nearest point.");

        float bestDistSqr = float.PositiveInfinity;
        int bestIndex = -1;
        for (int i = 0; i < list.Count; i++) {
            var entry = list[i];
            float dstSqr = Vector2.SqrMagnitude(pos - entry.Position);
            if (dstSqr < bestDistSqr) {
                bestDistSqr = dstSqr;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    /// <summary>
    /// Overwrites a given texture with the data of list ColorMap.
    /// This is done on the CPU side.
    /// </summary>
    public void FillTextureCPU(Texture2D texture, bool drawDebugInfo = false) {
        // yeah list breaks on 1x1 textures but who's gonna pass a 1x1 texture
        float maxWidth = texture.width - 1;
        float maxHeight = texture.height - 1;

        var textureData = texture.GetPixelData<Color32>(0);
        for (int y = 0; y < texture.height; y++) { 
            for (int x = 0; x < texture.width; x++) {
                int index = x + texture.width * y;
                float2 indexPos = new(x / maxWidth, y / maxHeight);
                textureData[index] = GetColorAtPosition(indexPos);
                if (drawDebugInfo && list.Count > 0) {
                    var nearest = list[GetIndexOfNearest(indexPos)];
                    float dist = math.distance(nearest.Position, indexPos);
                    if (dist < 0.01) {
                        textureData[index] = nearest.Color;
                    } else if (dist < 0.015) {
                        textureData[index] = new(0, 0, 0, 255);
                    }
                }
            }
        }
        texture.SetPixelData(textureData, 0);
        texture.Apply();
    }

    static readonly int colorBufferID = Shader.PropertyToID("_color_buffer");
    static readonly int colorBufferLengthID = Shader.PropertyToID("_color_buffer_length");
    static readonly int idwID = Shader.PropertyToID("_idw_exponent");
    /// <summary>
    /// <para>
    /// Adds commands to a command buffer that tells it to fill the texture
    /// on the gpu. This does not use live ColorMap data.
    /// </para>
    /// </summary>
    /// <param name="cb">
    /// The buffer to put the commands into.
    /// </param>
    /// <param name="target">
    /// The texture that will contain the data.
    /// </param>
    /// <param name="blitMaterial">
    /// The shader that contains the pass that will be used with the blit
    /// to compute the target texture.
    /// </param>
    /// <param name="blitPass">
    /// The pass of <paramref name="blitMaterial"/> to use. See
    /// <see cref="CommandBuffer.Blit(RenderTargetIdentifier, RenderTargetIdentifier, Material, int)"/>
    /// for more info.
    /// </param>
    /// <param name="buffer">
    /// A buffer that must be disposed at the same time <paramref name="cb"/>
    /// is disposed.
    /// </param>
    public void FillTextureGPU(CommandBuffer cb, RenderTexture target, Material blitMaterial, int blitPass, out ComputeBuffer buffer) {
        buffer = new(Mathf.Max(1,list.Count), 4*6, ComputeBufferType.Structured);
        List<BufferEntry> entries = new(list.Count);
        foreach (var entry in list)
            entries.Add(new() { position = entry.Position, color = (float4)(Vector4)(Color)entry.Color });
        if (list.Count == 0)
            entries.Add(new() { position = 0, color = emptyColor });
        buffer.SetData(entries);
        // CommandBuffer.SetBufferData exists, is this live? If so, life is a lot easier.
        // (Though resizes every time are still necessary, hmm.)
        cb.SetGlobalBuffer(colorBufferID, buffer);
        cb.SetGlobalInt(colorBufferLengthID, entries.Count);
        cb.SetGlobalFloat(idwID, idwExponent);
        cb.Blit(null, target, blitMaterial, blitPass);
    }

    /// <summary>
    /// For use on the gpu. Note that this is very wasteful (you can
    /// implement <see cref="ColorMapEntry"/> with just two ints), but
    /// we're sending so little data it doesn't really matter.
    /// </summary>
    /// <remarks>
    /// Mirrored on the GPU in ConvertColor.shader.
    /// </remarks>
    [StructLayout(LayoutKind.Sequential)]
    private struct BufferEntry {
        public float4 color;
        public float2 position;
    }

    /// <summary>
    /// Swaps the X and Y position of every key in this map.
    /// </summary>
    public void Transpose() {
        for (int i = 0; i < list.Count; i++) {
            var entry = list[i];
            list[i] = new(entry.Position.yx, entry.Color);
        }
    }

    static readonly HashSet<float2> interpolationKeyCoords = new();
    static readonly HashSet<float2> keyCoordsMap1 = new();
    static readonly HashSet<float2> keyCoordsMap2 = new();
    /// <summary>
    /// <para>
    /// For <paramref name="t"/> ∈ [0,1], morphs from <paramref name="map1"/>
    /// to <paramref name="map2"/>. This is only a linear interpolation
    /// for the key vertices, the rest of the map does not linearly
    /// interpolate, it just changes smoothly.
    /// </para>
    /// <para>
    /// To reduce GC pressure, you can give an output map to store the
    /// results in, <paramref name="outputContainer"/>. This may not be one
    /// of the input color maps. This gives two styles of calling this:
    /// <code>
    ///     var result = ColorMap.Interpolate(map1, map2, t);
    ///     ColorMap.Interpolate(map1, map2, t, result);
    /// </code>
    /// </para>
    /// </summary>
    public static ColorMap Morph(ColorMap map1, ColorMap map2, float t, ColorMap outputContainer = null) {
        if (map1 == outputContainer || map2 == outputContainer)
            throw new ArgumentException("The given output container ColorMap is the same as one of the input ColorMaps. This is not supported.");
        if (t < 0 || t > 1)
            throw new ArgumentOutOfRangeException(nameof(t), $"Interpolation is only supported on [0,1], but got {t} instead.");

        interpolationKeyCoords.Clear();
        keyCoordsMap1.Clear();
        keyCoordsMap2.Clear();
        if (t < 1)
            foreach (var (pos, _) in map1)
                keyCoordsMap1.Add(pos);
        if (t > 0)
            foreach (var (pos, _) in map2)
                keyCoordsMap2.Add(pos);
        interpolationKeyCoords.UnionWith(keyCoordsMap1);
        interpolationKeyCoords.UnionWith(keyCoordsMap2);

        outputContainer?.Clear();
        outputContainer ??= new();

        // Linearly interpolating an exponent is very questionable, but eh.
        var exp = Mathf.Lerp(map1.idwExponent, map2.idwExponent, t);
        outputContainer.idwExponent = exp;

        foreach (float2 pos in interpolationKeyCoords) {
            Color res = Color.Lerp(
                map1.GetColorAtPosition(pos),
                map2.GetColorAtPosition(pos),
                t
            );
            // If we're in both maps, no need to interpolate the weight to/from 0.
            // Otherwise, we leave behind blobs that aren't part of the original
            // maps, so fade the effect out.
            if (!keyCoordsMap1.Contains(pos))
                res.a = t;
            else if (!keyCoordsMap2.Contains(pos))
                res.a = 1 - t;
            outputContainer.Add(pos, res);
        }

        return outputContainer;
    }

    /// <summary>
    /// <para>
    /// Creates a completely independent copy of a color map.
    /// </para>
    /// <para>
    /// To reduce GC pressure, you can give an output map to store the
    /// results in, <paramref name="outputContainer"/>. This may not be the
    /// input color map. This gives two styles of calling this:
    /// <code>
    ///     var result = ColorMap.DeepCopy(input);
    ///     ColorMap.DeepCopy(input, result);
    /// </code>
    /// </para>
    /// </summary>
    public static ColorMap DeepCopy(ColorMap map, ColorMap outputContainer = null) {
        if (map == outputContainer)
            throw new ArgumentException("The given output container ColorMap is the same as the input ColorMap, this is not supported.");

        outputContainer?.Clear();
        outputContainer ??= new();
        outputContainer.idwExponent = map.idwExponent;
        foreach (var entry in map.list)
            outputContainer.Add(entry);

        return outputContainer;
    }

    /// <summary>
    /// Computes an interpolated color at a given position in [0,1]^2.
    /// This value does not include weight (i.e. alpha is maxed).
    /// </summary>
    public Color32 GetColorAtPosition(float2 pos) {
        if (list.Count == 0)
            return (Color)(Vector4)emptyColor;

        float ε = 0.00001f;
        // inverse distance weighting, p=2 or custom
        Color resNumerator = Color.black;
        float resDenominator = 0;

        foreach (var (p,col) in list) {
            float dSq = math.distancesq(p, pos) + ε;
            if (idwExponent != 2)
                dSq = math.pow(dSq, idwExponent * 0.5f);
            dSq += ε;

            float weight = 1 / dSq;
            weight *= col.a / 255f;
            resNumerator += weight * (Color)new Color32(col.r, col.g, col.b, 255);
            resDenominator += weight;
        }
        return resNumerator / resDenominator;
    }

    public int IndexOf(ColorMapEntry item)
        => list.IndexOf(item);

    public void Insert(int index, ColorMapEntry item)
        => list.Insert(index, item);

    public void RemoveAt(int index)
        => list.RemoveAt(index);

    public void Add(float2 position, Color32 color)
        => Add(new(position, color));

    public void Add(ColorMapEntry item)
        => list.Add(item);

    public void Clear()
        => list.Clear();

    public bool Contains(ColorMapEntry item)
        => list.Contains(item);

    public bool Remove(ColorMapEntry item)
        => list.Remove(item);

    public IEnumerator<ColorMapEntry> GetEnumerator()
        => list.GetEnumerator();

    IEnumerator IEnumerable.GetEnumerator()
        => ((IEnumerable)list).GetEnumerator();

    void ICollection<ColorMapEntry>.CopyTo(ColorMapEntry[] array, int arrayIndex)
        => list.CopyTo(array, arrayIndex);

    bool ICollection<ColorMapEntry>.IsReadOnly => ((ICollection<ColorMapEntry>)list).IsReadOnly;
}

// Could've been `readonly` if unity didn't wasn't unity, tsk
[Serializable]
public struct ColorMapEntry : IEquatable<ColorMapEntry> {
    [SerializeField]
    ushort x;
    [SerializeField]
    ushort y;
    [SerializeField]
    byte r;
    [SerializeField]
    byte g;
    [SerializeField]
    byte b;
    [SerializeField]
    byte weight;

    /// <summary>
    /// The [0,1]^2 position of this entry on the Color Map.
    /// </summary>
    public float2 Position => new float2(x, y) / 65535f;
    /// <summary>
    /// The (r,g,b) color of this entry. The alpha channel contains the
    /// weight.
    /// </summary>
    public Color32 Color => new(r, g, b, weight);

    public void Deconstruct(out float2 position, out Color32 color) {
        position = Position;
        color = Color;
    }

    /// <summary>
    /// Create a Color Map Entry.
    /// </summary>
    /// <param name="pos"> A position ∈ [0,1]^2. </param>
    /// <param name="col"> A non-HDR color.  </param>
    public ColorMapEntry(Vector2 pos, Color32 col) : this(col) {
        CheckPos(pos);
        x = (ushort)(pos.x * 65535);
        y = (ushort)(pos.y * 65535);
    }

    /// <summary>
    /// Returns a copy of list ColorMapEntry but with a different color.
    /// </summary>
    public ColorMapEntry WithColor(Color32 col)
        => new(Position, col);

    private ColorMapEntry(Color32 col) {
        x = 0;
        y = 0;
        r = col.r;
        g = col.g;
        b = col.b;
        weight = col.a;
    }

    static void CheckPos(Vector2 pos) {
        if (pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1)
            throw new ArgumentException($"Both coordinates of {pos} must be in the [0,1]-range.");
    }

    public override bool Equals(object obj)
        => obj is ColorMapEntry cme && cme.Equals(this);

    public override int GetHashCode() {
        return HashCode.Combine(Position, Color);
    }

    public bool Equals(ColorMapEntry other)
        => other.x == x && other.y == y
        && other.r == r && other.g == g && other.b == b;
}