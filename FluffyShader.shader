Shader "Custom/FluffyShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        [Header(Fur Properties)]
        // The .xyz is normalized.
        _Direction("Tangent Fur Dir [XYZ], Hair Length (cm) [W]", Vector) = (0,1,0,5)
        _Variance("Fur Variance (%)", Range(0,20)) = 0
        [PowerSlider(2.5)] _Detail("Detail", Range(1,64)) = 10

        [Header(Mesh)]
        _Phong_Mesh_Smoothing("Mesh Smoothing", Range(0,1)) = 0.5
        [Toggle(_USE_MODEL_TANGENTS)] _UsingTangentUghNiceKeyword("Use Model Tangents", Float) = 1

        [Header(Standard Shader Properties)]
        _Color("Color", Color) = (1,1,1,1)

        // Using this makes no sense, but if I use Unity's default shader, it
        // must exist. So set it to always be zero.
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.0

        [Toggle(_EMISSION)] _EmissionIsEnabledUghNiceKeyword("Enable Emission", Float) = 0
        _EmissionColor("Emission Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Lighting On

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            Cull Back

            CGPROGRAM
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ _USE_MODEL_TANGENTS

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag
            
            #define FLUFFY_FORWARD_PASS
            #include "FluffyContent.cginc"
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }

            Cull Back
            Blend One One
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile _ _USE_MODEL_TANGENTS

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag
            
            #define FLUFFY_ADD_PASS
            #include "FluffyContent.cginc"
            ENDCG
        }

        Pass
        {
            Tags { "LightMode" = "ShadowCaster" }

            Cull Off
            ZWrite On
            ZTest LEqual

            CGPROGRAM
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma multi_compile_shadowcaster
            #pragma multi_compile _ _USE_MODEL_TANGENTS

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment fragShadowCaster

            #define FLUFFY_SHADOW_PASS
            #include "FluffyShadowContent.cginc"
            ENDCG
        }
    }
    FallBack "Standard"
}
