<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# RK3588 模型量化部署原理手册

**——从 ONNX 到 NPU 指令，编译器内部做了什么，参数怎么配，以及为什么这么做**

## 第一部分：环境与依赖

> **文档定位**：任何部署工作的前提。环境不对，转换流程根本启动不了。表格列出断裂点，读者快速对照排查。

### 1.1 版本断裂点

RKNN-Toolkit2 与多个 Python 库存在版本耦合。以下四个库的特定版本引入了破坏性变更，导致 RKNN-Toolkit2 无法正常工作：

| 依赖库     | 断裂版本  | 断裂原因                   | 报错表现                                                   |
| :--------- | :-------- | :------------------------- | :--------------------------------------------------------- |
| setuptools | ≥ v82     | 移除 `pkg_resources` 模块  | `ModuleNotFoundError: No module named 'pkg_resources'`     |
| ONNX       | ≥ v1.14.0 | 移除 `onnx.mapping` 模块   | `AttributeError: module 'onnx' has no attribute 'mapping'` |
| protobuf   | ≥ v3.20   | `TypeProto` 序列化方式变更 | `TypeError` / `DecodeError`                                |
| torch      | ≥ v2.5.0  | 破坏性 ABI 变更            | 段错误或符号冲突                                           |

**setuptools** 在 v82 之前，`pkg_resources` 是内置模块。v82 开始被重构为 `setuptools.extern.pkg_resources`，不再允许直接 `import pkg_resources`。RKNN-Toolkit2 内部版本解析代码直接依赖该模块，导致升级后 `import rknn` 直接崩溃。

**ONNX** v1.14.0 移除了 `onnx.mapping` 模块。RKNN-Toolkit2 的 ONNX 解析器内部引用了该模块，导致 `rknn.build()` 解析 ONNX 图时抛出 `AttributeError`。

**protobuf** v3.20 修改了复杂消息类型（如 `TypeProto`）的序列化/反序列化实现。ONNX 图结构依赖 protobuf 解析，RKNN-Toolkit2 基于旧版 API 编译，升级后触发 `TypeError` 或 `DecodeError`。

**torch** v2.5.0 开始引入破坏性 ABI 变更（`c10::Tensor` 内存布局变化），导致 RKNN-Toolkit2 运行时与新版 PyTorch 发生符号冲突或段错误。

### 1.2 双端版本一致性

PC 端 RKNN-Toolkit2 的版本**必须等于**板端 `librknnrt.so` 的版本。

根本原因不在软件层面，而在硬件层面。`.rknn` 文件中包含的 NPU 机器指令格式（指令编码、操作数布局、立即数格式）由编译器版本决定。不同编译器版本生成的指令流格式可能不同。板端 Runtime 加载模型时校验文件头中的版本哈希，不匹配时直接返回 `RKNN_ERR_MODEL_INVALID`。

这是 NPU 硬件的安全机制，不是软件建议。

### 1.3 环境问题排查路径

环境问题按以下逻辑顺序排查——从最外层到最内层：

1. **双端版本对齐**：PC 端 Toolkit 版本与板端 Runtime 版本是否一致
2. **核心依赖版本**：setuptools、ONNX、protobuf、torch 是否落在断裂点之外
3. **RKNN 安装完整性**：`from rknn.api import RKNN` 是否正常执行
4. **Python 环境隔离**：确认当前解释器位于 Conda/venv 环境内
5. **系统库依赖**：`libOpenCL.so.1` 是否存在（影响 PC 端仿真）

## 第二部分：模型转换——图优化 + 量化

> **文档定位**：整份文档唯一核心。图优化和量化是在 `rknn.build(do_quantization=True)` 内部**串行执行**的两个阶段——先做图优化改变图结构，再在改变后的图上做量化。所有参数配置、代码示例、坑点都在这里。

### 2.1 总览：`rknn.build()` 内部发生了什么

`rknn.build(do_quantization=True)` 执行时，编译器内部按顺序做两件事：

text

```
ONNX 图 → 图优化（改变图结构）→ 量化（在改变后的图上做数值压缩）→ RKNN 模型
```



**图优化**改变图结构——节点变少、算子融合。**量化**在改变后的图上做数值压缩——FP32 权重和激活值转为 INT8。

两者是流水线关系：图优化先跑完，量化在图优化之后的图上执行。不理解这个顺序，就无法理解“图优化参数”和“量化参数”为什么都在同一个代码块里配置。

### 2.2 图优化

