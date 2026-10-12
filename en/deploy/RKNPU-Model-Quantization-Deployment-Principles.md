<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# RK3588 Model Quantization Deployment Principle Manual

**—From ONNX to NPU instructions, what does the compiler do internally, how are parameters configured, and why?**

## Part 1: Environment and Dependence

> **Documentation is** essential for any deployment. If the environment is unsuitable, the conversion process simply cannot begin. A table lists the breakpoints, allowing readers to quickly check and troubleshoot.

### Breakpoints in version 1.1

RKNN-Toolkit2 is version-coupled with several Python libraries. Specific versions of the following four libraries introduced breaking changes that cause RKNN-Toolkit2 to malfunction:

Dependency libraries | Broken version | Cause of fracture | Error message
:-- | :-- | :-- | :--
setuptools | ≥ v82 | Remove the `pkg_resources` module | `ModuleNotFoundError: No module named 'pkg_resources'`
ONNX | ≥ v1.14.0 | Remove the `onnx.mapping` module | `AttributeError: module 'onnx' has no attribute 'mapping'`
protobuf | ≥ v3.20 | `TypeProto` serialization method changed | `TypeError` / `DecodeError`
torch | ≥ v2.5.0 | Disruptive ABI changes | Segmentation fault or symbol conflict

Prior to v82, `pkg_resources` was a built-in module in **`setuptools`** . Starting with v82, it was refactored to `setuptools.extern.pkg_resources` , no longer allowing direct `import pkg_resources` . The internal parsing code of RKNN-Toolkit2 directly depends on this module, causing `import rknn` to crash after the upgrade.

**ONNX** v1.14.0 removed the `onnx.mapping` module. The RKNN-Toolkit2 ONNX parser internally referenced this module, causing `rknn.build()` to throw `AttributeError` when parsing the ONNX graph.

**Protobuf** v3.20 modifies the serialization/deserialization implementation for complex message types (such as `TypeProto` ). ONNX graph structures rely on protobuf for parsing. RKNN-Toolkit2 is compiled based on the older API, and upgrading it will trigger `TypeError` or `DecodeError` .

Starting with **torch** v2.5.0, a destructive ABI change (a change `c10::Tensor` memory layout) was introduced, causing symbol conflicts or segmentation faults when the RKNN-Toolkit2 runtime is used with newer versions of PyTorch.

### 1.2 Dual-end version consistency

The PC version of RKNN-Toolkit2 **must be the same as** the board version of `librknnrt.so` .

The root cause lies not in the software, but in the hardware. The NPU machine instruction format (instruction encoding, operand layout, immediate format) contained in the `.rknn` file is determined by the compiler version. Different compiler versions may generate different instruction stream formats. When the on-board runtime loads the model, it checks the version hash in the file header; if it doesn't match, it directly returns `RKNN_ERR_MODEL_INVALID` .

This is a security mechanism of the NPU hardware, not a software suggestion.

### 1.3 Environmental Issue Investigation Path

Environmental issues should be investigated in the following logical order—from the outermost layer to the innermost layer:

1. **Dual-end version alignment** : Are the PC-side Toolkit version and the board-side Runtime version consistent?
2. Are **the core dependency versions** (setuptools, ONNX, protobuf, torch) outside the breakpoint?
3. **RKNN installation completeness** : Does `from rknn.api import RKNN` function execute correctly?
4. **Python environment isolation** : Ensure the current interpreter is located within the Conda/venv environment.
5. **System library dependency** : Does `libOpenCL.so.1` exist? (This affects PC-side emulation)

## Part Two: Model Transformation – Graph Optimization + Quantization

