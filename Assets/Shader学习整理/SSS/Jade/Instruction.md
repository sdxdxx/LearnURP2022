# 说明

1\. 请在不透明物体渲染前, 将Pass `DiffuseBRDF ` 渲染到 `_DiffuseBRDF`(贴图格式为`ARGB32`)中, 将Pass `SSSMask` 渲染到 `_SSSMask`(贴图格式为`R8`)中

2\. `Subsurface Scattering Range`控制SSS背面透光的范围

3\.  `NormalDistortion` 控制SSS背面透光的法线扰动强度

4\.  `Scatter Distance(RGB)` 对应 **Burley Normalized SSS** 公式里面的  *d* 值, 因为散射在RGB三个颜色的值和效果在不同的材质是不同的, 所以要设置相应的值

5\. `Max Sample Distance Scale` 理论上应该是使用`c#`根据`Scatter Distance(RGB)`进行计算的, 但是这里为了图方便就使用Slider手动调节了, 其是控制光线最远可以散射到多远