#### 2.2.1 图优化做了什么

图优化是量化执行前的**图结构准备阶段**。原始 ONNX 图中的节点数量会减少：

- **常量折叠**：静态计算节点（所有输入均为常量）在编译时直接求值，替换为常量张量
- **冗余消除**：删除推理时无效的节点——Dropout、Identity、连续两次互相抵消的 Transpose、孤立节点等
- **算子融合**：将连续执行的多个算子合并为单个优化操作——Conv+BN 合并为单个 Conv（BN 参数吸收进 Conv 的权重和偏置）、MatMul+Add 合并为 Fused MatMul（偏置合并进权重矩阵）

图优化器完成 **15 种优化策略**。

**融合触发条件**：前一个算子的输出只流向一个后继算子（无分支）。由模型结构决定，不是版本决定。

#### 2.2.2 参数配置：optimization_level

`optimization_level` 控制图优化的强度：

| 取值      | 含义                       |
| :-------- | :------------------------- |
| 0         | 关闭所有优化               |
| 1         | 关闭部分可能影响精度的优化 |
| 2         | 关闭部分可能影响精度的优化 |
| 3（默认） | 打开所有优化选项           |

**配置方法：**

python

```
rknn.config(optimization_level=3)  # 默认值，一般不需要改
```



精度异常时可降级到 2 或 1 排查是否某个优化策略导致了精度问题。

### 2.3 量化

> **图优化做完之后，量化在改变后的图上执行。以下所有参数都在 `rknn.config()` 中配置。**

#### 2.3.1 量化收益

量化的两个核心收益：

1. **模型变小**：权重从 32 位浮点变为 8 位整数，**体积减少 75%**
2. **速度变快**：整数运算吞吐量高于浮点运算，**推理速度提升 4~8 倍**

代价是精度损失。

#### 2.3.2 量化数学本质

8 位量化的核心是通过**缩放因子（Scale）**和**零点（Zero Point）**建立 FP32 与 INT8 的线性映射关系。

**量化公式**（FP32 → INT8）：

text

```
Q = round(R / S) + Z
```



其中 `R` 是原始浮点值，`S` 是缩放因子（Scale），`Z` 是零点（Zero Point）。

**反量化公式**（INT8 → FP32）：

text

```
R_hat = (Q - Z) × S
```



INT8 有效范围为 [-127, 127]（对称量化）或 [0, 255]（非对称量化）。关键在于 `S` 和 `Z` 的计算策略——三种量化算法的核心差异正在于此。

**对称量化 vs 非对称量化**：

| 类型       | Zero Point | 特点                                   |
| :--------- | :--------- | :------------------------------------- |
| 对称量化   | Z = 0      | 实现简单，但对非对称分布的数据精度较差 |
| 非对称量化 | Z ≠ 0      | 能更充分利用整数表示范围，精度更高     |

RKNN 默认使用**非对称量化**。

#### 2.3.3 三种校准算法：quantized_algorithm

RKNN-Toolkit2 提供三种量化校准算法，通过 `quantized_algorithm` 参数指定：

| 算法             | 原理                                     | 速度             | 推荐数据量 | 适用场景               |
| :--------------- | :--------------------------------------- | :--------------- | :--------- | :--------------------- |
| `normal`（默认） | 从模型 feature 中取 min/max 确定量化范围 | 最快             | 20-100张   | 快速验证流程           |
| `kl`             | 最小化原始浮点分布与量化后分布的 KL 散度 | 中等             | 20-100张   | 默认推荐，信息损失最小 |
| `mmse`           | 最小化量化前后均方误差（MSE Loss）       | 最慢（暴力迭代） | 20-50张    | normal/kl 不够时       |

**速度对比**：normal 最快 → kl 中等 → mmse 最慢（mmse 需要对量化参数进行多次调整，速度会慢很多）。

**精度对比**：在混合量化场景下，kl 和 mmse 精度最好，normal 略差。

**配置方法：**

python

```
rknn.config(quantized_algorithm='kl')  # normal / mmse / kl
```



**选型决策**：

1. 先用 `normal` 快速验证流程是否跑通
2. 精度不够换 `kl`（feature 分布不均匀时改善明显）
3. 仍不够换 `mmse`（暴力迭代，精度最高但最慢）

#### 2.3.4 量化粒度：quantized_method

`quantized_method` 控制量化参数的粒度：