> **Document Focus** : This is the sole core of the entire document. Graph optimization and quantization are two stages **executed sequentially** within `rknn.build(do_quantization=True)` `—first, graph optimization changes the graph structure, then quantization is performed on the modified graph. All parameter configurations, code examples, and potential pitfalls are located here.

### 2.1 Overview: What happens inside `rknn.build()`

When `rknn.build(do_quantization=True)` is executed, the compiler internally performs two tasks in sequence:

text

```
ONNX 图 → 图优化（改变图结构）→ 量化（在改变后的图上做数值压缩）→ RKNN 模型
```

**Graph optimization** alters the graph structure—reducing the number of nodes and merging operators. **Quantization** performs numerical compression on the modified graph—FP32 weights and activation values ​​are converted to INT8.

The two have a pipeline relationship: graph optimization runs first, and quantization is performed on the graph after optimization. Without understanding this order, it's impossible to understand why "graph optimization parameters" and "quantization parameters" are configured in the same code block.

### 2.2 Graph Optimization

#### 2.2.1 What did graph optimization do?

Graph optimization is **the graph structure preparation stage** before quantization. The number of nodes in the original ONNX graph will be reduced:

- **Constant folding** : Static compute nodes (where all inputs are constants) are evaluated directly at compile time and replaced with constant tensors.
- **Redundancy elimination** : Remove invalid nodes during inference—Dropout, Identity, consecutively canceling Transpose, isolated nodes, etc.
- **Operator fusion** : Merging multiple operators executed consecutively into a single optimization operation—Conv+BN is merged into a single Conv (BN parameters are absorbed into the weights and biases of Conv), MatMul+Add is merged into Fused MatMul (biases are merged into the weight matrix).

The graph optimizer performs **15 optimization strategies** .

**Fusion trigger condition** : The output of the previous operator flows to only one successor operator (no branching). This is determined by the model structure, not the version.

#### 2.2.2 Parameter Configuration: optimization_level

`optimization_level` controls the strength of the optimization chart:

Value | meaning
:-- | :--
0 | Turn off all optimizations.
1 | Closing certain optimizations may affect accuracy.
2 | Closing certain optimizations may affect accuracy.
3 (default) | Enable all optimization options

**Configuration method:**

Python

```
rknn.config(optimization_level=3)  # 默认值，一般不需要改
```

If the accuracy is abnormal, it can be downgraded to 2 or 1 to check whether a certain optimization strategy is causing the accuracy problem.

### 2.3 Quantification

> **After graph optimization is complete, quantization is performed on the modified graph. All the following parameters are configured in `rknn.config()` .**

#### 2.3.1 Quantitative Returns

The two core benefits of quantitative analysis:

1. **The model is smaller** : the weights have been changed from 32-bit floating-point to 8-bit integers, **reducing the size by 75%.**
2. **Increased speed** : Integer operations have higher throughput than floating-point operations, **and inference speed is increased by 4 to 8 times.**

The cost is a loss of accuracy.

#### 2.3.2 Quantifying the Mathematical Essence

The core of 8-bit quantization is to establish a linear mapping relationship between FP32 and INT8 through **scale factor **and** zero point**.

**Quantization formula** (FP32 → INT8):

text

```
Q = round(R / S) + Z
```

Where `R` is the original floating-point value, `S` is the scaling factor, `Z` is the zero point.

**Dequantization formula** (INT8 → FP32):

text

```
R_hat = (Q - Z) × S
```

The effective range of INT8 is [-127, 127] (symmetric quantization) or [0, 255] (asymmetric quantization). The key lies in the calculation strategies of `S` and `Z` —this is the core difference between the three quantization algorithms.

**Symmetric quantization vs. asymmetric quantization** :

type | Zero Point | Features
:-- | :-- | :--
Symmetric quantization | Z = 0 | It is simple to implement, but its accuracy is poor for asymmetric data.
Asymmetric quantization | Z ≠ 0 | It can make better use of the range of integer representations and achieve higher precision.

RKNN uses **asymmetric quantization** by default.

#### 2.3.3 Three calibration algorithms: quantized_algorithm

RKNN-Toolkit2 provides three quantization calibration algorithms, specified by `quantized_algorithm` parameter:

algorithm | principle | speed | Recommended data volume | Applicable Scenarios
:-- | :-- | :-- | :-- | :--
`normal` (default) | Determine the quantization range by taking the min/max values ​​from the model features. | Fastest | 20-100 photos | Quick verification process
`kl` | Minimize the KL divergence between the original floating-point distribution and the quantized distribution. | medium | 20-100 photos | Default recommendation, with minimal information loss
`mmse` | Minimize the mean squared error (MSE Loss) before and after quantization. | Slowest (brute-force iteration) | 20-50 photos | When normal/kl is insufficient

**Speed ​​comparison** : normal is the fastest → kl is medium → mmse is the slowest (mmse requires multiple adjustments to the quantization parameters, so it is much slower).

**Accuracy comparison** : In mixed quantization scenarios, KL and MMSE have the best accuracy, while Normal is slightly worse.

**Configuration method:**

Python

```
rknn.config(quantized_algorithm='kl')  # normal / mmse / kl
```

**Selection Decision** :

1. First, use `normal` to quickly verify whether the process runs successfully.
2. If the accuracy is insufficient, switch to `kl` (which significantly improves performance when the feature distribution is uneven).
3. Still not enough to replace `mmse` (brute-force iteration, highest accuracy but slowest).

#### 2.3.4 Quantization Granularity: quantized_method

`quantized_method` controls the granularity of the quantization parameters.

granularity | meaning | accuracy | illustrate
:-- | :-- | :-- | :--
`layer` | Each layer has only one set of quantization parameters. | lower | Simple calculation
`channel` (default) | Each channel of each layer's weight has its own set of quantization parameters. | **higher** | RKNN-Toolkit2 v1.0 introduced

**Why is channel precision higher?** The numerical ranges of different channels can vary greatly, and sharing a quantization range would cause the precision of smaller numerical channels to be "squeezed" by larger numerical channels. Per-channel calculates the scale independently for each channel, avoiding this problem.

**Configuration method:**

Python

```
rknn.config(quantized_method='channel')  # layer / channel，默认 channel
```

In general, channels have higher precision than layers, so the default setting is fine.

#### 2.3.5 Quantized data type: quantized_dtype

`quantized_dtype` specifies the quantization precision:

Value | illustrate
:-- | :--
`asymmetric_quantized-8` (default) | Asymmetric INT8 quantization, the most commonly used
`dynamic_fixed_point-8` | Dynamic fixed-point INT8
`dynamic_fixed_point-16` | Dynamic fixed-point INT16
`w8a8` | Both weights and activations are 8-bit asymmetric quantization.
`w4a16` | 4-bit weight + 16-bit activation
`float16` | FP16 quantization results in no quantization loss but doubles the file size.

**`w8a8` behavior on RK3588** : For RK3588, `quantized_dtype='w8a8'` indicates that both weights and activation values ​​use 8-bit asymmetric quantization, which actually uses the INT8 data type.

**Platform limitations of `w4a16`** : `w4a16` is currently primarily supported on the RK3576 platform.

**Configuration method:**

Python

```
rknn.config(quantized_dtype='asymmetric_quantized-8')
```

#### 2.3.6 Quantized Hybrid Level

`quantized_hybrid_level` controls the intensity of hybrid quantization, providing further finer control based on `quantized_dtype` .

Value | meaning
:-- | :--
0 | Disable hybrid quantization, use all INT8.
1 | Quantize weights only, activate and retain FP16
2 | Some sensitive layers retain FP16 (automatic selection).
3 | To retain the FP16 as much as possible (highest accuracy, slowest speed).

**Configuration method:**

Python

```
rknn.config(quantized_hybrid_level=2)
```

Normally, no configuration is needed; the default value is sufficient. You can try increasing this value when full INT8 precision is insufficient.

#### 2.3.7 Separate control of weights and activation quantization types

RKNN supports configuring the quantization method for weights and activations separately, overriding the global setting of `quantized_dtype` :

parameter | illustrate
:-- | :--
`quantized_weight_dtype` | Specify weight quantization type separately
`quantized_activation_dtype` | Specify activation quantization type separately
`quantized_weight_algorithm` | Specify weight quantization algorithm separately
`quantized_activation_algorithm` | Specify activation quantization algorithm separately

**Configuration method:**

Python

```
rknn.config(
    quantized_weight_dtype='asymmetric_quantized-8',
    quantized_activation_dtype='float16',  # 激活保留高精度
    quantized_weight_algorithm='mmse',     # 权重用高精度算法
    quantized_activation_algorithm='kl'    # 激活用默认算法
)
```

Typically, separate configuration is not required; it is used when the global configuration cannot meet specific needs.

#### 2.3.8 Skip quantization of a specified layer: disable_quantize_layer

`disable_quantize_layer` skips the quantization of the specified layer directly:

**Configuration method:**

Python

```
rknn.config(disable_quantize_layer=['output_layer', 'softmax'])
```

This is not recommended as a standard practice. Instead, we recommend using the mixed quantization `.cfg` file method (see 2.3.14) because the `.cfg` method allows for more precise control over the quantization type of each layer (e.g., specifying it as `float16` ), while `disable_quantize_layer` can only be skipped abruptly.

#### 2.3.9 Calibration set: dataset

The calibration set is a representative sample set used in the quantization process to statistically analyze the numerical distribution of each layer.

**Organization** : `calibration_dataset.txt` , one sample path per line:

text

```
./images/001.jpg
./images/002.jpg
./images/003.jpg
```

**Recommended number of images** : 100-500. KL algorithm recommends 20-100 images.

**Key principle** : **Never use the test set as the quantization dataset** —this will lead to data leakage and cause the quantified metrics to be artificially inflated.

**Distribution matching** : The calibration data must maintain a consistent distribution with the real inference scenario.

**Configuration method:**

Python

```
rknn.build(dataset='./calibration_dataset.txt')
```

#### 2.3.10 Inference batch size: rknn_batch_size

`rknn_batch_size` specifies the batch size during inference:

**Configuration method:**

Python

```
rknn.build(rknn_batch_size=4)
```

**Notice** :

- When exporting from ONNX, the batch dimension needs to be set accordingly.
- The number of calibration set images must be greater than or equal to batch_size.

#### 2.3.11 Normalization (Maximum Pitfall)

The essence of `mean_values` ​​and `std_values` ​​is a linear transformation of the input data:

text

```
x_out = (x_in - mean) / std
```

**Why embed the computation graph?** This transformation operates on the input tensor, which is the starting point of the data flow. After embedding, the input data enters the NPU directly via DMA, and the transformation is completed while loading into SRAM, eliminating the need for the CPU to traverse memory additionally.

**Three configuration options** :

Configuration method | RKNN actual execution | Board input requirements | console
:-- | :-- | :-- | :--
Fill in mean/std | `(x-mean)/std` | Raw data (e.g., pixel values ​​from 0-255) | No warning
Leave blank | The default values ​​are mean=0 and std=1. | Normalized data | Warning
Explicitly fill in 0/1 | `x` | Normalized data | No warning

**Numerical range conversion** : If the mean value is in the range [0,1] during training (e.g., mean=0.485), **it must be multiplied by 255** in the RKNN configuration (becoming 123.675). This is because the original data input to the NPU is pixel values ​​in the range [0,255].

**Channel order** : ONNX models typically export in RGB, while Caffe models typically export in BGR. This can be controlled using `quant_img_RGB2BGR` or `reorder_channel` .

Python

```
rknn.config(
    mean_values=[[123.675, 116.28, 103.53]],
    std_values=[[58.395, 57.12, 57.375]],
    quant_img_RGB2BGR=False,  # 需要 BGR 时改为 True
    # reorder_channel='2 1 0',  # 或手动指定通道重排
)
```

**Key constraint** : If mean/std is specified, the onboard inference code **is prohibited** from further normalization. If mean/std is not specified, the onboard code **must** perform normalization manually. Choose one.

**The reason why repeated normalization causes NaN** is that after two scaling operations, the value exceeds the range of INT8 (-128~127), triggering saturation truncation, and all subsequent calculations overflow.

#### 2.3.12 Pre-compile: pre_compile

`pre_compile` completes part of the compilation work in advance during model conversion, accelerating the loading of the model on the board.

**Configuration method** : Enable when the input shape is fixed.

Python

```
rknn.build(pre_compile=True)
```

**Note** : Enabling `pre_compile` requires a fixed input shape; it cannot be used with dynamic shapes.

#### 2.3.13 Single-core mode: single_core_mode

Force the use of a single-core NPU.

**Configuration method** :

Python

```
rknn.config(single_core_mode=True)
```

Normally, no configuration is required, and multi-core is used by default. Enabling multi-core can be attempted when encountering multi-core scheduling anomalies.

#### 2.3.14 Hybrid quantization (a remedial measure when accuracy is insufficient)

Hybrid quantization allows precision-sensitive layers to retain FP16 precision when full INT8 quantization is insufficient.

**Complete three-step workflow** :

**Step 1: Generate configuration file**

Call the `hybrid_quantization_step1` interface to generate the `.quantization.cfg` configuration file:

Python

```
rknn.hybrid_quantization_step1(
    dataset='./calibration_dataset.txt',
    model_quantization_cfg='./model.quantization.cfg'
)
```

The generated configuration file is in YAML format.

**Step 2: Edit the `.cfg` file**

Modify `customized_quantize_layers` in the configuration file:

yaml

```
# model.quantization.cfg
customized_quantize_layers:
  Conv_266: float16
  Sigmoid_294: float16
  output_layer: float16
