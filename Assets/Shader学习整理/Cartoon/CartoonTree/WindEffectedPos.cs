using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WindEffectedPos : MonoBehaviour
{
    private Material mat;
    void Start()
    {
        mat = gameObject.GetComponent<Renderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        mat.SetVector("_windEffectedPos",new Vector4(transform.position.x,transform.position.y,transform.position.z,0f));
    }
}