| 粒度              | 含义                               | 精度     | 说明                    |
| :---------------- | :--------------------------------- | :------- | :---------------------- |
| `layer`           | 每层权重只有一套量化参数           | 较低     | 计算简单                |
| `channel`（默认） | 每层权重的每个通道各有一套量化参数 | **更高** | RKNN-Toolkit2 v1.0 引入 |

**为什么 channel 精度更高？** 不同通道的数值范围差异可能很大，共享量化范围会导致小数值通道的精度被大数值通道“挤压”。per-channel 为每个通道独立计算 scale，避免了这个问题。

**配置方法：**

python

```
rknn.config(quantized_method='channel')  # layer / channel，默认 channel
```



通常情况下 channel 比 layer 精度更高，保持默认即可。

#### 2.3.5 量化数据类型：quantized_dtype

`quantized_dtype` 指定量化精度：

| 取值                             | 说明                            |
| :------------------------------- | :------------------------------ |
| `asymmetric_quantized-8`（默认） | 非对称 INT8 量化，最常用        |
| `dynamic_fixed_point-8`          | 动态定点 INT8                   |
| `dynamic_fixed_point-16`         | 动态定点 INT16                  |
| `w8a8`                           | 权重和激活均为 8bit 非对称量化  |
| `w4a16`                          | 4bit 权重 + 16bit 激活          |
| `float16`                        | FP16 量化，无量化损失但体积翻倍 |

**`w8a8` 在 RK3588 上的行为**：对于 RK3588，`quantized_dtype='w8a8'` 表示权重和激活值都采用 8bit 非对称量化，实际采取的是 INT8 数据类型。

**`w4a16` 的平台限制**：`w4a16` 目前主要在 RK3576 平台支持。

**配置方法：**

python

```
rknn.config(quantized_dtype='asymmetric_quantized-8')
```



#### 2.3.6 混合量化等级：quantized_hybrid_level

`quantized_hybrid_level` 控制混合量化的强度，在 `quantized_dtype` 基础上进一步精细控制：

| 取值 | 含义                                    |
| :--- | :-------------------------------------- |
| 0    | 关闭混合量化，全 INT8                   |
| 1    | 仅量化权重，激活保留 FP16               |
| 2    | 部分敏感层保留 FP16（自动选择）         |
| 3    | 最大程度保留 FP16（精度最高，速度最慢） |

**配置方法：**

python

```
rknn.config(quantized_hybrid_level=2)
```



通常不需要配置，默认即可。当全 INT8 精度不足时可尝试调高此值。

#### 2.3.7 单独控制权重和激活的量化类型

RKNN 支持单独配置权重和激活的量化方式，覆盖 `quantized_dtype` 的全局设置：

| 参数                             | 说明                 |
| :------------------------------- | :------------------- |
| `quantized_weight_dtype`         | 单独指定权重量化类型 |
| `quantized_activation_dtype`     | 单独指定激活量化类型 |
| `quantized_weight_algorithm`     | 单独指定权重量化算法 |
| `quantized_activation_algorithm` | 单独指定激活量化算法 |

**配置方法：**

python

```
rknn.config(
    quantized_weight_dtype='asymmetric_quantized-8',
    quantized_activation_dtype='float16',  # 激活保留高精度
    quantized_weight_algorithm='mmse',     # 权重用高精度算法
    quantized_activation_algorithm='kl'    # 激活用默认算法
)
```



通常不需要单独配置，当全局配置无法满足特定需求时使用。

#### 2.3.8 跳过指定层量化：disable_quantize_layer

`disable_quantize_layer` 直接跳过指定层的量化：

**配置方法：**

python

```
rknn.config(disable_quantize_layer=['output_layer', 'softmax'])
```



不推荐作为常规手段——推荐用混合量化的 `.cfg` 文件方式（见 2.3.14），因为 `.cfg` 方式可以更精细地控制每层的量化类型（如指定为 `float16`），而 `disable_quantize_layer` 只能粗暴地跳过。

#### 2.3.9 校准集：dataset

校准集是量化过程中用于统计每层数值分布的代表性样本集合。

**组织方式**：`calibration_dataset.txt`，每行一个样本路径：

text

```
./images/001.jpg
./images/002.jpg
./images/003.jpg
```



**推荐数量**：100-500 张。kl 算法推荐 20-100 张。

**关键原则**：**绝对不要使用测试集作为量化数据集**——这会导致数据泄露，使量化后的指标虚高。

**分布匹配**：校准数据必须与真实推理场景保持分布一致性。

**配置方法：**

python

