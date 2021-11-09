Shader "Custom/SketchOutline"
{
    Properties
    {
        // This texture is to have 8 vertical lines per channel.
        // In order of rgba, the lines should become shorter (but
        //  still stretched out to the full height).
        _LineTex("Line Texture", 2D) = "white" {}
        _Shrink("Inner Shrink", Range(0,1)) = 0.95
        _Thickness("Thickness", Range(0,1)) = 0.01
        _UpdateSpeed("Update Speed", Range(1,60)) = 2
        _DotRange("Right Angle Requirement", Range(0,1)) = 0.1
        _InnerColor("Inner Color", Color) = (0,0,0,1)
        _OuterColor("Outer Color", Color) = (1,0,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        // The black inner pass.
        Pass
        {
            Cull Back
            Blend One OneMinusSrcAlpha

            CGPROGRAM
            #include "SketchOutlineContent.cginc"
            ENDCG
        }

        // The wireframe outer pass.
        Pass
        {
            Cull Off
            ZWrite Off
            Blend One OneMinusSrcAlpha

            CGPROGRAM
            #include "SketchOutlineContent2.cginc"
            ENDCG
        }
    }
}
