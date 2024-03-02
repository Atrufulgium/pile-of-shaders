using UnityEngine;

public static class Extensionmethods {
    // Vector extensions
    public static Vector2 ToVector2(this (float, float) tuple)
        => new(tuple.Item1, tuple.Item2);

    public static Vector2Int ToVector2Int(this (int, int) tuple)
        => new(tuple.Item1, tuple.Item2);

    public static Vector3 ToVector3(this (float, float, float) tuple)
        => new(tuple.Item1, tuple.Item2, tuple.Item3);

    public static Vector3Int ToVector3Int(this (int, int, int) tuple)
        => new(tuple.Item1, tuple.Item2, tuple.Item3);

    public static Vector4 ToVector4(this (float, float, float, float) tuple)
        => new(tuple.Item1, tuple.Item2, tuple.Item3, tuple.Item4);

    public static Vector2 xy(this Vector3 v) => v;
    public static Vector2 yz(this Vector3 v) => new(v.y, v.z);
    public static Vector2 xz(this Vector3 v) => new(v.x, v.z);

    public static Vector2 WithX(this Vector2 v, float x) => new(x, v.y);
    public static Vector2 WithY(this Vector2 v, float y) => new(v.x, y);
    public static Vector3 WithX(this Vector3 v, float x) => new(x, v.y, v.z);
    public static Vector3 WithY(this Vector3 v, float y) => new(v.x, y, v.z);
    public static Vector3 WithZ(this Vector3 v, float z) => new(v.x, v.y, z);
    public static Vector4 WithX(this Vector4 v, float x) => new(x, v.y, v.z, v.w);
    public static Vector4 WithY(this Vector4 v, float y) => new(v.x, y, v.z, v.w);
    public static Vector4 WithZ(this Vector4 v, float z) => new(v.x, v.y, z, v.w);
    public static Vector4 WithW(this Vector4 v, float w) => new(v.x, v.y, v.z, w);

    // Rect extensions
    public static Rect Move(this Rect rect, Vector2 move)
        => new(rect.position + move, rect.size);

    public static Rect Move(this Rect rect, float x, float y)
        => rect.Move(new(x, y));

    public static Rect Extend(this Rect rect, Vector2 sizeChange)
        => new(rect.position, rect.size + sizeChange);

    public static Rect Extend(this Rect rect, float xChange, float yChange)
        => rect.Extend(new(xChange, yChange));

    public static Rect ShrinkLeft(this Rect rect, float amount)
        => new(rect.position + new Vector2(amount, 0), rect.size - new Vector2(amount, 0));

    public static Rect ShrinkRight(this Rect rect, float amount)
        => new(rect.position, rect.size - new Vector2(amount, 0));

    public static Rect ShrinkTop(this Rect rect, float amount)
        => new(rect.position + new Vector2(0, amount), rect.size - new Vector2(0, amount));

    public static Rect WithWidth(this Rect rect, float width)
        => new(rect.position, new Vector2(width, rect.height));

    public static Rect WithHeight(this Rect rect, float height)
        => new(rect.position, new Vector2(rect.width, height));

    public static Color Clamp01(this Color color)
        => new(Mathf.Clamp01(color.r), Mathf.Clamp01(color.g), Mathf.Clamp01(color.b), Mathf.Clamp01(color.a));
}