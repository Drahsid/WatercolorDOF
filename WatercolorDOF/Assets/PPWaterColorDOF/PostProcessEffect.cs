using UnityEngine;
using System;


[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class PostProcessEffect : MonoBehaviour
{
    public Material Mat;

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        RenderTexture watercolor = RenderTexture.GetTemporary(
            _source.width, _source.height, 0,
            RenderTextureFormat.Default, RenderTextureReadWrite.Default
        );

        Mat.SetTexture("_WaterColorTex", watercolor);

        Graphics.Blit(_source, watercolor, Mat, 0);
        Graphics.Blit(_source, _destination, Mat, 1);

        RenderTexture.ReleaseTemporary(watercolor);
    }
}



