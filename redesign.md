我觉得需要重新设计，细化一下：
1. 拆分现在的节点类型
2. 去掉 Scatter Group，Instances就是最终输出
3. 最终输出就是多个Instances的Merge
4. 其余的节点使用下面的关系

```typescript

// coordinate
enum Space {
    Global,     // global coord
    Local,      // multimesh coord
    Instance,   // instance coord
}

```

```typescript

// Graph's final output is type Instances

interface Instances {
    transforms : Transforms3D[]; // Space.Local's transform
    colors : Color[];            // instance colors
    // ...other instance data
}

// Base shape in Global or Local
interface Shape {
    space : Omit<Space, Space.Instance>; // coordinate
    contain(point: Vector3): bool;       // point in Space.Local
}

interface Region extends Shape {}
interface Path extends Shape {
    sample(val: number): Vector3; // 给一个[0-1]的浮点数，在path上均匀采样一个点，除了this的信息外，这要是一个纯函数，返回 Space.Local 的点
}

interface RegularRegion extends Region {
    sample(val: number): Vector3; // 给一个[0-1]的浮点数，在region内均匀采样一个点，除了this的信息外，这要是一个纯函数，返回 Space.Local 的点
}

interface Sampler { // 采样器，生成最初的 Instances，依靠contain的投机采样
    sample(shape: Shape): Instances;
}

interface UniformSampler extends Sampler { // 均匀采样，可靠的通过随机数生成确定数量的采样
    count: number;
    override sample(shape: Path | RegularRegion): Instances;
}

interface PathSampler extends Sampler { // 路径采样，基于多段线的随机，间隔，连续，均匀采样，这里用一个表示，实际上是多种
    override sample(shape: Path): Instances;
}

interface Union, Intersect, Subtract extends Shape { // 布尔操作统一返回 Shape 降级
    a: Shape;
    b: Shape;
}

interface Transform { // 转换器，按单个instance逐一筛选，转换，投影，颜色，自定义等
    transform(instances: Instances): Instances 
}

```

编辑器要改的是：
1. 假定每一个节点都要在编辑器视图中绘制gizmo，需要抽象相关的编辑器接口，而不是像现在这样统一在plugin中注册，因为node可以动态注册
2. port的类型检查要支持继承关系