```
rknn.build(dataset='./calibration_dataset.txt')
```



#### 2.3.10 推理批次大小：rknn_batch_size

`rknn_batch_size` 指定推理时的批次大小：

**配置方法：**

python

```
rknn.build(rknn_batch_size=4)
```



**注意**：

- ONNX 导出时需对应设置 batch 维度
- 校准集图片数量必须 ≥ batch_size

#### 2.3.11 归一化（最大坑点）

`mean_values` 和 `std_values` 的本质是输入数据的线性变换：

text

```
x_out = (x_in - mean) / std
```



**为什么嵌入计算图？** 这个变换作用于输入张量，是数据流的起点。嵌入后，输入数据通过 DMA 直接进入 NPU，在加载到 SRAM 的同时完成变换，无需 CPU 额外遍历内存。

**三种配置方式**：

| 配置方式      | RKNN 实际执行      | 板端输入要求                | 控制台 |
| :------------ | :----------------- | :-------------------------- | :----- |
| 填写 mean/std | `(x-mean)/std`     | 原始数据（如 0-255 像素值） | 无警告 |
| 不填          | 默认 mean=0, std=1 | 已归一化数据                | 有警告 |
| 显式填 0/1    | `x`                | 已归一化数据                | 无警告 |

**数值范围转换**：训练时如果用的是 [0,1] 范围的 mean（如 mean=0.485），RKNN 配置时**必须乘以 255**（变成 123.675）。因为 NPU 输入的原始数据是 [0,255] 的像素值。

**通道顺序**：ONNX 导出时通常是 RGB，Caffe 模型通常是 BGR。可用 `quant_img_RGB2BGR` 或 `reorder_channel` 控制。

python

```
rknn.config(
    mean_values=[[123.675, 116.28, 103.53]],
    std_values=[[58.395, 57.12, 57.375]],
    quant_img_RGB2BGR=False,  # 需要 BGR 时改为 True
    # reorder_channel='2 1 0',  # 或手动指定通道重排
)
```



**关键约束**：填了 mean/std，板端推理代码**禁止**再做归一化。不填 mean/std，板端代码**必须**手动执行归一化。二选一。

**重复归一化导致 nan 的原因**：两次缩放后数值超出 INT8 表示范围（-128~127），触发饱和截断，后续计算全部溢出。

#### 2.3.12 预编译：pre_compile

`pre_compile` 在模型转换时提前完成部分编译工作，加速板端模型加载。

**配置方法**：固定输入形状时开启

python

```
rknn.build(pre_compile=True)
```



**注意**：开启 `pre_compile` 要求输入形状固定，动态形状时无法使用。

#### 2.3.13 单核模式：single_core_mode

强制使用单核 NPU。

**配置方法**：

python

```
rknn.config(single_core_mode=True)
```



通常不需要配置，默认使用多核。当遇到多核调度异常时可尝试开启。

#### 2.3.14 混合量化（精度不够时的补救手段）

当全 INT8 量化精度不足时，混合量化允许对精度敏感的层保留 FP16 精度。

**完整三步工作流**：

**Step 1：生成配置文件**

调用 `hybrid_quantization_step1` 接口，生成 `.quantization.cfg` 配置文件：

python

```
rknn.hybrid_quantization_step1(
    dataset='./calibration_dataset.txt',
    model_quantization_cfg='./model.quantization.cfg'
)
```



生成的配置文件格式为 YAML。

**Step 2：编辑 `.cfg` 文件**

在配置文件中修改 `customized_quantize_layers`：

yaml

```
# model.quantization.cfg
customized_quantize_layers:
  Conv_266: float16
  Sigmoid_294: float16
  output_layer: float16
```



格式为 `<层名>: <量化类型>`。工具链会在配置文件中标记出精度损失较大的层。

**Step 3：使用修改后的配置重新转换**

python

```
rknn.build(
    do_quantization=True,
    dataset='./calibration_dataset.txt',
    model_quantization_cfg='./model.quantization.cfg'
)
```



**自动建议：proposal=True**

RKNN-Toolkit 2.0 支持通过 `proposal=True` 参数自动生成混合量化配置建议：

python

```
rknn.build(
    do_quantization=True,
    dataset='./calibration_dataset.txt',
    proposal=True   # 工具自动分析每层量化误差，输出建议
)
```



**RK3588 限制**：RK3588 混合量化只支持 **float16**。

**哪些层该跳过量化**：

