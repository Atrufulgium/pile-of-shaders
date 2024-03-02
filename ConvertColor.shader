Shader "Hidden/ConvertColor"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    // (All passes seperately called via Blit. See ColorConverterBehaviour.cs.)
    SubShader
    {
        Cull Off ZWrite Off ZTest Off

        Pass
        {
            Name "Color Map Pass"

            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            sampler2D _MainTex;
            sampler2D _color_map;

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                fixed4 col = tex2D(_MainTex, uv);
                col = tex2D(_color_map, col.rg);
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Bloom Color Grab Pass"

            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            // Downscaled unprocessed
            sampler2D _MainTex;
            // Previous pass' result
            sampler2D _camera_active2;
            // TODO: global bloom scale factor

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                float amount = tex2D(_MainTex, uv).b;
                fixed4 col = tex2D(_camera_active2, uv);
                col.rgb *= amount;
                col.a = amount;
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Bloom Blur X Pass"

            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            // Previous pass' result
            sampler2D _MainTex;
            float4  _MainTex_TexelSize;
            // See https://www.rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
            // tl;dr: Gaussian blur with less texture samples by abusing bilinear filtering.
            static const float offset[3] = { 0.0, 1.3846153846, 3.2307692308 };
            static const float weight[3] = { 0.2270270270, 0.3162162162, 0.0702702703 };

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                fixed4 c = tex2D(_MainTex, uv) * weight[0];
                float2 t = _MainTex_TexelSize.xy;
                [unroll]
                for (int s = 1; s < 3; s++) {
                    c += tex2D(_MainTex, uv + t*float2(offset[s], 0)) * weight[s];
                    c += tex2D(_MainTex, uv - t*float2(offset[s], 0)) * weight[s];
                }
				return c;
            }
            ENDCG
        }

        Pass
        {
            Name "Bloom Blur Y Pass"

            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            sampler2D _MainTex;
            float4  _MainTex_TexelSize;
            static const float offset[3] = { 0.0, 1.3846153846, 3.2307692308 };
            static const float weight[3] = { 0.2270270270, 0.3162162162, 0.0702702703 };

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                fixed4 c = tex2D(_MainTex, uv) * weight[0];
                float2 t = _MainTex_TexelSize.xy;
                [unroll]
                for (int s = 1; s < 3; s++) {
                    c += tex2D(_MainTex, uv + t*float2(0, offset[s])) * weight[s];
                    c += tex2D(_MainTex, uv - t*float2(0, offset[s])) * weight[s];
                }
				return c;
            }
            ENDCG
        }

        Pass
        {
            Name "Combine Camera and Bloom Pass"
            
            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            // Color-corrected camera without bloom
            sampler2D _MainTex;
            // Bloom to overlay, previous pass' result
            sampler2D _bloom_temp2;

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                // Unity also flips stuff at some point.
                // Fix that.
                #if UNITY_UV_STARTS_AT_TOP
                    uv.y = 1 - uv.y;
                #endif

                fixed4 col = saturate(tex2D(_MainTex, uv));
                fixed4 glow = saturate(tex2D(_bloom_temp2, uv));
                // Whatever blendmode seems nice, play around
                //col.rgb = 1 - (1 - col.rgb) * (1 - glow.rgb);
                col.rgb = glow.rgb + col.rgb * (1 - glow.a);
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Because the Blit(scale, offset) overload doesn't work-Pass"
            
            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            sampler2D _MainTex;

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                fixed4 col = tex2D(_MainTex, uv);
                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Compute Color Map Pass"

            CGPROGRAM
            #pragma fragment frag
            #include "ImageEffect.cginc"

            // Mirrored on the CPU side in ColorConverterBehaviour.cs.
            struct BufferEntry {
                float4 color;
                float2 position;
            };
            StructuredBuffer<BufferEntry> _color_buffer;
            int _color_buffer_length;
            float _idw_exponent;

            const float epsilon = 0.00001;

            fixed4 frag (float2 uv : TEXCOORD) : SV_Target {
                fixed4 numerator = float4(0,0,0,1);
                float denominator = 0;
                for (int i = 0; i < _color_buffer_length; i++) {
                    float2 pos = _color_buffer[i].position;
                    float4 col = _color_buffer[i].color;

                    float2 delta = uv - pos;
                    float dSq = dot(delta, delta) + epsilon;
                    if (_idw_exponent != 2)
                        dSq = pow(dSq, _idw_exponent * 0.5);
                    dSq += epsilon;

                    float weight = 1 / dSq;
                    weight *= col.a;
                    numerator.rgb += weight * col.rgb;
                    denominator += weight;
                }
                
                return numerator / denominator;
            }
            ENDCG
        }
    }
}
