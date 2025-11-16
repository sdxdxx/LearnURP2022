using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

public class MoveAround : MonoBehaviour
{
    public float speed;
    public Transform[] targets;
    
    private Vector3 targetDirection = Vector3.zero;
    
    
    private Transform target;
    public int index = 0;
    void Start()
    {
        target = targets[index];
        targetDirection = target.position - transform.position;
        targetDirection.Normalize();
    }

    // Update is called once per frame
    void Update()
    {
        transform.position += targetDirection * speed * Time.deltaTime;
        
        Vector3 realDirection = target.position - transform.position;
        
        if (Vector3.Dot(realDirection,targetDirection)<=0)
        {
            if (index<targets.Length-1)
            {
                index++;
            }
            else
            {
                index = 0;
            }
            
            target = targets[index];
            targetDirection = target.position - transform.position;
            targetDirection.Normalize();
            
        }
    }
}
