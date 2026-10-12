**English** | [简体中文](../../deploy/melotts-rknn量化部署踩坑记录.md)

<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 KY (kyshipit)
-->

# MeloTTS RKNN Quantization Troubleshooting Log

> This document is suitable for developers who are new to AI model deployment. It covers the entire process from PyTorch model to RK3588 NPU inference, including all the pitfalls encountered, technical details, and final conclusions.

## I. Project Background

### 1.1 Project Overview

MeloTTS is an open-source text-to-speech (TTS) model implemented in PyTorch, using the VITS/VITS2 architecture at its core, designed for high-quality speech synthesis. The RK3588 development board is equipped with an NPU (Neural Processing Unit) specifically for accelerating AI inference.

The goal of this project is to convert MeloTTS from PyTorch format to RKNN format, enabling it to utilize the hardware acceleration capabilities of the RK3588 NPU for inference, thereby achieving more efficient speech synthesis.

### 1.2 Trade-off between delay and sound quality

MeloTTS is a "quality-first" TTS model. Its VITS/VITS2 architecture is optimized for high-quality speech synthesis, rather than low-latency inference. Real-world testing on an RK3588 NPU shows a stable single-sentence inference time of 1.8–2.2 seconds, and this latency is independent of the input text length. This is determined by the architecture's characteristics and does not change with model conversion.

This project documents the complete conversion process and the pitfalls encountered, including ONNX export, dynamic dimension processing, RKNN conversion, INT8 quantization, and calibration data design. It can serve as a reference for deploying similar TTS models to the RK3588 NPU.

### 1.3 Overall Technical Approach

**General conversion process:**

```
PyTorch 模型
    ↓   ① onnxsim.simplify()
    ↓   ② torch.onnx.export()
ONNX 模型
    ↓   ③ rknn-toolkit2
    ↓   ④ 量化（提供校准数据）
RKNN 模型
    ↓   ⑤ 部署到 NPU
```

**Actual implementation status of this project:**

stage | plan | Actual results
:-- | :-- | :--
① Optimization Model | `onnxsim.simplify` optimization model | The Encoder is fixed as completely static, while the Decoder retains the `dim_param` flag (metadata is dynamic, but the actual data is static).
② ONNX Export | Configure `dynamic_axes` to support dynamic shape | `dynamic_axes` is invalid; the tracing mechanism is fixed. Revert to static 256.
③ Conversion tools | Configure `dynamic_input` to support multiple lengths | Multiple lengths failed, so a single length was locked `seq_lens=256`
④ INT8 Quantization | Provides calibration data, full model INT8 | Encoder failed ( `Less` operator type conflict); Decoder succeeded but audio quality degraded.

Final available solution:

- Encoder: FP16 static (INT8 quantization failed)
- Decoder: FP16 Fixed Length (INT8 can be quantized but the sound quality is degraded, not recommended for production use)

**The role of ONNX:** ONNX (Open Neural Network Exchange) is an intermediate format in the AI ​​field. Almost all deep learning frameworks can export ONNX, and almost all inference engines can read ONNX. It acts as a "translation middleman" between PyTorch and RKNN.

## II. PyTorch → ONNX Export

### 2.1 Repository Selection: Official vs. Community Edition

MeloTTS has multiple versions, as compared below:

