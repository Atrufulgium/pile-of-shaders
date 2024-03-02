using System;
using UnityEditor;
using UnityEngine;

[CustomPropertyDrawer(typeof(ColorMap))]
public class ColorMapPropertyDrawer : PropertyDrawer, IDisposable {

    Texture2D tex = null;
    bool showMap = false;

    void Setup(SerializedProperty property) {
        tex = new(128, 128);

        var colorMap = RecreateColorMap(property);
        colorMap.FillTextureCPU(tex);
    }

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label) {
        if (tex == null) {
            Setup(property);
        }

        // So actually grabbing the class is stupidly hard and requires reflection.
        // (Unless you're in 2022 and have `boxedValue`.)
        // Just recreate it.
        // Sigh.
        var colorMap = RecreateColorMap(property);

        GUIStyle customLabel = new(EditorStyles.foldout) {
            alignment = TextAnchor.UpperLeft
        };
        var plural = colorMap.Count == 1 ? "" : "s";
        GUIContent header = new($"{label.text} (Color map with {colorMap.Count} color{plural})", label.tooltip);
        bool newShowMap = EditorGUI.Foldout(position, showMap, header, toggleOnLabelClick: false, customLabel);
        bool openedFold = !showMap & newShowMap;
        showMap = newShowMap;

        if (showMap) {
            position = position.ShrinkLeft(14).ShrinkTop(18);

            var idwHeight = EditorGUI.GetPropertyHeight(property.FindPropertyRelative("idwExponent"));
            var listHeight = EditorGUI.GetPropertyHeight(property.FindPropertyRelative("list"));

            var previewPosition = position.WithHeight(148);
            EditorGUI.DrawRect(previewPosition, new(0.19f, 0.19f, 0.19f));
            var idwPosition = previewPosition.ShrinkTop(148).WithHeight(idwHeight);
            var listPosition = idwPosition.ShrinkTop(idwHeight).WithHeight(listHeight);

            var idwProperty = property.FindPropertyRelative("idwExponent");
            var listProperty = property.FindPropertyRelative("list");

            EditorGUI.BeginChangeCheck();
            EditorGUI.PropertyField(idwPosition, idwProperty, new GUIContent("IDW Exponent", "Controls colour intensity falloff.\nLow values merge quickly.\nHigh values look like a Voronoi diagram."));
            EditorGUI.PropertyField(listPosition, listProperty, new GUIContent("Key Colours"));
            bool refreshTexture = EditorGUI.EndChangeCheck() | openedFold;
            float excessWidth = (previewPosition.width - 130) / 2;
            previewPosition = previewPosition.ShrinkLeft(excessWidth).ShrinkRight(excessWidth).WithHeight(130);
            EditorGUI.DrawPreviewTexture(previewPosition, tex);

            // Stupid axis labels
            var labelXPosition = previewPosition.Extend(0, 18).ShrinkTop(130);
            customLabel = new(EditorStyles.label);
            customLabel.richText = true;
            EditorGUI.LabelField(labelXPosition, new GUIContent("<i>→ X axis: input R</i>"), customLabel);
            var labelYPosition = previewPosition.ShrinkTop(130 - 18);
            var pivotRotation = new Vector2(labelYPosition.xMin, labelYPosition.yMax);
            EditorGUIUtility.RotateAroundPivot(-90, pivotRotation);
            EditorGUI.LabelField(labelYPosition, new GUIContent("<i>→ Y axis: input G</i>"), customLabel);
            EditorGUIUtility.RotateAroundPivot(90, pivotRotation);

            // Transpose button
            var buttonPosition = previewPosition.Move(-18, 0).WithWidth(18).WithHeight(18);
            bool transposeTexture = GUI.Button(buttonPosition, new GUIContent("⇗", "Transpose color texture."));
            refreshTexture |= transposeTexture;
            if (transposeTexture) {
                foreach (SerializedProperty entry in listProperty) {
                    var xProperty = entry.FindPropertyRelative("x");
                    var yProperty = entry.FindPropertyRelative("y");
                    var x = xProperty.intValue;
                    var y = yProperty.intValue;
                    xProperty.intValue = y;
                    yProperty.intValue = x;
                }
            }

            // Manual refresh button
            buttonPosition = labelXPosition.Move(-18, 0).WithWidth(18);
            refreshTexture |= GUI.Button(buttonPosition, new GUIContent("↺", "Refresh color map preview.\n(For performance reasons, changes from outside\nhere are not detected, in which case you can use\nthis button to manually refresh.)"));

            if (refreshTexture) {
                colorMap = RecreateColorMap(property);
                colorMap.FillTextureCPU(tex, true);
            }
        }
    }

    public override float GetPropertyHeight(SerializedProperty property, GUIContent label) {
        if (!showMap)
            return base.GetPropertyHeight(property, label);
        float res = 18 + 130 + 18;
        res += EditorGUI.GetPropertyHeight(property.FindPropertyRelative("idwExponent"));
        res += EditorGUI.GetPropertyHeight(property.FindPropertyRelative("list"));
        return res;
    }

    // Supposedly for image troubles
    //public override bool CanCacheInspectorGUI(SerializedProperty property) => false;

    public void Dispose() {
        // If I ever switch to rendertextures
    }

    ColorMap colorMap = new();
    ColorMap RecreateColorMap(SerializedProperty property) {
        colorMap.idwExponent = property.FindPropertyRelative("idwExponent").floatValue;
        colorMap.Clear();
        foreach (SerializedProperty entry in property.FindPropertyRelative("list")) {
            var x = entry.FindPropertyRelative("x").intValue / 65535f;
            var y = entry.FindPropertyRelative("y").intValue / 65535f;
            var r = entry.FindPropertyRelative("r").intValue / 255f;
            var g = entry.FindPropertyRelative("g").intValue / 255f;
            var b = entry.FindPropertyRelative("b").intValue / 255f;
            var a = entry.FindPropertyRelative("weight").intValue / 255f;
            colorMap.Add(new(new(x, y), new Color(r, g, b, a)));
        }
        return colorMap;
    }
}