```

The format is `<层名>: <量化类型>` . The toolchain will mark layers with significant accuracy loss in the configuration file.

**Step 3: Reconstruct using the modified configuration**

Python

```
rknn.build(
    do_quantization=True,
    dataset='./calibration_dataset.txt',
    model_quantization_cfg='./model.quantization.cfg'
)
```

**Automatic suggestions: proposal=True**

RKNN-Toolkit 2.0 supports automatically generating mixed quantization configuration suggestions using `proposal=True` parameter:

Python

```
rknn.build(
    do_quantization=True,
    dataset='./calibration_dataset.txt',
    proposal=True   # 工具自动分析每层量化误差，输出建议
)
```

**RK3588 Limitation** : RK3588 mixed quantization only supports **float16** .

**Which layers should skip quantization** :

- Output layer
- Softmax layer
- Layers with drastic changes in numerical range
- The problem layer identified by `accuracy_analysis`

#### 2.3.15 Accuracy Analysis

When accuracy decreases after quantization, `accuracy_analysis` can diagnose problems layer by layer.

**Working principle** : `accuracy_analysis` uses the inter-layer feature comparison method. It calculates **the cosine distance between** the output tensors of the original floating-point model and the quantized model at each layer to quantize the accuracy loss of each layer.

**Core diagnostic process** :

1. **Data snapshot generation** : Run inference on the simulator or development board, dump the FP32 and INT8 output tensors of each layer.
2. **Layer-by-layer comparison** : Calculate the cosine similarity before and after each layer of quantization.
3. **Problem localization** : Label layers with similarity below a threshold

**Configuration method** :

Python

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

**Prerequisites** :

- It is essential to ensure the accuracy of the original floating-point model.
- The test dataset must be exactly the same as the model input size and normalization method.
- To connect to the board, add the `target` parameter.

**Output content** :

- **The cosine distance between** the output after each quantization layer and the original output of FP32.
- Dump the tensor data for each layer, including both FP32 and quantized data types.

**Five-step method for quantitative debugging** :

1. **Quantitative assessment** : How much did it drop? Which indicator dropped?
2. **Layer-by-layer diagnostics** : Which layers have the largest quantization errors? (using accuracy_analysis)
3. **Attribution analysis** : Is it a calibration set problem? An algorithmic problem? Or a specific operator problem?
4. **Targeted fixes** : Algorithm change / Hybrid quantization / Supplemental calibration set
5. **Regression verification** : Has the overall accuracy been restored after the repair?

#### 2.3.16 Complete Conversion Code Example

Python

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

#### 2.3.17 Parameter Quick Reference Table

**`rknn.config()` parameters**

parameter | Optional values | default value | illustrate
:-- | :-- | :-- | :--
`target_platform` | rk3588/rk3566/rk3576 etc. | **Required** | Target NPU model
`optimization_level` | 0/1/2/3 | 3 | Image optimization level
`mean_values` | List | None | Average values ​​of each channel
`std_values` | List | None | Standard deviation of each channel
`quant_img_RGB2BGR` | True/False | False | RGB to BGR channel conversion
`reorder_channel` | '0 1 2' etc. | None | Manual channel rearrangement
`quantized_dtype` | asymmetric_quantized-8/dynamic_fixed_point-8/dynamic_fixed_point-16/w8a8/w4a16/float16 | asymmetric_quantized-8 | Quantized data types
`quantized_algorithm` | normal / mmse / kl | normal | Quantization calibration algorithm
`quantized_method` | layer / channel | channel | Quantization granularity
`quantized_hybrid_level` | 0/1/2/3 | None | Mixed Quantitative Levels
`quantized_weight_dtype` | Same as quantized_dtype | None | Weight quantization type
`quantized_activation_dtype` | Same as quantized_dtype | None | Activation Quantization Type
`quantized_weight_algorithm` | normal/mmse/kl | None | Weight quantization algorithm
`quantized_activation_algorithm` | normal/mmse/kl | None | Activation quantization algorithm
`disable_quantize_layer` | List of layer names | [] | Skip to specified layer quantization
`single_core_mode` | True/False | False | Single-core NPU mode

**`rknn.build()` parameters**

parameter | Optional values | default value | illustrate
:-- | :-- | :-- | :--
`do_quantization` | True/False | False | Enable quantization
`dataset` | File paths/list | None | Calibration dataset
`rknn_batch_size` | Integer | 1 | Inference batch size
`pre_compile` | True/False | False | Pre-compilation speeds up loading
`proposal` | True/False | False | Automatic Mixing Quantization Recommendation
`accuracy_analysis` | True/False | False | Layer-by-layer precision analysis

## Part 3: Subgraph Extraction and NNBG

> **Document Location** : After model transformation (graph optimization + quantization) is completed, the compiler performs final pruning and packaging of the computation graph. NNBG is the output format of this stage and is not an independent operation.

### 3.1 Subgraph Extraction

After graph optimization and quantization are completed, the compiler traverses the ONNX computation graph, creates an independent subgraph for each OP, and performs topology sorting and memory reuse optimization.

### 3.2 NNBG

Drag the `.rknn` file into Netron. At the top level, you will only see a square named **NNBG** . The input comes in from the left and the output goes out from the right.

Double-clicking this square will expand its interior—which contains all the operators left after graph optimization and quantization.

NNBG is not a new concept invented by RKNN; it is the result of **subgraph cutting** : the compiler packages all operators that can be executed consecutively on the NPU into a top-level node. Operators not inside NNBG are cut out and left for CPU execution.

### 3.3 CPU fallback identification

**How do we determine which operators are being used by the CPU?**

- **Netron** : Independent nodes outside of NNBG
- **Compiler Log** : Operators marked as `CPU`
- **Profiling** : Layers with exceptionally high processing time (more than 10 times longer than similar NPU operators).

## Part Four: Panel Deployment and Inference

> **Document positioning** : After the model transformation is completed, it is finally deployed and executed. The runtime does not participate in the calculation, but is only responsible for loading, verification, and scheduling.

### 4.1 Runtime Responsibilities

The on-board `librknnrt.so` is responsible for executing the compiled RKNN model on the NPU. **The runtime does not participate in the computation** —all computations are performed by the NPU hardware.

The responsibilities of the Runtime are:

1. **Model loading** : Parsing the file header, instruction stream, and weight data of the `.rknn` file.
2. **Version verification** : Verifies that the version hash in the file header matches its own version.
3. **Memory allocation** : Allocate SRAM and DDR space for input/output tensors and intermediate activation values.
4. **Instruction scheduling** : Loads the NPU instruction stream into the instruction cache and triggers NPU execution.
5. **Synchronization and Interrupt Handling** : Waiting for the NPU to complete the calculation and handling the interrupt signal.

### 4.2 Version Verification Mechanism

The `.rknn` file header contains the compiler version hash. The runtime performs two checks when loading the model:

1. Read the version hash field in the file header
2. Compare with the runtime's own version hash
3. Mismatch → Returns `RKNN_ERR_MODEL_INVALID`

**The underlying reason** is that the NPU instruction set is not entirely stable. Each RKNN version may make minor adjustments to the instruction encoding. The differences in instruction stream formats generated by different versions cannot be correctly parsed by older versions of the runtime. Version hash verification is a safety measure to prevent erroneous instructions from entering the NPU and causing hardware malfunctions.

### 4.3 Reasoning about the root cause

If all inference results are NaN or the same value, **it indicates that over 95% of the time the normalized repetitive execution is involved** .

- The config file contains `mean_values` ​​and `std_values`
- I manually rewrote the board-side inference code again: `(x - mean) / std`
- The data was scaled twice, and the value is outside the range of INT8 (-128~127).
- The saturation cutoff is triggered, and all subsequent calculations overflow.

**Troubleshooting path** : Check the mean/std configuration in the config file → Check if the board-side inference code has been normalized → Ensure that only one of the two options is selected.