- 输出层
- Softmax 层
- 数值范围剧烈变化的层
- `accuracy_analysis` 定位的问题层

#### 2.3.15 精度诊断：accuracy_analysis

当量化后精度下降时，`accuracy_analysis` 可以逐层诊断问题。

**工作原理**：`accuracy_analysis` 采用层间特征比对法，通过计算原始浮点模型与量化模型在各层输出张量的**余弦距离**，量化每一层的精度损失。

**核心诊断流程**：

1. **数据快照生成**：在模拟器或开发板运行推理，dump 各层的 FP32 和 INT8 输出张量
2. **逐层比对**：计算每层量化前后的余弦相似度
3. **问题定位**：标记相似度低于阈值的层

**配置方法**：

python

```
# build 时开启精度分析
rknn.build(
    do_quantization=True,
    dataset='./calibration_dataset.txt',
    accuracy_analysis=True
)

# 执行精度分析（需连接板端或使用仿真器）
rknn.accuracy_analysis(
    inputs=['./test_image.jpg'],
    output_dir='./analysis',
    target='rk3588'  # 连接板端时添加
)
```



**前置条件**：

- 必须确保原始浮点模型精度正确
- 测试数据集需与模型输入尺寸、归一化方式完全一致
- 如需连接板端，添加 `target` 参数

**输出内容**：

- 每层量化后输出与 FP32 原始输出的**余弦距离**
- dump 出包括 FP32 和量化两种数据类型的每层 tensor 数据

**量化调试五步法**：

1. **定量评估**：掉了多少？哪个指标掉了？
2. **逐层诊断**：哪几层量化误差最大？（用 accuracy_analysis）
3. **归因分析**：是校准集问题？算法问题？还是特定算子？
4. **针对性修复**：换算法 / 混合量化 / 补充校准集
5. **回归验证**：修复后整体精度是否恢复？

#### 2.3.16 完整转换代码示例

python

```
from rknn.api import RKNN

rknn = RKNN()

# 所有 config 参数一次性配置
rknn.config(
    # 必填：目标平台
    target_platform='rk3588',
    
    # 图优化等级（默认 3，一般不改）
    optimization_level=3,
    
    # 归一化（图像模型必须配，非图像模型配 0/1 消警告）
    mean_values=[[123.675, 116.28, 103.53]],
    std_values=[[58.395, 57.12, 57.375]],
    quant_img_RGB2BGR=False,  # 需要 BGR 时改为 True
    
    # 量化核心参数
    quantized_algorithm='kl',                    # normal / mmse / kl
    quantized_method='channel',                  # layer / channel
    quantized_dtype='asymmetric_quantized-8',    # 量化数据类型
    
    # 可选高级参数
    # quantized_hybrid_level=0,                  # 混合量化等级
    # single_core_mode=False,                    # 单核模式
)

# 加载 ONNX 模型
rknn.load_onnx(model='./model.onnx')

# build 执行：图优化 → 量化（串行）
rknn.build(
    do_quantization=True,
    dataset='./calibration_dataset.txt',
    rknn_batch_size=1,
    pre_compile=False,
    accuracy_analysis=False,   # 需要诊断时改为 True
    # proposal=True,           # 需要自动混合量化建议时开启
)

# 导出 RKNN 模型
rknn.export_rknn('./model.rknn')
```



#### 2.3.17 参数速查总表

**`rknn.config()` 参数**

| 参数                             | 可选值                                                       | 默认值                 | 说明             |
| :------------------------------- | :----------------------------------------------------------- | :--------------------- | :--------------- |
| `target_platform`                | rk3588/rk3566/rk3576 等                                      | **必填**               | 目标 NPU 型号    |
| `optimization_level`             | 0/1/2/3                                                      | 3                      | 图优化等级       |
| `mean_values`                    | 列表                                                         | None                   | 各通道均值       |
| `std_values`                     | 列表                                                         | None                   | 各通道标准差     |
| `quant_img_RGB2BGR`              | True/False                                                   | False                  | RGB→BGR 通道转换 |
| `reorder_channel`                | '0 1 2' 等                                                   | None                   | 手动通道重排     |
| `quantized_dtype`                | asymmetric_quantized-8 / dynamic_fixed_point-8 / dynamic_fixed_point-16 / w8a8 / w4a16 / float16 | asymmetric_quantized-8 | 量化数据类型     |
| `quantized_algorithm`            | normal / mmse / kl                                           | normal                 | 量化校准算法     |
| `quantized_method`               | layer / channel                                              | channel                | 量化粒度         |
| `quantized_hybrid_level`         | 0/1/2/3                                                      | None                   | 混合量化等级     |
| `quantized_weight_dtype`         | 同 quantized_dtype                                           | None                   | 权重量化类型     |
| `quantized_activation_dtype`     | 同 quantized_dtype                                           | None                   | 激活量化类型     |
| `quantized_weight_algorithm`     | normal/mmse/kl                                               | None                   | 权重量化算法     |
| `quantized_activation_algorithm` | normal/mmse/kl                                               | None                   | 激活量化算法     |
| `disable_quantize_layer`         | 层名列表                                                     | []                     | 跳过指定层量化   |
| `single_core_mode`               | True/False                                                   | False                  | 单核 NPU 模式    |