[CustomPropertyDrawer(typeof(ColorMapEntry))]
public class ColorMapEntryDrawer : PropertyDrawer {

    readonly GUIContent[] posGUILabels = new[] {
    new GUIContent("X", "Input horizontal / red channel axis."),
    new GUIContent("Y", "Input vertical / green channel axis.")
};

    readonly GUIContent colGUILabel = new("Color", "Resulting color to turn into.");

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label) {
        // Handling these as ints is fine even though they're ushorts/bytes.
        var xProperty = property.FindPropertyRelative("x");
        var yProperty = property.FindPropertyRelative("y");
        var rProperty = property.FindPropertyRelative("r");
        var gProperty = property.FindPropertyRelative("g");
        var bProperty = property.FindPropertyRelative("b");
        var aProperty = property.FindPropertyRelative("weight");

        // Position part
        Rect posRect = position.ShrinkRight(100);

        float[] posses = new float[] {
        xProperty.intValue / 65535f,
        yProperty.intValue / 65535f
    };

        EditorGUI.BeginChangeCheck();
        EditorGUI.MultiFloatField(posRect, posGUILabels, posses);
        if (EditorGUI.EndChangeCheck()) {
            posses[0] = Mathf.Clamp01(posses[0]);
            posses[1] = Mathf.Clamp01(posses[1]);
            xProperty.intValue = (ushort)(posses[0] * 65535);
            yProperty.intValue = (ushort)(posses[1] * 65535);
        }

        // Color part
        Rect colRect = position.ShrinkLeft(posRect.width + 10)
            .WithWidth(90);

        Color col = new Color(rProperty.intValue, gProperty.intValue, bProperty.intValue, aProperty.intValue) / 255f;

        EditorGUI.BeginChangeCheck();
        var oldLabelWidth = EditorGUIUtility.labelWidth;
        EditorGUIUtility.labelWidth = 35;
        col = EditorGUI.ColorField(colRect, colGUILabel, col);
        EditorGUIUtility.labelWidth = oldLabelWidth;
        if (EditorGUI.EndChangeCheck()) {
            col = col.Clamp01();
            rProperty.intValue = (byte)(col.r * 255f);
            gProperty.intValue = (byte)(col.g * 255f);
            bProperty.intValue = (byte)(col.b * 255f);
            aProperty.intValue = (byte)(col.a * 255f);
        }
    }