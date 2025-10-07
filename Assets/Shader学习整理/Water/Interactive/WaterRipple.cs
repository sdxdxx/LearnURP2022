using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterRipple : MonoBehaviour
{
    public GameObject Player;
    public GameObject Water;
    public GameObject Ripple;
    public float WaitTime = 1f;
    private float timelock = 0;
    public float playerPositionYBias = 0;
    
    private void Update()
    {
        if (Player == null || Water == null || Ripple == null)
        {
            return;
        }
        
        Ripple.transform.position = new Vector3(Player.transform.position.x, Water.transform.position.y, Player.transform.position.z);
        
        if ((Player.transform.position.y+playerPositionYBias) < Water.transform.position.y)
        {
            
            Ripple.SetActive(true);
            timelock = Time.time + WaitTime;
        }
        else
        {
            if (Time.time > timelock)
            {
                Ripple.SetActive(false);
            }
        }

    }
}