Comparison items | Official repository (myshell-ai/MeloTTS) | Modified version (mmontol/MeloTTS)
:-- | :-- | :--
Does the main branch have ONNX export functionality? | ❌ No main branch | ✅ Includes (export_onnx method + export.py script)
Supplementary Explanation | PR #276 attempts to add ONNX support, but it has not yet been merged. | —
Source code | [MyShell.ai](https://myshell.ai/) official release | Modified by mmontol after being forked from the official site.

**Conclusion** : The `mmontol/MeloTTS` community edition must be used. The official repository's main branch can only perform inference and does not currently support exporting to ONNX (although the official team attempted to add this feature through PR #276, it has not yet been merged). Key difference: The official repository's main branch is a "pure TTS engine," while the modified version is a "TTS engine + ONNX export toolkit."

### 2.2 Export Steps and Dependency Issues

**Environment preparation and code cloning:**

```
git clone https://github.com/mmontol/MeloTTS.git
cd MeloTTS
```

**Question 1: RuntimeError: Failed initializing MeCab**

Reason: MeloTTS loads all language modules (including Japanese) upon startup. Japanese requires the mecab word segmenter and a Unicode dictionary.

Solution: pip install unidic-lite

**Note** : MeCab is a Japanese lexical analyzer (word segmentation tool). MeloTTS, although a Chinese TTS program, attempts to load all language support. unidic-lite is a lightweight dictionary; it can be installed directly via pip, bypassing the full download.

Alternatively, if Japanese support is not needed, you can modify `melo/text/cleaner.py` and simply remove the Japanese-related imports:

```
from . import chinese, english, chinese_mix, korean, french, spanish
language_module_map = {"ZH": chinese, "EN": english, 'ZH_MIX_EN': chinese_mix,
        'KR': korean, 'FR': french, 'SP': spanish, 'ES': spanish}
```

Also modify `melo/text/japanese.py` to silently degrade when MeCab initialization fails:

```
try:
    _TAGGER = MeCab.Tagger()
except Exception:
    _TAGGER = None
```

**Question 2: NameError: name 'language_id_map' is not defined**

Cause: The community version's api.py file uses the `export_onnx` function, but an import is missing at the top of the file.

Solution: Add the following line to the top of api.py: `from .text import language_id_map`

**Note** : `language_id_map` is a mapping table in MeloTTS from language names (e.g., "ZH") to numeric IDs (e.g., 1). The model internally uses numeric IDs to distinguish different languages.

### 2.3 Detailed Explanation of Core Parameters of torch.onnx.export()

This is the most crucial function in the entire export process. Think of it as the "translator":

```
torch.onnx.export(
    model,                         # PyTorch 模型
    inputs,                        # 示例输入，告诉翻译官"输入长什么样"
    "model.onnx",                  # 输出文件名
    opset_version=16,              # 使用哪个版本的"翻译规则"
    do_constant_folding=True,      # 开启优化：把固定不变的部分提前算好
    keep_initializers_as_inputs=False,  # 优化后把多余输入删掉
    input_names=["x", ...],        # 给输入起名字
    output_names=["y", ...],       # 给输出起名字
    dynamic_axes={...}             # 声明哪些维度是可变的
)
```

**Explanation of each parameter:**

parameter | Plain explanation | Why is it set up this way?
:-- | :-- | :--
`opset_version=16` | Translation rule version number | Version 16 provides better support for "variable size" to avoid issues caused by operators not being supported in older versions.
`do_constant_folding=True` | Calculate the fixed parts in advance | Eliminate dynamic placeholders in `Expand` nodes to avoid RKNN reporting `invalid expand shape` .
`keep_initializers_as_inputs=False` | Remove constants from the input list | Simplified model with constant folding
`dynamic_axes` | Declare which dimensions are variable | The sequence length varies with the text and must be declared as dynamic.

**Regarding the number of `ja_bert` inputs:** Whether they appear in the ONNX input depends on the actual exported ONNX file. Run the following command to confirm:

```
python -c "import onnx; m=onnx.load('encoder.onnx'); print([i.name for i in m.graph.input])"
```

- Output includes → If inputs are 8, calibration data must be included; Output does not include → If inputs are 7, calibration data is not required.
- The number of calibration data files must match the actual number of ONNX inputs.

### 2.4 dynamic_axes — How to declare "variable size"

```
dynamic_axes={
    "x": {0: "batch", 1: "seq_len"},         # x 的第0维叫 batch，第1维叫 seq_len
    "tone": {0: "batch", 1: "seq_len"},
    "lang_ids": {0: "batch", 1: "seq_len"},
    "ja_bert": {0: "batch", 1: "channels", 2: "seq_len"},
    "logw": {0: "batch", 1: "channels", 2: "seq_len"},
    # ...
}
```

**Core concept** : Dimensions in the ONNX model can be represented in two ways:

Representation | meaning | Example
:-- | :-- | :--
dim_value: 1 | Fixed value, will never change | dim_value: 1 (batch is always 1)
dim_param: "seq_len | Dynamic placeholders, variable at runtime | dim_param: "seq_len" (The value is smaller for shorter text and larger for longer text)

**Naming principles are important** :

Writing style | result | evaluate
:-- | :-- | :--
"logw": {2: "seq_len"} | The third dimension is called seq_len, and the first two dimensions are automatically generated as Addlogw_dim_0/Addlogw_dim_1. | ❌ Not recommended; RKNN may fail to make inferences due to unclear names.
"logw": {0: "batch", 1: "channels", 2: "seq_len"} | All three dimensions have clear names. | ✅ Recommended

⚠️Important **Warning** : dim_param is just a "metadata tag" in the ONNX file and does not mean that the model actually supports dynamic changes. If the model code has hard-coded `y_lengths = 2 * x_length` , dynamic_axes is only "dynamic on paper"—it looks dynamic, but in actual operation it is still a fixed length.

### 2.5 onnxsim.simplify() — "Slimming down" the ONNX model

```
sim_model, _ = onnxsim.simplify(encoder_name)
onnx.save(sim_model, encoder_name)
```

**What does this function do?**

1. Constant folding: Pre-calculating fixed, unchanging operations.
2. Redundancy elimination: Remove operations that have no practical effect.
3. Operator fusion: combining multiple small operations into one.

**Its effect on dynamic shapes** :

Model | The effect after adding simplify
:-- | :--
Encoder + without dynamic_axes | All dimensions become fixed values ​​(dim_value), making it completely static.
Decoder + has dynamic_axes | The `dim_param: "seq_len"` parameter is retained, and the metadata layer remains dynamic.

**Why this difference?** The ScatterND+Slice operation inside the Encoder, after simplification, resolves its shape dependency to a fixed value (256), so all dimensions are static. The Decoder structure is simpler, and the dependency on seq_len is not completely eliminated.

## III. ONNX → RKNN Conversion

### 3.1 RKNN Dynamic Shapes' "Preset Menu" Mode

Many people's first reaction is: "Since the model supports dynamics, just convert it to a dynamic RKNN."

However, the dynamic shapes of RKNN and the dynamic shapes of PyTorch/ONNX are not the same thing.

```
rknn.config(
    target_platform='rk3588',
    dynamic_input=[
        [[1, 64], [1], [1], [1, 64], [1, 64], [1, 768, 64], [1], [1]],
        [[1, 128], [1], [1], [1, 128], [1, 128], [1, 768, 128], [1], [1]],
        [[1, 256], [1], [1], [1, 256], [1, 256], [1, 768, 256], [1], [1]],
    ]
)
```

**Core understanding** :

- RKNN's "dynamic" doesn't mean "calculate the length of the input," but rather **a "preset menu" mode** .
- **All possible shapes** must be listed during the conversion.
- The NPU generates a set of optimized instructions for each shape.
- During reasoning, you can only select one from the preset menu; you cannot temporarily "customize" it.

**Analogy** : This is not "ordering food as needed", but "buying a set meal in advance" - you can only choose from set meals A/B/C, and you can't mix and match as you like.

### 3.2 Decoder's dynamic_input shape configuration

```
shapes = [
    [1, 2*seq_len, 256],   # attn: [batch, 2*seq_len, attn_dim]
    [1, 1, 2*seq_len],     # y_mask: [batch, 1, 2*seq_len]
    [1, 256, 1],           # g: [batch, 256, 1]（固定）
    [1, 192, seq_len],     # m_p: [batch, 192, seq_len]
    [1, 192, seq_len],     # logs_p: [batch, 192, seq_len]
    [1]                    # noise_scale: [1]（固定）
]
```

**Key points** :

- The second dimension of attn is 2 * seq_len, because `y_lengths = 2 * x_length`
- g and noise_scale are fixed dimensions and do not participate in dynamic operations.

### 3.3 Reasons for failure of multi-length configurations (128/256/512)

We initially tried `seq_lens=[128, 256, 512]` , but the conversion failed with the error "MatMul dimension mismatch".

**Cause analysis** :

- RKNN requires shape inference for three different seq_len values.
- The Decoder contains a large number of shape-sensitive operations such as MatMul and Expand.
- Dimension inference can fail under certain combinations (such as 128 and 512).
- Ultimately, only **a single length (256)** can be accepted.

**Lessons learned** : Don't strive for "perfect dynamics." First, verify feasibility with a certain length, and then gradually expand.

### 3.4 op_target — Forces the operator to execute correctly on the CPU

Sometimes the NPU does not support certain operators, and it is necessary to force them to run on the CPU:

```
rknn.config(
    target_platform='rk3588',
    op_target={'/sdp/flows.7/Less_output_0': 'cpu'}
)
```

⚠️Common **mistakes in writing** :

```
op_target={'Less': 'cpu'}  # ❌ 错误！Less 是算子类型名，不是输出 tensor 名
```

**Correct writing requirements** :

- The key must be **the output tensor name of the operator** (not the operator type name).
- The output tensor name needs to be obtained through **accuracy analysis.**
- The standard usage of op_target in the official documentation is to specify it by the output tensor name; an undefined way is to specify it in bulk by operator type name.

**Methods to obtain the correct tensor name** :

1. Accuracy analysis returns results
2. Netron Visualization: View Operator Output Edge Names
3. Print `node.output[0]` from the ONNX node.

## IV. Core Findings: The Pseudo-Dynamic Problem

### 4.1 Root cause: The inherent limitations of the tracing mechanism

`torch.onnx.export` exports models based on **the tracing** mechanism by default. It works **by running the model once with your provided example input and recording all tensor operations performed** .

- **Fatal flaw** : Tracing cannot handle conditional branches or loops that depend on the data itself. It can only record the fixed path traversed by the "example input". You can think of it as a screen recording software that only records the entire process of you operating the computer, but doesn't know why you did those operations.
- Although `dynamic_axes` is set, torch.onnx.export uses the tracing mechanism by default to export the model. This mechanism records the tensor shape information on the execution path of the example input and writes this shape information into the ONNX graph.
- The model has an internal dependence on shape: MeloTTS models contain operations such as x.size() that depend on the shape of tensors. During tracing, the specific length of the example input (e.g., 256) is recorded, and subsequent calculations based on this value are fixed into a static graph based on 256.
- **The "pushing effect" of constant folding** : Enabling `do_constant_folding=True` will further pre-calculate the results of all determinable constants in the graph. Since `x_length` has already been fixed as a constant 256 by tracing, calculations such as `y_lengths = 2 * x_length` will be directly folded into a constant 512, thus completely fixing the entire computation graph.
- **The "Limitations" of `dynamic_axes`** : `dynamic_axes` acts more like a marker on the ONNX model's **metadata** , telling the inference engine that "this dimension can theoretically change." However, it **cannot alter the computation graph itself, which is already fixed by tracing** . Therefore, even if you mark `seq_len` , the expected input shape for operators like `Reshape` and `MatMul` within the model is already fixed at 512. When you try to input data with `seq_len=128` , the shape mismatch will naturally result in an error.

### 4.2 Direct cause: x_length was fixed at 256

In the community edition of the `export_onnx` function, x_length is hardcoded as 256:

```
def export_onnx(self, ..., x_length=256, ...):
    # ...
    x_lengths = torch.LongTensor([x_length])
    # ...
```

This **256** is the specific value "recorded" during the tracing process. From this point onward, the entire computation graph is constructed around the premise that "the sequence length is 256", and is further solidified by `do_constant_folding` .

### 4.3 How to verify true dynamics?

Use the ONNX Runtime to input different seq_len values ​​and check if the output shape changes:

```
# 通用验证代码模板
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession('model.onnx')
# 正确构造不同 seq_len 的输入
out1 = sess.run(None, make_inputs(seq_len=128))
out2 = sess.run(None, make_inputs(seq_len=256))
print(out1[0].shape, out2[0].shape)  # 相同=假动态，不同=真动态
```

- If the output shape **is different** → ✅ True Dynamics
- If the output shape **is the same** or **an error occurs** → ❌ Fake Dynamics

**Actual test results** : MeloTTS output is the same → fake dynamics.

**Typical manifestations of pseudo-dynamics** :

- ONNX prints " `dim_param: "seq_len"` → This is just a metadata declaration.
- Netron displays `[1,1,262144]` → `y_lengths = 2 * x_length` → fixed to 512. Internal values ​​are already fixed.
- ONNX Runtime test failed → Unable to handle different seq_len values
- RKNN inference time is fixed → computation graph is constant

### 4.4 Conclusion: Why must it be "completely static"?

- The tracing mechanism solidifies all shape-dependent operations.
- `x_length` is hardcoded as 256, providing a specific fixed value for Tracing.
- Constant folding will further fold based on these fixed calculations.
- Ultimately, the `dynamic_axes` flag is merely theoretical and cannot change the already fixed computation graph.

When this model is exported, its computation graph is already "flattened" into a static model that only recognizes `seq_len=256` . All the settings you make about `seq_lens` in RKNN afterwards are just "communicating" with this fixed static graph.

### 4.5 The Necessary Conditions for True Dynamics and the Compromises of Community Editions

condition | Difficulty
:-- | :--
Modify the model source code to restore `y_lengths = sum(w_ceil)` (the original Duration Predictor). | high
When exporting, `do_constant_folding=False` | middle
Use `torch.jit.script` instead of tracing | Extremely high (MeloTTS contains a large amount of Python control flow, making it almost impossible).

`mmontol/MeloTTS` uses tracing + hard-coding of `y_lengths` to **ensure a high export success rate** . This is an engineering trade-off: sacrificing "perfect dynamism" for "basic usability".

**How to achieve true dynamic output? The** following conditions must be met simultaneously:

1. **Preserve the original duration prediction logic** :

```
# 删除硬编码行！
# y_lengths = torch.FloatTensor([2 * x_length])

# 改回动态计算
w = torch.exp(logw) * x_mask * length_scale
w_ceil = torch.ceil(w)
y_lengths = torch.clamp_min(torch.sum(w_ceil, [1, 2]), 1).long()
```

1. **Ensure that all upsampling operations are performed dynamically based on y_lengths** : there should be no `F.pad(..., max_len)` , and there should be no `interpolate` with a fixed `size=` .
2. **When exporting, use symbolic tracing (not tracing)** : `torch.onnx.export` uses `torch.jit.trace` by default, which cannot handle dynamic control flow. You should use `torch.jit.script` instead (but MeloTTS contains a lot of Python control flow, which may cause it to fail).
3. **Disable constant folding** : `do_constant_folding=False`

### 4.6 MeloTTS Architecture Streaming Analysis

MeloTTS is based on the VITS (VITS2) architecture, and its core features are **non-autoregressive and end-to-end** .

Components | Is it a streaming method? | illustrate
:-- | :-- | :--
Text Encoder | ❌ Non-flow cytometry | Using the Transformer's full attention mechanism, the entire sentence must be seen before the text representation can be output.
Duration Predictor | ❌ Non-flow cytometry | Predicting the duration of each phoneme in frames depends on global text features.
Flow-based Decoder | ❌ Non-flow cytometry | The entire Mel spectrum is generated at once, and T is determined by the duration prediction module.
Vocoder (HiFi-GAN) | ⚠️ Support is conditional | The standard implementation generates the entire graph, and there are causal variants that support streaming synthesis.

**Key bottleneck** : MeloTTS's Decoder must wait until the entire Mel spectrum is fully generated before it can be handed over to the Vocoder. Therefore, even with streaming variants of the Vocoder, in the standard MeloTTS architecture, single-sentence inference cannot be output until the entire spectrum is generated.

**Clarification regarding "streaming synthesis"** : The "streaming synthesis" mentioned in the official MeloTTS documentation is different from frame-by-frame/token-by-token output. According to the official API implementation, the `/tts/stream` interface provides sentence-level streaming responses; the model does not output token-level audio.

ability | Does it support? | illustrate
:-- | :-- | :--
Segmentation based on sentence boundaries | ✅ Support | Long texts are broken down into sentences according to punctuation, synthesized sentence by sentence, and then output. This is the actual meaning of MeloTTS's "streaming synthesis".
Output in advance during single-sentence reasoning | ❌ Not supported | A single sentence must wait until the entire dataset is generated.
Frame-by-frame/token-by-token output | ❌ Not supported | The official documentation explicitly states that the model does not output token-level audio.
Post-processing, cropping, and playback | ✅ Support | After full generation, the data is cropped according to the actual number of frames to improve perceived latency.

## V. INT8 Quantization

### 5.1 What is quantification? Why do we need quantification?

Quantization is the process of converting model weights and activations from FP32 to INT8. It can be understood as "lossy compression": INT8 quantization requires calibration data to statistically analyze the distribution of activation values, calculate the scale and zero point, and determine the mapping method from FP32 to INT8.

**Differences in FP16 vs INT8 quantization:**

- FP16 conversion: No calibration data required, accuracy loss is negligible.
- INT8 quantization: requires calibration data, offers more significant volume compression, but suffers greater loss of accuracy.

**Benefits of INT8 quantization:**

- Model size reduced (129MB → 67MB)
- Reduced memory usage

**The cost of INT8 quantization:**

- Audio quality degrades (noise) in TTS generative tasks.
- Some model structures cannot be quantized using INT8 (e.g., the Encoder fails due to an error caused by the Less operator).
- Reasoning time did not improve significantly.

**The INT8 quantization verification results for this project are as follows:**

Validation item | result
:-- | :--
The Netron display structure remains unchanged, but dtype is changed to int8. | ✔️ Correct
Decoder quantization✅, file size reduced from 129MB to 67MB | ✔️ Meets INT8 quantitative expectations
Changes in reasoning time | ❌ No significant improvement
Playback audio quality | ❌ Noise, unclear
Encoder quantization failed. | ❌ Less operator type conflict, failure.

### 5.1.5 RKNN Quantization Mechanism

RKNN's PTQ (Post-Training Quantization) handles different objects in the model as follows when `do_quantization=True` :

object | Quantifying behavior | Is it controllable?
:-- | :-- | :--
**Model weights** | Default Uniform Quantization INT8 | Fine-grained control can be achieved through hybrid quantization (disable_quantize_layer).
**Model internal activation values** | Default Uniform Quantization INT8 | Determined by the calibration dataset, its behavior is basically fixed.
**Constant nodes in the graph** | Always keep FP32, never quantize. | ❌ Uncontrollable, forever unchanging

**Core rules** :

- When `do_quantization=True` , the weights and activation values ​​inside the model will be quantized to INT8 by default.
- Constant nodes within the graph are never quantized and are always FP32.

**Important supplement** :

- External input data (such as scalars passed to `sdp_ratio` ) can be flexibly specified in terms of data type during inference, and is not forced to be INT8.

### 5.2 Quantization parameters

Python

```
ret = rknn.build(
    do_quantization=True,   # 开启 INT8 量化
    dataset='dataset.txt'   # 校准数据集索引文件——必须提供！
)
```

**Why is calibration data necessary?** Quantization isn't simply about "cutting off decimal places," but rather finding an optimal mapping method. For example, given a set of floating-point numbers [0.1, 0.5, 1.2, 3.8], to compress them to the integer range of 0-255, we need to know the maximum and minimum values ​​of this set of numbers to calculate the mapping ratio. **Calibration data is the "sample" shown to the quantization tools, allowing them to understand the data's distribution range.**

### 5.3 Calibration Data Format and Generation Specifications

The content format of dataset.txt should use a .npy file.

Key rules:

- Each line represents a complete sample, containing all the inputs for that sample.
- Number of files = Number of inputs to the ONNX model (8 Encoders, including `ja_bert` ; 6 Decoders)
- The order must be consistent with the ONNX input order.
- The shape and dtype of each `.npy` file must exactly match the ONNX input.

> Note: Whether ja_bert appears in the ONNX input depends on the actual exported ONNX file, and the number of calibration data files must match it. Run the following command to confirm: `python -c "import onnx; m=onnx.load('encoder.onnx'); print([i.name for i in m.graph.input])"`

**Why use .npy instead of .npz?** Testing showed that RKNN's support for .npz files is unstable; using a list of .npy files is more reliable.

**Best practices for generating calibration data** :

rule | illustrate
:-- | :--
Use np.random.uniform(-1, 1) | Stable and controllable, will not produce NaN
Avoid np.random.randn() | Extreme values ​​or NaN may occur.
Data types should be consistent with ONNX inputs. | Avoid introducing additional errors through type conversion (int64 / float32)

**Why use a uniform distribution instead of a normal distribution?**

- `np.random.randn()` : Executes a standard normal distribution, which may produce extreme values ​​(such as 100) or even NaN (numerical overflow).
- `np.random.uniform(-1, 1)` `: The range is bounded and always stable.
- Quantitative calibration only requires **the approximate distribution range** of the data; the specific values ​​are not important.

### 5.4 Common Quantitative Errors and Troubleshooting

error message | reason | Solution
:-- | :-- | :--
`The input num: 8 not match 7` | The number of calibration data files does not match the actual number of ONNX inputs. | Confirm the actual number of ONNX inputs and adjust the calibration data accordingly.
`cannot convert float NaN to integer` | Random data generates `NaN` | Replace `randn` with `np.random.uniform(-1, 1)`
`Unsupport file` | `.npz` format is incompatible | list of `.npy` files to use
`ElementwiseLogical unsupported` | INT8 and FP32 type conflict | Use FP16 (without `--do_quant` ) to roll back

### 5.5 Encoder INT8 quantization failed: Less operator type conflict

**Error message** :

```
ElementwiseLogical: unsupported A type: INT8, B type: FLOAT!
Op type:Less, name: Less:/sdp/flows.7/Less, fallback cpu failed.
```

**Analysis based on core mechanisms** :

`sdp_ratio` is an external input scalar that is passed in during inference. The Less operator compares it with an in-graph constant. According to the core quantization mechanism:

- The activation values ​​within the model are quantized to INT8, `sdp_ratio` , as input, is also quantized to INT8.
- Intra-graphical constants (derived from the sdp_ratio parameter, and permanently maintained at FP32).
- The NPU does not support mixed INT8 and FP32 operations.

**The complete error chain** :

```
sdp_ratio（外部输入，量化后转为 INT8）
    ↓
Less 比较算子（NPU 的 ElementwiseLogical）
    ↓
图内常量（由 sdp_ratio 参数固化而来）是图内硬编码 FP32
    ↓
❌ NPU 不支持 INT8 + FP32 混合运算
    ↓
尝试 fallback 到 CPU 执行 → 失败
    ↓
rknn_run 返回 -1
```

**Why are common solutions ineffective?**

Tried solutions | Why is it ineffective?
:-- | :--
op_target={'Less': 'cpu'} | ❌ The key must be the output tensor name, not the operator type name; this is an illegal syntax.
op_target={'ElementwiseLogical': 'cpu'} | ❌ Same as above, illegal spelling
Hybrid quantization custom_quantize_layers: float16 | ⚠️ Changing only the operator's computational precision without altering the input tensor type will still result in conflicts.
Scalars are transmitted to FP32, others to INT8. | ❌ Runtime verification of dtype must be consistent; intercept directly.

### 5.6 Why did the Decoder's INT8 quantization succeed?

The Decoder's input consists entirely of tensors of the same type generated internally by the model; no external scalar inputs are introduced that need to be compared with the FP32 constants within the graph. Therefore, scenarios involving mixed INT8 and FP32 operations will not occur, and quantization can be completed smoothly.

The key difference between the Encoder and the sdp_ratio is that `sdp_ratio` is an external scalar passed in by the user, which is quantized into INT8, while the graph constant (which is fixed by the sdp_ratio parameter) is a graph hard-coded FP32. The two clash at the Less operator, triggering a type conflict.

## VI. Pitfalls in Dynamic Dimensions (Runtime)

### 6.1 Process

1. Basic version: Decoder uses **a static, fixed-shape RKNN model** . The original code requires no additional dimension configuration and inference runs normally without crashes.
2. After switching to the dynamic shape model (adding `--seq_lens 256` to the conversion command to enable dynamic dimensions), without any code adaptation, the program crashed immediately: `std::out_of_range` , with the error index being an extremely large unsigned number `18446744073709551615` ;
3. After investigating and eliminating quantization factors: Regardless of whether INT8 quantization is enabled, the dynamic model crashes, while the static model works normally, confirming that the problem is only related to the dynamic shape mechanism;
4. Pitfall 1: Mistakenly assuming that the `rknn_input` structure has `dims/n_dims` members and directly assigning values, resulting in a compilation error, when the structure itself does not have these two fields;
5. Pitfall 2: Misuse of the 4-parameter version of the `rknn_set_input_shape` function, which does not match the function signature declared in the current RKNN 2.3.2 SDK header file, resulting in compilation failure;
6. After consulting the SDK standard interface and switching to the two-parameter standard API that uses the `rknn_tensor_attr` structure to pass parameters, and adding the logic for setting dynamic dimensions, the program ran normally and the crash disappeared.

### 6.2 Root Causes of the Core Problem

1. **RKNN dynamic shape model enforces constraints** : static models have tensor dimensions fixed during compilation, and the SDK uses the compiled dimensions for inference by default; **dynamic models require manual specification of the actual input dimensions for each inference round** , otherwise the SDK will continue to use the maximum sequence length (256) specified when transforming the model to parse the data.
2. **The failure to set the true dimension caused a chain of failures** : the NPU incorrectly parsed the input tensor according to the maximum length, the inference output data was completely messed up, the variable `predicted_lengths_max_real` used to allocate the audio output length was calculated as a negative number; when the negative int was forcibly converted to `size_t` , it overflowed into an excessively large value, and accessing the vector index triggered `std::out_of_range` crash.
3. **Reasons for the failure of the first two code solutions** :
    - Solution 1: Directly modify `inputs[0].dims` : The `rknn_input` structure does not have dimension members, resulting in a compilation error at the syntax level;
    - Option 2: Parameter `rknn_set_input_shape` : Adapts to higher versions of the RKNN API, but is incompatible with the current 2.3.2 SDK interface definition.

### 6.3 Final Solution

1. Interface adaptation: Uses the standard dynamic dimension API supported by the current RKNN 2.3.2 `int rknn_set_input_shape(rknn_context ctx, rknn_tensor_attr* attr)` ;
2. Dynamically update the dimensions of each input tensor before inference:
    - Copy `app_ctx->input_attrs` tensor attributes saved during initialization;
    - Modify `n_dims` and `dims` in `attr` to reflect the true dimensions of this inference;
    - Call `rknn_set_input_shape` to send the updated dimensions to the RKNN context;
3. The original logic for copying all inputs, allocating memory using malloc, inference, copying outputs, and releasing memory is retained. Only the dimension configuration code is added, with no other business logic changes.
4. Results: The NPU infers based on the actual valid sequence length, outputs normal values, `predicted_lengths_max_real` will not be negative, completely solving the vector out-of-bounds crash problem, while retaining the core advantages of dynamic shape model in terms of sentence length adaptation, speed improvement, and memory saving.

## VII. Comparison of Options

### 7.1 Comparison of various solutions

plan | principle | Effect | risk | feasibility
:-- | :-- | :-- | :-- | :--
Post-processing cropping + streaming playback | After the reasoning is complete, the frame rate is truncated to the actual number of frames, and the first few frames are played in advance | Improve perceived latency | none | ⭐⭐⭐⭐⭐
INT8 Quantization | Quantize the FP16 model to INT8 | The effectiveness of model volume compression depends on the degree of operator support. | Precision loss, audio quality degradation in TTS tasks | ⭐⭐⭐
Only change `seq_lens` | I hope the text is short and fast. | ❌ Invalid (Internal calculation graph is fixed, resulting in pseudo-dynamics) | none | ✘
Only change `dim_param` | Surface modification | ❌ Invalid (internal still static) | none | ✘

### 7.2 Recommended Path

- **Recommended approach** : Use the FP16 model (clear sound quality, stable and usable), combined with post-processing trimming to optimize perceived latency.
- **Alternative solution** : INT8 quantization (reduced size, but audio quality degraded for TTS tasks)
- **Not recommended** : Continuing to attempt dynamic shapes (the model's internal structure is fixed and cannot achieve true dynamics).

### 7.3 Facts Confirmed for This Project

fact | illustrate
:-- | :--
FP16 Decoder Available | The audio quality is clear, and the reasoning time is approximately 1.8–2.2 seconds, regardless of the text length.
INT8 Decoder is available | There is sound but there is background noise, and the reasoning time has not improved significantly.
Encoder INT8 quantization failed. | `Less` operator INT8/FP32 type conflict, unresolved.
Dynamic shape invalid | The tracing mechanism is embedded during ONNX export; `dynamic_axes` is merely a metadata marker.
Calibration data | Must be derived from real reasoning; random number calibration is invalid.

### 7.4 Conclusion

If MeloTTS must be used: accept the current latency (1.8–2.2s) and optimize the user experience through engineering techniques such as preloading, caching, and post-processing playback.

If a different model is available: This project has not tested other TTS architectures. You will need to port and test them yourself. Latency data cannot be provided.

## VIII. Final Summary

### 8.1 Final Solution and Model Combination

**The model used in this project**

Model | plan | illustrate
:-- | :-- | :--
Encoder | FP16 Static | Fixed at 256 frames, without `--do_quant`
Decoder | FP16 Fixed Length (256) | The `dim_param` flag (metadata is dynamic) is retained, but it is internally fixed.

How it works during reasoning:

1. Enter text → padding to frame 256 (no matter how short the text is, pad it to frame 256).
2. Encoder (FP16) → Output Features
3. Decoder (FP16) → Generate audio (fixed 512 frames)

Inference time is independent of text length and is fixed at 1.8–2.2 seconds. This is determined by the architecture and cannot be solved by conversion.

Quantitative results:

Model | Quantification results | illustrate
:-- | :-- | :--
Encoder INT8 | ❌ Failure | `Less` operator INT8/FP32 type conflict, unresolved.
Decoder INT8 | ✅ Volume compression successful | Compressing from 129MB to 67MB resulted in sound but with significant background noise, and no noticeable improvement in inference time.

Completion status:

Components | state
:-- | :--
Encoder → RKNN (FP16) | ✅ Conversion successful, sound quality normal
Decoder → RKNN (FP16) | ✅ Conversion successful, clear sound quality
Decoder → RKNN (INT8) | ✅ Conversion successful, sound is present but with heavy static.
Encoder → RKNN (INT8) | ❌ Quantization failed, `Less` operator type conflict

> This project utilizes the FP16 complete solution. While the INT8 Decoder offers a size advantage, its audio quality is significantly reduced, and its inference time is not noticeably improved; therefore, it is not recommended for production use.

### 8.2 Quick Reference for Common Errors

error message | root cause
:-- | :--
invalid expand shape | The target shape for the Expand operation includes dim_param
MatMul dimension mismatch | A shape configuration error exists in dynamic_input.
The input number does not match. | The number of calibration data files is incorrect (8 vs 7).
cannot convert float NaN | NaN appeared in the calibration data.
ElementwiseLogical unsupported | INT8 and FP32 type conflict
std::out_of_range(18446744073709551615) | The dynamic model does not have a defined true dimension, and negative numbers overflow into an excessively large size_t.

### 8.3 Core Understanding

1. MeloTTS is a sound quality-first model, not a speed-first model. An inference time of 1.8–2.2 seconds is the norm due to its architecture.
2. The main value of quantization (INT8) is to reduce file size (129MB → 67MB), with limited improvement in inference time.
3. In the current export mode, `dynamic_axes` + `seq_lens` is "paper dynamic".
4. `torch.jit.trace` is the root of pseudo-dynamics because it fixes all shape-related values.
5. The root cause of the Less operator error is that the activation value inside the model after quantization is INT8, while the constant nodes in the graph (which are fixed by the sdp_ratio parameter) remain FP32. The NPU does not support mixed operations of INT8 and FP32, which causes the Less operator to be unable to be executed on the NPU.
6. The most effective optimization path is post-processing trimming + streaming playback – zero model changes, significantly improving perceived latency.
7. Don't obsess over low latency with non-autoregressive architectures—the wrong choice is more fatal than a technical problem. If a latency of &lt;500ms is required, evaluate autoregressive TTS such as FastSpeech2.
8. FP16 is a safe alternative to INT8: it does not require calibration data, does not cause type conflicts, and is stable and usable.

### 8.4 Key Documents and Tools

Files/Tools | illustrate
:-- | :--
melo/api.py | The modified export_onnx function (including dynamic_axes and constant folding)
convert_dynamic.py | Dynamic RKNN transformation script (hard-coded shape rules, supports encoder/decoder)
generate_calibration_data.py | Generate quantization calibration data (.npy file)
dataset.txt | The index pointing to the calibration data file during quantization
encoder-ZH_MIX_EN.onnx | Dynamic ONNX model (8 inputs, including ja_bert)
decoder-ZH_MIX_EN.onnx | Dynamic ONNX model (6 inputs)
decoder-ZH_MIX_EN.rknn | Successfully converted dynamic RKNN model

**The main pitfalls I encountered:**

pit | nature
:-- | :--
Changes in the number of `ja_bert` inputs | This depends on whether the Japanese module was effectively used in the calculation during ONNX export; the actual exported ONNX input list should be used as the reference. The number of calibration data files must match this.
`Expand` error | The target shape contains a dynamic placeholder `dim_param` , and RKNN constant folding cannot determine the specific shape. Enabling `do_constant_folding=True` will fold it into a specific value.
`ScatterND` error | The Encoder's internal SDP module uses `ScatterND + Slice` to construct shapes, but `-1` cannot be eliminated by the RKNN constant folding, causing dynamic transformation failure. Therefore, the Encoder ultimately adopts a static solution.
Multi-length Decoder Failure | RKNN's dynamic shape is a "preset menu" mode. Multiple length presets cause shape inference errors. Locking a single length `seq_lens=256` solves the problem.
Calibration data `NaN` | `np.random.randn()` may produce extreme values ​​or `NaN` ; instead, use `np.random.uniform(-1, 1)` .
Quantization `input num` does not match | The number of calibration data files does not match the actual number of ONNX inputs.

The command to confirm the actual number of ONNX inputs is as follows:

```
python -c "import onnx; m=onnx.load('model.onnx'); print([i.name for i in m.graph.input])"
```

### 8.5 Transferable General Skills🟢

#### ONNX Export General Skills

parameter | General knowledge points
:-- | :--
opset_version | The opset version determines the set of available operators; version 16 offers better support for dynamic shapes. However, higher isn't always better—a balance needs to be struck between operator support and stability.
do_constant_folding | Enabling this feature will pre-calculate results for all subgraphs with constant inputs. Side effect: This may result in inputs being removed (e.g., all-zero tensors), requiring adaptation in subsequent processes.
keep_initializers_as_inputs | Used in conjunction with `do_constant_folding`. Setting it to `False` will remove constants from the input list, affecting the number of subsequent `graph.input` values.
dynamic_axes | This declares which dimensions are dynamic. Key takeaway: This is only a metadata declaration and does not guarantee that the internal computation graph actually supports dynamic changes.

**Understanding the ONNX model structure** :

- `dim_value` vs `dim_param` : `dim_value` is a fixed value, while `dim_param` is a dynamic placeholder. It's normal for both to coexist.
- Unnamed `dim_param` (such as `Addlogw_dim_0` ) will cause RKNN shape inference to fail. All dynamic dimensions must be explicitly named.
- `graph.input` and `graph.output` : Using `onnx.load()` to view the model's input and output is a fundamental skill for troubleshooting.

**The method to verify true dynamics** : Do not trust the "paper declaration" of `dim_param` ; you must verify it using actual inference with ONNX Runtime.

#### RKNN converts general skills

- **Key takeaway** : RKNN does not support completely free dynamic dimensions; all possible shape combinations must be listed during transformation using `dynamic_input` .
- **General recommendation** : First verify feasibility with a certain length, then gradually expand it.
- **`optimization_level`** : Values ​​range from 0 to 3. Setting it to 0 disables optimization, eliminates interference, and is suitable for debugging. First set it to 0 to confirm the model can be converted, then gradually increase it.
- **General rule for `op_target`** : The key must be the output tensor name, not the operator type name. Specify the required name using `onnx.load()` and printing node information.

#### INT8 Quantitative General Skills

- The core quantization mechanism is applicable to all RKNN PTQ quantizations, not just MeloTTS.
- Calibration data determines the success or failure of quantization: the quantity, order, shape, and data type of ONNX inputs must be precisely matched.
- Troubleshooting method: `python -c "import numpy as np; data=np.load('sample.npy'); print(data.shape, data.dtype)"`

#### Debugging Methodology

tool | use | Universality
:-- | :-- | :--
**Netron** | Visualize the model structure and view the input and output shapes. | 🟢 All models
**ONNX Runtime** | Verify whether the ONNX model can reason correctly. | 🟢 All models
onnx.load() + print() | View model metadata (input/output names, shapes) | 🟢 All models
rknn-toolkit2 logs | View quantification details and operator rollback information. | 🟢 All RKNN projects

**Common commands for model analysis** :

```
# 查看输入输出
python -c "import onnx; m=onnx.load('model.onnx'); print([i.name for i in m.graph.input])"
python -c "import onnx; m=onnx.load('model.onnx'); print(m.graph.output[0])"

# 查看特定算子节点
python -c "import onnx; m=onnx.load('model.onnx'); [print(n.name) for n in m.graph.node if n.op_type=='MatMul']"
```

**Binary search method for locating problems** :

1. First, use a single-length (static) verification model to confirm whether it can be converted.
2. Try expanding gradually with multiple lengths (dynamically).
3. First, verify the floating-point model with quantization disabled → then try quantization again.

**General workflow template** :

```
1. 导出 ONNX
   ├── 正确设置 opset_version
   ├── 声明 dynamic_axes（所有动态维度命名）
   └── 验证 ONNX 可用（ONNX Runtime 推理）

2. 转换 RKNN
   ├── 先用单长度浮点验证
   ├── 再尝试多长度浮点
   └── 最后尝试量化（可能需要回退到 FP16）

3. 量化调试
   ├── 检查校准数据（数量、顺序、dtype）
   ├── 排查算子回退
   └── 必要时放弃 INT8，使用 FP16
```

### 8.6 MeloTTS-specific knowledge (non-transferable)

The following knowledge **applies only to this MeloTTS project** and is not universal:

Knowledge | illustrate
:-- | :--
`y_lengths = 2 * x_length` (hard-coded) | This is the hard-coded default value. If it is changed to dynamic calculation (such as `torch.sum(w_ceil)` ), the ONNX export will introduce operators such as `ScatterND` that are not easily transformed by RKNN, resulting in a higher risk of transformation failure.
Changes in the number of `ja_bert` inputs | Whether `ja_bert` appears in the ONNX input depends on the actual exported ONNX file, and the number of calibration data files must match it.
`mmontol/MeloTTS` warehouse | The community-modified version adds ONNX export functionality to the official repository, while also supporting non-official repositories.
`Less` operator conflicts with `sdp_ratio` type. | During INT8 quantization, the external input `sdp_ratio` is forcibly converted to INT8, while the threshold constant (e.g., 0.2) is an in-figure FP32 constant. The NPU does not support mixed-type logical comparisons. This is not a model design flaw, but an inherent limitation of the RKNN PTQ quantization rules.
The decoder loop has a fixed number of levels (4). | The VITS architecture uses a streaming generation design with a fixed `n_flows` of 4 layers. The number of layers can be reduced by modifying the source code, but this will significantly degrade sound quality and make the RKNN power conversion uncertain.
The output length is fixed `[1,1,262144]` | During ONNX export, the tracing mechanism fixes `y_lengths` as a constant `2 * x_length` (512), corresponding to an audio length of `512 * 512 = 262144` `dynamic_axes` is merely metadata and cannot alter the fixed computation graph.
`MeCab` + `unidic` dependency | MeloTTS multilingual support requires a Japanese word segmenter and dictionary, which can be solved `pip install unidic-lite` . This is not a model design issue.

### 8.7 Key Terms

the term | explain
:-- | :--
**ONNX** | Open Neural Network Exchange Format (ORF) is a common standard format for exporting models from frameworks such as PyTorch and TensorFlow, serving as an intermediary bridge between PyTorch and RKNN.
**RKNN** | Rockchip's proprietary model format ( `.rknn` ) for its NPU platform enables hardware-accelerated inference on devices such as the RK3588 and RK3566.
**`dim_value`** | In ONNX tensor shape descriptions, fixed values ​​indicate that the dimension is fixed to a specific integer and cannot be changed at runtime. For example, ` `dim_value: 1` means that the dimension will always be 1.
**`dim_param`** | Symbolic placeholders in ONNX tensor shape descriptions, named as strings, indicate that the dimension is theoretically variable. For example, `dim_param: "seq_len"` . However, this flag only affects the shape declaration of ONNX I/O nodes and does not change the internal computation graph. It has no effect if the internal computation graph is already fixed by tracing.
**`dynamic_axes`** | The parameters exported by PyTorch to ONNX are used to declare which dimensions in the model input/output are dynamic, and will generate `dim_param` tags for I/O nodes. For example, `{"x": {1: "seq_len"}}` indicates that the second dimension of `x` can change during inference.
**Constant folding** | Graph optimization techniques utilize static computation, which relies only on the graph portion defined by constant initialization expressions. The results are calculated at compile time, eliminating the need for runtime computation. For example, `y_lengths = 2 * x_length` , if `x_length` is a constant 256, then `y_lengths` is collapsed to a constant 512.
**`onnxsim`** | ONNX model simplification tools optimize ONNX models through constant folding, redundant node elimination, and operator fusion, potentially fixing `dim_param` into `dim_value`
**`dynamic_input`** | The parameters used during RKNN transformation are used to configure the model to support dynamic shape input. RKNN needs to list all possible shape combinations during transformation (preset menu mode), and the NPU generates optimization instructions for each combination, selecting from the presets during inference.
**INT8 Quantization** | Mapping model weights and activations from FP32 to INT8 reduces the model size to 1/4 of FP32 (a 75% reduction), increases inference speed by 3-5 times, and keeps accuracy loss manageable.
**FP16 Quantization** | Converting the model from FP32 to FP16 (half-precision floating-point) reduces the size by approximately 50%, with negligible loss of accuracy.
**Calibration data** | The dataset used for INT8 quantization is the statistical distribution of activation values ​​across different layers of the model. The quantization tool uses this dataset to calculate the scale factor and zero point, determining the mapping from FP32 to INT8. Calibration data must come from real-world inference scenarios; random number calibration can be performed using `build`, but the model output may be abnormal.
**`dataset.txt`** | The index file for calibration data during RKNN quantization, with each line containing a complete sample and the paths to all `.npy` files containing the input tensors for that sample. The number of files must match the number of ONNX model inputs, and their order must match the order of `graph.input`
**`MatMul`** | Matrix multiplication is one of the most fundamental computational operations in deep learning. It is prevalent in TTS models, but is sensitive to tensor shape, and is prone to `dimension mismatch` errors under multi-length dynamic shapes.
**`ScatterND`** | The ONNX operator writes the updated value to a specified position in the tensor based on the index. The SDP module of the MeloTTS Encoder uses this operator to construct shapes, and its output shape depends on dynamic indexing, which is one of the reasons why dynamic transformations in the Encoder fail.
**`Expand`** | The ONNX operator broadcasts a tensor to a target shape. When the target shape contains `dim_param` , RKNN constant folding cannot determine the specific shape, reporting `invalid expand shape` ". Enabling `do_constant_folding=True` will fold it to a specific value.
**SDP** | The Stochastic Duration Predictor, an internal module of the MeloTTS Encoder, is used to predict the duration of each phoneme. This module uses `ScatterND` and `Slice` to construct shapes and is a major cause of dynamic transformation failures in the Encoder.

### Repository Link

- MeloTTS: https://github.com/kyshipit/MeloTTS
- [MeloTTS RKNN Quantization Deployment Troubleshooting Log](https://github.com/kyshipit/tech-notes/blob/main/deploy/melotts-rknn%E9%87%8F%E5%8C%96%E9%83%A8%E7%BD%B2%E8%B8%A9%E5%9D%91%E8%AE%B0%E5%BD%95.md) : https://github.com/kyshipit/tech-notes