**`rknn.build()` 参数**

| 参数                | 可选值        | 默认值 | 说明             |
| :------------------ | :------------ | :----- | :--------------- |
| `do_quantization`   | True/False    | False  | 是否启用量化     |
| `dataset`           | 文件路径/列表 | None   | 校准数据集       |
| `rknn_batch_size`   | 整数          | 1      | 推理批次大小     |
| `pre_compile`       | True/False    | False  | 预编译加速加载   |
| `proposal`          | True/False    | False  | 自动混合量化建议 |
| `accuracy_analysis` | True/False    | False  | 逐层精度分析     |

## 第三部分：子图提取与 NNBG

> **文档定位**：模型转换（图优化+量化）完成后，编译器对计算图做最后的裁剪和打包。NNBG 是这一阶段的输出形态，不是独立操作。

### 3.1 子图提取

图优化和量化完成后，编译器遍历 ONNX 计算图，为每个 OP 创建独立子图，进行拓扑排序和内存复用优化。

### 3.2 NNBG

把 `.rknn` 文件拖进 Netron，顶层只看到一个名为 **NNBG** 的方块，输入从左边进来，输出从右边出去。

双击这个方块，才会展开内部——里面是图优化和量化之后留下的所有算子。

NNBG 不是 RKNN 发明的新概念，它是**子图切割**的结果：编译器把所有能在 NPU 上连续执行的算子，打包封装成一个顶层节点。不在 NNBG 内部的算子，就是被切出去留给 CPU 执行的。

### 3.3 CPU fallback 识别

**如何判断哪些算子落到了 CPU？**

- **Netron**：NNBG 外部的独立节点
- **编译日志**：标记为 `CPU` 的算子
- **Profiling**：耗时异常高的层（比同类 NPU 算子高 10 倍以上）

## 第四部分：板端部署与推理

> **文档定位**：模型转换完成后，最终落地执行。Runtime 不参与计算，只负责加载、校验、调度。

### 4.1 Runtime 职责

板端 `librknnrt.so` 负责将编译好的 RKNN 模型在 NPU 上执行。Runtime **不参与计算**——计算全部由 NPU 硬件完成。

Runtime 的职责是：

1. **模型加载**：解析 `.rknn` 文件的文件头、指令流和权重数据
2. **版本校验**：验证文件头中的版本哈希与自身版本匹配
3. **内存分配**：为输入输出张量、中间激活值分配 SRAM 和 DDR 空间
4. **指令调度**：将 NPU 指令流加载到指令缓存，触发 NPU 执行
5. **同步与中断处理**：等待 NPU 完成计算，处理中断信号

### 4.2 版本校验机制

`.rknn` 文件头包含编译器的版本哈希。Runtime 加载模型时执行两步校验：

1. 读取文件头的版本哈希字段
2. 与 Runtime 自身的版本哈希比对
3. 不匹配 → 返回 `RKNN_ERR_MODEL_INVALID`

**底层原因**：NPU 指令集并非完全稳定。每个 RKNN 版本可能对指令编码做微调。不同版本生成的指令流格式差异无法被旧版 Runtime 正确解析。版本哈希校验是防止错误指令进入 NPU 导致硬件异常的安全措施。

### 4.3 推理 nan 根因

推理结果全为 nan 或相同数值，**95% 以上是归一化重复执行**：

- config 中配置了 `mean_values` 和 `std_values`
- 板端推理代码又手动做了一遍 `(x - mean) / std`
- 数据被缩放两次，数值超出 INT8 表示范围（-128~127）
- 触发饱和截断，后续计算全部溢出

**排查路径**：检查 config 中的 mean/std 配置 → 检查板端推理代码是否做了归一化 → 确保二选一。