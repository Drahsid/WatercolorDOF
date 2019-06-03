using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Skydome : MonoBehaviour
{
    private float yaw = 0;

    void FixedUpdate()
    {
        this.transform.rotation = Quaternion.Euler(0, yaw, 0);
        yaw = yaw + 0.01f;
    }
}
