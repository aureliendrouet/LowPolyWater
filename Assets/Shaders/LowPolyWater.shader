﻿Shader "Custom/LowPolyWater (Sum of Sines)"
{
    Properties
    {
        _AlbedoTex("Albedo", 2D) = "white" {}
        _AlbedoColor("Albedo Color", Color) = (1, 1, 1, 1)
        _SpecularColor("Specular Color", Color) = (0, 0, 0, 0)
       	_Shininess ("Shininess", Float) = 10
    }
    SubShader
    {
        Tags{ "RenderMode" = "Opaque" "Queue" = "Geometry" "LightMode" = "ForwardBase" }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct VS_Input
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct VS_Output
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posWorld : WORLDPOSITION;
                float3 normalDir : NORMAL;
                float4 color : COLOR;
            };

            static const float PI = float(3.14159);

            // SineWave definition
            // x = amplitude, y = frequency, z = phase, w = direction angle
            uniform float4 _SineWave[8];
            uniform int _Waves;
            uniform float _TimeScale;
            // properties input
            sampler2D _AlbedoTex;
            float4 _AlbedoTex_ST;
            fixed4 _AlbedoColor;
            fixed4 _SpecularColor;
            float _Shininess;

            float Wave(int i, float x, float y)
            {
                float A = _SineWave[i].x; 										// amplitude
				float O = _SineWave[i].y; 										// frequency
                float P = _SineWave[i].z; 										// phase
                float2 D = float2(cos(_SineWave[i].w), sin(_SineWave[i].w));	// direction
                return A * sin(dot(D, float2(x,y)) * O + _Time.x * _TimeScale * P);
            }

            float WaveHeight(float x, float y)
            {
                float height = 0.0;

                for(int i = 0; i < _Waves; i++)
                {
                    height += Wave(i, x, y);
                }

                return height;
            }

            VS_Output vert(VS_Input v)
            {
                VS_Output o = (VS_Output)0;
                // Water simulation
                v.vertex.xyz += v.normal * WaveHeight(v.vertex.x, v.vertex.z);
                // Space transform
                o.uv = TRANSFORM_TEX(v.uv, _AlbedoTex);
                o.normalDir = v.normal;
                o.posWorld = mul(_Object2World, v.vertex).xyz;
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
                // gourad specular
                float3 lightDirection;
                float3 normalDirection = normalize(mul(float4(v.normal, 0.0), _World2Object).xyz);

                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle VS_Output input[3], inout TriangleStream<VS_Output> OutputStream)
            {
                VS_Output test = (VS_Output)0;
                float3 planeNormal = normalize(cross(input[1].posWorld.xyz -
                                                	 input[0].posWorld.xyz,
                                                	 input[2].posWorld.xyz - 
                                                	 input[0].posWorld.xyz));
                // shading
                float3 normalDirection = normalize(mul(_World2Object, float4(planeNormal, 0.0f)));
                float3 lightDirection;

				if (0.0 == _WorldSpaceLightPos0.w) // directional light?
				{
					lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				}

				// diffuse intensity
				float nDotL = dot(normalDirection, lightDirection);
				float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * _AlbedoColor.rgb;
				float3 diffuse = _LightColor0.rgb * _AlbedoColor.rgb * max(0.0f, nDotL);
				float3 specular = float3(0.0f, 0.0f, 0.0f);

				if(nDotL > 0.0f)
				{
					float3 center = (input[0].posWorld + input[1].posWorld 
									+ input[2].posWorld) / 3.0f;
					float3 viewDir = normalize(_WorldSpaceCameraPos - center);
					float3 H = normalize(lightDirection + viewDir);
					// specular intensity
					float NdotH = pow(saturate(dot(normalDirection, H)), _Shininess);
					specular = _LightColor0.rgb * _SpecularColor.rgb * max(0.0f, NdotH);  
				}

				float4 final = float4(ambient + diffuse + specular, _AlbedoColor.a);

                for (int i = 0; i < 3; i++)
                {
					// pass values to fragment shader
                    test.normalDir = normalDirection;
                    test.pos = input[i].pos;
                    test.uv = input[i].uv;
                    test.color = final;
                    OutputStream.Append(test);
                }
            }

            fixed4 frag(VS_Output i) : SV_Target
            {
                // obtain surface color
                fixed4 col = tex2D(_AlbedoTex, i.uv) * i.color;
                return col;
            }
            ENDCG
        }
    }
    //Fallback "Diffuse"
}