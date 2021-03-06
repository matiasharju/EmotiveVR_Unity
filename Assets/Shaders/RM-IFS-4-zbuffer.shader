// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/Raymarcher-IFS-4-ZBuffer"
{
	Properties
	{
		 [NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}
		 _iterations ("Iteration Count", int) = 4
		 _baseSpeed ("Global Animation Speed", float) = 0.1
         _globalTime ("Global Time", float) = 0.0

        // Z buffer
        
        
         // VR Parameters
         //_rightHandPosition ("Right Hand", float4) = float4(0.0,0.0,0.0,0.0)
         _rightHandX ("Right Hand X", float) = 0.0
         _rightHandY ("Right Hand Y", float) = 0.0
         _rightHandZ ("Right Hand Z", float) = 0.0


         // Raymarcher parameters
         _maxSteps ("Max Steps", float) = 90
         _maxDistance ("Max Distance", float) = 200
         _travelMultiplier ("Travel Multiplier", float) = 1
         _touchDistanceMultiplier ("Touch Distance Multiplier", float) = 0.001

         // Mandelbox parameters (ei käytössä tässä)
         _foldValue ("Fold Value", float) = 2

         // IFS Rotations
         _foldRotateXY ("Fold Rotation XY", float) = 0
         _foldRotateXZ ("Fold Rotation XZ", float) = 0
         _foldRotateYZ ("Fold Rotation YZ", float) = 0


	}
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
            #include "DE-Operations.cginc"
            #include "DE-Primitives.cginc"
            
            // Z buffer
            uniform sampler2D _CameraDepthTexture;

            
            //uniform float4 _rightHandPosition;
            float _rightHandX;
            float _rightHandY;
            float _rightHandZ;
            float3 rightHandPosition = float3(0,0,0); 

                        // uniform keyword käytössä vain selkeyden vuoksi.
			int foldCount;
            uniform int _iterations;
			uniform float _baseSpeed; 
            uniform float _globalTime;

            // Raymarcher parameters
            uniform float _maxSteps;
            uniform float _maxDistance;
            uniform float _travelMultiplier;
            uniform float _touchDistanceMultiplier;

            // Fractal rotations
            uniform float _foldRotateXY;
            uniform float _foldRotateXZ;
            uniform float _foldRotateYZ;

            int elementID;

			struct appdata
			{
				float4 vertex : POSITION; // vertex position
				float2 uv : TEXCOORD0;	  // texture coordinate
			};

			struct v2f  // vertex to fragment
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION; // clip space position (mikä?)
				float3 viewDirection : TEXCOORD1;
			};

			// vertex shader
			v2f vert (appdata v)
			{
				v2f output;
				// multiply with model*view*projection matrix
				output.vertex = UnityObjectToClipPos(v.vertex);
				output.uv = v.uv;
				output.viewDirection = WorldSpaceViewDir(v.vertex);

				return output;
			}

			// texture we will sample
			sampler2D _MainTex;


			float scaletester(float input) {
				if (input > 1) return 0;
				if (input < 0) return 1;
				return input * 0.5 + 0.25;
			}

			// square wave
			int sqw(float x) {
				return max(0, int(sin(x)+1));
			}

            // IFS iterator
			float3 foldIterator(float3 p) {
				for (int i = 0; i < _iterations; i++) {
					//p = orientation * p; // orientation ei ole mukana
					float3 foldNormal; // = float3(1,0,0);

					p -= float3(0, sin(_globalTime), 0);
					if (i%3 == 2) {
						foldNormal = float3(cos(_globalTime * 1.0) * _foldRotateXY, 
									 		-sin(_globalTime * 1.0) * _foldRotateXZ,
									 		0);
			 		} else {
			 			foldNormal = float3(0,
									 		-sin(_globalTime * 1.0 * _foldRotateXZ),
									 		cos(_globalTime * 1.0) * _foldRotateYZ);
					}
					p -= 2.0 * min((sin(_globalTime) + 2.0) * 0.1, dot(p, foldNormal)) * foldNormal;
					p = mul(rotateXZ(sin(_globalTime)), p);
					//p = mul(rotateXZ(viewDirection.angle.y), p);

					if (dot(p, foldNormal) > 0) {
						foldCount += 1;
					}


				    } 
				return p;
			}

			// Distance estimator
			float distanceEstimator(float3 position) {

				foldCount = 0;
				float3 p = position - float3(1, 3, 2.5);
                rightHandPosition = float3(_rightHandX,_rightHandY,_rightHandZ);
				p = foldIterator(p);

                p = mul(rotateXY(_foldRotateXY), p);
                p = mul(rotateXZ(_foldRotateXZ), p);
                p = mul(rotateYZ(_foldRotateYZ), p);

				float element1 = sphere(p, float(0.3));
				float elementSlab = box(position - float3(0.1, -0.25, 1.8), float3(4.0, 0.2, 4.0)); //Slab
                float rightHand = sphere(position + float3(0,0,0), float(0.4));
                
                float frontElement = element1;
                elementID = 1;
                if (elementSlab < frontElement) {
                    frontElement = elementSlab;
                    elementID = 2;
                }
                if (10000 < frontElement) {
                    frontElement = rightHand;
                    elementID = 3;
                }
                return frontElement;
				//return min(element1, element2);
			}

            fixed4 raymarch(float3 eyePosition, float3 viewDirection, float zBuffer) {
                // Raymarch parameters
                float maxSteps = 64; // maxstep
                float3 rayPosition = eyePosition;  // t
                float maxDistance = 40;
                float travelMultiplier = 0.25;
                float touchDistanceMultiplier = 0.001;
                
                // Raymarch initiliazation
                float stepNumber = 0;
                float travelDistance = 0;
                float distanceToSurface;
                float touchDistance;
                
                // Actual raymarching
                while ((stepNumber == 0) ||
                       (travelDistance < _maxDistance &&
                        travelDistance < zBuffer &&
                        distanceToSurface > touchDistance &&
                        stepNumber < _maxSteps) ) {
                           stepNumber += 1;
                           rayPosition = eyePosition + travelDistance * viewDirection;
                           distanceToSurface = distanceEstimator(rayPosition);
                           travelDistance += travelMultiplier * distanceToSurface;
                           touchDistance = travelDistance * _touchDistanceMultiplier;
                       }
                bool didHitSurface = distanceToSurface <= touchDistance;
                float brightness = (maxSteps - stepNumber)/maxSteps;

                // Background color
                if (!didHitSurface) {
                    //brightness = 1 - brightness;
                    brightness = pow(brightness, 3.4);  // pow 1.4 was the earlier default
                    return fixed4(pow(brightness, 2), pow(brightness, 0.9), pow(brightness, 0.7), 1);
                    //return fixed4(1.0, 1.0, 1.0, 1.0);
                }
                brightness = log(stepNumber) / log(maxSteps);
                brightness = pow(brightness, 4);
                return fixed4(brightness.xxxx);
            }
            
			// pixel shader - returns low precision "fixed4" type
			fixed4 frag (v2f input) : SV_Target
			{
                float3 eyePosition = _WorldSpaceCameraPos;
                float3 viewDirection = -normalize(input.viewDirection);

                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, input.uv).r);
                depth *= length(input.viewDirection);
                fixed3 color = tex2D(_MainTex, input.uv);
                fixed4 add = raymarch(eyePosition, viewDirection, depth);
               
                // Element colors
                if (elementID == 1) {
				    color = fixed3(1, 1, 1);
                } else if (elementID == 2) {
                    color = fixed3(0.1, 0.1, 0.1);
                } else {
                    color = fixed3(0.1, 0.1, 0.7);
                }
                
                return fixed4(color * add, 1.0);
			}
			ENDCG
		}
	}
}
