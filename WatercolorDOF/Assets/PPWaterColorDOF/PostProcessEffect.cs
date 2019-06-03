using UnityEngine;
using System;


[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class PostProcessEffect : MonoBehaviour
{
    public Material Mat;
    [Range(0f, 255f)]
    public float focusDistance = 10f;
    [Range(0f, 24f)]
    public float focusRange = 3f;
    [Range(0.01f, 16f)]
    public float maxDepthBlur = 6f;

    private void OnRenderImage(RenderTexture _source, RenderTexture _destination)
    {
        Mat.SetFloat("_FocusDistance", focusDistance);
        Mat.SetFloat("_FocusRange", focusRange);
        Mat.SetFloat("_MaxBlur", maxDepthBlur);

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



